package Koha::REST::V1::Holding;

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

use Mojo::Base 'Mojolicious::Controller';

use MARC::Record;
use MARC::Record::MiJ;

use C4::Holdings;
use Koha::Biblios;
use Koha::Holdings;
use Koha::Holdings::Metadatas;

use Koha::Exceptions::Holding;
use Koha::Exceptions::Metadata;

use Scalar::Util qw( blessed );
use Try::Tiny;

=head1 API

=head2 Class Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $filter;
        my $args = $c->req->params->to_hash;

        unless ($args) {
            return $c->render( status  => 400,
                openapi => { error => "At least one query parameter is required" } );
        }

        my @starts_with_search = ( 'timestamp', 'datecreated', 'deleted_on' );

        for my $filter_param ( keys %$args ) {
            if ( grep ( /^$filter_param$/, @starts_with_search ) ) {
                $filter->{$filter_param} = { LIKE => $args->{$filter_param} . "%" };
                next;
            }
            $filter->{$filter_param} = $args->{$filter_param};
        }

        # FIXME
        # A bit hacky use of Koha::Biblio->holdings_full
        # Use a better approach when Bug 20447 reaches upstream
        my $holdings = Koha::Biblio::holdings_full({}, $filter);

        return $c->render( status => 200, openapi => $holdings );
    }
    catch {
        Koha::Exceptions::rethrow_exception($_);
    };
}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $holding = Koha::Holdings->find( $c->validation->param('holding_id') );
    unless ($holding) {
        return $c->render( status  => 404,
            openapi => { error => "Holding not found" } );
    }

    return $c->respond_with_content_type( $holding );
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my ( $record, $frameworkcode, $biblionumber ) = $c->convert_content_to_marc_record();

        my $biblio;
        unless ( $biblio = Koha::Biblios->find( $biblionumber )) {
            return $c->render( status  => 404,
                openapi => { error => "Biblio with given biblionumber not found" } );
        }

        my $holding_id = C4::Holdings::AddHolding(
            $record,
            $frameworkcode,
            $biblionumber
        );

        my $holding = Koha::Holdings->find( $holding_id );

        $c->res->headers->location( $c->req->url->to_string . $holding_id );
        return $c->respond_with_content_type( $holding, 201 );
    }
    catch {
        unless (blessed $_ && $_->can('rethrow')) {
            Koha::Exceptions::rethrow_exception($_);
        }
        if ($_->isa('Koha::Exceptions::Metadata::Invalid')) {
            return $c->render(status  => 400,
                openapi => { error => Koha::Exceptions::_stringify_exception($_->decoding_error) }
            );
        }
        elsif ($_->isa('Koha::Exceptions::Holding::MissingProperty')) {
            return $c->render(status  => 400,
                openapi => { error => $_->error }
            );
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;
}


sub convert_content_to_marc_record {
    my $c = shift;
    my $req = $c->tx->req;

    my $content = $req->content->asset->{'content'};
    my $content_type = $req->headers->content_type;
    my $frameworkcode = $req->headers->header('X-Koha-Frameworkcode') || 'HLD';

    my $record = _content_to_marc_record( $content, $content_type );

    my $biblionumber = C4::Holdings::TransformMarcHoldingToKohaOneField(
        'biblio.biblionumber', $record );

    unless ( $biblionumber ) {
        Koha::Exceptions::Holding::MissingProperty->throw(
            error => 'MARC record is missing Koha field biblio.biblionumber.'
        );
    }

    return ( $record, $frameworkcode, $biblionumber );
}

sub respond_with_content_type {
    my $c = shift;
    my ( $holding, $status ) = @_;

    $status //= 200;
    if ( ( !$c->req->headers->accept || $c->req->headers->accept =~ m/application\/json/ )
        && grep( /application\/json/, @{$c->openapi->spec->{'produces'}} ) ) {
        # FIXME
        # A bit hacky use of Koha::Biblio->holdings_full
        # Use a better approach when Bug 20447 reaches upstream
        $holding = Koha::Biblio::holdings_full({}, {
            'me.holding_id' => $holding->holding_id
        });

        return $c->render(
            status => $status,
            json   => $holding->[0]
        );
    }
    else {
        my $record = $holding->metadata->record;

        $c->respond_to(
            marcxml => {
                status => $status,
                format => 'marcxml',
                text   => $record->as_xml_record
            },
            mij => {
                status => $status,
                format => 'mij',
                text   => $record->to_mij
            },
            marc => {
                status => $status,
                format => 'marc',
                text   => $record->as_usmarc
            },
            any => {
                status  => 406,
                openapi => $c->openapi->spec->{'produces'}
            }
        );
    }
}

sub _content_to_marc_record {
    my ( $content, $content_type ) = @_;

    my $record;
    my $marcflavour = C4::Context->preference('marcflavour') || 'MARC21';

    # Note! The order of if-elsif statements here is important since we want to
    # match e.g. "marc-in-json" before "marc"
    if ( $content_type =~ m/application\/marc-in-json/ ) {
        $record = eval { MARC::Record::MiJ->new( $content ); };
    }
    elsif ( $content_type =~ m/application\/marcxml\+xml/ ) {
        $record = eval { MARC::Record::new_from_xml( $content, 'utf8', $marcflavour ); };
    }
    elsif ( $content_type =~ m/application\/marc/ ) {
        $record = eval { MARC::Record::new_from_usmarc( $content ); };
    }

    if ($@) {
        Koha::Exceptions::Metadata::Invalid->throw(
            decoding_error => $@,
        );
    }

    return $record;
}

1;
