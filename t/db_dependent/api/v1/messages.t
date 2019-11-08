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

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Patron::Messages;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'SessionStorage', 'tmp' );

subtest 'list() tests' => sub {

    plan tests => 25;

    $schema->storage->txn_begin;

    Koha::Patron::Messages->search->delete;

    my ( $borrowernumber, $session_id ) =
      create_user_and_session( { authorized => 1 } );
    my $librarian = Koha::Patrons->find($borrowernumber)->unblessed;
    my $userid = $librarian->{userid};

    my ( $patron_no_permission, $session_id_no_permission ) =
      create_user_and_session( { authorized => 0 } );
    my $patron = Koha::Patrons->find($patron_no_permission)->unblessed;

    my $unauth_userid = $patron->{userid};

    ## Authorized user tests
    # No messages, so empty array should be returned
    my $tx = $t->ua->build_tx( GET => '/api/v1/messages' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(200)
      ->json_is( [] );

    my $message = $builder->build_object({ class => 'Koha::Patron::Messages' });

    # One message created, should get returned
    $tx = $t->ua->build_tx( GET => '/api/v1/messages' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(200)
      ->json_is( [$message->TO_JSON] );

    my $another_message = $builder->build_object(
        { class => 'Koha::Patron::Messages', value => { message_type => $message->message_type } } );
    my $message_with_another_message_type = $builder->build_object({ class => 'Koha::Patron::Messages' });

    # Two messages created, they should both be returned
    $tx = $t->ua->build_tx( GET => '/api/v1/messages' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(200)
      ->json_is([$message->TO_JSON,
                 $another_message->TO_JSON,
                 $message_with_another_message_type->TO_JSON
                 ] );

    # Filtering works, two messages sharing message_type
    $tx = $t->ua->build_tx( GET => "/api/v1/messages?message_type=" . $message->message_type );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(200)
      ->json_is([ $message->TO_JSON,
                  $another_message->TO_JSON
                  ]);

    $tx = $t->ua->build_tx( GET => "/api/v1/messages?message=" . $message->message );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(200)
      ->json_is( [$message->TO_JSON] );

    # Warn on unsupported query parameter
    $tx = $t->ua->build_tx( GET => "/api/v1/messages?message_blah=blah" );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(400)
      ->json_is( [{ path => '/query/message_blah', message => 'Malformed query string'}] );

    # Unauthorized access
    $tx = $t->ua->build_tx( GET => '/api/v1/messages' );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id_no_permission } );
      $t->request_ok($tx)->status_is(403);

    my $message_own_object = $builder->build_object({
        class => 'Koha::Patron::Messages',
        value => {
            borrowernumber => $patron->{borrowernumber},
            message_type   => 'B'
        }
    });

    # Patron accessing own messages
    $tx = $t->ua->build_tx( GET => "/api/v1/messages?borrowernumber=" . $patron->{borrowernumber} );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id_no_permission } );
      $t->request_ok($tx)->status_is(200)
      ->json_is( [$message_own_object->TO_JSON] );

    # Patron accessing someone else's messages
    $tx = $t->ua->build_tx( GET => "/api/v1/messages?borrowernumber=" . $librarian->{borrowernumber} );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id_no_permission } );
      $t->request_ok($tx)->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {

    plan tests => 11;

    $schema->storage->txn_begin;

    my ( $borrowernumber, $session_id ) =
      create_user_and_session( { authorized => 1 } );
    my $librarian = Koha::Patrons->find($borrowernumber)->unblessed;
    my $userid = $librarian->{userid};

    my ( $patron_no_permission, $session_id_no_permission ) =
      create_user_and_session( { authorized => 0 } );
    my $patron = Koha::Patrons->find($patron_no_permission)->unblessed;

    my $unauth_userid = $patron->{userid};

    my $message_no_permission = $builder->build_object({
        class => 'Koha::Patron::Messages',
    });
    my $message = $builder->build_object({
        class => 'Koha::Patron::Messages',
        value => {
            borrowernumber => $patron->{borrowernumber},
            message_type   => 'B',
        }
    });

    my $tx = $t->ua->build_tx( GET => "/api/v1/messages/" . $message_no_permission->message_id );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(200)
      ->json_is($message_no_permission->TO_JSON);

    $tx = $t->ua->build_tx( GET => "/api/v1/messages/" . $message_no_permission->message_id );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id_no_permission } );
      $t->request_ok($tx)->status_is(403);

    my $message_to_delete = $builder->build_object({ class => 'Koha::Patron::Messages' });
    my $non_existent_id = $message_to_delete->id;
    $message_to_delete->delete;

    $tx = $t->ua->build_tx( GET => "/api/v1/messages/$non_existent_id" );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(404)
      ->json_is( '/error' => 'Message not found' );

    # Patron accessing own messages
    $tx = $t->ua->build_tx( GET => "/api/v1/messages/" . $message->message_id );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id_no_permission } );
      $t->request_ok($tx)->status_is(200)
      ->json_is( $message->TO_JSON );

    $schema->storage->txn_rollback;
};

