package Koha::REST::V1::Biblio;

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

use C4::Biblio qw( GetBiblioData AddBiblio ModBiblio DelBiblio BiblioAutoLink GetFrameworkCode GetMarcBiblio getHostRecord );
use C4::Matcher;
use C4::Items qw ( AddItemBatchFromMarc );
use Koha::Biblios;
use Koha::Serials;
use Koha::Subscriptions;
use MARC::Record;
use MARC::Batch;
use MARC::File::USMARC;
use MARC::File::XML;

use Data::Dumper;

sub get {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find($c->validation->param('biblionumber'));

    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }
    my $marcxml = $biblio->marcxml;
    $biblio = $biblio->unblessed;
    $biblio->{serial} = $biblio->{serial} ? $biblio->{serial} : 0; # Don't know why null serial gives error even it is defined on Swagger
    $biblio->{marcxml} = $marcxml;
    return $c->render(status => 200, openapi => $biblio);
}

sub getitems {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find($c->validation->param('biblionumber'));
    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }
    return $c->render(status => 200, openapi => { biblio => $biblio, items => $biblio->items });
}

sub getexpanded {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find($c->validation->param('biblionumber'));
    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }
    my @expanded = $biblio->items;
    foreach my $item (@expanded) {

        # we assume item is available by default
        $item->{status} = "available";

        if ($item->{onloan}) {
            $item->{status} = "onloan"
        }

        if ($item->{restricted}) {
            $item->{status} = "restricted";
        }

        # mark as unavailable if notforloan, damaged, lost, or withdrawn
        if ($item->{damaged} || $item->{itemlost} || $item->{withdrawn} || $item->{notforloan}) {
            $item->{status} = "unavailable";
        }

        my $holds = Koha::Holds->search({itemnumber => $item->{itemnumber}})->unblessed;

        # mark as onhold if item marked as hold
        if (scalar(@{$holds}) > 0) {
            $item->{status} = "onhold";
        }
    }
    my @holdings = $biblio->holdings;

    return $c->render(status => 200, openapi => { biblio => $biblio, holdings => \@holdings, items => \@expanded });
}

sub getholdings {
    my $c = shift->openapi->valid_input or return;
 
    my $biblio = Koha::Biblios->find($c->validation->param('biblionumber'));
    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }
    return $c->render(status => 200, openapi => { biblio => $biblio, holdings => $biblio->holdings_full });
}

sub getserialsubscriptions {
    my $c = shift->openapi->valid_input or return;

    # Can't use a join here since subscriptions and serials are missing proper relationship in the database.
    my @all_serials;
    my $subscriptions = Koha::Subscriptions->search( 
        { 
            biblionumber => $c->validation->param('biblionumber')
        },
        {
            select => [ qw( subscriptionid biblionumber branchcode location callnumber ) ]
        }
    );
    while (my $subscription = $subscriptions->next()) {
        my $serials = Koha::Serials->search(
            { 
                subscriptionid => $subscription->subscriptionid 
            },
            {
                select => [ qw( serialid serialseq serialseq_x serialseq_y serialseq_z publisheddate publisheddatetext notes ) ],
                '+columns' => {
                    received => \do { "IF(status=2, 1, 0)" }
                }
            }
        );
        if ($serials->count > 0) {
            my $record = {
                subscriptionid => $subscription->subscriptionid, 
                biblionumber   => $subscription->biblionumber, 
                branchcode     => $subscription->branchcode,
                location       => $subscription->location,
                callnumber     => $subscription->callnumber,
                issues         => $serials->unblessed
            };
            if ($subscription->location) {
                my $loc = Koha::AuthorisedValues->search({
                    category => 'LOC',
                    authorised_value => $subscription->location
                })->next;
                $record->{location_description} = $loc->lib if defined $loc;
            }
            push @all_serials, $record;
        }
    }

    return $c->render(status => 200, openapi => { subscriptions => \@all_serials });
}

sub getcomponentparts {
    my $c = shift->openapi->valid_input or return;

    my $biblio = Koha::Biblios->find($c->validation->param('biblionumber'));

    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }
    my $marcxml = $biblio->marcxml;
    my $componentparts = $biblio->componentparts;
    $biblio = $biblio->unblessed;
    $biblio->{serial} = $biblio->{serial} ? $biblio->{serial} : 0; # Don't know why null serial gives error even it is defined on Swagger
    $biblio->{marcxml} = $marcxml;
    return $c->render(status => 200, openapi => { biblio => $biblio, componentparts => $componentparts });
}

