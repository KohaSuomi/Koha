#!/usr/bin/perl

# Copyright 2015 Koha Development team
#
# This file is part of Koha
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 23;
use Test::Warn;
use DateTime;

use C4::Biblio;
use C4::Circulation;
use C4::Members;
use C4::Circulation;

use Koha::Holds;
use Koha::Patron;
use Koha::Patrons;
use Koha::Database;
use Koha::DateUtils;
use Koha::Virtualshelves;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder       = t::lib::TestBuilder->new;
my $library = $builder->build({source => 'Branch' });
my $category = $builder->build({source => 'Category' });
my $nb_of_patrons = Koha::Patrons->search->count;
my $new_patron_1  = Koha::Patron->new(
    {   cardnumber => 'test_cn_1',
        branchcode => $library->{branchcode},
        categorycode => $category->{categorycode},
        surname => 'surname for patron1',
        firstname => 'firstname for patron1',
        userid => 'a_nonexistent_userid_1',
    }
)->store;
my $new_patron_2  = Koha::Patron->new(
    {   cardnumber => 'test_cn_2',
        branchcode => $library->{branchcode},
        categorycode => $category->{categorycode},
        surname => 'surname for patron2',
        firstname => 'firstname for patron2',
        userid => 'a_nonexistent_userid_2',
    }
)->store;

C4::Context->_new_userenv('xxx');
C4::Context->set_userenv(0,0,0,'firstname','surname', $library->{branchcode}, 'Midway Public Library', '', '', '');

is( Koha::Patrons->search->count, $nb_of_patrons + 2, 'The 2 patrons should have been added' );

my $retrieved_patron_1 = Koha::Patrons->find( $new_patron_1->borrowernumber );
is( $retrieved_patron_1->cardnumber, $new_patron_1->cardnumber, 'Find a patron by borrowernumber should return the correct patron' );

subtest 'library' => sub {
    plan tests => 2;
    is( $retrieved_patron_1->library->branchcode, $library->{branchcode}, 'Koha::Patron->library should return the correct library' );
    is( ref($retrieved_patron_1->library), 'Koha::Library', 'Koha::Patron->library should return a Koha::Library object' );
};

subtest 'guarantees' => sub {
    plan tests => 8;
    my $guarantees = $new_patron_1->guarantees;
    is( ref($guarantees), 'Koha::Patrons', 'Koha::Patron->guarantees should return a Koha::Patrons result set in a scalar context' );
    is( $guarantees->count, 0, 'new_patron_1 should have 0 guarantee' );
    my @guarantees = $new_patron_1->guarantees;
    is( ref(\@guarantees), 'ARRAY', 'Koha::Patron->guarantees should return an array in a list context' );
    is( scalar(@guarantees), 0, 'new_patron_1 should have 0 guarantee' );

    my $guarantee_1 = $builder->build({ source => 'Borrower', value => { guarantorid => $new_patron_1->borrowernumber }});
    my $guarantee_2 = $builder->build({ source => 'Borrower', value => { guarantorid => $new_patron_1->borrowernumber }});

    $guarantees = $new_patron_1->guarantees;
    is( ref($guarantees), 'Koha::Patrons', 'Koha::Patron->guarantees should return a Koha::Patrons result set in a scalar context' );
    is( $guarantees->count, 2, 'new_patron_1 should have 2 guarantees' );
    @guarantees = $new_patron_1->guarantees;
    is( ref(\@guarantees), 'ARRAY', 'Koha::Patron->guarantees should return an array in a list context' );
    is( scalar(@guarantees), 2, 'new_patron_1 should have 2 guarantees' );
    $_->delete for @guarantees;
};

subtest 'category' => sub {
    plan tests => 2;
    my $patron_category = $new_patron_1->category;
    is( ref( $patron_category), 'Koha::Patron::Category', );
    is( $patron_category->categorycode, $category->{categorycode}, );
};

subtest 'siblings' => sub {
    plan tests => 7;
    my $siblings = $new_patron_1->siblings;
    is( $siblings, undef, 'Koha::Patron->siblings should not crashed if the patron has no guarantor' );
    my $guarantee_1 = $builder->build( { source => 'Borrower', value => { guarantorid => $new_patron_1->borrowernumber } } );
    my $retrieved_guarantee_1 = Koha::Patrons->find($guarantee_1);
    $siblings = $retrieved_guarantee_1->siblings;
    is( ref($siblings), 'Koha::Patrons', 'Koha::Patron->siblings should return a Koha::Patrons result set in a scalar context' );
    my @siblings = $retrieved_guarantee_1->siblings;
    is( ref( \@siblings ), 'ARRAY', 'Koha::Patron->siblings should return an array in a list context' );
    is( $siblings->count,  0,       'guarantee_1 should not have siblings yet' );
    my $guarantee_2 = $builder->build( { source => 'Borrower', value => { guarantorid => $new_patron_1->borrowernumber } } );
    my $guarantee_3 = $builder->build( { source => 'Borrower', value => { guarantorid => $new_patron_1->borrowernumber } } );
    $siblings = $retrieved_guarantee_1->siblings;
    is( $siblings->count,               2,                               'guarantee_1 should have 2 siblings' );
    is( $guarantee_2->{borrowernumber}, $siblings->next->borrowernumber, 'guarantee_2 should exist in the guarantees' );
    is( $guarantee_3->{borrowernumber}, $siblings->next->borrowernumber, 'guarantee_3 should exist in the guarantees' );
    $_->delete for $retrieved_guarantee_1->siblings;
    $retrieved_guarantee_1->delete;
};

