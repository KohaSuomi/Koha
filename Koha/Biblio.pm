package Koha::Biblio;

# Copyright ByWater Solutions 2014
#
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

use Carp;

use C4::Biblio qw();

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

use base qw(Koha::Object);

use Koha::AuthorisedValues;
use Koha::Items;
use Koha::Biblioitems;
use Koha::ArticleRequests;
use Koha::ArticleRequest::Status;
use Koha::IssuingRules;
use Koha::Subscriptions;
use Koha::Item::Transfer::Limits;
use Koha::Libraries;
use Koha::Holdings;

use Koha::Exceptions::Library;
use Koha::Exceptions::Biblio;

=head1 NAME

Koha::Biblio - Koha Biblio Object class

=head1 API

=head2 Class Methods

=cut

=head3 subtitles

my @subtitles = $biblio->subtitles();

Returns list of subtitles for a record.

Keyword to MARC mapping for subtitle must be set for this method to return any possible values.

=cut

sub subtitles {
    my ( $self ) = @_;

    return map { $_->{subfield} } @{ C4::Biblio::GetRecordValue( 'subtitle', C4::Biblio::GetMarcBiblio( $self->id ), $self->frameworkcode ) };
}

=head3 can_article_request

my $bool = $biblio->can_article_request( $borrower );

Returns true if article requests can be made for this record

$borrower must be a Koha::Patron object

=cut

sub can_article_request {
    my ( $self, $borrower ) = @_;

    my $rule = $self->article_request_type($borrower);
    return q{} if $rule eq 'item_only' && !$self->items()->count();
    return 1 if $rule && $rule ne 'no';

    return q{};
}

=head3 can_be_transferred

$biblio->can_be_transferred({ to => $to_library, from => $from_library })

Checks if at least one item of a biblio can be transferred to given library.

This feature is controlled by two system preferences:
UseBranchTransferLimits to enable / disable the feature
BranchTransferLimitsType to use either an itemnumber or ccode as an identifier
                         for setting the limitations

Performance-wise, it is recommended to use this method for a biblio instead of
iterating each item of a biblio with Koha::Item->can_be_transferred().

Takes HASHref that can have the following parameters:
    MANDATORY PARAMETERS:
    $to   : Koha::Library or branchcode string
    OPTIONAL PARAMETERS:
    $from : Koha::Library or branchcode string  # if given, only items from that
                                                # holdingbranch are considered

Returns 1 if at least one of the item of a biblio can be transferred
to $to_library, otherwise 0.

=cut

sub can_be_transferred {
    my ($self, $params) = @_;

    my $to = $params->{'to'};
    my $from = $params->{'from'};
    if (ref($to) ne 'Koha::Library') {
        my $tobranchcode = defined $to ? $to : '';
        $to = Koha::Libraries->find($tobranchcode);
        unless ($to) {
            Koha::Exceptions::Library::BranchcodeNotFound->throw(
                error => "Library '$tobranchcode' not found.",
            );
        }
    }
    if ($from && ref($from) ne 'Koha::Library') {
        my $frombranchcode = defined $from ? $from : '';
        $from = Koha::Libraries->find($frombranchcode);
        unless ($from) {
            Koha::Exceptions::Library::BranchcodeNotFound->throw(
                error => "Library '$frombranchcode' not found.",
            );
        }
    }

    return 1 unless C4::Context->preference('UseBranchTransferLimits');
    my $limittype = C4::Context->preference('BranchTransferLimitsType');

    my $items;
    foreach my $item_of_bib ($self->items) {
        next unless $item_of_bib->holdingbranch;
        next if $from && $from->branchcode ne $item_of_bib->holdingbranch;
        return 1 if $item_of_bib->holdingbranch eq $to->branchcode;
        my $code = $limittype eq 'itemtype'
                    ? $item_of_bib->effective_itemtype
                    : $item_of_bib->ccode;
        return 1 unless $code;
        $items->{$code}->{$item_of_bib->holdingbranch} = 1;
    }

    # At this point we will have a HASHref containing each itemtype/ccode that
    # this biblio has, inside which are all of the holdingbranches where those
    # items are located at. Then, we will query Koha::Item::Transfer::Limits to
    # find out whether a transfer limits for such $limittype from any of the
    # listed holdingbranches to the given $to library exist. If at least one
    # holdingbranch for that $limittype does not have a transfer limit to given
    # $to library, then we know that the transfer is possible.
    foreach my $code (keys %{$items}) {
        my @holdingbranches = keys %{$items->{$code}};
        return 1 if Koha::Item::Transfer::Limits->search({
            toBranch => $to->branchcode,
            fromBranch => { 'in' => \@holdingbranches },
            $limittype => $code
        }, {
            group_by => [qw/fromBranch/]
        })->count == scalar(@holdingbranches) ? 0 : 1;
    }

    return 0;
}

