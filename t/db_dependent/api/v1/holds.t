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

use Test::More tests => 4;
use Test::Mojo;
use t::lib::TestBuilder;

use DateTime;

use C4::Context;
use C4::Reserves;

use Koha::Database;
use Koha::Biblios;
use Koha::Items;
use Koha::Patrons;

my $builder = t::lib::TestBuilder->new();

my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;

$ENV{REMOTE_ADDR} = '127.0.0.1';
my $t = Test::Mojo->new('Koha::REST::V1');
my $tx;

my $categorycode = $builder->build({ source => 'Category' })->{categorycode};
my $branchcode = $builder->build({ source => 'Branch' })->{branchcode};

# User without any permissions
my $nopermission = $builder->build({
    source => 'Borrower',
    value => {
        branchcode   => $branchcode,
        categorycode => $categorycode,
        flags        => 0
    }
});
my $session_nopermission = C4::Auth::get_session('');
$session_nopermission->param('number', $nopermission->{ borrowernumber });
$session_nopermission->param('id', $nopermission->{ userid });
$session_nopermission->param('ip', '127.0.0.1');
$session_nopermission->param('lasttime', time());
$session_nopermission->flush;

my $borrower = Koha::Patron->new;
$borrower->categorycode( $categorycode );
$borrower->branchcode( $branchcode );
$borrower->surname("Test Surname");
$borrower->flags(80); #borrowers and reserveforothers flags
$borrower->userid($nopermission->{ userid }."z");
$borrower->store;
my $borrowernumber = $borrower->borrowernumber;

my $borrower2 = Koha::Patron->new;
$borrower2->categorycode( $categorycode );
$borrower2->branchcode( $branchcode );
$borrower2->surname("Test Surname 2");
$borrower2->userid($nopermission->{ userid }."x");
$borrower2->flags(16); # borrowers flag
$borrower2->store;
my $borrowernumber2 = $borrower2->borrowernumber;

my $borrower3 = Koha::Patron->new;
$borrower3->categorycode( $categorycode );
$borrower3->branchcode( $branchcode );
$borrower3->surname("Test Surname 2");
$borrower3->userid($nopermission->{ userid }."y");
$borrower3->flags(64); # reserveforothers flag
$borrower3->store;
my $borrowernumber3 = $borrower3->borrowernumber;

# Get sessions
my $session = C4::Auth::get_session('');
$session->param('number', $borrower->borrowernumber);
$session->param('id', $borrower->userid);
$session->param('ip', '127.0.0.1');
$session->param('lasttime', time());
$session->flush;
my $session2 = C4::Auth::get_session('');
$session2->param('number', $borrower2->borrowernumber);
$session2->param('id', $borrower2->userid);
$session2->param('ip', '127.0.0.1');
$session2->param('lasttime', time());
$session2->flush;
my $session3 = C4::Auth::get_session('');
$session3->param('number', $borrower3->borrowernumber);
$session3->param('id', $borrower3->userid);
$session3->param('ip', '127.0.0.1');
$session3->param('lasttime', time());
$session3->flush;

my $biblionumber = create_biblio('RESTful Web APIs');
my $itemnumber = create_item($biblionumber, 'TEST000001');

my $biblionumber2 = create_biblio('RESTful Web APIs');
my $itemnumber2 = create_item($biblionumber2, 'TEST000002');

$dbh->do('DELETE FROM reserves');
$dbh->do('DELETE FROM issuingrules');
    $dbh->do(q{
        INSERT INTO issuingrules (categorycode, branchcode, itemtype, reservesallowed)
        VALUES (?, ?, ?, ?)
    }, {}, '*', '*', '*', 1);

my $reserve_id = C4::Reserves::AddReserve($branchcode, $borrowernumber,
    $biblionumber, undef, 1, undef, undef, undef, '', $itemnumber);

# Add another reserve to be able to change first reserve's rank
my $reserve_id2 = C4::Reserves::AddReserve($branchcode, $borrowernumber2,
    $biblionumber, undef, 2, undef, undef, undef, '', $itemnumber);