subtest 'has_overdues' => sub {
    plan tests => 3;

    my $biblioitem_1 = $builder->build( { source => 'Biblioitem' } );
    my $item_1 = $builder->build(
        {   source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                notforloan    => 0,
                itemlost      => 0,
                withdrawn     => 0,
                biblionumber  => $biblioitem_1->{biblionumber}
            }
        }
    );
    my $retrieved_patron = Koha::Patrons->find( $new_patron_1->borrowernumber );
    is( $retrieved_patron->has_overdues, 0, );

    my $tomorrow = DateTime->today( time_zone => C4::Context->tz() )->add( days => 1 );
    my $issue = Koha::Checkout->new({ borrowernumber => $new_patron_1->id, itemnumber => $item_1->{itemnumber}, date_due => $tomorrow, branchcode => $library->{branchcode} })->store();
    is( $retrieved_patron->has_overdues, 0, );
    $issue->delete();
    my $yesterday = DateTime->today(time_zone => C4::Context->tz())->add( days => -1 );
    $issue = Koha::Checkout->new({ borrowernumber => $new_patron_1->id, itemnumber => $item_1->{itemnumber}, date_due => $yesterday, branchcode => $library->{branchcode} })->store();
    $retrieved_patron = Koha::Patrons->find( $new_patron_1->borrowernumber );
    is( $retrieved_patron->has_overdues, 1, );
    $issue->delete();
};

subtest 'update_password' => sub {
    plan tests => 7;

    t::lib::Mocks::mock_preference( 'BorrowersLog', 1 );
    my $original_userid   = $new_patron_1->userid;
    my $original_password = $new_patron_1->password;
    warning_like { $retrieved_patron_1->update_password( $new_patron_2->userid, 'another_password' ) }
    qr{Duplicate entry},
      'Koha::Patron->update_password should warn if the userid is already used by another patron';
    is( Koha::Patrons->find( $new_patron_1->borrowernumber )->userid,   $original_userid,   'Koha::Patron->update_password should not have updated the userid' );
    is( Koha::Patrons->find( $new_patron_1->borrowernumber )->password, $original_password, 'Koha::Patron->update_password should not have updated the userid' );

    $retrieved_patron_1->update_password( 'another_nonexistent_userid_1', 'another_password' );
    is( Koha::Patrons->find( $new_patron_1->borrowernumber )->userid,   'another_nonexistent_userid_1', 'Koha::Patron->update_password should have updated the userid' );
    is( Koha::Patrons->find( $new_patron_1->borrowernumber )->password, 'another_password',             'Koha::Patron->update_password should have updated the password' );

    my $number_of_logs = $schema->resultset('ActionLog')->search( { module => 'MEMBERS', action => 'CHANGE PASS', object => $new_patron_1->borrowernumber } )->count;
    is( $number_of_logs, 1, 'With BorrowerLogs, Koha::Patron->update_password should have logged' );

    t::lib::Mocks::mock_preference( 'BorrowersLog', 0 );
    $retrieved_patron_1->update_password( 'yet_another_nonexistent_userid_1', 'another_password' );
    $number_of_logs = $schema->resultset('ActionLog')->search( { module => 'MEMBERS', action => 'CHANGE PASS', object => $new_patron_1->borrowernumber } )->count;
    is( $number_of_logs, 1, 'With BorrowerLogs, Koha::Patron->update_password should not have logged' );
};

subtest 'is_expired' => sub {
    plan tests => 5;
    my $patron = $builder->build({ source => 'Borrower' });
    $patron = Koha::Patrons->find( $patron->{borrowernumber} );
    $patron->dateexpiry( undef )->store->discard_changes;
    is( $patron->is_expired, 0, 'Patron should not be considered expired if dateexpiry is not set');
    $patron->dateexpiry( '0000-00-00' )->store->discard_changes;
    is( $patron->is_expired, 0, 'Patron should not be considered expired if dateexpiry is not 0000-00-00');
    $patron->dateexpiry( dt_from_string )->store->discard_changes;
    is( $patron->is_expired, 0, 'Patron should not be considered expired if dateexpiry is today');
    $patron->dateexpiry( dt_from_string->add( days => 1 ) )->store->discard_changes;
    is( $patron->is_expired, 0, 'Patron should not be considered expired if dateexpiry is tomorrow');
    $patron->dateexpiry( dt_from_string->add( days => -1 ) )->store->discard_changes;
    is( $patron->is_expired, 1, 'Patron should be considered expired if dateexpiry is yesterday');

    $patron->delete;
};