=head3 article_request_type

my $type = $biblio->article_request_type( $borrower );

Returns the article request type based on items, or on the record
itself if there are no items.

$borrower must be a Koha::Patron object

=cut

sub article_request_type {
    my ( $self, $borrower ) = @_;

    return q{} unless $borrower;

    my $rule = $self->article_request_type_for_items( $borrower );
    return $rule if $rule;

    # If the record has no items that are requestable, go by the record itemtype
    $rule = $self->article_request_type_for_bib($borrower);
    return $rule if $rule;

    return q{};
}

=head3 article_request_type_for_bib

my $type = $biblio->article_request_type_for_bib

Returns the article request type 'yes', 'no', 'item_only', 'bib_only', for the given record

=cut

sub article_request_type_for_bib {
    my ( $self, $borrower ) = @_;

    return q{} unless $borrower;

    my $borrowertype = $borrower->categorycode;
    my $itemtype     = $self->itemtype();

    my $issuing_rule = Koha::IssuingRules->get_effective_issuing_rule({ categorycode => $borrowertype, itemtype => $itemtype });

    return q{} unless $issuing_rule;
    return $issuing_rule->article_requests || q{}
}

=head3 article_request_type_for_items

my $type = $biblio->article_request_type_for_items

Returns the article request type 'yes', 'no', 'item_only', 'bib_only', for the given record's items

If there is a conflict where some items are 'bib_only' and some are 'item_only', 'bib_only' will be returned.

=cut

sub article_request_type_for_items {
    my ( $self, $borrower ) = @_;

    my $counts;
    foreach my $item ( $self->items()->as_list() ) {
        my $rule = $item->article_request_type($borrower);
        return $rule if $rule eq 'bib_only';    # we don't need to go any further
        $counts->{$rule}++;
    }

    return 'item_only' if $counts->{item_only};
    return 'yes'       if $counts->{yes};
    return 'no'        if $counts->{no};
    return q{};
}

=head3 article_requests

my @requests = $biblio->article_requests

Returns the article requests associated with this Biblio

=cut

sub article_requests {
    my ( $self, $borrower ) = @_;

    $self->{_article_requests} ||= Koha::ArticleRequests->search( { biblionumber => $self->biblionumber() } );

    return wantarray ? $self->{_article_requests}->as_list : $self->{_article_requests};
}

=head3 article_requests_current

my @requests = $biblio->article_requests_current

Returns the article requests associated with this Biblio that are incomplete

=cut

sub article_requests_current {
    my ( $self, $borrower ) = @_;

    $self->{_article_requests_current} ||= Koha::ArticleRequests->search(
        {
            biblionumber => $self->biblionumber(),
            -or          => [
                { status => Koha::ArticleRequest::Status::Pending },
                { status => Koha::ArticleRequest::Status::Processing }
            ]
        }
    );

    return wantarray ? $self->{_article_requests_current}->as_list : $self->{_article_requests_current};
}

=head3 article_requests_finished

my @requests = $biblio->article_requests_finished

Returns the article requests associated with this Biblio that are completed

=cut

sub article_requests_finished {
    my ( $self, $borrower ) = @_;

    $self->{_article_requests_finished} ||= Koha::ArticleRequests->search(
        {
            biblionumber => $self->biblionumber(),
            -or          => [
                { status => Koha::ArticleRequest::Status::Completed },
                { status => Koha::ArticleRequest::Status::Canceled }
            ]
        }
    );

    return wantarray ? $self->{_article_requests_finished}->as_list : $self->{_article_requests_finished};
}

=head3 items

my @items = $biblio->items();
my $items = $biblio->items();

Returns the related Koha::Items object for this biblio in scalar context,
or list of Koha::Item objects in list context.

=cut

sub items {
    my ($self) = @_;

    $self->{_items} ||= Koha::Items->search( { biblionumber => $self->biblionumber() } );

    return wantarray ? $self->{_items}->as_list : $self->{_items};
}

=head3 holdings

my @holdings = $biblio->holdings();
my $holdings = $biblio->holdings();

Returns the related Koha::Holdings object for this biblio in scalar context,
or list of Koha::Holding objects in list context.

=cut

sub holdings {
    my ($self) = @_;

    $self->{_holdings} ||= Koha::Holdings->search( { biblionumber => $self->biblionumber(), deleted_on => undef } );

    return wantarray ? $self->{_holdings}->as_list : $self->{_holdings};
}

=head3 holdings_full

my @holdings = $biblio->holdings_full();

Returns the related Koha::Holdings object including metadata for this biblio as an array ref.

=cut

