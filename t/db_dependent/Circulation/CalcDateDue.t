#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 5;
use Test::MockModule;
use DBI;
use DateTime;
use t::lib::Mocks;
use t::lib::TestBuilder;

use_ok('C4::Circulation');

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;

my $categorycode = 'B';
my $itemtype = 'MX';
my $branchcode = 'FPL';
my $checkout_type = $Koha::Checkouts::type->{checkout};
my $issuelength = 10;
my $renewalperiod = 5;
my $lengthunit = 'days';
my $ccode = 'FIC',
my $permanent_location = 'FIC';
my $ccode_and_loc = {
    ccode => $ccode,
    permanent_location => $permanent_location,
};

Koha::Database->schema->resultset('Issuingrule')->create({
  categorycode => $categorycode,
  itemtype => $itemtype,
  branchcode => $branchcode,
  issuelength => $issuelength,
  renewalperiod => $renewalperiod,
  lengthunit => $lengthunit,
  ccode => $ccode,
  permanent_location => $permanent_location,
  checkout_type => $checkout_type,
});

#Set syspref ReturnBeforeExpiry = 1 and useDaysMode = 'Days'
t::lib::Mocks::mock_preference('ReturnBeforeExpiry', 1);
t::lib::Mocks::mock_preference('useDaysMode', 'Days');

my $dateexpiry = '2013-01-01';

my $borrower = {categorycode => 'B', dateexpiry => $dateexpiry};
my $start_date = DateTime->new({year => 2013, month => 2, day => 9});
my $date = C4::Circulation::CalcDateDue( $start_date, $itemtype, $branchcode, $borrower, $checkout_type, undef, $ccode_and_loc );
is($date, $dateexpiry . 'T23:59:00', 'date expiry');
$date = C4::Circulation::CalcDateDue( $start_date, $itemtype, $branchcode, $borrower, $checkout_type, 1, $ccode_and_loc );


#Set syspref ReturnBeforeExpiry = 1 and useDaysMode != 'Days'
t::lib::Mocks::mock_preference('ReturnBeforeExpiry', 1);
t::lib::Mocks::mock_preference('useDaysMode', 'noDays');

$borrower = {categorycode => 'B', dateexpiry => $dateexpiry};
$start_date = DateTime->new({year => 2013, month => 2, day => 9});
$date = C4::Circulation::CalcDateDue( $start_date, $itemtype, $branchcode, $borrower, $checkout_type, undef, $ccode_and_loc );
is($date, $dateexpiry . 'T23:59:00', 'date expiry');

$date = C4::Circulation::CalcDateDue( $start_date, $itemtype, $branchcode, $borrower, $checkout_type, 1, $ccode_and_loc );


#Set syspref ReturnBeforeExpiry = 0 and useDaysMode = 'Days'
t::lib::Mocks::mock_preference('ReturnBeforeExpiry', 0);
t::lib::Mocks::mock_preference('useDaysMode', 'Days');

$borrower = {categorycode => 'B', dateexpiry => $dateexpiry};
$start_date = DateTime->new({year => 2013, month => 2, day => 9});
$date = C4::Circulation::CalcDateDue( $start_date, $itemtype, $branchcode, $borrower, $checkout_type, undef, $ccode_and_loc );
is($date, '2013-02-' . (9 + $issuelength) . 'T23:59:00', "date expiry ( 9 + $issuelength )");

$date = C4::Circulation::CalcDateDue( $start_date, $itemtype, $branchcode, $borrower, $checkout_type, 1, $ccode_and_loc );
is($date, '2013-02-' . (9 + $renewalperiod) . 'T23:59:00', "date expiry ( 9 + $renewalperiod )");

$schema->storage->txn_rollback;