subtest 'is_going_to_expire' => sub {
    plan tests => 9;
    my $patron = $builder->build({ source => 'Borrower' });
    $patron = Koha::Patrons->find( $patron->{borrowernumber} );
    $patron->dateexpiry( undef )->store->discard_changes;
    is( $patron->is_going_to_expire, 0, 'Patron should not be considered going to expire if dateexpiry is not set');
    $patron->dateexpiry( '0000-00-00' )->store->discard_changes;
    is( $patron->is_going_to_expire, 0, 'Patron should not be considered going to expire if dateexpiry is not 0000-00-00');

    t::lib::Mocks::mock_preference('NotifyBorrowerDeparture', 0);
    $patron->dateexpiry( dt_from_string )->store->discard_changes;
    is( $patron->is_going_to_expire, 0, 'Patron should not be considered going to expire if dateexpiry is today');

    $patron->dateexpiry( dt_from_string )->store->discard_changes;
    is( $patron->is_going_to_expire, 0, 'Patron should not be considered going to expire if dateexpiry is today and pref is 0');

    t::lib::Mocks::mock_preference('NotifyBorrowerDeparture', 10);
    $patron->dateexpiry( dt_from_string->add( days => 11 ) )->store->discard_changes;
    is( $patron->is_going_to_expire, 0, 'Patron should not be considered going to expire if dateexpiry is 11 days ahead and pref is 10');

    t::lib::Mocks::mock_preference('NotifyBorrowerDeparture', 0);
    $patron->dateexpiry( dt_from_string->add( days => 10 ) )->store->discard_changes;
    is( $patron->is_going_to_expire, 0, 'Patron should not be considered going to expire if dateexpiry is 10 days ahead and pref is 0');

    t::lib::Mocks::mock_preference('NotifyBorrowerDeparture', 10);
    $patron->dateexpiry( dt_from_string->add( days => 10 ) )->store->discard_changes;
    is( $patron->is_going_to_expire, 0, 'Patron should not be considered going to expire if dateexpiry is 10 days ahead and pref is 10');
    $patron->delete;

    t::lib::Mocks::mock_preference('NotifyBorrowerDeparture', 10);
    $patron->dateexpiry( dt_from_string->add( days => 20 ) )->store->discard_changes;
    is( $patron->is_going_to_expire, 0, 'Patron should not be considered going to expire if dateexpiry is 20 days ahead and pref is 10');

    t::lib::Mocks::mock_preference('NotifyBorrowerDeparture', 20);
    $patron->dateexpiry( dt_from_string->add( days => 10 ) )->store->discard_changes;
    is( $patron->is_going_to_expire, 1, 'Patron should be considered going to expire if dateexpiry is 10 days ahead and pref is 20');

    $patron->delete;
};


subtest 'renew_account' => sub {
    plan tests => 10;
    my $a_month_ago                = dt_from_string->add( months => -1 )->truncate( to => 'day' );
    my $a_year_later               = dt_from_string->add( months => 12 )->truncate( to => 'day' );
    my $a_year_later_minus_a_month = dt_from_string->add( months => 11 )->truncate( to => 'day' );
    my $a_month_later              = dt_from_string->add( months => 1  )->truncate( to => 'day' );
    my $a_year_later_plus_a_month  = dt_from_string->add( months => 13 )->truncate( to => 'day' );
    my $patron_category = $builder->build(
        {   source => 'Category',
            value  => {
                enrolmentperiod     => 12,
                enrolmentperioddate => undef,
            }
        }
    );
    my $patron = $builder->build(
        {   source => 'Borrower',
            value  => {
                dateexpiry   => $a_month_ago,
                categorycode => $patron_category->{categorycode},
            }
        }
    );
    my $patron_2 = $builder->build(
        {  source => 'Borrower',
           value  => {
               dateexpiry => $a_month_ago,
               categorycode => $patron_category->{categorycode},
            }
        }
    );
    my $patron_3 = $builder->build(
        {  source => 'Borrower',
           value  => {
               dateexpiry => $a_month_later,
               categorycode => $patron_category->{categorycode},
           }
        }
    );
    my $retrieved_patron = Koha::Patrons->find( $patron->{borrowernumber} );
    my $retrieved_patron_2 = Koha::Patrons->find( $patron_2->{borrowernumber} );
    my $retrieved_patron_3 = Koha::Patrons->find( $patron_3->{borrowernumber} );

    t::lib::Mocks::mock_preference( 'BorrowerRenewalPeriodBase', 'dateexpiry' );
    t::lib::Mocks::mock_preference( 'BorrowersLog',              1 );
    my $expiry_date = $retrieved_patron->renew_account;
    is( $expiry_date, $a_year_later_minus_a_month, );
    my $retrieved_expiry_date = Koha::Patrons->find( $patron->{borrowernumber} )->dateexpiry;
    is( dt_from_string($retrieved_expiry_date), $a_year_later_minus_a_month );
    my $number_of_logs = $schema->resultset('ActionLog')->search( { module => 'MEMBERS', action => 'RENEW', object => $retrieved_patron->borrowernumber } )->count;
    is( $number_of_logs, 1, 'With BorrowerLogs, Koha::Patron->renew_account should have logged' );

    t::lib::Mocks::mock_preference( 'BorrowerRenewalPeriodBase', 'now' );
    t::lib::Mocks::mock_preference( 'BorrowersLog',              0 );
    $expiry_date = $retrieved_patron->renew_account;
    is( $expiry_date, $a_year_later, );
    $retrieved_expiry_date = Koha::Patrons->find( $patron->{borrowernumber} )->dateexpiry;
    is( dt_from_string($retrieved_expiry_date), $a_year_later );
    $number_of_logs = $schema->resultset('ActionLog')->search( { module => 'MEMBERS', action => 'RENEW', object => $retrieved_patron->borrowernumber } )->count;
    is( $number_of_logs, 1, 'Without BorrowerLogs, Koha::Patron->renew_account should not have logged' );

    t::lib::Mocks::mock_preference( 'BorrowerRenewalPeriodBase', 'combination' );
    $expiry_date = $retrieved_patron_2->renew_account;
    is( $expiry_date, $a_year_later );
    $retrieved_expiry_date = Koha::Patrons->find( $patron_2->{borrowernumber} )->dateexpiry;
    is( dt_from_string($retrieved_expiry_date), $a_year_later );

    $expiry_date = $retrieved_patron_3->renew_account;
    is( $expiry_date, $a_year_later_plus_a_month );
    $retrieved_expiry_date = Koha::Patrons->find( $patron_3->{borrowernumber} )->dateexpiry;
    is( dt_from_string($retrieved_expiry_date), $a_year_later_plus_a_month );

    $retrieved_patron->delete;
    $retrieved_patron_2->delete;
    $retrieved_patron_3->delete;
};