subtest 'add() tests' => sub {

    plan tests => 27;

    $schema->storage->txn_begin;

    my ( $borrowernumber, $session_id ) =
      create_user_and_session( { authorized => 1 } );
    my $librarian = Koha::Patrons->find($borrowernumber)->unblessed;
    my $userid = $librarian->{userid};

    my ( $patron_no_permission, $session_id_no_permission ) =
      create_user_and_session( { authorized => 0 } );
    my $patron = Koha::Patrons->find($patron_no_permission)->unblessed;

    my $unauth_userid = $patron->{userid};

    my $message = {
        borrowernumber       => $patron->{borrowernumber},
        branchcode      => $patron->{branchcode},
        message_type    => "B",
        message         => "Old Fox jumped over Cheeseboy"
    };

    # Unauthorized attempt to write
    my $tx = $t->ua->build_tx( POST => "/api/v1/messages" => json => $message);
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id_no_permission } );
      $t->request_ok($tx)->status_is(403);

    # Authorized attempt to write invalid data
    my $message_with_invalid_field = {
        blah            => "message Blah",
        borrowernumber       => $patron->{borrowernumber},
        branchcode      => $patron->{branchcode},
        message_type    => "B",
        message         => "Old Fox jumped over Cheeseboy",
        manager_id      => $librarian->{borrowernumber}
    };

    $tx = $t->ua->build_tx( POST => "/api/v1/messages" => json => $message_with_invalid_field );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(400)
      ->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
      );

    # Authorized attempt to write
      $tx = $t->ua->build_tx( POST => "/api/v1/messages" => json => $message );
      $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is( 201, 'SWAGGER3.2.1' )
        ->header_like(
            Location => qr|^\/api\/v1\/messages/\d*|,
            'SWAGGER3.4.1'
            )
        ->json_is( '/borrowernumber'     => $message->{borrowernumber} )
        ->json_is( '/branchcode'    => $message->{branchcode} )
        ->json_is( '/message_type'  => $message->{message_type} )
        ->json_is( '/message'       => $message->{message} )
        ->json_is( '/manager_id'    => $librarian->{borrowernumber} );

    # Authorized attempt to write with manager_id defined
    $message->{manager_id} = $message->{borrowernumber};
      $tx = $t->ua->build_tx( POST => "/api/v1/messages" => json => $message );
      $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is( 201, 'SWAGGER3.2.1' )
        ->header_like(
            Location => qr|^\/api\/v1\/messages/\d*|,
            'SWAGGER3.4.1'
            )
        ->json_is( '/borrowernumber'     => $message->{borrowernumber} )
        ->json_is( '/branchcode'    => $message->{branchcode} )
        ->json_is( '/message_type'  => $message->{message_type} )
        ->json_is( '/message'       => $message->{message} )
        ->json_is( '/manager_id'    => $message->{borrowernumber} );
    my $message_id = $tx->res->json->{message_id};

    # Authorized attempt to create with null id
    $message->{message_id} = undef;
    $tx = $t->ua->build_tx( POST => "/api/v1/messages" => json => $message );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(400)
      ->json_has('/errors');

    # Authorized attempt to create with existing id
    $message->{message_id} = $message_id;
    $tx = $t->ua->build_tx( POST => "/api/v1/messages" => json => $message );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(400)
      ->json_is(
        "/errors" => [
            {
                message => "Read-only.",
                path    => "/body/message_id"
            }
        ]
    );

    $schema->storage->txn_rollback;
};