sub add {
    my $c = shift->openapi->valid_input or return;

    my $biblionumber;
    my $biblioitemnumber;

    my $body = $c->req->body;
    unless ($body) {
        return $c->render(status => 400, openapi => {error => "Missing MARCXML body"});
    }

    my $record = eval {MARC::Record::new_from_xml( $body, "utf8", '')};
    if ($@) {
        return $c->render(status => 400, openapi => {error => $@});
    } else {
        if (C4::Context->preference("BiblioAddsAuthorities")){
            BiblioAutoLink($record, '');
        }
        my $hostrecord = C4::Biblio::getHostRecord($record);
        if ($hostrecord) {
            my $field = MARC::Field->new('942','','','c' => $hostrecord->subfield('942','c'));
            $record->append_fields($field);
        }
        ( $biblionumber, $biblioitemnumber ) = &AddBiblio($record, '');
    }
    if ($biblionumber) {
        $c->res->headers->location($c->url_for('/api/v1/biblios/')->to_abs . $biblionumber);
        my ( $itemnumbers, $errors ) = &AddItemBatchFromMarc( $record, $biblionumber, $biblioitemnumber, '' );
        unless (@{$errors}) {
            return $c->render(status => 201, openapi => {biblionumber => 0+$biblionumber, items => join(",", @{$itemnumbers})});
        } else {
            warn Dumper($errors);
            return $c->render(status => 400, openapi => {error => "Error creating items, see Koha Logs for details.", biblionumber => $biblionumber, items => join(",", @{$itemnumbers})});
        }
    } else {
        return $c->render(status => 400, openapi => {error => "unable to create record"});
    }
}

# NB: This will not update any items, Items should be a separate API route
sub update {
    my $c = shift->openapi->valid_input or return;

    my $biblionumber = $c->validation->param('biblionumber');
    my $matcher_id = $c->validation->param('matcher_id');

    my $biblio = Koha::Biblios->find($biblionumber);
    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }

    my $success;
    my $body = $c->req->body;
    my $record = eval {MARC::Record::new_from_xml( $body, "utf8", '')};
    if ($@) {
        return $c->render(status => 400, openapi => {error => $@});
    } else {
        my $frameworkcode = GetFrameworkCode( $biblionumber );
        if (C4::Context->preference("BiblioAddsAuthorities")){
            BiblioAutoLink($record, $frameworkcode);
        }
        my $hostrecord = C4::Biblio::getHostRecord($record);
        if ($hostrecord) {
           my $field = MARC::Field->new('942','','','c' => $hostrecord->subfield('942','c'));
           $record->append_fields($field);
        }
        if($matcher_id) {
            my $old_record = C4::Biblio::GetMarcBiblio($biblionumber);
            my $matcher = C4::Matcher->fetch($matcher_id);

            my $mergedrecord = $matcher->overlayRecord($old_record, $record);
            $success = &ModBiblio($mergedrecord, $biblionumber, $frameworkcode);
        } else {
            $success = &ModBiblio($record, $biblionumber, $frameworkcode);
        }
    }
    if ($success) {
        my $biblio = Koha::Biblios->find($c->validation->param('biblionumber'));
        return $c->render(status => 200, openapi => {biblio => $biblio});
    } else {
        return $c->render(status => 400, openapi => {error => "unable to update record"});
    }
}

sub delete {
    my $c = shift->openapi->valid_input or return;
    my $res;

    my $biblio = Koha::Biblios->find($c->validation->param('biblionumber'));
    unless ($biblio) {
        return $c->render(status => 404, openapi => {error => "Biblio not found"});
    }

    my @item_errors = ();
    if (!$c->req->query_params->param('safe')) {
        my @items = $biblio->items;
        # Delete items
        foreach my $item (@items) {
            my $res = $item->delete;
            unless ($res eq 1) {
                push @item_errors, $item->unblessed->{itemnumber};
            }
        }

        my @holdings = $biblio->holdings;
        # Delete holdings
        foreach my $holding (@holdings) {
            $holding->delete;
        }
        $res = C4::Biblio::DelBiblio($biblio->biblionumber, 1);
    } else {
        if ($biblio->holdings->count) {
            $res = "This Biblio has holdings records attached, please delete them first before deleting this biblio";
        } else {
            $res = C4::Biblio::DelBiblio($biblio->biblionumber, 1);
        }
    }


    unless ($res) {
        return $c->render(status => 200, openapi => {});
    } else {
        return $c->render(status => 400, openapi => {
            error => $res,
            items => @item_errors,
        });
    }
}

1;