subtest "move_to_deleted" => sub {
    plan tests => 5;
    my $originally_updated_on = '2016-01-01 12:12:12';
    my $patron = $builder->build( { source => 'Borrower',value => { updated_on => $originally_updated_on } } );
    my $retrieved_patron = Koha::Patrons->find( $patron->{borrowernumber} );
    is( ref( $retrieved_patron->move_to_deleted ), 'Koha::Schema::Result::Deletedborrower', 'Koha::Patron->move_to_deleted should return the Deleted patron' )
      ;    # FIXME This should be Koha::Deleted::Patron
    my $deleted_patron = $schema->resultset('Deletedborrower')
        ->search( { borrowernumber => $patron->{borrowernumber} }, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' } )
        ->next;
    ok( $retrieved_patron->updated_on, 'updated_on should be set for borrowers table' );
    ok( $deleted_patron->{updated_on}, 'updated_on should be set for deleted_borrowers table' );
    isnt( $deleted_patron->{updated_on}, $retrieved_patron->updated_on, 'Koha::Patron->move_to_deleted should have correctly updated the updated_on column');
    $deleted_patron->{updated_on} = $originally_updated_on; #reset for simplicity in comparing all other fields
    is_deeply( $deleted_patron, $patron, 'Koha::Patron->move_to_deleted should have correctly moved the patron to the deleted table' );
    $retrieved_patron->delete( $patron->{borrowernumber} );    # Cleanup
};

subtest "delete" => sub {
    plan tests => 5;
    t::lib::Mocks::mock_preference( 'BorrowersLog', 1 );
    my $patron           = $builder->build( { source => 'Borrower' } );
    my $retrieved_patron = Koha::Patrons->find( $patron->{borrowernumber} );
    my $hold             = $builder->build(
        {   source => 'Reserve',
            value  => { borrowernumber => $patron->{borrowernumber} }
        }
    );
    my $list = $builder->build(
        {   source => 'Virtualshelve',
            value  => { owner => $patron->{borrowernumber} }
        }
    );

    my $deleted = $retrieved_patron->delete;
    is( $deleted, 1, 'Koha::Patron->delete should return 1 if the patron has been correctly deleted' );

    is( Koha::Patrons->find( $patron->{borrowernumber} ), undef, 'Koha::Patron->delete should have deleted the patron' );

    is( Koha::Holds->search( { borrowernumber => $patron->{borrowernumber} } )->count, 0, q|Koha::Patron->delete should have deleted patron's holds| );

    is( Koha::Virtualshelves->search( { owner => $patron->{borrowernumber} } )->count, 0, q|Koha::Patron->delete should have deleted patron's lists| );

    my $number_of_logs = $schema->resultset('ActionLog')->search( { module => 'MEMBERS', action => 'DELETE', object => $retrieved_patron->borrowernumber } )->count;
    is( $number_of_logs, 1, 'With BorrowerLogs, Koha::Patron->delete should have logged' );
};

subtest 'add_enrolment_fee_if_needed' => sub {
    plan tests => 4;

    my $enrolmentfee_K  = 5;
    my $enrolmentfee_J  = 10;
    my $enrolmentfee_YA = 20;

    my $dbh = C4::Context->dbh;
    $dbh->do(q|UPDATE categories set enrolmentfee=? where categorycode=?|, undef, $enrolmentfee_K, 'K');
    $dbh->do(q|UPDATE categories set enrolmentfee=? where categorycode=?|, undef, $enrolmentfee_J, 'J');
    $dbh->do(q|UPDATE categories set enrolmentfee=? where categorycode=?|, undef, $enrolmentfee_YA, 'YA');

    my %borrower_data = (
        firstname    => 'my firstname',
        surname      => 'my surname',
        categorycode => 'K',
        branchcode   => $library->{branchcode},
    );

    my $borrowernumber = C4::Members::AddMember(%borrower_data);
    $borrower_data{borrowernumber} = $borrowernumber;

    my ($total) = C4::Members::GetMemberAccountRecords($borrowernumber);
    is( $total, $enrolmentfee_K, "New kid pay $enrolmentfee_K" );

    t::lib::Mocks::mock_preference( 'FeeOnChangePatronCategory', 0 );
    $borrower_data{categorycode} = 'J';
    C4::Members::ModMember(%borrower_data);
    ($total) = C4::Members::GetMemberAccountRecords($borrowernumber);
    is( $total, $enrolmentfee_K, "Kid growing and become a juvenile, but shouldn't pay for the upgrade " );

    $borrower_data{categorycode} = 'K';
    C4::Members::ModMember(%borrower_data);
    t::lib::Mocks::mock_preference( 'FeeOnChangePatronCategory', 1 );

    $borrower_data{categorycode} = 'J';
    C4::Members::ModMember(%borrower_data);
    ($total) = C4::Members::GetMemberAccountRecords($borrowernumber);
    is( $total, $enrolmentfee_K + $enrolmentfee_J, "Kid growing and become a juvenile, they should pay " . ( $enrolmentfee_K + $enrolmentfee_J ) );

    # Check with calling directly Koha::Patron->get_enrolment_fee_if_needed
    my $patron = Koha::Patrons->find($borrowernumber);
    $patron->categorycode('YA')->store;
    my $fee = $patron->add_enrolment_fee_if_needed;
    ($total) = C4::Members::GetMemberAccountRecords($borrowernumber);
    is( $total,
        $enrolmentfee_K + $enrolmentfee_J + $enrolmentfee_YA,
        "Juvenile growing and become an young adult, they should pay " . ( $enrolmentfee_K + $enrolmentfee_J + $enrolmentfee_YA )
    );

    $patron->delete;
};

subtest 'checkouts + get_overdues' => sub {
    plan tests => 8;

    my $library = $builder->build( { source => 'Branch' } );
    my ($biblionumber_1) = AddBiblio( MARC::Record->new, '' );
    my $item_1 = $builder->build(
        {
            source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                biblionumber  => $biblionumber_1
            }
        }
    );
    my $item_2 = $builder->build(
        {
            source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                biblionumber  => $biblionumber_1
            }
        }
    );
    my ($biblionumber_2) = AddBiblio( MARC::Record->new, '' );
    my $item_3 = $builder->build(
        {
            source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                biblionumber  => $biblionumber_2
            }
        }
    );
    my $patron = $builder->build(
        {
            source => 'Borrower',
            value  => { branchcode => $library->{branchcode} }
        }
    );

    $patron = Koha::Patrons->find( $patron->{borrowernumber} );
    my $checkouts = $patron->checkouts;
    is( $checkouts->count, 0, 'checkouts should not return any issues for that patron' );
    is( ref($checkouts), 'Koha::Checkouts', 'checkouts should return a Koha::Checkouts object' );

    # Not sure how this is useful, but AddIssue pass this variable to different other subroutines
    $patron = GetMember( borrowernumber => $patron->borrowernumber );

    my $module = new Test::MockModule('C4::Context');
    $module->mock( 'userenv', sub { { branch => $library->{branchcode} } } );

    AddIssue( $patron, $item_1->{barcode}, DateTime->now->subtract( days => 1 ) );
    AddIssue( $patron, $item_2->{barcode}, DateTime->now->subtract( days => 5 ) );
    AddIssue( $patron, $item_3->{barcode} );

    $patron = Koha::Patrons->find( $patron->{borrowernumber} );
    $checkouts = $patron->checkouts;
    is( $checkouts->count, 3, 'checkouts should return 3 issues for that patron' );
    is( ref($checkouts), 'Koha::Checkouts', 'checkouts should return a Koha::Checkouts object' );

    my $overdues = $patron->get_overdues;
    is( $overdues->count, 2, 'Patron should have 2 overdues');
    is( ref($overdues), 'Koha::Checkouts', 'Koha::Patron->get_overdues should return Koha::Checkouts' );
    is( $overdues->next->itemnumber, $item_1->{itemnumber}, 'The issue should be returned in the same order as they have been done, first is correct' );
    is( $overdues->next->itemnumber, $item_2->{itemnumber}, 'The issue should be returned in the same order as they have been done, second is correct' );

    # Clean stuffs
    Koha::Checkouts->search( { borrowernumber => $patron->borrowernumber } )->delete;
    $patron->delete;
    $module->unmock('userenv');
};

