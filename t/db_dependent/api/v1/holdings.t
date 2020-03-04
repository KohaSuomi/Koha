#!/usr/bin/env perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Test::More tests => 5;
use Test::Mojo;
use t::lib::Mocks;
use t::lib::TestBuilder;

use DateTime;

use MARC::Record::MiJ;

use C4::Context;
use C4::Biblio;
use C4::Holdings;

use Koha::Biblios;
use Koha::BiblioFrameworks;
use Koha::Database;
use Koha::Holdings;
use Koha::MarcSubfieldStructures;
use Koha::Patrons;

# FIXME: sessionStorage defaults to mysql, but it seems to break transaction handling
# this affects the other REST api tests
t::lib::Mocks::mock_preference( 'SessionStorage', 'tmp' );

my $builder = t::lib::TestBuilder->new();
my $schema  = Koha::Database->new->schema;

my $t = Test::Mojo->new('Koha::REST::V1');
my $tx;

subtest "list() tests" => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my ($patron, $session_patron) = create_user_and_session( { authorized => 0 } );

    Koha::Holdings->search->delete;

    subtest 'no holdings' => sub {
        plan tests => 3;

        $tx = $t->ua->build_tx( GET => '/api/v1/holdings' );
        $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
        $t->request_ok( $tx )->status_is( 200 )
            ->json_is( [] );
    };


    my $biblionumber = create_biblio( 'test' );

    subtest 'one holding' => sub {
        plan tests => 3;

        my $holding = create_holding( $biblionumber );
        my $holdings_full = Koha::Biblios->find( $biblionumber )->holdings_full();
        $tx = $t->ua->build_tx( GET => '/api/v1/holdings' );
        $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
        $t->request_ok( $tx )->status_is( 200 )
            ->json_is( $holdings_full );
    };

    subtest 'multiple holdings' => sub {
        plan tests => 3;

        my $holding2 = create_holding( $biblionumber );
        my $holding3 = create_holding( $biblionumber );

        my $holdings_full = Koha::Biblios->find( $biblionumber )->holdings_full();
        $tx = $t->ua->build_tx( GET => '/api/v1/holdings' );
        $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
        $t->request_ok( $tx )->status_is( 200 )
            ->json_is( $holdings_full );
    };

    subtest 'test search parameters' => sub {
        plan tests => 4;

        my $branchcode = $builder->build( { source => 'Branch' } )->{branchcode};
        my $holding = create_holding( $biblionumber, $branchcode, $branchcode );
        my $holdings_full = Koha::Biblios->find( $biblionumber )->holdings_full({
            holdingbranch => $branchcode
        });
        $tx = $t->ua->build_tx( GET => '/api/v1/holdings?holdingbranch=' . $branchcode );
        $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
        $t->request_ok( $tx )->status_is( 200 )
            ->json_is( $holdings_full );

        subtest 'test datecreated starts-with search' => sub {
            plan tests => 3;

            my ( $datecreated_starts_with ) = $holding->datecreated =~ /^(\d{4})/;
            $tx = $t->ua->build_tx( GET => '/api/v1/holdings?holdingbranch=' .
                $branchcode . '&datecreated=' . $datecreated_starts_with );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
            $t->request_ok( $tx )->status_is( 200 )
                ->json_is( $holdings_full );
        };
    };

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my ($patron, $session_patron) = create_user_and_session( { authorized => 0 } );

    Koha::Holdings->search->delete;

    $tx = $t->ua->build_tx( GET => '/api/v1/holdings/0' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
    $t->request_ok( $tx )->status_is( 404 );

    my $biblionumber = create_biblio( 'test' );

    my $holding = create_holding( $biblionumber );
    my $holdings_full = Koha::Biblios->find( $biblionumber )->holdings_full();
    $tx = $t->ua->build_tx( GET => '/api/v1/holdings/'.$holding->holding_id );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
    $t->request_ok( $tx )->status_is( 200 )
        ->json_is( $holdings_full->[0] );

    my $record;
    subtest 'test different content-types' => sub {
        plan tests => 4;

        subtest 'application/json' => sub {
            plan tests => 4;
            $tx = $t->ua->build_tx( GET => '/api/v1/holdings/'.$holding->holding_id
                                        => { Accept => 'application/json' }
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
            $t->request_ok( $tx )->status_is( 200 )
              ->json_is( '/holding_id' => $holding->holding_id )
              ->json_is( '/metadata/metadata' => $holding->metadata->metadata );
        };

        subtest 'application/marc' => sub {
            plan tests => 3;
            $record = $holding->metadata->record;
            $tx = $t->ua->build_tx( GET => '/api/v1/holdings/'.$holding->holding_id
                                        => { Accept => 'application/marc' }
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
            $t->request_ok( $tx )->status_is( 200 )
              ->content_is( $record->as_usmarc );
        };

        subtest 'application/marc-in-json' => sub {
            plan tests => 3;
            $record = $holding->metadata->record;
            $tx = $t->ua->build_tx( GET => '/api/v1/holdings/'.$holding->holding_id
                                        => { Accept => 'application/marc-in-json' }
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
            $t->request_ok( $tx )->status_is( 200 )
              ->json_is( Mojo::JSON::decode_json($record->to_mij) );
        };

        subtest 'application/marcxml+xml' => sub {
            plan tests => 3;
            $record = $holding->metadata->record;
            $tx = $t->ua->build_tx( GET => '/api/v1/holdings/'.$holding->holding_id
                                        => { Accept => 'application/marcxml+xml' }
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
            $t->request_ok( $tx )->status_is( 200 )
              ->content_is( $record->as_xml_record );
        };

    };

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my ($patron, $session_patron) = create_user_and_session( { authorized => 0 } );
    my ($librarian, $session_librarian) = create_user_and_session( { authorized => 1 } );

    my $branchcode1 = $builder->build( { source => 'Branch' } )->{branchcode};
    my $branchcode2 = $builder->build( { source => 'Branch' } )->{branchcode};
    create_framework();

    Koha::Holdings->search->delete;

    my $biblionumber = create_biblio( 'test' );
    my $biblio = Koha::Biblios->find( $biblionumber );
    my $biblioitemnumber = $biblio->biblioitem->biblioitemnumber;

    my $holding_marc = MARC::Record->new();
    $holding_marc->encoding('utf8');
    C4::Biblio::UpsertMarcSubfield( $holding_marc, '852', 'b', $branchcode1 );
    C4::Biblio::UpsertMarcSubfield( $holding_marc, '852', 'c', $branchcode2 );
    my $record = $holding_marc;

    subtest 'test unauthorised access' => sub {
        plan tests => 4;
        $tx = $t->ua->build_tx( POST
            => '/api/v1/holdings'
            => { 'Content-Type' => 'application/marc' }
            => $record->as_usmarc
        );
        $t->request_ok( $tx )->status_is( 401 );

        $tx = $t->ua->build_tx( POST
            => '/api/v1/holdings'
            => { 'Content-Type' => 'application/marc' }
            => $record->as_usmarc
        );
        $tx->req->cookies( { name => 'CGISESSID', value => $session_patron } );
        $t->request_ok( $tx )->status_is( 403 );
    };

    subtest 'test required parameters' => sub {
        plan tests => 2;

        subtest 'missing biblionumber' => sub {
            plan tests => 3;

            $tx = $t->ua->build_tx( POST
                => '/api/v1/holdings/'
                => {
                    'Accept'       => 'application/json',
                    'Content-Type' => 'application/marc'
                   }
                => $record->as_usmarc
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_librarian } );
            $t->request_ok( $tx )->status_is( 400 )
              ->json_like('/error' => qr/biblionumber/);
        };

        subtest 'biblionumber given but no such biblio exists' => sub {
            plan tests => 3;

            C4::Biblio::UpsertMarcSubfield( $record, '999', 'c', -1 );
            $tx = $t->ua->build_tx( POST
                => '/api/v1/holdings/'
                => {
                    'Accept'       => 'application/json',
                    'Content-Type' => 'application/marc'
                   }
                => $record->as_usmarc
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_librarian } );
            $t->request_ok( $tx )->status_is( 404 )
                ->json_like('/error' => qr/biblionumber/);
        };
    };

    C4::Biblio::UpsertMarcSubfield( $holding_marc, '999', 'c', $biblionumber );
    C4::Biblio::UpsertMarcSubfield( $holding_marc, '999', 'd', $biblioitemnumber );
    $record = $holding_marc;

    subtest 'test different content-types' => sub {
        plan tests => 4;

        subtest 'application/json (Accept-header only)' => sub {
            plan tests => 3;

            $tx = $t->ua->build_tx( POST
                => '/api/v1/holdings/'
                => {
                    'Accept'       => 'application/json',
                    'Content-Type' => 'application/marcxml+xml'
                   }
                => $record->as_xml_record
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_librarian } );
            $t->request_ok( $tx )->status_is( 201 );

            my $holdings_full = Koha::Biblios->find( $biblionumber )->holdings_full();

            $t->json_is( $holdings_full->[0] );
        };

        subtest 'application/marc' => sub {
            plan tests => 3;
            $record = $holding_marc;
            $tx = $t->ua->build_tx( POST
                => '/api/v1/holdings/'
                => {
                    'Accept'       => 'application/marc',
                    'Content-Type' => 'application/marc'
                   }
                => $record->as_usmarc
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_librarian } );
            $t->request_ok( $tx )->status_is( 201 );

            my ( $holding_id ) = $tx->res->headers->header('Location') =~ /(\d+)$/;
            C4::Biblio::UpsertMarcSubfield( $record, '999', 'e', $holding_id );

            $t->content_is( $record->as_usmarc );
        };

        subtest 'application/marc-in-json' => sub {
            plan tests => 3;
            $record = $holding_marc;
            $tx = $t->ua->build_tx( POST
                => '/api/v1/holdings/'
                => {
                    'Accept'       => 'application/marc-in-json',
                    'Content-Type' => 'application/marc-in-json'
                   }
                => json => Mojo::JSON::decode_json( $record->to_mij )
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_librarian } );
            $t->request_ok( $tx )->status_is( 201 );

            my ( $holding_id ) = $tx->res->headers->header('Location') =~ /(\d+)$/;
            C4::Biblio::UpsertMarcSubfield( $record, '999', 'e', $holding_id );

            $t->json_is( Mojo::JSON::decode_json($record->to_mij) );
        };

        subtest 'application/marcxml+xml' => sub {
            plan tests => 3;
            $record = $holding_marc;
            $tx = $t->ua->build_tx( POST
                => '/api/v1/holdings/'
                => {
                    'Accept'       => 'application/marcxml+xml',
                    'Content-Type' => 'application/marcxml+xml'
                   }
                => $record->as_xml_record
            );
            $tx->req->cookies( { name => 'CGISESSID', value => $session_librarian } );
            $t->request_ok( $tx )->status_is( 201 );

            my ( $holding_id ) = $tx->res->headers->header('Location') =~ /(\d+)$/;
            C4::Biblio::UpsertMarcSubfield( $record, '999', 'e', $holding_id );

            $t->content_is( $record->as_xml_record );
        };

    };

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {
    plan skip_all => 'not implemented';

    $schema->storage->txn_begin;
    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {
    plan skip_all => 'not implemented';

    $schema->storage->txn_begin;
    $schema->storage->txn_rollback;
};

sub create_biblio {
    my ( $title ) = @_;

    $title //= join('', map{('a'..'z','A'..'Z',0..9)[rand 62]} 0..8);
    my $record = MARC::Record->new();
    my $field = MARC::Field->new('245','','','a' => $title);
    $record->append_fields( $field );
    my ($biblionumber) = C4::Biblio::AddBiblio($record, '');

    return $biblionumber;
}

sub create_framework {
    my ( $frameworkcode ) = @_;

    $frameworkcode //= 'HLD';
    my $existing_mss = Koha::MarcSubfieldStructures->search({frameworkcode => $frameworkcode});
    $existing_mss->delete() if $existing_mss;
    my $existing_fw = Koha::BiblioFrameworks->find({frameworkcode => $frameworkcode});
    $existing_fw->delete() if $existing_fw;
    Koha::BiblioFramework->new({
        frameworkcode => $frameworkcode,
        frameworktext => 'Holdings'
    })->store();
    Koha::MarcSubfieldStructure->new({
        frameworkcode => $frameworkcode,
        tagfield => 852,
        tagsubfield => 'b',
        kohafield => 'holdings.holdingbranch'
    })->store();
    Koha::MarcSubfieldStructure->new({
        frameworkcode => $frameworkcode,
        tagfield => 852,
        tagsubfield => 'c',
        kohafield => 'holdings.location'
    })->store();
    Koha::MarcSubfieldStructure->new({
        frameworkcode => $frameworkcode,
        tagfield => 999,
        tagsubfield => 'c',
        kohafield => 'biblio.biblionumber'
    })->store();
    Koha::MarcSubfieldStructure->new({
        frameworkcode => $frameworkcode,
        tagfield => 999,
        tagsubfield => 'd',
        kohafield => 'biblioitems.biblioitemnumber'
    })->store();
    Koha::MarcSubfieldStructure->new({
        frameworkcode => $frameworkcode,
        tagfield => 999,
        tagsubfield => 'e',
        kohafield => 'holdings.holding_id'
    })->store();

    return $frameworkcode;
}

sub create_holding {
    my ( $biblionumber, $branchcode1, $branchcode2, $frameworkcode ) = @_;

    $biblionumber //= create_biblio();
    $branchcode1 //= $builder->build( { source => 'Branch' } )->{branchcode};
    $branchcode2 //= $builder->build( { source => 'Branch' } )->{branchcode};
    $frameworkcode //= create_framework();

    my $holding_marc = MARC::Record->new();
    $holding_marc->append_fields(MARC::Field->new(
        '852','','','b' => $branchcode1, 'c' => $branchcode2));
    my $holding_id = C4::Holdings::AddHolding(
        $holding_marc, $frameworkcode, $biblionumber
    );

    return Koha::Holdings->find( $holding_id );
}

sub create_user_and_session {
    my ($params) = @_;

    my $categorycode = $builder->build({ source => 'Category' })->{categorycode};
    my $branchcode = $builder->build({ source => 'Branch' })->{ branchcode };

    my $patron = $builder->build({
        source => 'Borrower',
        value => {
            branchcode   => $branchcode,
            categorycode => $categorycode,
            flags        => $params->{'flags'} || 0,
            lost         => 0,
        }
    });

    my $session = t::lib::Mocks::mock_session({borrower => $patron});
    $patron = Koha::Patrons->find($patron->{borrowernumber});
    if ( $params->{authorized} ) {
        Koha::Auth::PermissionManager->grantAllSubpermissions($patron, 'editcatalogue');
    }

    return ($patron, $session->id);
}