sub holdings_full {
    my ($self, $filter) = @_;

    # additional search parameters
    $filter //= {};
    $filter->{biblionumber} //= $self->biblionumber() if ref $self eq 'Koha::Biblio';
    $filter->{'me.deleted_on'} //= undef;

    # holding 1:1 holdings_metadata like biblio - biblio_metadata
    # see comments of https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=22700
    $filter->{'holdings_metadatas.format'} = 'marcxml'; # force marcxml
    $filter->{'holdings_metadatas.marcflavour'} = C4::Context->preference('marcflavour');

    if ( !$self->{_holdings_full} ) {
        my $schema = Koha::Database->new()->schema();
        my @holdings = $schema->resultset('Holding')->search(
            $filter,
            {
                join         => 'holdings_metadatas',
                '+columns'   => [ qw/ holdings_metadatas.format holdings_metadatas.marcflavour holdings_metadatas.metadata / ],
                result_class => 'DBIx::Class::ResultClass::HashRefInflator'
            }
        );

        # Nicer name for the metadata array and additional information
        for my $holding (@holdings) {
            $holding->{metadata} = delete $holding->{holdings_metadatas};

            if ($holding->{ccode}) {
                my $ccode = Koha::AuthorisedValues->search({
                    category => 'CCODE',
                    authorised_value => $holding->{ccode}
                })->next;
                $holding->{ccode_description} = $ccode->lib if defined $ccode;
            }
            if ($holding->{location}) {
                my $loc = Koha::AuthorisedValues->search({
                    category => 'LOC',
                    authorised_value => $holding->{location}
                })->next;
                $holding->{location_description} = $loc->lib if defined $loc;
            }
        }

        $self->{_holdings_full} = \@holdings;
    }
    return $self->{_holdings_full};
}

=head3 componentparts

my @componentparts = $biblio->componentparts();

Returns the related component parts for this biblio.

=cut

sub componentparts {
    my ($self) = @_;

    my $record = C4::Biblio::GetMarcBiblio($self->biblionumber());
    Koha::Exceptions::Biblio::NotFound->throw(error => 'Metadata not found.', biblionumber => $self->biblionumber()) unless $record;
    my @componentPartRecords;
    if ($record->field('001') && $record->field('003')) {
        my ($componentPartBiblios, $totalCount, $query) = C4::Biblio::getComponentRecords( $record->field('001')->data(), $record->field('003')->data());
        if (@$componentPartBiblios) {
            for my $cb ( @{$componentPartBiblios} ) {
                $cb =~ s/^<\?xml.*?\?>//;
                my $component->{biblionumber} = C4::Biblio::getComponentBiblionumber($cb)+0;
                $component->{marcxml} = Encode::decode('utf8', $cb);
                push @componentPartRecords, $component;
            }
        }
    }
    return \@componentPartRecords;
}


=head3 itemtype

my $itemtype = $biblio->itemtype();

Returns the itemtype for this record.

=cut

sub itemtype {
    my ( $self ) = @_;

    return $self->biblioitem()->itemtype();
}

=head3 marcxml

my $marcxml = $biblio->marcxml();

Returns the marcxml for this record.

=cut

sub marcxml {
    my ( $self ) = @_;

    return C4::Biblio::GetXmlBiblio( $self->biblionumber() );
}

=head3 holds

my $holds = $biblio->holds();

return the current holds placed on this record

=cut

sub holds {
    my ( $self, $params, $attributes ) = @_;
    $attributes->{order_by} = 'priority' unless exists $attributes->{order_by};
    my $hold_rs = $self->_result->reserves->search( $params, $attributes );
    return Koha::Holds->_new_from_dbic($hold_rs);
}

=head3 current_holds

my $holds = $biblio->current_holds

Return the holds placed on this bibliographic record.
It does not include future holds.

=cut

sub current_holds {
    my ($self) = @_;
    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    return $self->holds(
        { reservedate => { '<=' => $dtf->format_date(dt_from_string) } } );
}

=head3 biblioitem

my $field = $self->biblioitem()->itemtype

Returns the related Koha::Biblioitem object for this Biblio object

=cut

sub biblioitem {
    my ($self) = @_;

    $self->{_biblioitem} ||= Koha::Biblioitems->find( { biblionumber => $self->biblionumber() } );

    return $self->{_biblioitem};
}

=head3 subscriptions

my $subscriptions = $self->subscriptions

Returns the related Koha::Subscriptions object for this Biblio object

=cut

sub subscriptions {
    my ($self) = @_;

    $self->{_subscriptions} ||= Koha::Subscriptions->search( { biblionumber => $self->biblionumber } );

    return $self->{_subscriptions};
}


=head3 store

=cut

sub store {
    my ($self) = @_;

    $self->{_record} = undef;

    $self->SUPER::store;
}

=head3 TO_JSON

=cut

sub TO_JSON {
    my ($self) = @_;

    my $json = $self->SUPER::TO_JSON;
    return $json;
}

=head3 type

=cut

sub _type {
    return 'Biblio';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