subtest 'get_age' => sub {
    plan tests => 7;

    my $patron = $builder->build( { source => 'Borrower' } );
    $patron = Koha::Patrons->find( $patron->{borrowernumber} );

    my $today = dt_from_string;

    $patron->dateofbirth( undef );
    is( $patron->get_age, undef, 'get_age should return undef if no dateofbirth is defined' );
    $patron->dateofbirth( $today->clone->add( years => -12, months => -6, days => -1 ) );
    is( $patron->get_age, 12, 'Patron should be 12' );
    $patron->dateofbirth( $today->clone->add( years => -18, months => 0, days => 1 ) );
    is( $patron->get_age, 17, 'Patron should be 17, happy birthday tomorrow!' );
    $patron->dateofbirth( $today->clone->add( years => -18, months => 0, days => 0 ) );
    is( $patron->get_age, 18, 'Patron should be 18' );
    $patron->dateofbirth( $today->clone->add( years => -18, months => -12, days => -31 ) );
    is( $patron->get_age, 19, 'Patron should be 19' );
    $patron->dateofbirth( $today->clone->add( years => -18, months => -12, days => -30 ) );
    is( $patron->get_age, 19, 'Patron should be 19 again' );
    $patron->dateofbirth( $today->clone->add( years => 0,   months => -1, days => -1 ) );
    is( $patron->get_age, 0, 'Patron is a newborn child' );

    $patron->delete;
};

subtest 'account' => sub {
    plan tests => 1;

    my $patron = $builder->build({source => 'Borrower'});

    $patron = Koha::Patrons->find( $patron->{borrowernumber} );
    my $account = $patron->account;
    is( ref($account),   'Koha::Account', 'account should return a Koha::Account object' );

    $patron->delete;
};

