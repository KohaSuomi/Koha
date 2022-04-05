#!/usr/bin/perl

use Modern::Perl;

use C4::Context;
use Koha::Database;
use Koha::Patrons;

use t::lib::TestBuilder;

use Test::More tests => 35;

use_ok('Koha::Patron::Debarments');

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;
my $dbh = C4::Context->dbh;

my $library = $builder->build({
    source => 'Branch',
});

my $patron_category = $builder->build({ source => 'Category' });
my $borrowernumber = Koha::Patron->new({
    firstname =>  'my firstname',
    surname => 'my surname',
    categorycode => $patron_category->{categorycode},
    branchcode => $library->{branchcode},
})->store->borrowernumber;

my $success = Koha::Patron::Debarments::AddDebarment({
    borrowernumber => $borrowernumber,
    expiration => '9999-06-10',
    type => 'MANUAL',
    comment => 'Test 1',
});
is( $success, 1, "AddDebarment returned true" );


my $debarments = Koha::Patron::Debarments::GetDebarments({ borrowernumber => $borrowernumber });
is( @$debarments, 1, "GetDebarments returns 1 debarment" );
is( $debarments->[0]->{'type'}, 'MANUAL', "Correctly stored 'type'" );
is( $debarments->[0]->{'expiration'}, '9999-06-10', "Correctly stored 'expiration'" );
is( $debarments->[0]->{'comment'}, 'Test 1', "Correctly stored 'comment'" );


$success = Koha::Patron::Debarments::AddDebarment({
    borrowernumber => $borrowernumber,
    comment => 'Test 2',
});

$debarments = Koha::Patron::Debarments::GetDebarments({ borrowernumber => $borrowernumber });
is( @$debarments, 2, "GetDebarments returns 2 debarments" );
is( $debarments->[1]->{'type'}, 'MANUAL', "Correctly stored 'type'" );
is( $debarments->[1]->{'expiration'}, undef, "Correctly stored debarrment with no expiration" );
is( $debarments->[1]->{'comment'}, 'Test 2', "Correctly stored 'comment'" );


Koha::Patron::Debarments::ModDebarment({
    borrower_debarment_id => $debarments->[1]->{'borrower_debarment_id'},
    comment => 'Test 3',
    expiration => '9998-06-10',
});
$debarments = Koha::Patron::Debarments::GetDebarments({ borrowernumber => $borrowernumber });
is( $debarments->[1]->{'comment'}, 'Test 3', "ModDebarment functions correctly" );

my $patron = Koha::Patrons->find( $borrowernumber )->unblessed;
is( $patron->{'debarred'}, '9999-06-10', "Field borrowers.debarred set correctly" );
is( $patron->{'debarredcomment'}, "Test 1\nTest 3", "Field borrowers.debarredcomment set correctly" );


Koha::Patron::Debarments::AddUniqueDebarment({
    borrowernumber => $borrowernumber,
    type           => 'OVERDUES'
});
$debarments = Koha::Patron::Debarments::GetDebarments({
    borrowernumber => $borrowernumber,
    type => 'OVERDUES',
});
is( @$debarments, 1, "GetDebarments returns 1 OVERDUES debarment" );
is( $debarments->[0]->{'type'}, 'OVERDUES', "AddOverduesDebarment created new debarment correctly" );

Koha::Patron::Debarments::AddUniqueDebarment({
    borrowernumber => $borrowernumber,
    expiration => '9999-11-09',
    type => 'OVERDUES'
});
$debarments = Koha::Patron::Debarments::GetDebarments({
    borrowernumber => $borrowernumber,
    type => 'OVERDUES',
});
is( @$debarments, 1, "GetDebarments returns 1 OVERDUES debarment after running AddOverduesDebarment twice" );
is( $debarments->[0]->{'expiration'}, '9999-11-09', "AddOverduesDebarment updated OVERDUES debarment correctly" );


my $delUniqueDebarment = Koha::Patron::Debarments::DelUniqueDebarment({
});
is( $delUniqueDebarment, undef, "DelUniqueDebarment without the arguments 'borrowernumber' and 'type' returns undef" );
$debarments = Koha::Patron::Debarments::GetDebarments({
    borrowernumber => $borrowernumber,
    type => 'OVERDUES',
});
is( @$debarments, 1, "DelUniqueDebarment without the arguments 'borrowernumber' and 'type' does not delete the debarment" );

$delUniqueDebarment = Koha::Patron::Debarments::DelUniqueDebarment({
    borrowernumber => $borrowernumber,
});
is( $delUniqueDebarment, undef, "DelUniqueDebarment without the argument 'type' returns undef" );
$debarments = Koha::Patron::Debarments::GetDebarments({
    borrowernumber => $borrowernumber,
    type => 'OVERDUES',
});
is( @$debarments, 1, "DelUniqueDebarment without the argument 'type' does not delete the debarment" );