my $suspend_until = DateTime->now->add(days => 10)->ymd;
my $expirationdate = DateTime->now->add(days => 10)->ymd;

my $post_data = {
    borrowernumber => int($borrowernumber),
    biblionumber => int($biblionumber),
    itemnumber => int($itemnumber),
    branchcode => $branchcode,
    expirationdate => $expirationdate,
};
my $put_data = {
    priority => 2,
    suspend_until => $suspend_until,
};

subtest "Test endpoints without authentication" => sub {
    plan tests => 8;
    $t->get_ok('/api/v1/holds')
      ->status_is(401);
    $t->post_ok('/api/v1/holds')
      ->status_is(401);
    $t->put_ok('/api/v1/holds/0')
      ->status_is(401);
    $t->delete_ok('/api/v1/holds/0')
      ->status_is(401);
};


subtest "Test endpoints without permission" => sub {
    plan tests => 10;

    $tx = $t->ua->build_tx(GET => "/api/v1/holds?borrowernumber=$borrowernumber");
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx) # no permission
      ->status_is(403);
    $tx = $t->ua->build_tx(GET => "/api/v1/holds?borrowernumber=$borrowernumber");
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx) # reserveforothers permission
      ->status_is(403);
    $tx = $t->ua->build_tx(POST => "/api/v1/holds" => json => $post_data );
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx) # no permission
      ->status_is(403);
    $tx = $t->ua->build_tx(PUT => "/api/v1/holds/0" => json => $put_data );
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx) # no permission
      ->status_is(403);
    $tx = $t->ua->build_tx(DELETE => "/api/v1/holds/0");
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx) # no permission
      ->status_is(403);
};
subtest "Test endpoints without permission, but accessing own object" => sub {
    plan tests => 21;

    my $reserve_id3 = C4::Reserves::AddReserve($branchcode, $nopermission->{'borrowernumber'},
    $biblionumber, undef, 2, undef, undef, undef, '', $itemnumber, 'W');
    # try to delete my own hold while it's waiting; an error should occur
    $tx = $t->ua->build_tx(DELETE => "/api/v1/holds/$reserve_id3" => json => $put_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx)
      ->status_is(403)
      ->json_is('/error', 'Hold is already in transfer or waiting and cannot be cancelled by patron.');
    # reset the hold's found status; after that, cancellation should work
    Koha::Holds->find($reserve_id3)->found('')->store;
    $tx = $t->ua->build_tx(DELETE => "/api/v1/holds/$reserve_id3" => json => $put_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx)
      ->status_is(200);
    is(Koha::Holds->find({ borrowernumber => $nopermission->{borrowernumber} }), undef, "Hold deleted.");

    my $borrno_tmp = $post_data->{'borrowernumber'};
    $post_data->{'borrowernumber'} = int $nopermission->{'borrowernumber'};
    $tx = $t->ua->build_tx(POST => "/api/v1/holds" => json => $post_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx) # create hold to myself
      ->status_is(201)
      ->json_has('/reserve_id');

    $post_data->{'borrowernumber'} = $borrno_tmp;
    $tx = $t->ua->build_tx(GET => "/api/v1/holds?borrowernumber=".$nopermission-> { borrowernumber });
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx) # get my own holds
      ->status_is(200)
      ->json_is('/0/borrowernumber', $nopermission->{ borrowernumber })
      ->json_is('/0/biblionumber', $biblionumber)
      ->json_is('/0/itemnumber', $itemnumber)
      ->json_is('/0/expirationdate', $expirationdate)
      ->json_is('/0/branchcode', $branchcode);

    $reserve_id3 = Koha::Holds->find({ borrowernumber => $nopermission->{borrowernumber} })->reserve_id;
    $tx = $t->ua->build_tx(PUT => "/api/v1/holds/$reserve_id3" => json => $put_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session_nopermission->id});
    $t->request_ok($tx) # create hold to myself
      ->status_is(200)
      ->json_is('/reserve_id', $reserve_id3)
      ->json_is('/suspend_until', $suspend_until . ' 00:00:00')
      ->json_is('/priority', 2);
};