subtest 'search_upcoming_membership_expires' => sub {
    plan tests => 9;

    my $expiry_days = 15;
    t::lib::Mocks::mock_preference( 'MembershipExpiryDaysNotice', $expiry_days );
    my $nb_of_days_before = 1;
    my $nb_of_days_after = 2;

    my $builder = t::lib::TestBuilder->new();

    my $library = $builder->build({ source => 'Branch' });

    # before we add borrowers to this branch, add the expires we have now
    # note that this pertains to the current mocked setting of the pref
    # for this reason we add the new branchcode to most of the tests
    my $nb_of_expires = Koha::Patrons->search_upcoming_membership_expires->count;

    my $patron_1 = $builder->build({
        source => 'Borrower',
        value  => {
            branchcode              => $library->{branchcode},
            dateexpiry              => dt_from_string->add( days => $expiry_days )
        },
    });

    my $patron_2 = $builder->build({
        source => 'Borrower',
        value  => {
            branchcode              => $library->{branchcode},
            dateexpiry              => dt_from_string->add( days => $expiry_days - $nb_of_days_before )
        },
    });

    my $patron_3 = $builder->build({
        source => 'Borrower',
        value  => {
            branchcode              => $library->{branchcode},
            dateexpiry              => dt_from_string->add( days => $expiry_days + $nb_of_days_after )
        },
    });

    # Test without extra parameters
    my $upcoming_mem_expires = Koha::Patrons->search_upcoming_membership_expires();
    is( $upcoming_mem_expires->count, $nb_of_expires + 1, 'Get upcoming membership expires should return one new borrower.' );

    # Test with branch
    $upcoming_mem_expires = Koha::Patrons->search_upcoming_membership_expires({ 'me.branchcode' => $library->{branchcode} });
    is( $upcoming_mem_expires->count, 1, 'Test with branch parameter' );
    my $expired = $upcoming_mem_expires->next;
    is( $expired->surname, $patron_1->{surname}, 'Get upcoming membership expires should return the correct patron.' );
    is( $expired->library->branchemail, $library->{branchemail}, 'Get upcoming membership expires should return the correct patron.' );
    is( $expired->branchcode, $patron_1->{branchcode}, 'Get upcoming membership expires should return the correct patron.' );

    t::lib::Mocks::mock_preference( 'MembershipExpiryDaysNotice', 0 );
    $upcoming_mem_expires = Koha::Patrons->search_upcoming_membership_expires({ 'me.branchcode' => $library->{branchcode} });
    is( $upcoming_mem_expires->count, 0, 'Get upcoming membership expires with MembershipExpiryDaysNotice==0 should not return new records.' );

    # Test MembershipExpiryDaysNotice == undef
    t::lib::Mocks::mock_preference( 'MembershipExpiryDaysNotice', undef );
    $upcoming_mem_expires = Koha::Patrons->search_upcoming_membership_expires({ 'me.branchcode' => $library->{branchcode} });
    is( $upcoming_mem_expires->count, 0, 'Get upcoming membership expires without MembershipExpiryDaysNotice should not return new records.' );

    # Test the before parameter
    t::lib::Mocks::mock_preference( 'MembershipExpiryDaysNotice', 15 );
    $upcoming_mem_expires = Koha::Patrons->search_upcoming_membership_expires({ 'me.branchcode' => $library->{branchcode}, before => $nb_of_days_before });
    is( $upcoming_mem_expires->count, 2, 'Expect two results for before');
    # Test after parameter also
    $upcoming_mem_expires = Koha::Patrons->search_upcoming_membership_expires({ 'me.branchcode' => $library->{branchcode}, before => $nb_of_days_before, after => $nb_of_days_after });
    is( $upcoming_mem_expires->count, 3, 'Expect three results when adding after' );
    Koha::Patrons->search({ borrowernumber => { in => [ $patron_1->{borrowernumber}, $patron_2->{borrowernumber}, $patron_3->{borrowernumber} ] } })->delete;
};

subtest 'holds' => sub {
    plan tests => 3;

    my $library = $builder->build( { source => 'Branch' } );
    my ($biblionumber_1) = AddBiblio( MARC::Record->new, '' );
    my $item_1 = $builder->build(
        {
            source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                biblionumber  => $biblionumber_1
            }
        }
    );
    my $item_2 = $builder->build(
        {
            source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                biblionumber  => $biblionumber_1
            }
        }
    );
    my ($biblionumber_2) = AddBiblio( MARC::Record->new, '' );
    my $item_3 = $builder->build(
        {
            source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                biblionumber  => $biblionumber_2
            }
        }
    );
    my $patron = $builder->build(
        {
            source => 'Borrower',
            value  => { branchcode => $library->{branchcode} }
        }
    );

    $patron = Koha::Patrons->find( $patron->{borrowernumber} );
    my $holds = $patron->holds;
    is( ref($holds), 'Koha::Holds',
        'Koha::Patron->holds should return a Koha::Holds objects' );
    is( $holds->count, 0, 'There should not be holds placed by this patron yet' );

    C4::Reserves::AddReserve( $library->{branchcode},
        $patron->borrowernumber, $biblionumber_1 );
    # In the future
    C4::Reserves::AddReserve( $library->{branchcode},
        $patron->borrowernumber, $biblionumber_2, undef, undef, dt_from_string->add( days => 2 ) );

    $holds = $patron->holds;
    is( $holds->count, 2, 'There should be 2 holds placed by this patron' );

    $holds->delete;
    $patron->delete;
};

