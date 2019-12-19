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

use Test::More tests => 47;
use Test::Mojo;
use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Auth;
use C4::Context;

use Koha::AuthUtils;
use Koha::Database;
use Koha::Patron;
use Koha::Patron::Attributes;
use Koha::Patron::Attribute;

BEGIN {
    use_ok('Koha::Object');
    use_ok('Koha::Patron');
    use_ok('Koha::Patron::Attributes');
}

t::lib::Mocks::mock_preference('SessionStorage', 'tmp');

my $builder = t::lib::TestBuilder->new();
my $dbh = C4::Context->dbh;
my $schema = Koha::Database->schema;

$ENV{REMOTE_ADDR} = '127.0.0.1';
my $t = Test::Mojo->new('Koha::REST::V1');

$schema->storage->txn_begin;

my $categorycode = $builder->build({ source => 'Category', value => { passwordpolicy => '' } })->{ categorycode };
my $branchcode = $builder->build({ source => 'Branch' })->{ branchcode };
my $password = "secret";
my $patron = $builder->build({
    source => 'Borrower',
    value  => {
        branchcode    => $branchcode,
        categorycode  => $categorycode,
        flags         => 0,
        lost          => 0,
        gonenoaddress => 0,
        password      => Koha::AuthUtils::hash_password($password),
        email         => 'nobody@example.com',
        emailpro      => 'nobody@example.com',
        B_email       => 'nobody@example.com',
    }
});

my $patron_attribute_type = $builder->build({
    source => 'BorrowerAttributeType',
    value  => {
        code      => "testcode",
        unique_id => 0,
        repeatable => 0
    }
});

Koha::Patron::Attribute->new({ borrowernumber => $patron->{borrowernumber}, code => "testcode", attribute => 'testval' })
    ->store();

my $librarian = $builder->build({
    source => 'Borrower',
    value  => {
        branchcode   => $branchcode,
        categorycode => $categorycode,
        lost         => 0,
        password     => Koha::AuthUtils::hash_password("test"),
        othernames   => 'librarian_othernames',
    }
});

Koha::Auth::PermissionManager->grantPermissions({
    $librarian->{borrowernumber}, {
    borrowers => 'view_borrowers'
}
});

my $valid_params = 'code=testcode&attribute=testval';


### GET /api/v1/patrons/attributes

## should require authentication
$t->get_ok('/api/v1/patrons/attributes?' . $valid_params)
    ->status_is(401);


## should require view_borrowers permission
my $session = C4::Auth::get_session('');
$session->param('number', $librarian->{ borrowernumber });
$session->param('id', $librarian->{ userid });
$session->param('ip', '127.0.0.1');
$session->param('lasttime', time());
$session->flush;

my $tx = $t->ua->build_tx(GET => '/api/v1/patrons/attributes?' . $valid_params);
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(403)
    ->json_is('/required_permissions', { "borrowers" => "view_borrowers" });

Koha::Auth::PermissionManager->grantAllSubpermissions(
    $librarian->{borrowernumber}, 'borrowers'
);

## should require both attribute code and value query parameters
$tx = $t->ua->build_tx(GET => "/api/v1/patrons/attributes");
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)->status_is(400);

$tx = $t->ua->build_tx(GET => "/api/v1/patrons/attributes?code=testcode");
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)->status_is(400);

$tx = $t->ua->build_tx(GET => "/api/v1/patrons/attributes?attribute=testval");
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)->status_is(400);
#

## should return our test patron
$tx = $t->ua->build_tx(GET => "/api/v1/patrons/attributes?code=testcode&attribute=testval");
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(200)
    ->json_is('/0/borrowernumber' => $patron->{ borrowernumber });

## should return empty array for non-existing attribute value
$tx = $t->ua->build_tx(GET => "/api/v1/patrons/attributes?code=testcode&attribute=testva");
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(200)
    ->content_is('[]');

## should return empty array for non-existing attribute code
$tx = $t->ua->build_tx(GET => "/api/v1/patrons/attributes?code=testcod&attribute=testval");
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(200)
    ->content_is('[]');


### POST /api/v1/patrons/attributes

$patron_attribute_type = $builder->build({
    source => 'BorrowerAttributeType',
    value  => {
        code      => "test_post",
        unique_id => 0,
        repeatable => 0
    }
});

my $valid_post_data = {
    borrowernumber => $patron->{borrowernumber},
    code           => "test_post",
    attribute          => "valid value"
};

## should require authentication
$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => $valid_post_data);
$t->request_ok($tx)
    ->status_is(401);

## should require borrowers permission

Koha::Auth::PermissionManager->revokeAllPermissions($librarian);

$session = C4::Auth::get_session('');
$session->param('number', $librarian->{ borrowernumber });
$session->param('id', $librarian->{ userid });
$session->param('ip', '127.0.0.1');
$session->param('lasttime', time());
$session->flush;

$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => $valid_post_data);
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(403)
    ->json_is('/required_permissions', { "borrowers" => "*" });

Koha::Auth::PermissionManager->grantAllSubpermissions(
    $librarian->{borrowernumber}, 'borrowers'
);

## should require all fields
$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => {borrowernumber => $patron->{borrowernumber}});
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(400);

$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => {
    borrowernumber => $patron->{borrowernumber},
    code           => $valid_post_data->{code},
});
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(400);

## should return error for non-existing patrons
my $invalid_post_data = {
    borrowernumber => $patron->{borrowernumber} + 100,
    code           => $valid_post_data->{code},
    attribute          => $valid_post_data->{attribute}
};

$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => $invalid_post_data);
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(500);

## should return error for invalid attribute code
$invalid_post_data->{borrowernumber} = $patron->{borrowernumber};
$invalid_post_data->{code} = "non-existing-attribute-code";

$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => $invalid_post_data);
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(500);

## should return 201 with the created attribute as body on success
$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => $valid_post_data);
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(201)
    ->json_is('/borrowernumber', $valid_post_data->{borrowernumber})
    ->json_is('/code', $valid_post_data->{code})
    ->json_is('/attribute', $valid_post_data->{attribute});

## should return 409 for non-repeatable code which already exists for patron
$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => $valid_post_data);
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(409)
    ->json_like('/error' => qr/repeatable not set for attribute type/i);


## should not allow adding multiple same values for unique type

my $patron2 = $builder->build({
    source => 'Borrower',
    value  => {
        branchcode    => $branchcode,
        categorycode  => $categorycode,
        flags         => 0,
        lost          => 0,
        gonenoaddress => 0,
        password      => Koha::AuthUtils::hash_password($password),
        email         => 'nobody@example.com',
        emailpro      => 'nobody@example.com',
        B_email       => 'nobody@example.com',
    }
});

$builder->build({
    source => 'BorrowerAttributeType',
    value  => {
        code      => "t_unique",
        unique_id => 1,
        repeatable => 0
    }
});

# set unique_value for patron1, then try to add the same value for patron2
Koha::Patron::Attribute->new({ borrowernumber => $patron->{borrowernumber}, code => "t_unique", attribute => 'unique_value' })
    ->store();

$valid_post_data->{code} = "t_unique";
$valid_post_data->{borrowernumber} = $patron2->{borrowernumber};
$valid_post_data->{attribute} = "unique_value";

$tx = $t->ua->build_tx(POST => "/api/v1/patrons/attributes" => json => $valid_post_data);
$tx->req->cookies({ name => 'CGISESSID', value => $session->id });
$t->request_ok($tx)
    ->status_is(409)
    ->json_like('/error' => qr/unique_id set for attribute type/i);