subtest "Test endpoints with permission" => sub {
    plan tests => 45;

    $tx = $t->ua->build_tx(GET => '/api/v1/holds');
    $tx->req->cookies({name => 'CGISESSID', value => $session->id});
    $t->request_ok($tx)
      ->status_is(200)
      ->json_has('/0')
      ->json_has('/1')
      ->json_has('/2')
      ->json_hasnt('/3');

    $tx = $t->ua->build_tx(GET => '/api/v1/holds?priority=2');
    $tx->req->cookies({name => 'CGISESSID', value => $session->id});
    $t->request_ok($tx)
      ->status_is(200)
      ->json_is('/0/borrowernumber', $nopermission->{borrowernumber})
      ->json_hasnt('/1');

    $tx = $t->ua->build_tx(PUT => "/api/v1/holds/$reserve_id" => json => $put_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx)
      ->status_is(200)
      ->json_is('/reserve_id', $reserve_id)
      ->json_is('/suspend_until', $suspend_until . ' 00:00:00')
      ->json_is('/priority', 2);

    $tx = $t->ua->build_tx(DELETE => "/api/v1/holds/$reserve_id");
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx)
      ->status_is(200);

    $tx = $t->ua->build_tx(PUT => "/api/v1/holds/$reserve_id" => json => $put_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx)
      ->status_is(404)
      ->json_has('/error');

    $tx = $t->ua->build_tx(DELETE => "/api/v1/holds/$reserve_id");
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx)
      ->status_is(404)
      ->json_has('/error');

    $tx = $t->ua->build_tx(GET => "/api/v1/holds?borrowernumber=".$borrower->borrowernumber);
    $tx->req->cookies({name => 'CGISESSID', value => $session2->id}); # get with borrowers flag
    $t->request_ok($tx)
      ->status_is(200)
      ->json_is([]);

    my $inexisting_borrowernumber = $borrowernumber2*2;
    $tx = $t->ua->build_tx(GET => "/api/v1/holds?borrowernumber=$inexisting_borrowernumber");
    $tx->req->cookies({name => 'CGISESSID', value => $session->id});
    $t->request_ok($tx)
      ->status_is(200)
      ->json_is([]);

    $tx = $t->ua->build_tx(DELETE => "/api/v1/holds/$reserve_id2");
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx)
      ->status_is(200);

    $tx = $t->ua->build_tx(POST => "/api/v1/holds" => json => $post_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx)
      ->status_is(201)
      ->json_has('/reserve_id');
    $reserve_id = $t->tx->res->json->{reserve_id};

    $tx = $t->ua->build_tx(GET => "/api/v1/holds?borrowernumber=$borrowernumber");
    $tx->req->cookies({name => 'CGISESSID', value => $session->id});
    $t->request_ok($tx)
      ->status_is(200)
      ->json_is('/0/reserve_id', $reserve_id)
      ->json_is('/0/expirationdate', $expirationdate)
      ->json_is('/0/branchcode', $branchcode);

    $tx = $t->ua->build_tx(POST => "/api/v1/holds" => json => $post_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx)
      ->status_is(403)
      ->json_like('/error', qr/itemAlreadyOnHold/);

    $post_data->{biblionumber} = int($biblionumber2);
    $post_data->{itemnumber} = int($itemnumber2);
    $tx = $t->ua->build_tx(POST => "/api/v1/holds" => json => $post_data);
    $tx->req->cookies({name => 'CGISESSID', value => $session3->id});
    $t->request_ok($tx)
      ->status_is(403)
      ->json_like('/error', qr/tooManyReserves/);
};


$dbh->rollback;

sub create_biblio {
    my ($title) = @_;

    my $biblio = Koha::Biblio->new( { title => $title } )->store;

    return $biblio->biblionumber;
}

sub create_item {
    my ( $biblionumber, $barcode ) = @_;

    Koha::Items->search( { barcode => $barcode } )->delete;
    my $builder = t::lib::TestBuilder->new;
    my $item    = $builder->build(
        {
            source => 'Item',
            value  => {
                biblionumber     => $biblionumber,
                barcode          => $barcode,
            }
        }
    );

    return $item->{itemnumber};
}