subtest 'search_patrons_to_anonymise & anonymise_issue_history' => sub {
    plan tests => 4;

    # TODO create a subroutine in t::lib::Mocks
    my $branch = $builder->build({ source => 'Branch' });
    my $userenv_patron = $builder->build({
        source => 'Borrower',
        value  => { branchcode => $branch->{branchcode} },
    });
    C4::Context->_new_userenv('DUMMY SESSION');
    C4::Context->set_userenv(
        $userenv_patron->{borrowernumber},
        $userenv_patron->{userid},
        'usercnum', 'First name', 'Surname',
        $branch->{branchcode},
        $branch->{branchname},
        0,
    );
    my $anonymous = $builder->build( { source => 'Borrower', }, );

    t::lib::Mocks::mock_preference( 'AnonymousPatron', $anonymous->{borrowernumber} );

    subtest 'patron privacy is 1 (default)' => sub {
        plan tests => 8;

        t::lib::Mocks::mock_preference('IndependentBranches', 0);
        my $patron = $builder->build(
            {   source => 'Borrower',
                value  => { privacy => 1, }
            }
        );
        my $item_1 = $builder->build(
            {   source => 'Item',
                value  => {
                    itemlost  => 0,
                    withdrawn => 0,
                },
            }
        );
        my $issue_1 = $builder->build(
            {   source => 'Issue',
                value  => {
                    borrowernumber => $patron->{borrowernumber},
                    itemnumber     => $item_1->{itemnumber},
                },
            }
        );
        my $item_2 = $builder->build(
            {   source => 'Item',
                value  => {
                    itemlost  => 0,
                    withdrawn => 0,
                },
            }
        );
        my $issue_2 = $builder->build(
            {   source => 'Issue',
                value  => {
                    borrowernumber => $patron->{borrowernumber},
                    itemnumber     => $item_2->{itemnumber},
                },
            }
        );

        my ( $returned_1, undef, undef ) = C4::Circulation::AddReturn( $item_1->{barcode}, undef, undef, undef, '2010-10-10' );
        my ( $returned_2, undef, undef ) = C4::Circulation::AddReturn( $item_2->{barcode}, undef, undef, undef, '2011-11-11' );
        is( $returned_1 && $returned_2, 1, 'The items should have been returned' );

        my $patrons_to_anonymise = Koha::Patrons->search_patrons_to_anonymise( { before => '2010-10-11' } )->search( { 'me.borrowernumber' => $patron->{borrowernumber} } );
        is( ref($patrons_to_anonymise), 'Koha::Patrons', 'search_patrons_to_anonymise should return Koha::Patrons' );

        my $rows_affected = Koha::Patrons->search_patrons_to_anonymise( { before => '2011-11-12' } )->anonymise_issue_history( { before => '2010-10-11' } );
        ok( $rows_affected > 0, 'AnonymiseIssueHistory should affect at least 1 row' );

        my $dbh = C4::Context->dbh;
        my $sth = $dbh->prepare(q|SELECT borrowernumber FROM old_issues where itemnumber = ?|);
        $sth->execute($item_1->{itemnumber});
        my ($borrowernumber_used_to_anonymised) = $sth->fetchrow_array;
        is( $borrowernumber_used_to_anonymised, $anonymous->{borrowernumber}, 'With privacy=1, the issue should have been anonymised' );
        $sth->execute($item_2->{itemnumber});
        ($borrowernumber_used_to_anonymised) = $sth->fetchrow_array;
        is( $borrowernumber_used_to_anonymised, $patron->{borrowernumber}, 'The issue should not have been anonymised, the returned date is later' );

        $rows_affected = Koha::Patrons->search_patrons_to_anonymise( { before => '2011-11-12' } )->anonymise_issue_history;
        $sth->execute($item_2->{itemnumber});
        ($borrowernumber_used_to_anonymised) = $sth->fetchrow_array;
        is( $borrowernumber_used_to_anonymised, $anonymous->{borrowernumber}, 'The issue should have been anonymised, the returned date is before' );

        my $sth_reset = $dbh->prepare(q|UPDATE old_issues SET borrowernumber = ? WHERE itemnumber = ?|);
        $sth_reset->execute( $patron->{borrowernumber}, $item_1->{itemnumber} );
        $sth_reset->execute( $patron->{borrowernumber}, $item_2->{itemnumber} );
        $rows_affected = Koha::Patrons->search_patrons_to_anonymise->anonymise_issue_history;
        $sth->execute($item_1->{itemnumber});
        ($borrowernumber_used_to_anonymised) = $sth->fetchrow_array;
        is( $borrowernumber_used_to_anonymised, $anonymous->{borrowernumber}, 'The issue 1 should have been anonymised, before parameter was not passed' );
        $sth->execute($item_2->{itemnumber});
        ($borrowernumber_used_to_anonymised) = $sth->fetchrow_array;
        is( $borrowernumber_used_to_anonymised, $anonymous->{borrowernumber}, 'The issue 2 should have been anonymised, before parameter was not passed' );

        Koha::Patrons->find( $patron->{borrowernumber})->delete;
    };

    subtest 'patron privacy is 0 (forever)' => sub {
        plan tests => 3;

        t::lib::Mocks::mock_preference('IndependentBranches', 0);
        my $patron = $builder->build(
            {   source => 'Borrower',
                value  => { privacy => 0, }
            }
        );
        my $item = $builder->build(
            {   source => 'Item',
                value  => {
                    itemlost  => 0,
                    withdrawn => 0,
                },
            }
        );
        my $issue = $builder->build(
            {   source => 'Issue',
                value  => {
                    borrowernumber => $patron->{borrowernumber},
                    itemnumber     => $item->{itemnumber},
                },
            }
        );

        my ( $returned, undef, undef ) = C4::Circulation::AddReturn( $item->{barcode}, undef, undef, undef, '2010-10-10' );
        is( $returned, 1, 'The item should have been returned' );
        my $rows_affected = Koha::Patrons->search_patrons_to_anonymise( { before => '2010-10-11' } )->anonymise_issue_history( { before => '2010-10-11' } );
        ok( $rows_affected > 0, 'AnonymiseIssueHistory should not return any error if success' );

        my $dbh = C4::Context->dbh;
        my ($borrowernumber_used_to_anonymised) = $dbh->selectrow_array(q|
            SELECT borrowernumber FROM old_issues where itemnumber = ?
        |, undef, $item->{itemnumber});
        is( $borrowernumber_used_to_anonymised, $patron->{borrowernumber}, 'With privacy=0, the issue should not be anonymised' );
        Koha::Patrons->find( $patron->{borrowernumber})->delete;
    };

    t::lib::Mocks::mock_preference( 'AnonymousPatron', '' );

    subtest 'AnonymousPatron is not defined' => sub {
        plan tests => 3;

        t::lib::Mocks::mock_preference('IndependentBranches', 0);
        my $patron = $builder->build(
            {   source => 'Borrower',
                value  => { privacy => 1, }
            }
        );
        my $item = $builder->build(
            {   source => 'Item',
                value  => {
                    itemlost  => 0,
                    withdrawn => 0,
                },
            }
        );
        my $issue = $builder->build(
            {   source => 'Issue',
                value  => {
                    borrowernumber => $patron->{borrowernumber},
                    itemnumber     => $item->{itemnumber},
                },
            }
        );

        my ( $returned, undef, undef ) = C4::Circulation::AddReturn( $item->{barcode}, undef, undef, undef, '2010-10-10' );
        is( $returned, 1, 'The item should have been returned' );
        my $rows_affected = Koha::Patrons->search_patrons_to_anonymise( { before => '2010-10-11' } )->anonymise_issue_history( { before => '2010-10-11' } );
        ok( $rows_affected > 0, 'AnonymiseIssueHistory should affect at least 1 row' );

        my $dbh = C4::Context->dbh;
        my ($borrowernumber_used_to_anonymised) = $dbh->selectrow_array(q|
            SELECT borrowernumber FROM old_issues where itemnumber = ?
        |, undef, $item->{itemnumber});
        is( $borrowernumber_used_to_anonymised, undef, 'With AnonymousPatron is not defined, the issue should have been anonymised anyway' );
        Koha::Patrons->find( $patron->{borrowernumber})->delete;
    };

    subtest 'Logged in librarian is not superlibrarian & IndependentBranches' => sub {
        plan tests => 1;
        t::lib::Mocks::mock_preference( 'IndependentBranches', 1 );
        my $patron = $builder->build(
            {   source => 'Borrower',
                value  => { privacy => 1 }    # Another branchcode than the logged in librarian
            }
        );
        my $item = $builder->build(
            {   source => 'Item',
                value  => {
                    itemlost  => 0,
                    withdrawn => 0,
                },
            }
        );
        my $issue = $builder->build(
            {   source => 'Issue',
                value  => {
                    borrowernumber => $patron->{borrowernumber},
                    itemnumber     => $item->{itemnumber},
                },
            }
        );

        my ( $returned, undef, undef ) = C4::Circulation::AddReturn( $item->{barcode}, undef, undef, undef, '2010-10-10' );
        is( Koha::Patrons->search_patrons_to_anonymise( { before => '2010-10-11' } )->count, 0 );
        Koha::Patrons->find( $patron->{borrowernumber})->delete;
    };

    Koha::Patrons->find( $anonymous->{borrowernumber})->delete;
    Koha::Patrons->find( $userenv_patron->{borrowernumber})->delete;
};

