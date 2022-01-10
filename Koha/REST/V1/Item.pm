package Koha::REST::V1::Item;

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
use Mojo::JSON;

use C4::Auth qw( haspermission );
use C4::Items qw( GetHiddenItemnumbers );

use Koha::Items;

sub list {
    my $c = shift->openapi->valid_input or return;

    my $params  = $c->req->params->to_hash;
    my $items = Koha::Items->search({ barcode => { -in => $params->{barcode} } });
    my @public_items;

    # Return only public items if user has no staff access
    my $user = $c->stash('koha.user');
    if (!$user || !haspermission($user->userid, {catalogue => 1})) {
	while ( my $item = $items->next ) {
	    my @hiddenitems = C4::Items::GetHiddenItemnumbers( ({ itemnumber => $item->itemnumber}) );
	    my %hiddenitems = map { $_ => 1 } @hiddenitems;
	    next if $hiddenitems{$item->itemnumber};

	    $item->set({ itemnotes_nonpublic => undef });
	    push @public_items, $item;
	}
	return $c->render( status => 200, openapi => \@public_items);
    } else {
	return $c->render( status => 200, openapi => $items);
    }
}

sub get {
    my $c = shift->openapi->valid_input or return;

    my $itemnumber = $c->validation->param('itemnumber');
    my $item = Koha::Items->find($itemnumber);
    unless ($item) {
        return $c->render(status => 404, openapi => {error => "Item not found"});
    }

    # Hide non-public itemnotes if user has no staff access
    my $user = $c->stash('koha.user');
    unless ($user && haspermission($user->userid, {catalogue => 1})) {

        my @hiddenitems = C4::Items::GetHiddenItemnumbers( ({ itemnumber => $itemnumber}) );
        my %hiddenitems = map { $_ => 1 } @hiddenitems;

        # Pretend it was not found as it's hidden from OPAC to regular users
        return $c->render( status => 404, openapi => {error => "Item not found"} )
          if $hiddenitems{$itemnumber};

        $item->set({ itemnotes_nonpublic => undef });
    }

    return $c->render( status => 200, openapi => $item );
}

sub patch {
    my $c = shift->openapi->valid_input or return;

    my $item;
    return try {
        my $itemnumber = $c->validation->param('itemnumber');
        $item = Koha::Items->find($itemnumber);
        my $body = $c->req->json;

        $item->set($body);
        $item->store;
        return $c->render( status => 200, openapi => $item);
    }
    catch {
        unless ($item) {
            return $c->render( status  => 404,
                               openapi => { error => "Item not found" } );
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

1;
