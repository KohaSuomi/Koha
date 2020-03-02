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

use C4::Context;
use C4::Biblio;
use C4::Holdings;

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
    plan skip_all => 'not implemented';

    $schema->storage->txn_begin;
    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {
    plan skip_all => 'not implemented';

    $schema->storage->txn_begin;
    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {
    plan skip_all => 'not implemented';

    $schema->storage->txn_begin;
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