subtest 'account_locked' => sub {
    plan tests => 8;
    my $patron = $builder->build({ source => 'Borrower', value => { login_attempts => 0 } });
    $patron = Koha::Patrons->find( $patron->{borrowernumber} );
    for my $value ( undef, '', 0 ) {
        t::lib::Mocks::mock_preference('FailedloginAttempts', $value);
        is( $patron->account_locked, 0, 'Feature is disabled, patron account should not be considered locked' );
        $patron->login_attempts(1)->store;
        is( $patron->account_locked, 0, 'Feature is disabled, patron account should not be considered locked' );
    }

    t::lib::Mocks::mock_preference('FailedloginAttempts', 3);
    $patron->login_attempts(2)->store;
    is( $patron->account_locked, 0, 'Patron has 2 failed attempts, account should not be considered locked yet' );
    $patron->login_attempts(3)->store;
    is( $patron->account_locked, 1, 'Patron has 3 failed attempts, account should be considered locked yet' );

    $patron->delete;
};

subtest 'status_not_ok' => sub {
    plan tests => 5;

    t::lib::Mocks::mock_preference('maxoutstanding', 5);
    my $patron = $builder->build(
        {
            source => 'Borrower',
            value  => { branchcode => $library->{branchcode},
                        gonenoaddress => 0,
                        lost => 0,
                        debarred => undef,
                        debarredcomment => undef,
                        dateexpiry => '9999-12-12' }
        }
    );

    $patron = Koha::Patrons->find($patron->{borrowernumber});
    my $line = Koha::Account::Line->new({
        borrowernumber => $patron->borrowernumber,
        amountoutstanding => 9001,
    })->store;
    my $outstanding = $patron->account->balance;
    my $maxoutstanding = C4::Context->preference('maxoutstanding');
    my $expecting = 'Koha::Exceptions::Patron::Debt';
    my @problems = $patron->status_not_ok;

    ok($maxoutstanding, 'When I look at system preferences, I see that maximum '
       .'allowed outstanding fines is set.');
    ok($maxoutstanding < $outstanding, 'When I check patron\'s balance, I found '
       .'out they have more outstanding fines than allowed.');
    is(scalar(@problems), 1, 'There is an issue with patron\'s current status');
    my $debt = $problems[0];
    is($debt->max_outstanding, 0+$maxoutstanding, 'Then I can see the status '
       .'showing me how much outstanding total can be at maximum.');
    is($debt->current_outstanding, 0+$outstanding, 'Then I can see the status '
       .'showing me how much outstanding fines patron has right now.');
    $patron->delete;
};

$retrieved_patron_1->delete;
is( Koha::Patrons->search->count, $nb_of_patrons + 1, 'Delete should have deleted the patron' );

$schema->storage->txn_rollback;

