package Koha::REST::V1::Messages;

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

use C4::Auth qw( haspermission );
use Koha::Patron::Messages;

use Try::Tiny;

=head1 API

=head2 Class Methods

=head3 list

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $messages;
        my $filter;
        my $args = $c->req->params->to_hash;

        for my $filter_param ( keys %$args ) {
            $filter->{$filter_param} = { LIKE => $args->{$filter_param} . "%" };
        }

        $messages = Koha::Patron::Messages->search( $filter )->as_list;

        # Hide non-public messages if user has no borrowers flag
        my @public_messages;
        my $user = $c->stash('koha.user');
        unless ($user && haspermission($user->userid, {borrowers => 1})) {
            foreach my $message (@{$messages}) {
                if ($message->message_type eq 'B') {
                    push @public_messages, $message;
                }
            }
            return $c->render( status => 200, openapi => \@public_messages );
        }

        return $c->render( status => 200, openapi => $messages );
    }
    catch {
        Koha::Exceptions::rethrow_exception($_);
    };

}

=head3 get

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    my $message = Koha::Patron::Messages->find( $c->validation->param('message_id') );
    unless ($message) {
        return $c->render( status  => 404,
                           openapi => { error => "Message not found" } );
    }

    # Hide non-public messages if user has no borrowers flag
    my $user = $c->stash('koha.user');
    unless ($user && haspermission($user->userid, {borrowers => 1})) {
        if ($message->message_type ne 'B') {    # hide message from patron
            return $c->render( status  => 404,  # if message type is not 'B'
                openapi => { error => "Message not found" } );
        }
    }

    return $c->render( status => 200, openapi => $message );
}

=head3 add

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $message = Koha::Patron::Message->new( $c->validation->param('body') );
        my $user = $c->stash('koha.user');
        $message->set({ manager_id => $user->borrowernumber }) unless defined $message->manager_id;
        $message->store;
        $c->res->headers->location( $c->req->url->to_string . '/' . $message->message_id );
        return $c->render(
            status  => 201,
            openapi => $message
        );
    }
    catch {
        Koha::Exceptions::rethrow_exception($_);
    };
}

=head3 update

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $message = Koha::Patron::Messages->find( $c->validation->param('message_id') );

    if ( not defined $message ) {
        return $c->render( status  => 404,
                           openapi => { error => "Object not found" } );
    }

    return try {
        my $params = $c->req->json;
        $message->set( $params );
        $message->store();
        return $c->render( status => 200, openapi => $message );
    }
    catch {
        Koha::Exceptions::rethrow_exception($_);
    };
}

=head3 delete

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $message = Koha::Patron::Messages->find( $c->validation->param('message_id') );
    if ( not defined $message ) {
        return $c->render( status  => 404,
                           openapi => { error => "Object not found" } );
    }

    return try {
        $message->delete;
        return $c->render( status => 200, openapi => "" );
    }
    catch {
        Koha::Exceptions::rethrow_exception($_);
    };
}

1;