subtest 'update() tests' => sub {

    plan tests => 15;

    $schema->storage->txn_begin;

    my ( $borrowernumber, $session_id ) =
      create_user_and_session( { authorized => 1 } );
    my $librarian = Koha::Patrons->find($borrowernumber)->unblessed;
    my $userid = $librarian->{userid};

    my ( $patron_no_permission, $session_id_no_permission ) =
      create_user_and_session( { authorized => 0 } );
    my $patron = Koha::Patrons->find($patron_no_permission)->unblessed;

    my $unauth_userid = $patron->{userid};

    my $message_id = $builder->build_object({ class => 'Koha::Patron::Messages' } )->id;

    # Unauthorized attempt to update
    my $tx = $t->ua->build_tx( PUT => "/api/v1/messages/$message_id" => json => {
        borrowernumber => $patron->{borrowernumber},
        message => 'New unauthorized name change',
        message_type => 'B',
    } );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id_no_permission } );
      $t->request_ok($tx)->status_is(403);

    # Attempt partial update on a PUT
    my $message_with_missing_field = {
        borrowernumber       => $patron->{borrowernumber},
        branchcode      => $patron->{branchcode},
        message         => "Old Fox jumped over Cheeseboy",
        manager_id      => $librarian->{borrowernumber}
    };

    $tx = $t->ua->build_tx( PUT => "/api/v1/messages/$message_id" => json => $message_with_missing_field );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(400)
      ->json_is( "/errors" =>
          [ { message => "Missing property.", path => "/body/message_type" } ]
      );

    # Full object update on PUT
    my $message_with_updated_field = {
        borrowernumber       => $patron->{borrowernumber},
        branchcode      => $patron->{branchcode},
        message_type    => "B",
        message         => "Old Fox jumped over Cheeseboy",
        manager_id      => $librarian->{borrowernumber}
    };

    $tx = $t->ua->build_tx( PUT => "/api/v1/messages/$message_id" => json => $message_with_updated_field );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(200)
      ->json_is( '/message' => 'Old Fox jumped over Cheeseboy' );

    # Authorized attempt to write invalid data
    my $message_with_invalid_field = {
        blah            => "message Blah",
        borrowernumber       => $patron->{borrowernumber},
        branchcode      => $patron->{branchcode},
        message_type    => "B",
        message         => "Old Fox jumped over Cheeseboy",
        manager_id      => $librarian->{borrowernumber}
    };

    $tx = $t->ua->build_tx( PUT => "/api/v1/messages/$message_id" => json => $message_with_invalid_field );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(400)
      ->json_is(
        "/errors" => [
            {
                message => "Properties not allowed: blah.",
                path    => "/body"
            }
        ]
    );

    my $message_to_delete = $builder->build_object({ class => 'Koha::Patron::Messages' });
    my $non_existent_id = $message_to_delete->id;
    $message_to_delete->delete;

    $tx = $t->ua->build_tx( PUT => "/api/v1/messages/$non_existent_id" => json => $message_with_updated_field );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(404);

    # Wrong method (POST)
    $message_with_updated_field->{message_id} = 2;

    $tx = $t->ua->build_tx( POST => "/api/v1/messages/$message_id" => json => $message_with_updated_field );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(404);

    $schema->storage->txn_rollback;
};

subtest 'delete() tests' => sub {

    plan tests => 7;

    $schema->storage->txn_begin;

    my ( $borrowernumber, $session_id ) =
      create_user_and_session( { authorized => 1 } );
    my $librarian = Koha::Patrons->find($borrowernumber)->unblessed;
    my $userid = $librarian->{userid};

    my ( $patron_no_permission, $session_id_no_permission ) =
      create_user_and_session( { authorized => 0 } );
    my $patron = Koha::Patrons->find($patron_no_permission)->unblessed;

    my $unauth_userid = $patron->{userid};

    my $message_id = $builder->build_object({ class => 'Koha::Patron::Messages' })->id;

    # Unauthorized attempt to delete
    my $tx = $t->ua->build_tx( DELETE => "/api/v1/messages/$message_id" );
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id_no_permission } );
      $t->request_ok($tx)->status_is(403);

    $tx = $t->ua->build_tx( DELETE => "/api/v1/messages/$message_id");
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(200)
      ->content_is('""');

    $tx = $t->ua->build_tx( DELETE => "/api/v1/messages/$message_id");
    $tx->req->cookies( { name => 'CGISESSID', value => $session_id } );
      $t->request_ok($tx)->status_is(404);

    $schema->storage->txn_rollback;
};

sub create_user_and_session {

    my $args  = shift;
    my $flags = ( $args->{authorized} ) ? $args->{authorized} : 0;
    my $dbh   = C4::Context->dbh;

    my $user = $builder->build(
        {
            source => 'Borrower',
            value  => {
                flags => $flags,
                lost  => 0,
            }
        }
    );

    # Create a session for the authorized user
    my $session = t::lib::Mocks::mock_session({borrower => $user});

    if ( $args->{authorized} ) {
        my $patron = Koha::Patrons->find($user->{borrowernumber});
        Koha::Auth::PermissionManager->grantAllSubpermissions($patron, 'borrowers');
    }

    return ( $user->{borrowernumber}, $session->id );
}
