#!/usr/bin/env perl

# Copyright 2016 Koha-Suomi
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

use Test::More tests => 12;
use Test::Mojo;
use t::lib::TestBuilder;

use C4::Auth;
use C4::Biblio;
use C4::Context;
use C4::Items;

use Koha::Database;
use Koha::Patron;
use Koha::Items;

my $builder = t::lib::TestBuilder->new();

my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

$ENV{REMOTE_ADDR} = '127.0.0.1';
my $t = Test::Mojo->new('Koha::REST::V1');

my $categorycode = $builder->build({ source => 'Category' })->{ categorycode };
my $branchcode = $builder->build({ source => 'Branch' })->{ branchcode };
my $borrower = $builder->build({
    source => 'Borrower',
    value => {
        branchcode   => $branchcode,
        categorycode => $categorycode,
        flags => 16,
    }
});

my $librarian = $builder->build({
    source => "Borrower",
    value => {
        categorycode => $categorycode,
        branchcode => $branchcode,
        flags => 4,
    },
});

my ($session, $session2) = create_session($borrower, $librarian);

my $biblio = $builder->build({
    source => 'Biblio'
});
my $biblionumber = $biblio->{biblionumber};
my $item = $builder->build({
    source => 'Item',
    value => {
        biblionumber => $biblionumber,
    }
});
my $itemnumber = $item->{itemnumber};

my $nonExistentItemnumber = -14362719;
my $tx = $t->ua->build_tx(GET => "/api/v1/items/$nonExistentItemnumber");
$tx->req->cookies({name => 'CGISESSID', value => $session->id});
$t->request_ok($tx)
  ->status_is(404);

$tx = $t->ua->build_tx(GET => "/api/v1/items/$itemnumber");
$tx->req->cookies({name => 'CGISESSID', value => $session->id});
$t->request_ok($tx)
  ->status_is(200)
  ->json_is('/itemnumber' => $itemnumber)
  ->json_is('/biblionumber' => $biblionumber)
  ->json_is('/itemnotes_nonpublic' => undef);

$tx = $t->ua->build_tx(GET => "/api/v1/items/$itemnumber");
$tx->req->cookies({name => 'CGISESSID', value => $session2->id});
$t->request_ok($tx)
  ->status_is(200)
  ->json_is('/itemnumber' => $itemnumber)
  ->json_is('/biblionumber' => $biblionumber)
  ->json_is('/itemnotes_nonpublic' => $item->{itemnotes_nonpublic});

$dbh->rollback;

sub create_session {
    my (@borrowers) = @_;

    my @sessions;
    foreach $borrower (@borrowers) {
        my $session = C4::Auth::get_session('');
        $session->param('number', $borrower->{borrowernumber});
        $session->param('id', $borrower->{userid});
        $session->param('ip', '127.0.0.1');
        $session->param('lasttime', time());
        $session->flush;
        push @sessions, $session;
    }

    return @sessions;
}