$delUniqueDebarment = Koha::Patron::Debarments::DelUniqueDebarment({
    type => 'OVERDUES'
});
is( $delUniqueDebarment, undef, "DelUniqueDebarment without the argument 'borrowernumber' returns undef" );
$debarments = Koha::Patron::Debarments::GetDebarments({
    borrowernumber => $borrowernumber,
    type => 'OVERDUES',
});
is( @$debarments, 1, "DelUniqueDebarment without the argument 'borrowerumber' does not delete the debarment" );

$delUniqueDebarment = Koha::Patron::Debarments::DelUniqueDebarment({
    borrowernumber => $borrowernumber,
    type => 'SUSPENSION',
});
is( $delUniqueDebarment, undef, "DelUniqueDebarment with wrong arguments returns undef" );
$debarments = Koha::Patron::Debarments::GetDebarments({
    borrowernumber => $borrowernumber,
    type => 'OVERDUES',
});
is( @$debarments, 1, "DelUniqueDebarment with wrong arguments does not delete the debarment" );

$delUniqueDebarment = Koha::Patron::Debarments::DelUniqueDebarment({
    borrowernumber => $borrowernumber,
    type => 'OVERDUES',
});
is( $delUniqueDebarment, 1, "DelUniqueDebarment returns 1" );
$debarments = Koha::Patron::Debarments::GetDebarments({
    borrowernumber => $borrowernumber,
    type => 'OVERDUES',
});
is( @$debarments, 0, "DelUniqueDebarment functions correctly" );


$debarments = Koha::Patron::Debarments::GetDebarments({ borrowernumber => $borrowernumber });
foreach my $d ( @$debarments ) {
    Koha::Patron::Debarments::DelDebarment( $d->{'borrower_debarment_id'} );
}
$debarments = Koha::Patron::Debarments::GetDebarments({ borrowernumber => $borrowernumber });
is( @$debarments, 0, "DelDebarment functions correctly" );

$dbh->do(q|UPDATE borrowers SET debarred = '1970-01-01'|);
is( Koha::Patrons->find( $borrowernumber )->is_debarred, undef, 'A patron with a debarred date in the past is not debarred' );

$dbh->do(q|UPDATE borrowers SET debarred = NULL|);
is( Koha::Patrons->find( $borrowernumber )->is_debarred, undef, 'A patron without a debarred date is not debarred' );

$dbh->do(q|UPDATE borrowers SET debarred = '9999-12-31'|); # Note: Change this test before the first of January 10000!
is( Koha::Patrons->find( $borrowernumber )->is_debarred, '9999-12-31', 'A patron with a debarred date in the future is debarred' );

# Test patrons merge
my $borrowernumber2 = Koha::Patron->new(
    {
        firstname    => 'my firstname bis',
        surname      => 'my surname bis',
        categorycode => $patron_category->{categorycode},
        branchcode   => $library->{branchcode},
    }
)->store->borrowernumber;
my $debarreddate2    = '9999-06-10'; # Be sure to be in the future
my $debarredcomment2 = 'Test merge';
Koha::Patron::Debarments::AddDebarment(
    {
        borrowernumber => $borrowernumber2,
        expiration     => $debarreddate2,
        type           => 'MANUAL',
        comment        => $debarredcomment2,
    }
);
my $borrowernumber3 = Koha::Patron->new(
    {
        firstname    => 'my firstname ter',
        surname      => 'my surname ter',
        categorycode => $patron_category->{categorycode},
        branchcode   => $library->{branchcode},
    }
)->store->borrowernumber;
Koha::Patrons->find($borrowernumber3)->merge_with( [$borrowernumber2] );
is( Koha::Patrons->find($borrowernumber3)->debarred,
    $debarreddate2, 'Koha::Patron->merge_with() transfers well debarred' );
is( Koha::Patrons->find($borrowernumber3)->debarredcomment,
    $debarredcomment2, 'Koha::Patron->merge_with() transfers well debarredcomment' );

# Test removing debartments after payment
my $debarmentsRulesPref = C4::Context->preference("DebarmentsToLiftAfterPayment");
C4::Context->set_preference("DebarmentsToLiftAfterPayment", "Test debarment:\n  outstanding: 0\nTest debarment 2:");

AddDebarment({
    borrowernumber => $borrowernumber,
    comment => 'Test debarment',
});
AddDebarment({
    borrowernumber => $borrowernumber,
    comment => 'Test debarment 2',
});

$debarments = GetDebarments({ borrowernumber => $borrowernumber });
is( @$debarments, 2, "GetDebarments returns 2 debarments before payment" );

DelDebarmentsAfterPayment({ borrowernumber => $borrowernumber });
C4::Context->set_preference("DebarmentsToLiftAfterPayment", $debarmentsRulesPref);

$debarments = GetDebarments({ borrowernumber => $borrowernumber });
is( @$debarments, 0, "GetDebarments returns 0 debarments after payment" );