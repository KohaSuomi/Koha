#!/usr/bin/perl

# This file is part of Koha.
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

use Test::More tests => 96;

use DateTime;

use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Circulation;
use C4::Biblio;
use C4::Items;
use C4::Log;
use C4::Members;
use C4::Message;
use C4::Reserves;
use C4::Overdues qw(UpdateFine CalcFine);
use Koha::DateUtils;
use Koha::Database;
use Koha::IssuingRules;
use Koha::Patron::Message::Attributes;
use Koha::Patron::Message::Preferences;
use Koha::Subscriptions;

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;
my $builder = t::lib::TestBuilder->new;
my $dbh = C4::Context->dbh;

# Start transaction
$dbh->{RaiseError} = 1;

# Start with a clean slate
$dbh->do('DELETE FROM issues');

my $library = $builder->build({
    source => 'Branch',
});
my $library2 = $builder->build({
    source => 'Branch',
});
my $itemtype = $builder->build(
    {   source => 'Itemtype',
        value  => { notforloan => undef, rentalcharge => 0 }
    }
)->{itemtype};
my $patron_category = $builder->build({ source => 'Category', value => { enrolmentfee => 0 } });

my $CircControl = C4::Context->preference('CircControl');
my $HomeOrHoldingBranch = C4::Context->preference('HomeOrHoldingBranch');

my $item = {
    homebranch => $library2->{branchcode},
    holdingbranch => $library2->{branchcode}
};

my $borrower = {
    branchcode => $library2->{branchcode}
};

# No userenv, PickupLibrary
t::lib::Mocks::mock_preference('IndependentBranches', '0');
t::lib::Mocks::mock_preference('CircControl', 'PickupLibrary');
is(
    C4::Context->preference('CircControl'),
    'PickupLibrary',
    'CircControl changed to PickupLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $item->{$HomeOrHoldingBranch},
    '_GetCircControlBranch returned item branch (no userenv defined)'
);

# No userenv, PatronLibrary
t::lib::Mocks::mock_preference('CircControl', 'PatronLibrary');
is(
    C4::Context->preference('CircControl'),
    'PatronLibrary',
    'CircControl changed to PatronLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $borrower->{branchcode},
    '_GetCircControlBranch returned borrower branch'
);

# No userenv, ItemHomeLibrary
t::lib::Mocks::mock_preference('CircControl', 'ItemHomeLibrary');
is(
    C4::Context->preference('CircControl'),
    'ItemHomeLibrary',
    'CircControl changed to ItemHomeLibrary'
);
is(
    $item->{$HomeOrHoldingBranch},
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    '_GetCircControlBranch returned item branch'
);

# Now, set a userenv
C4::Context->_new_userenv('xxx');
C4::Context->set_userenv(0,0,0,'firstname','surname', $library2->{branchcode}, 'Midway Public Library', '', '', '');
is(C4::Context->userenv->{branch}, $library2->{branchcode}, 'userenv set');

# Userenv set, PickupLibrary
t::lib::Mocks::mock_preference('CircControl', 'PickupLibrary');
is(
    C4::Context->preference('CircControl'),
    'PickupLibrary',
    'CircControl changed to PickupLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $library2->{branchcode},
    '_GetCircControlBranch returned current branch'
);

# Userenv set, PatronLibrary
t::lib::Mocks::mock_preference('CircControl', 'PatronLibrary');
is(
    C4::Context->preference('CircControl'),
    'PatronLibrary',
    'CircControl changed to PatronLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $borrower->{branchcode},
    '_GetCircControlBranch returned borrower branch'
);

# Userenv set, ItemHomeLibrary
t::lib::Mocks::mock_preference('CircControl', 'ItemHomeLibrary');
is(
    C4::Context->preference('CircControl'),
    'ItemHomeLibrary',
    'CircControl changed to ItemHomeLibrary'
);
is(
    C4::Circulation::_GetCircControlBranch($item, $borrower),
    $item->{$HomeOrHoldingBranch},
    '_GetCircControlBranch returned item branch'
);

# Reset initial configuration
t::lib::Mocks::mock_preference('CircControl', $CircControl);
is(
    C4::Context->preference('CircControl'),
    $CircControl,
    'CircControl reset to its initial value'
);

# Set a simple circ policy
$dbh->do('DELETE FROM issuingrules');
$dbh->do(
    q{INSERT INTO issuingrules (categorycode, branchcode, itemtype,
                                ccode, permanent_location, reservesallowed,
                                maxissueqty, issuelength, lengthunit,
                                renewalsallowed, renewalperiod,
                                norenewalbefore, auto_renew,
                                fine, chargeperiod)
      VALUES (?, ?, ?,
              ?, ?, ?,
              ?, ?, ?,
              ?, ?,
              ?, ?,
              ?, ?
             )
    },
    {},
    '*', '*', '*',
    '*', '*', 25,
    20, 14, 'days',
    1, 7,
    undef, 0,
    .10, 1
);

# Test C4::Circulation::ProcessOfflinePayment
my $sth = C4::Context->dbh->prepare("SELECT COUNT(*) FROM accountlines WHERE amount = '-123.45' AND accounttype = 'Pay'");
$sth->execute();
my ( $original_count ) = $sth->fetchrow_array();

C4::Context->dbh->do("INSERT INTO borrowers ( cardnumber, surname, firstname, categorycode, branchcode ) VALUES ( '99999999999', 'Hall', 'Kyle', ?, ? )", undef, $patron_category->{categorycode}, $library2->{branchcode} );

C4::Circulation::ProcessOfflinePayment({ cardnumber => '99999999999', amount => '123.45' });

$sth->execute();
my ( $new_count ) = $sth->fetchrow_array();

ok( $new_count == $original_count  + 1, 'ProcessOfflinePayment makes payment correctly' );

C4::Context->dbh->do("DELETE FROM accountlines WHERE borrowernumber IN ( SELECT borrowernumber FROM borrowers WHERE cardnumber = '99999999999' )");
C4::Context->dbh->do("DELETE FROM borrowers WHERE cardnumber = '99999999999'");
C4::Context->dbh->do("DELETE FROM accountlines");
{
# CanBookBeRenewed tests

    # Generate test biblio
    my $biblio = MARC::Record->new();
    my $title = 'Silence in the library';
    $biblio->append_fields(
        MARC::Field->new('100', ' ', ' ', a => 'Moffat, Steven'),
        MARC::Field->new('245', ' ', ' ', a => $title),
    );

    my ($biblionumber, $biblioitemnumber) = AddBiblio($biblio, '');

    my $barcode = 'R00000342';
    my $branch = $library2->{branchcode};

    my ( $item_bibnum, $item_bibitemnum, $itemnumber ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode,
            replacementprice => 12.00,
            itype            => $itemtype
        },
        $biblionumber
    );

    my $barcode2 = 'R00000343';
    my ( $item_bibnum2, $item_bibitemnum2, $itemnumber2 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode2,
            replacementprice => 23.00,
            itype            => $itemtype
        },
        $biblionumber
    );

    my $barcode3 = 'R00000346';
    my ( $item_bibnum3, $item_bibitemnum3, $itemnumber3 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode3,
            replacementprice => 23.00,
            itype            => $itemtype
        },
        $biblionumber
    );




    # Create borrowers
    my %renewing_borrower_data = (
        firstname =>  'John',
        surname => 'Renewal',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );

    my %reserving_borrower_data = (
        firstname =>  'Katrin',
        surname => 'Reservation',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );

    my %hold_waiting_borrower_data = (
        firstname =>  'Kyle',
        surname => 'Reservation',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );

    my %restricted_borrower_data = (
        firstname =>  'Alice',
        surname => 'Reservation',
        categorycode => $patron_category->{categorycode},
        debarred => '3228-01-01',
        branchcode => $branch,
    );

    my $renewing_borrowernumber = AddMember(%renewing_borrower_data);
    my $reserving_borrowernumber = AddMember(%reserving_borrower_data);
    my $hold_waiting_borrowernumber = AddMember(%hold_waiting_borrower_data);
    my $restricted_borrowernumber = AddMember(%restricted_borrower_data);

    my $renewing_borrower = GetMember( borrowernumber => $renewing_borrowernumber );
    my $restricted_borrower = GetMember( borrowernumber => $restricted_borrowernumber );

    my $bibitems       = '';
    my $priority       = '1';
    my $resdate        = undef;
    my $expdate        = undef;
    my $notes          = '';
    my $checkitem      = undef;
    my $found          = undef;

    my $issue = AddIssue( $renewing_borrower, $barcode);
    my $datedue = dt_from_string( $issue->date_due() );
    is (defined $issue->date_due(), 1, "Item 1 checked out, due date: " . $issue->date_due() );

    my $issue2 = AddIssue( $renewing_borrower, $barcode2);
    $datedue = dt_from_string( $issue->date_due() );
    is (defined $issue2, 1, "Item 2 checked out, due date: " . $issue2->date_due());


    my $borrowing_borrowernumber = GetItemIssue($itemnumber)->{borrowernumber};
    is ($borrowing_borrowernumber, $renewing_borrowernumber, "Item checked out to $renewing_borrower->{firstname} $renewing_borrower->{surname}");

    my ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber, 1);
    is( $renewokay, 1, 'Can renew, no holds for this title or item');


    # Biblio-level hold, renewal test
    AddReserve(
        $branch, $reserving_borrowernumber, $biblionumber,
        $bibitems,  $priority, $resdate, $expdate, $notes,
        $title, $checkitem, $found
    );

    # Testing of feature to allow the renewal of reserved items if other items on the record can fill all needed holds
    C4::Context->dbh->do("UPDATE issuingrules SET onshelfholds = 1");
    t::lib::Mocks::mock_preference('AllowRenewalIfOtherItemsAvailable', 1 );
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 1, 'Bug 11634 - Allow renewal of item with unfilled holds if other available items can fill those holds');
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber2);
    is( $renewokay, 1, 'Bug 11634 - Allow renewal of item with unfilled holds if other available items can fill those holds');

    # Now let's add an item level hold, we should no longer be able to renew the item
    my $hold = Koha::Database->new()->schema()->resultset('Reserve')->create(
        {
            borrowernumber => $hold_waiting_borrowernumber,
            biblionumber   => $biblionumber,
            itemnumber     => $itemnumber,
            branchcode     => $branch,
            priority       => 3,
        }
    );
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 0, 'Bug 13919 - Renewal possible with item level hold on item');
    $hold->delete();

    # Now let's add a waiting hold on the 3rd item, it's no longer available tp check out by just anyone, so we should no longer
    # be able to renew these items
    $hold = Koha::Database->new()->schema()->resultset('Reserve')->create(
        {
            borrowernumber => $hold_waiting_borrowernumber,
            biblionumber   => $biblionumber,
            itemnumber     => $itemnumber3,
            branchcode     => $branch,
            priority       => 0,
            found          => 'W'
        }
    );
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 0, 'Bug 11634 - Allow renewal of item with unfilled holds if other available items can fill those holds');
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber2);
    is( $renewokay, 0, 'Bug 11634 - Allow renewal of item with unfilled holds if other available items can fill those holds');
    t::lib::Mocks::mock_preference('AllowRenewalIfOtherItemsAvailable', 0 );

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 0, '(Bug 10663) Cannot renew, reserved');
    is( $error, 'on_reserve', '(Bug 10663) Cannot renew, reserved (returned error is on_reserve)');

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber2);
    is( $renewokay, 0, '(Bug 10663) Cannot renew, reserved');
    is( $error, 'on_reserve', '(Bug 10663) Cannot renew, reserved (returned error is on_reserve)');

    my $reserveid = C4::Reserves::GetReserveId({ biblionumber => $biblionumber, borrowernumber => $reserving_borrowernumber});
    my $reserving_borrower = GetMember( borrowernumber => $reserving_borrowernumber );
    AddIssue($reserving_borrower, $barcode3);
    my $reserve = $dbh->selectrow_hashref(
        'SELECT * FROM old_reserves WHERE reserve_id = ?',
        { Slice => {} },
        $reserveid
    );
    is($reserve->{found}, 'F', 'hold marked completed when checking out item that fills it');

    # Item-level hold, renewal test
    AddReserve(
        $branch, $reserving_borrowernumber, $biblionumber,
        $bibitems,  $priority, $resdate, $expdate, $notes,
        $title, $itemnumber, $found
    );

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber, 1);
    is( $renewokay, 0, '(Bug 10663) Cannot renew, item reserved');
    is( $error, 'on_reserve', '(Bug 10663) Cannot renew, item reserved (returned error is on_reserve)');

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber2, 1);
    is( $renewokay, 1, 'Can renew item 2, item-level hold is on item 1');

    # Items can't fill hold for reasons
    ModItem({ notforloan => 1 }, $biblionumber, $itemnumber);
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber, 1);
    is( $renewokay, 0, 'Cannot renew, item is marked not for loan, hold is blocked');
    ModItem({ notforloan => 0, itype => $itemtype }, $biblionumber, $itemnumber,1);

    # FIXME: Add more for itemtype not for loan etc.

    # Restricted users cannot renew when RestrictionBlockRenewing is enabled
    my $barcode5 = 'R00000347';
    my ( $item_bibnum5, $item_bibitemnum5, $itemnumber5 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode5,
            replacementprice => 23.00,
            itype            => $itemtype
        },
        $biblionumber
    );
    my $datedue5 = AddIssue($restricted_borrower, $barcode5);
    is (defined $datedue5, 1, "Item with date due checked out, due date: $datedue5");

    t::lib::Mocks::mock_preference('RestrictionBlockRenewing','1');
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber2);
    is( $renewokay, 1, '(Bug 8236), Can renew, user is not restricted');
    ( $renewokay, $error ) = CanBookBeRenewed($restricted_borrowernumber, $itemnumber5);
    is( $renewokay, 0, '(Bug 8236), Cannot renew, user is restricted');

    # Users cannot renew an overdue item
    my $barcode6 = 'R00000348';
    my ( $item_bibnum6, $item_bibitemnum6, $itemnumber6 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode6,
            replacementprice => 23.00,
            itype            => $itemtype
        },
        $biblionumber
    );

    my $barcode7 = 'R00000349';
    my ( $item_bibnum7, $item_bibitemnum7, $itemnumber7 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode7,
            replacementprice => 23.00,
            itype            => $itemtype
        },
        $biblionumber
    );
    my $datedue6 = AddIssue( $renewing_borrower, $barcode6);
    is (defined $datedue6, 1, "Item 2 checked out, due date: $datedue6");

    my $now = dt_from_string();
    my $five_weeks = DateTime::Duration->new(weeks => 5);
    my $five_weeks_ago = $now - $five_weeks;

    my $passeddatedue1 = AddIssue($renewing_borrower, $barcode7, $five_weeks_ago);
    is (defined $passeddatedue1, 1, "Item with passed date due checked out, due date: " . $passeddatedue1->date_due);

    my ( $fine ) = CalcFine( GetItem(undef, $barcode7), $renewing_borrower->{categorycode}, $branch, undef, $five_weeks_ago, $now );
    C4::Overdues::UpdateFine(
        {
            issue_id       => $passeddatedue1->id(),
            itemnumber     => $itemnumber7,
            borrowernumber => $renewing_borrower->{borrowernumber},
            amount         => $fine,
            type           => 'FU',
            due            => Koha::DateUtils::output_pref($five_weeks_ago)
        }
    );
    t::lib::Mocks::mock_preference('RenewalLog', 0);
    my $date = output_pref( { dt => dt_from_string(), datenonly => 1, dateformat => 'iso' } );
    my $old_log_size =  scalar(@{GetLogs( $date, $date, undef,["CIRCULATION"], ["RENEWAL"]) } );
    AddRenewal( $renewing_borrower->{borrowernumber}, $itemnumber7, $branch );
    my $new_log_size =  scalar(@{GetLogs( $date, $date, undef,["CIRCULATION"], ["RENEWAL"]) } );
    is ($new_log_size, $old_log_size, 'renew log not added because of the syspref RenewalLog');

    t::lib::Mocks::mock_preference('RenewalLog', 1);
    $date = output_pref( { dt => dt_from_string(), datenonly => 1, dateformat => 'iso' } );
    $old_log_size =  scalar(@{GetLogs( $date, $date, undef,["CIRCULATION"], ["RENEWAL"]) } );
    AddRenewal( $renewing_borrower->{borrowernumber}, $itemnumber7, $branch );
    $new_log_size =  scalar(@{GetLogs( $date, $date, undef,["CIRCULATION"], ["RENEWAL"]) } );
    is ($new_log_size, $old_log_size + 1, 'renew log successfully added');


    $fine = $schema->resultset('Accountline')->single( { borrowernumber => $renewing_borrower->{borrowernumber}, itemnumber => $itemnumber7 } );
    is( $fine->accounttype, 'F', 'Fine on renewed item is closed out properly' );
    $fine->delete();

    t::lib::Mocks::mock_preference('OverduesBlockRenewing','blockitem');
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber6);
    is( $renewokay, 1, '(Bug 8236), Can renew, this item is not overdue');
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber7);
    is( $renewokay, 0, '(Bug 8236), Cannot renew, this item is overdue');


    $reserveid = C4::Reserves::GetReserveId({ biblionumber => $biblionumber, itemnumber => $itemnumber, borrowernumber => $reserving_borrowernumber});
    CancelReserve({ reserve_id => $reserveid });

    # Bug 14101
    # Test automatic renewal before value for "norenewalbefore" in policy is set
    # In this case automatic renewal is not permitted prior to due date
    my $barcode4 = '11235813';
    my ( $item_bibnum4, $item_bibitemnum4, $itemnumber4 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode4,
            replacementprice => 16.00,
            itype            => $itemtype
        },
        $biblionumber
    );

    $issue = AddIssue( $renewing_borrower, $barcode4, undef, undef, undef, undef, { auto_renew => 1 } );
    ( $renewokay, $error ) =
      CanBookBeRenewed( $renewing_borrowernumber, $itemnumber4 );
    is( $renewokay, 0, 'Bug 14101: Cannot renew, renewal is automatic and premature' );
    is( $error, 'auto_too_soon',
        'Bug 14101: Cannot renew, renewal is automatic and premature, "No renewal before" = undef (returned code is auto_too_soon)' );

    # Bug 7413
    # Test premature manual renewal
    $dbh->do('UPDATE issuingrules SET norenewalbefore = 7');

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 0, 'Bug 7413: Cannot renew, renewal is premature');
    is( $error, 'too_soon', 'Bug 7413: Cannot renew, renewal is premature (returned code is too_soon)');

    # Bug 14395
    # Test 'exact time' setting for syspref NoRenewalBeforePrecision
    t::lib::Mocks::mock_preference( 'NoRenewalBeforePrecision', 'exact_time' );
    is(
        GetSoonestRenewDate( $renewing_borrowernumber, $itemnumber ),
        $datedue->clone->add( days => -7 ),
        'Bug 14395: Renewals permitted 7 days before due date, as expected'
    );

    # Bug 14395
    # Test 'date' setting for syspref NoRenewalBeforePrecision
    t::lib::Mocks::mock_preference( 'NoRenewalBeforePrecision', 'date' );
    is(
        GetSoonestRenewDate( $renewing_borrowernumber, $itemnumber ),
        $datedue->clone->add( days => -7 )->truncate( to => 'day' ),
        'Bug 14395: Renewals permitted 7 days before due date, as expected'
    );

    # Bug 14101
    # Test premature automatic renewal
    ( $renewokay, $error ) =
      CanBookBeRenewed( $renewing_borrowernumber, $itemnumber4 );
    is( $renewokay, 0, 'Bug 14101: Cannot renew, renewal is automatic and premature' );
    is( $error, 'auto_too_soon',
        'Bug 14101: Cannot renew, renewal is automatic and premature (returned code is auto_too_soon)'
    );

    # Change policy so that loans can only be renewed exactly on due date (0 days prior to due date)
    # and test automatic renewal again
    $dbh->do('UPDATE issuingrules SET norenewalbefore = 0');
    ( $renewokay, $error ) =
      CanBookBeRenewed( $renewing_borrowernumber, $itemnumber4 );
    is( $renewokay, 0, 'Bug 14101: Cannot renew, renewal is automatic and premature' );
    is( $error, 'auto_too_soon',
        'Bug 14101: Cannot renew, renewal is automatic and premature, "No renewal before" = 0 (returned code is auto_too_soon)'
    );

    # Change policy so that loans can be renewed 99 days prior to the due date
    # and test automatic renewal again
    $dbh->do('UPDATE issuingrules SET norenewalbefore = 99');
    ( $renewokay, $error ) =
      CanBookBeRenewed( $renewing_borrowernumber, $itemnumber4 );
    is( $renewokay, 0, 'Bug 14101: Cannot renew, renewal is automatic' );
    is( $error, 'auto_renew',
        'Bug 14101: Cannot renew, renewal is automatic (returned code is auto_renew)'
    );

    subtest "too_late_renewal / no_auto_renewal_after" => sub {
        plan tests => 14;
        my $item_to_auto_renew = $builder->build(
            {   source => 'Item',
                value  => {
                    biblionumber  => $biblionumber,
                    homebranch    => $branch,
                    holdingbranch => $branch,
                    notforloan    => 0,
                }
            }
        );

        my $ten_days_before = dt_from_string->add( days => -10 );
        my $ten_days_ahead  = dt_from_string->add( days => 10 );
        AddIssue( $renewing_borrower, $item_to_auto_renew->{barcode}, $ten_days_ahead, undef, $ten_days_before, undef, { auto_renew => 1 } );

        $dbh->do('UPDATE issuingrules SET norenewalbefore = 7, no_auto_renewal_after = 9');
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_too_late', 'Cannot renew, too late(returned code is auto_too_late)' );

        $dbh->do('UPDATE issuingrules SET norenewalbefore = 7, no_auto_renewal_after = 10');
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_too_late', 'Cannot auto renew, too late - no_auto_renewal_after is inclusive(returned code is auto_too_late)' );

        $dbh->do('UPDATE issuingrules SET norenewalbefore = 7, no_auto_renewal_after = 11');
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_too_soon', 'Cannot auto renew, too soon - no_auto_renewal_after is defined(returned code is auto_too_soon)' );

        $dbh->do('UPDATE issuingrules SET norenewalbefore = 10, no_auto_renewal_after = 11');
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0,            'Do not renew, renewal is automatic' );
        is( $error,     'auto_renew', 'Cannot renew, renew is automatic' );

        $dbh->do('UPDATE issuingrules SET norenewalbefore = 7, no_auto_renewal_after = NULL, no_auto_renewal_after_hard_limit = ?', undef, dt_from_string->add( days => -1 ) );
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_too_late', 'Cannot renew, too late(returned code is auto_too_late)' );

        $dbh->do('UPDATE issuingrules SET norenewalbefore = 7, no_auto_renewal_after = 15, no_auto_renewal_after_hard_limit = ?', undef, dt_from_string->add( days => -1 ) );
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_too_late', 'Cannot renew, too late(returned code is auto_too_late)' );

        $dbh->do('UPDATE issuingrules SET norenewalbefore = 10, no_auto_renewal_after = NULL, no_auto_renewal_after_hard_limit = ?', undef, dt_from_string->add( days => 1 ) );
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_renew', 'Cannot renew, renew is automatic' );
    };

    subtest "auto_too_much_oweing | OPACFineNoRenewalsBlockAutoRenew" => sub {
        plan tests => 6;
        my $item_to_auto_renew = $builder->build({
            source => 'Item',
            value => {
                biblionumber => $biblionumber,
                homebranch       => $branch,
                holdingbranch    => $branch,
                notforloan       => 0,
            }
        });

        my $ten_days_before = dt_from_string->add( days => -10 );
        my $ten_days_ahead = dt_from_string->add( days => 10 );
        AddIssue( $renewing_borrower, $item_to_auto_renew->{barcode}, $ten_days_ahead, undef, $ten_days_before, undef, { auto_renew => 1 } );

        $dbh->do('UPDATE issuingrules SET norenewalbefore = 10, no_auto_renewal_after = 11');
        C4::Context->set_preference('OPACFineNoRenewalsBlockAutoRenew','1');
        C4::Context->set_preference('OPACFineNoRenewals','10');
        my $fines_amount = 5;
        C4::Accounts::manualinvoice( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber}, "Some fines", 'F', $fines_amount );
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_renew', 'Can auto renew, OPACFineNoRenewals=10, patron has 5' );

        C4::Accounts::manualinvoice( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber}, "Some fines", 'F', $fines_amount );
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_renew', 'Can auto renew, OPACFineNoRenewals=10, patron has 10' );

        C4::Accounts::manualinvoice( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber}, "Some fines", 'F', $fines_amount );
        ( $renewokay, $error ) =
          CanBookBeRenewed( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $renewokay, 0, 'Do not renew, renewal is automatic' );
        is( $error, 'auto_too_much_oweing', 'Cannot auto renew, OPACFineNoRenewals=10, patron has 15' );

        $dbh->do('DELETE FROM accountlines WHERE borrowernumber=?', undef, $renewing_borrowernumber);
    };

    subtest "GetLatestAutoRenewDate" => sub {
        plan tests => 5;
        my $item_to_auto_renew = $builder->build(
            {   source => 'Item',
                value  => {
                    biblionumber  => $biblionumber,
                    homebranch    => $branch,
                    holdingbranch => $branch,
                    notforloan    => 0
                }
            }
        );

        my $ten_days_before = dt_from_string->add( days => -10 );
        my $ten_days_ahead  = dt_from_string->add( days => 10 );
        AddIssue( $renewing_borrower, $item_to_auto_renew->{barcode}, $ten_days_ahead, undef, $ten_days_before, undef, { auto_renew => 1 } );
        $dbh->do('UPDATE issuingrules SET norenewalbefore = 7, no_auto_renewal_after = "", no_auto_renewal_after_hard_limit = NULL');
        my $latest_auto_renew_date = GetLatestAutoRenewDate( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $latest_auto_renew_date, undef, 'GetLatestAutoRenewDate should return undef if no_auto_renewal_after or no_auto_renewal_after_hard_limit are not defined' );
        my $five_days_before = dt_from_string->add( days => -5 );
        $dbh->do('UPDATE issuingrules SET norenewalbefore = 10, no_auto_renewal_after = 5, no_auto_renewal_after_hard_limit = NULL');
        $latest_auto_renew_date = GetLatestAutoRenewDate( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $latest_auto_renew_date->truncate( to => 'minute' ),
            $five_days_before->truncate( to => 'minute' ),
            'GetLatestAutoRenewDate should return -5 days if no_auto_renewal_after = 5 and date_due is 10 days before'
        );
        my $five_days_ahead = dt_from_string->add( days => 5 );
        $dbh->do('UPDATE issuingrules SET norenewalbefore = 10, no_auto_renewal_after = 15, no_auto_renewal_after_hard_limit = NULL');
        $latest_auto_renew_date = GetLatestAutoRenewDate( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $latest_auto_renew_date->truncate( to => 'minute' ),
            $five_days_ahead->truncate( to => 'minute' ),
            'GetLatestAutoRenewDate should return +5 days if no_auto_renewal_after = 15 and date_due is 10 days before'
        );
        my $two_days_ahead = dt_from_string->add( days => 2 );
        $dbh->do('UPDATE issuingrules SET norenewalbefore = 10, no_auto_renewal_after = "", no_auto_renewal_after_hard_limit = ?', undef, dt_from_string->add( days => 2 ) );
        $latest_auto_renew_date = GetLatestAutoRenewDate( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $latest_auto_renew_date->truncate( to => 'day' ),
            $two_days_ahead->truncate( to => 'day' ),
            'GetLatestAutoRenewDate should return +2 days if no_auto_renewal_after_hard_limit is defined and not no_auto_renewal_after'
        );
        $dbh->do('UPDATE issuingrules SET norenewalbefore = 10, no_auto_renewal_after = 15, no_auto_renewal_after_hard_limit = ?', undef, dt_from_string->add( days => 2 ) );
        $latest_auto_renew_date = GetLatestAutoRenewDate( $renewing_borrowernumber, $item_to_auto_renew->{itemnumber} );
        is( $latest_auto_renew_date->truncate( to => 'day' ),
            $two_days_ahead->truncate( to => 'day' ),
            'GetLatestAutoRenewDate should return +2 days if no_auto_renewal_after_hard_limit is < no_auto_renewal_after'
        );

    };

    # Too many renewals

    # set policy to forbid renewals
    $dbh->do('UPDATE issuingrules SET norenewalbefore = NULL, renewalsallowed = 0');

    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber);
    is( $renewokay, 0, 'Cannot renew, 0 renewals allowed');
    is( $error, 'too_many', 'Cannot renew, 0 renewals allowed (returned code is too_many)');

    # Test WhenLostForgiveFine and WhenLostChargeReplacementFee
    t::lib::Mocks::mock_preference('WhenLostForgiveFine','1');
    t::lib::Mocks::mock_preference('WhenLostChargeReplacementFee','1');

    C4::Overdues::UpdateFine(
        {
            issue_id       => $issue->id(),
            itemnumber     => $itemnumber,
            borrowernumber => $renewing_borrower->{borrowernumber},
            amount         => 15.00,
            type           => q{},
            due            => Koha::DateUtils::output_pref($datedue)
        }
    );

    LostItem( $itemnumber, 1 );

    my $item = Koha::Database->new()->schema()->resultset('Item')->find($itemnumber);
    ok( !$item->onloan(), "Lost item marked as returned has false onloan value" );

    my $total_due = $dbh->selectrow_array(
        'SELECT SUM( amountoutstanding ) FROM accountlines WHERE borrowernumber = ?',
        undef, $renewing_borrower->{borrowernumber}
    );

    ok( $total_due == 12, 'Borrower only charged replacement fee with both WhenLostForgiveFine and WhenLostChargeReplacementFee enabled' );

    C4::Context->dbh->do("DELETE FROM accountlines");

    t::lib::Mocks::mock_preference('WhenLostForgiveFine','0');
    t::lib::Mocks::mock_preference('WhenLostChargeReplacementFee','0');

    C4::Overdues::UpdateFine(
        {
            issue_id       => $issue2->id(),
            itemnumber     => $itemnumber2,
            borrowernumber => $renewing_borrower->{borrowernumber},
            amount         => 15.00,
            type           => q{},
            due            => Koha::DateUtils::output_pref($datedue)
        }
    );

    LostItem( $itemnumber2, 0 );

    my $item2 = Koha::Database->new()->schema()->resultset('Item')->find($itemnumber2);
    ok( $item2->onloan(), "Lost item *not* marked as returned has true onloan value" );

    $total_due = $dbh->selectrow_array(
        'SELECT SUM( amountoutstanding ) FROM accountlines WHERE borrowernumber = ?',
        undef, $renewing_borrower->{borrowernumber}
    );

    ok( $total_due == 15, 'Borrower only charged fine with both WhenLostForgiveFine and WhenLostChargeReplacementFee disabled' );

    my $future = dt_from_string();
    $future->add( days => 7 );
    my $units = C4::Overdues::get_chargeable_units('days', $future, $now, $library2->{branchcode});
    ok( $units == 0, '_get_chargeable_units returns 0 for items not past due date (Bug 12596)' );

    # Users cannot renew any item if there is an overdue item
    t::lib::Mocks::mock_preference('OverduesBlockRenewing','block');
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber6);
    is( $renewokay, 0, '(Bug 8236), Cannot renew, one of the items is overdue');
    ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber7);
    is( $renewokay, 0, '(Bug 8236), Cannot renew, one of the items is overdue');

  }

{
    # GetUpcomingDueIssues tests
    my $barcode  = 'R00000342';
    my $barcode2 = 'R00000343';
    my $barcode3 = 'R00000344';
    my $branch   = $library2->{branchcode};

    #Create another record
    my $biblio2 = MARC::Record->new();
    my $title2 = 'Something is worng here';
    $biblio2->append_fields(
        MARC::Field->new('100', ' ', ' ', a => 'Anonymous'),
        MARC::Field->new('245', ' ', ' ', a => $title2),
    );
    my ($biblionumber2, $biblioitemnumber2) = AddBiblio($biblio2, '');

    #Create third item
    AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode3,
            itype            => $itemtype
        },
        $biblionumber2
    );

    # Create a borrower
    my %a_borrower_data = (
        firstname =>  'Fridolyn',
        surname => 'SOMERS',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );

    my $a_borrower_borrowernumber = AddMember(%a_borrower_data);
    my $a_borrower = GetMember( borrowernumber => $a_borrower_borrowernumber );

    my $yesterday = DateTime->today(time_zone => C4::Context->tz())->add( days => -1 );
    my $two_days_ahead = DateTime->today(time_zone => C4::Context->tz())->add( days => 2 );
    my $today = DateTime->today(time_zone => C4::Context->tz());

    my $issue = AddIssue( $a_borrower, $barcode, $yesterday );
    my $datedue = dt_from_string( $issue->date_due() );
    my $issue2 = AddIssue( $a_borrower, $barcode2, $two_days_ahead );
    my $datedue2 = dt_from_string( $issue->date_due() );

    my $upcoming_dues;

    # GetUpcomingDueIssues tests
    for my $i(0..1) {
        $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => $i } );
        is ( scalar( @$upcoming_dues ), 0, "No items due in less than one day ($i days in advance)" );
    }

    #days_in_advance needs to be inclusive, so 1 matches items due tomorrow, 0 items due today etc.
    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 2 } );
    is ( scalar ( @$upcoming_dues), 1, "Only one item due in 2 days or less" );

    for my $i(3..5) {
        $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => $i } );
        is ( scalar( @$upcoming_dues ), 1,
            "Bug 9362: Only one item due in more than 2 days ($i days in advance)" );
    }

    # Bug 11218 - Due notices not generated - GetUpcomingDueIssues needs to select due today items as well

    my $issue3 = AddIssue( $a_borrower, $barcode3, $today );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => -1 } );
    is ( scalar ( @$upcoming_dues), 0, "Overdues can not be selected" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 0 } );
    is ( scalar ( @$upcoming_dues), 1, "1 item is due today" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 1 } );
    is ( scalar ( @$upcoming_dues), 1, "1 item is due today, none tomorrow" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 2 }  );
    is ( scalar ( @$upcoming_dues), 2, "2 items are due withing 2 days" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues( { days_in_advance => 3 } );
    is ( scalar ( @$upcoming_dues), 2, "2 items are due withing 2 days" );

    $upcoming_dues = C4::Circulation::GetUpcomingDueIssues();
    is ( scalar ( @$upcoming_dues), 2, "days_in_advance is 7 in GetUpcomingDueIssues if not provided" );

}

{
    my $barcode  = '1234567890';
    my $branch   = $library2->{branchcode};

    my $biblio = MARC::Record->new();
    my ($biblionumber, $biblioitemnumber) = AddBiblio($biblio, '');

    #Create third item
    my ( undef, undef, $itemnumber ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode,
            itype            => $itemtype
        },
        $biblionumber
    );

    # Create a borrower
    my %a_borrower_data = (
        firstname =>  'Kyle',
        surname => 'Hall',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );

    my $borrowernumber = AddMember(%a_borrower_data);

    my $issue = AddIssue( GetMember( borrowernumber => $borrowernumber ), $barcode );
    UpdateFine(
        {
            issue_id       => $issue->id(),
            itemnumber     => $itemnumber,
            borrowernumber => $borrowernumber,
            amount         => 0,
            type           => q{}
        }
    );

    my $hr = $dbh->selectrow_hashref(q{SELECT COUNT(*) AS count FROM accountlines WHERE borrowernumber = ? AND itemnumber = ?}, undef, $borrowernumber, $itemnumber );
    my $count = $hr->{count};

    is ( $count, 0, "Calling UpdateFine on non-existant fine with an amount of 0 does not result in an empty fine" );
}

{
    $dbh->do('DELETE FROM issues');
    $dbh->do('DELETE FROM items');
    $dbh->do('DELETE FROM issuingrules');
    $dbh->do(
        q{
        INSERT INTO issuingrules ( categorycode, branchcode, itemtype, ccode, permanent_location, reservesallowed, maxissueqty, issuelength, lengthunit, renewalsallowed, renewalperiod,
                    norenewalbefore, auto_renew, fine, chargeperiod ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
        },
        {},
        '*', '*', '*',
        '*', '*', 25,
        20,  14,  'days',
        1,   7,
        undef,  0,
        .10, 1
    );
    my $biblio = MARC::Record->new();
    my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $biblio, '' );

    my $barcode1 = '1234';
    my ( undef, undef, $itemnumber1 ) = AddItem(
        {
            homebranch    => $library2->{branchcode},
            holdingbranch => $library2->{branchcode},
            barcode       => $barcode1,
            itype         => $itemtype
        },
        $biblionumber
    );
    my $barcode2 = '4321';
    my ( undef, undef, $itemnumber2 ) = AddItem(
        {
            homebranch    => $library2->{branchcode},
            holdingbranch => $library2->{branchcode},
            barcode       => $barcode2,
            itype         => $itemtype
        },
        $biblionumber
    );

    my $borrowernumber1 = AddMember(
        firstname    => 'Kyle',
        surname      => 'Hall',
        categorycode => $patron_category->{categorycode},
        branchcode   => $library2->{branchcode},
    );
    my $borrowernumber2 = AddMember(
        firstname    => 'Chelsea',
        surname      => 'Hall',
        categorycode => $patron_category->{categorycode},
        branchcode   => $library2->{branchcode},
    );

    my $borrower1 = GetMember( borrowernumber => $borrowernumber1 );
    my $borrower2 = GetMember( borrowernumber => $borrowernumber2 );

    my $issue = AddIssue( $borrower1, $barcode1 );

    my ( $renewokay, $error ) = CanBookBeRenewed( $borrowernumber1, $itemnumber1 );
    is( $renewokay, 1, 'Bug 14337 - Verify the borrower can renew with no hold on the record' );

    AddReserve(
        $library2->{branchcode}, $borrowernumber2, $biblionumber,
        '',  1, undef, undef, '',
        undef, undef, undef
    );

    C4::Context->dbh->do("UPDATE issuingrules SET onshelfholds = 0");
    t::lib::Mocks::mock_preference( 'AllowRenewalIfOtherItemsAvailable', 0 );
    ( $renewokay, $error ) = CanBookBeRenewed( $borrowernumber1, $itemnumber1 );
    is( $renewokay, 0, 'Bug 14337 - Verify the borrower cannot renew with a hold on the record if AllowRenewalIfOtherItemsAvailable and onshelfholds are disabled' );

    C4::Context->dbh->do("UPDATE issuingrules SET onshelfholds = 0");
    t::lib::Mocks::mock_preference( 'AllowRenewalIfOtherItemsAvailable', 1 );
    ( $renewokay, $error ) = CanBookBeRenewed( $borrowernumber1, $itemnumber1 );
    is( $renewokay, 0, 'Bug 14337 - Verify the borrower cannot renew with a hold on the record if AllowRenewalIfOtherItemsAvailable is enabled and onshelfholds is disabled' );

    C4::Context->dbh->do("UPDATE issuingrules SET onshelfholds = 1");
    t::lib::Mocks::mock_preference( 'AllowRenewalIfOtherItemsAvailable', 0 );
    ( $renewokay, $error ) = CanBookBeRenewed( $borrowernumber1, $itemnumber1 );
    is( $renewokay, 0, 'Bug 14337 - Verify the borrower cannot renew with a hold on the record if AllowRenewalIfOtherItemsAvailable is disabled and onshelfhold is enabled' );

    C4::Context->dbh->do("UPDATE issuingrules SET onshelfholds = 1");
    t::lib::Mocks::mock_preference( 'AllowRenewalIfOtherItemsAvailable', 1 );
    ( $renewokay, $error ) = CanBookBeRenewed( $borrowernumber1, $itemnumber1 );
    is( $renewokay, 1, 'Bug 14337 - Verify the borrower can renew with a hold on the record if AllowRenewalIfOtherItemsAvailable and onshelfhold are enabled' );

    # Setting item not checked out to be not for loan but holdable
    ModItem({ notforloan => -1 }, $biblionumber, $itemnumber2);

    ( $renewokay, $error ) = CanBookBeRenewed( $borrowernumber1, $itemnumber1 );
    is( $renewokay, 0, 'Bug 14337 - Verify the borrower can not renew with a hold on the record if AllowRenewalIfOtherItemsAvailable is enabled but the only available item is notforloan' );
}

{
    # Don't allow renewing onsite checkout
    my $barcode  = 'R00000XXX';
    my $branch   = $library->{branchcode};

    #Create another record
    my $biblio = MARC::Record->new();
    $biblio->append_fields(
        MARC::Field->new('100', ' ', ' ', a => 'Anonymous'),
        MARC::Field->new('245', ' ', ' ', a => 'A title'),
    );
    my ($biblionumber, $biblioitemnumber) = AddBiblio($biblio, '');

    my (undef, undef, $itemnumber) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode,
            itype            => $itemtype
        },
        $biblionumber
    );

    my $borrowernumber = AddMember(
        firstname =>  'fn',
        surname => 'dn',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );

    my $borrower = GetMember( borrowernumber => $borrowernumber );
    my $issue = AddIssue( $borrower, $barcode, undef, undef, undef, undef, { onsite_checkout => 1 } );
    my ( $renewed, $error ) = CanBookBeRenewed( $borrowernumber, $itemnumber );
    is( $renewed, 0, 'CanBookBeRenewed should not allow to renew on-site checkout' );
    is( $error, 'onsite_checkout', 'A correct error code should be returned by CanBookBeRenewed for on-site checkout' );
}

{
    my $library = $builder->build({ source => 'Branch' });

    my $biblio = MARC::Record->new();
    my ($biblionumber, $biblioitemnumber) = AddBiblio($biblio, '');

    my $barcode = 'just a barcode';
    my ( undef, undef, $itemnumber ) = AddItem(
        {
            homebranch       => $library->{branchcode},
            holdingbranch    => $library->{branchcode},
            barcode          => $barcode,
            itype            => $itemtype
        },
        $biblionumber,
    );

    my $patron = $builder->build({ source => 'Borrower', value => { branchcode => $library->{branchcode} } } );

    my $issue = AddIssue( GetMember( borrowernumber => $patron->{borrowernumber} ), $barcode );
    UpdateFine(
        {
            issue_id       => $issue->id(),
            itemnumber     => $itemnumber,
            borrowernumber => $patron->{borrowernumber},
            amount         => 1,
            type           => q{}
        }
    );
    UpdateFine(
        {
            issue_id       => $issue->id(),
            itemnumber     => $itemnumber,
            borrowernumber => $patron->{borrowernumber},
            amount         => 2,
            type           => q{}
        }
    );
    is( Koha::Account::Lines->search({ issue_id => $issue->id })->count, 1, 'UpdateFine should not create a new accountline when updating an existing fine');
}

subtest 'CanBookBeIssued & AllowReturnToBranch' => sub {
    plan tests => 26;

    my $homebranch    = $builder->build( { source => 'Branch' } );
    my $holdingbranch = $builder->build( { source => 'Branch' } );
    my $otherbranch   = $builder->build( { source => 'Branch' } );
    my $patron_1      = $builder->build( { source => 'Borrower' } );
    my $patron_2      = $builder->build( { source => 'Borrower' } );

    my $biblioitem = $builder->build( { source => 'Biblioitem' } );
    my $item = $builder->build(
        {   source => 'Item',
            value  => {
                homebranch    => $homebranch->{branchcode},
                holdingbranch => $holdingbranch->{branchcode},
                notforloan    => 0,
                itemlost      => 0,
                withdrawn     => 0,
                restricted    => 0,
                biblionumber  => $biblioitem->{biblionumber}
            }
        }
    );

    set_userenv($holdingbranch);

    my $issue = AddIssue( $patron_1, $item->{barcode} );
    is( ref($issue), 'Koha::Schema::Result::Issue' );    # FIXME Should be Koha::Checkout

    my ( $error, $question, $alerts );

    # AllowReturnToBranch == anywhere
    t::lib::Mocks::mock_preference( 'AllowReturnToBranch', 'anywhere' );
    ## Can be issued from homebranch
    set_userenv($homebranch);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$error), 0, 'There should not be any errors (impossible)' );
    is( keys(%$alerts), 0, 'There should not be any alerts' );
    is( exists $question->{ISSUED_TO_ANOTHER}, 1 );
    ## Can be issued from holdingbranch
    set_userenv($holdingbranch);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$error), 0, 'There should not be any errors (impossible)' );
    is( keys(%$alerts), 0, 'There should not be any alerts' );
    is( exists $question->{ISSUED_TO_ANOTHER}, 1 );
    ## Can be issued from another branch
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$error), 0, 'There should not be any errors (impossible)' );
    is( keys(%$alerts), 0, 'There should not be any alerts' );
    is( exists $question->{ISSUED_TO_ANOTHER}, 1 );

    # AllowReturnToBranch == holdingbranch
    t::lib::Mocks::mock_preference( 'AllowReturnToBranch', 'holdingbranch' );
    ## Cannot be issued from homebranch
    set_userenv($homebranch);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$question) + keys(%$alerts),  0 );
    is( exists $error->{RETURN_IMPOSSIBLE}, 1 );
    is( $error->{branch_to_return},         $holdingbranch->{branchcode} );
    ## Can be issued from holdinbranch
    set_userenv($holdingbranch);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$error) + keys(%$alerts),        0 );
    is( exists $question->{ISSUED_TO_ANOTHER}, 1 );
    ## Cannot be issued from another branch
    set_userenv($otherbranch);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$question) + keys(%$alerts),  0 );
    is( exists $error->{RETURN_IMPOSSIBLE}, 1 );
    is( $error->{branch_to_return},         $holdingbranch->{branchcode} );

    # AllowReturnToBranch == homebranch
    t::lib::Mocks::mock_preference( 'AllowReturnToBranch', 'homebranch' );
    ## Can be issued from holdinbranch
    set_userenv($homebranch);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$error) + keys(%$alerts),        0 );
    is( exists $question->{ISSUED_TO_ANOTHER}, 1 );
    ## Cannot be issued from holdinbranch
    set_userenv($holdingbranch);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$question) + keys(%$alerts),  0 );
    is( exists $error->{RETURN_IMPOSSIBLE}, 1 );
    is( $error->{branch_to_return},         $homebranch->{branchcode} );
    ## Cannot be issued from holdinbranch
    set_userenv($otherbranch);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron_2, $item->{barcode} );
    is( keys(%$question) + keys(%$alerts),  0 );
    is( exists $error->{RETURN_IMPOSSIBLE}, 1 );
    is( $error->{branch_to_return},         $homebranch->{branchcode} );

    # TODO t::lib::Mocks::mock_preference('AllowReturnToBranch', 'homeorholdingbranch');
};

subtest 'AddIssue & AllowReturnToBranch' => sub {
    plan tests => 9;

    my $homebranch    = $builder->build( { source => 'Branch' } );
    my $holdingbranch = $builder->build( { source => 'Branch' } );
    my $otherbranch   = $builder->build( { source => 'Branch' } );
    my $patron_1      = $builder->build( { source => 'Borrower' } );
    my $patron_2      = $builder->build( { source => 'Borrower' } );

    my $biblioitem = $builder->build( { source => 'Biblioitem' } );
    my $item = $builder->build(
        {   source => 'Item',
            value  => {
                homebranch    => $homebranch->{branchcode},
                holdingbranch => $holdingbranch->{branchcode},
                notforloan    => 0,
                itemlost      => 0,
                withdrawn     => 0,
                biblionumber  => $biblioitem->{biblionumber}
            }
        }
    );

    set_userenv($holdingbranch);

    my $ref_issue = 'Koha::Schema::Result::Issue'; # FIXME Should be Koha::Checkout
    my $issue = AddIssue( $patron_1, $item->{barcode} );

    my ( $error, $question, $alerts );

    # AllowReturnToBranch == homebranch
    t::lib::Mocks::mock_preference( 'AllowReturnToBranch', 'anywhere' );
    ## Can be issued from homebranch
    set_userenv($homebranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), $ref_issue );
    set_userenv($holdingbranch); AddIssue( $patron_1, $item->{barcode} ); # Reinsert the original issue
    ## Can be issued from holdinbranch
    set_userenv($holdingbranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), $ref_issue );
    set_userenv($holdingbranch); AddIssue( $patron_1, $item->{barcode} ); # Reinsert the original issue
    ## Can be issued from another branch
    set_userenv($otherbranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), $ref_issue );
    set_userenv($holdingbranch); AddIssue( $patron_1, $item->{barcode} ); # Reinsert the original issue

    # AllowReturnToBranch == holdinbranch
    t::lib::Mocks::mock_preference( 'AllowReturnToBranch', 'holdingbranch' );
    ## Cannot be issued from homebranch
    set_userenv($homebranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), '' );
    ## Can be issued from holdingbranch
    set_userenv($holdingbranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), $ref_issue );
    set_userenv($holdingbranch); AddIssue( $patron_1, $item->{barcode} ); # Reinsert the original issue
    ## Cannot be issued from another branch
    set_userenv($otherbranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), '' );

    # AllowReturnToBranch == homebranch
    t::lib::Mocks::mock_preference( 'AllowReturnToBranch', 'homebranch' );
    ## Can be issued from homebranch
    set_userenv($homebranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), $ref_issue );
    set_userenv($holdingbranch); AddIssue( $patron_1, $item->{barcode} ); # Reinsert the original issue
    ## Cannot be issued from holdinbranch
    set_userenv($holdingbranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), '' );
    ## Cannot be issued from another branch
    set_userenv($otherbranch);
    is ( ref( AddIssue( $patron_2, $item->{barcode} ) ), '' );
    # TODO t::lib::Mocks::mock_preference('AllowReturnToBranch', 'homeorholdingbranch');
};

subtest 'CanBookBeIssued + Koha::Patron->is_debarred|has_overdues' => sub {
    plan tests => 8;

    my $library = $builder->build( { source => 'Branch' } );
    my $patron  = $builder->build( { source => 'Borrower' } );

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
    my $biblioitem_2 = $builder->build( { source => 'Biblioitem' } );
    my $item_2 = $builder->build(
        {   source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                notforloan    => 0,
                itemlost      => 0,
                withdrawn     => 0,
                biblionumber  => $biblioitem_2->{biblionumber}
            }
        }
    );

    my ( $error, $question, $alerts );

    # Patron cannot issue item_1, they have overdues
    my $yesterday = DateTime->today( time_zone => C4::Context->tz() )->add( days => -1 );
    my $issue = AddIssue( $patron, $item_1->{barcode}, $yesterday );    # Add an overdue

    t::lib::Mocks::mock_preference( 'OverduesBlockCirc', 'confirmation' );
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron, $item_2->{barcode} );
    is( keys(%$error) + keys(%$alerts),  0 );
    is( $question->{USERBLOCKEDOVERDUE}, 1 );

    t::lib::Mocks::mock_preference( 'OverduesBlockCirc', 'block' );
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron, $item_2->{barcode} );
    is( keys(%$question) + keys(%$alerts), 0 );
    is( $error->{USERBLOCKEDOVERDUE},      1 );

    # Patron cannot issue item_1, they are debarred
    my $tomorrow = DateTime->today( time_zone => C4::Context->tz() )->add( days => 1 );
    Koha::Patron::Debarments::AddDebarment( { borrowernumber => $patron->{borrowernumber}, expiration => $tomorrow } );
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron, $item_2->{barcode} );
    is( keys(%$question) + keys(%$alerts), 0 );
    is( $error->{USERBLOCKEDWITHENDDATE}, output_pref( { dt => $tomorrow, dateformat => 'sql', dateonly => 1 } ) );

    Koha::Patron::Debarments::AddDebarment( { borrowernumber => $patron->{borrowernumber} } );
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron, $item_2->{barcode} );
    is( keys(%$question) + keys(%$alerts), 0 );
    is( $error->{USERBLOCKEDNOENDDATE},    '9999-12-31' );
};

subtest 'MultipleReserves' => sub {
    plan tests => 3;

    my $biblio = MARC::Record->new();
    my $title = 'Silence in the library';
    $biblio->append_fields(
        MARC::Field->new('100', ' ', ' ', a => 'Moffat, Steven'),
        MARC::Field->new('245', ' ', ' ', a => $title),
    );

    my ($biblionumber, $biblioitemnumber) = AddBiblio($biblio, '');

    my $branch = $library2->{branchcode};

    my $barcode1 = 'R00110001';
    my ( $item_bibnum1, $item_bibitemnum1, $itemnumber1 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode1,
            replacementprice => 12.00,
            itype            => $itemtype
        },
        $biblionumber
    );

    my $barcode2 = 'R00110002';
    my ( $item_bibnum2, $item_bibitemnum2, $itemnumber2 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode2,
            replacementprice => 12.00,
            itype            => $itemtype
        },
        $biblionumber
    );

    my $bibitems       = '';
    my $priority       = '1';
    my $resdate        = undef;
    my $expdate        = undef;
    my $notes          = '';
    my $checkitem      = undef;
    my $found          = undef;

    my %renewing_borrower_data = (
        firstname =>  'John',
        surname => 'Renewal',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );
    my $renewing_borrowernumber = AddMember(%renewing_borrower_data);
    my $renewing_borrower = GetMember( borrowernumber => $renewing_borrowernumber );
    my $issue = AddIssue( $renewing_borrower, $barcode1);
    my $datedue = dt_from_string( $issue->date_due() );
    is (defined $issue->date_due(), 1, "item 1 checked out");
    my $borrowing_borrowernumber = GetItemIssue($itemnumber1)->{borrowernumber};

    my %reserving_borrower_data1 = (
        firstname =>  'Katrin',
        surname => 'Reservation',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );
    my $reserving_borrowernumber1 = AddMember(%reserving_borrower_data1);
    AddReserve(
        $branch, $reserving_borrowernumber1, $biblionumber,
        $bibitems,  $priority, $resdate, $expdate, $notes,
        $title, $checkitem, $found
    );

    my %reserving_borrower_data2 = (
        firstname =>  'Kirk',
        surname => 'Reservation',
        categorycode => $patron_category->{categorycode},
        branchcode => $branch,
    );
    my $reserving_borrowernumber2 = AddMember(%reserving_borrower_data2);
    AddReserve(
        $branch, $reserving_borrowernumber2, $biblionumber,
        $bibitems,  $priority, $resdate, $expdate, $notes,
        $title, $checkitem, $found
    );

    {
        my ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber1, 1);
        is($renewokay, 0, 'Bug 17641 - should cover the case where 2 books are both reserved, so failing');
    }

    my $barcode3 = 'R00110003';
    my ( $item_bibnum3, $item_bibitemnum3, $itemnumber3 ) = AddItem(
        {
            homebranch       => $branch,
            holdingbranch    => $branch,
            barcode          => $barcode3,
            replacementprice => 12.00,
            itype            => $itemtype
        },
        $biblionumber
    );

    {
        my ( $renewokay, $error ) = CanBookBeRenewed($renewing_borrowernumber, $itemnumber1, 1);
        is($renewokay, 1, 'Bug 17641 - should cover the case where 2 books are reserved, but a third one is available');
    }
};

subtest 'CanBookBeIssued + AllowMultipleIssuesOnABiblio' => sub {
    plan tests => 5;

    my $library = $builder->build( { source => 'Branch' } );
    my $patron  = $builder->build( { source => 'Borrower' } );

    my $biblioitem = $builder->build( { source => 'Biblioitem' } );
    my $biblionumber = $biblioitem->{biblionumber};
    my $item_1 = $builder->build(
        {   source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                notforloan    => 0,
                itemlost      => 0,
                withdrawn     => 0,
                biblionumber  => $biblionumber,
            }
        }
    );
    my $item_2 = $builder->build(
        {   source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                notforloan    => 0,
                itemlost      => 0,
                withdrawn     => 0,
                biblionumber  => $biblionumber,
            }
        }
    );

    my ( $error, $question, $alerts );
    my $issue = AddIssue( $patron, $item_1->{barcode}, dt_from_string->add( days => 1 ) );

    t::lib::Mocks::mock_preference('AllowMultipleIssuesOnABiblio', 0);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron, $item_2->{barcode} );
    is( keys(%$error) + keys(%$alerts),  0, 'No error or alert should be raised' );
    is( $question->{BIBLIO_ALREADY_ISSUED}, 1, 'BIBLIO_ALREADY_ISSUED question flag should be set if AllowMultipleIssuesOnABiblio=0 and issue already exists' );

    t::lib::Mocks::mock_preference('AllowMultipleIssuesOnABiblio', 1);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron, $item_2->{barcode} );
    is( keys(%$error) + keys(%$question) + keys(%$alerts),  0, 'No BIBLIO_ALREADY_ISSUED flag should be set if AllowMultipleIssuesOnABiblio=1' );

    # Add a subscription
    Koha::Subscription->new({ biblionumber => $biblionumber })->store;

    t::lib::Mocks::mock_preference('AllowMultipleIssuesOnABiblio', 0);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron, $item_2->{barcode} );
    is( keys(%$error) + keys(%$question) + keys(%$alerts),  0, 'No BIBLIO_ALREADY_ISSUED flag should be set if it is a subscription' );

    t::lib::Mocks::mock_preference('AllowMultipleIssuesOnABiblio', 1);
    ( $error, $question, $alerts ) = CanBookBeIssued( $patron, $item_2->{barcode} );
    is( keys(%$error) + keys(%$question) + keys(%$alerts),  0, 'No BIBLIO_ALREADY_ISSUED flag should be set if it is a subscription' );
};

subtest 'AddReturn + CumulativeRestrictionPeriods' => sub {
    plan tests => 8;

    my $library = $builder->build( { source => 'Branch' } );
    my $patron  = $builder->build( { source => 'Borrower' } );

    # Add 2 items
    my $biblioitem_1 = $builder->build( { source => 'Biblioitem' } );
    my $item_1 = $builder->build(
        {
            source => 'Item',
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

    my $biblioitem_2 = $builder->build( { source => 'Biblioitem' } );
    my $item_2 = $builder->build(
        {
            source => 'Item',
            value  => {
                homebranch    => $library->{branchcode},
                holdingbranch => $library->{branchcode},
                notforloan    => 0,
                itemlost      => 0,
                withdrawn     => 0,
                biblionumber  => $biblioitem_2->{biblionumber}
            }
        }
    );

    # And the issuing rule
    Koha::IssuingRules->search->delete;
    my $rule = Koha::IssuingRule->new(
        {
            categorycode => '*',
            itemtype     => '*',
            branchcode   => '*',
            ccode        => '*',
            permanent_location => '*',
            checkout_type => '*',
            maxissueqty  => 99,
            issuelength  => 1,
            firstremind  => 1,        # 1 day of grace
            finedays     => 2,        # 2 days of fine per day of overdue
            lengthunit   => 'days',
        }
    );
    $rule->store();

    # Patron cannot issue item_1, they have overdues
    my $five_days_ago = dt_from_string->subtract( days => 5 );
    my $ten_days_ago  = dt_from_string->subtract( days => 10 );
    AddIssue( $patron, $item_1->{barcode}, $five_days_ago );    # Add an overdue
    AddIssue( $patron, $item_2->{barcode}, $ten_days_ago )
      ;    # Add another overdue

    t::lib::Mocks::mock_preference( 'CumulativeRestrictionPeriods', '0' );
    AddReturn( $item_1->{barcode}, $library->{branchcode},
        undef, undef, dt_from_string );
    my $debarments = Koha::Patron::Debarments::GetDebarments(
        { borrowernumber => $patron->{borrowernumber}, type => 'SUSPENSION' } );
    is( scalar(@$debarments), 1 );

    # FIXME Is it right? I'd have expected 5 * 2 - 1 instead
    # Same for the others
    my $expected_expiration = output_pref(
        {
            dt         => dt_from_string->add( days => ( 5 - 1 ) * 2 ),
            dateformat => 'sql',
            dateonly   => 1
        }
    );
    is( $debarments->[0]->{expiration}, $expected_expiration );

    AddReturn( $item_2->{barcode}, $library->{branchcode},
        undef, undef, dt_from_string );
    $debarments = Koha::Patron::Debarments::GetDebarments(
        { borrowernumber => $patron->{borrowernumber}, type => 'SUSPENSION' } );
    is( scalar(@$debarments), 1 );
    $expected_expiration = output_pref(
        {
            dt         => dt_from_string->add( days => ( 10 - 1 ) * 2 ),
            dateformat => 'sql',
            dateonly   => 1
        }
    );
    is( $debarments->[0]->{expiration}, $expected_expiration );

    Koha::Patron::Debarments::DelUniqueDebarment(
        { borrowernumber => $patron->{borrowernumber}, type => 'SUSPENSION' } );

    t::lib::Mocks::mock_preference( 'CumulativeRestrictionPeriods', '1' );
    AddIssue( $patron, $item_1->{barcode}, $five_days_ago );    # Add an overdue
    AddIssue( $patron, $item_2->{barcode}, $ten_days_ago )
      ;    # Add another overdue
    AddReturn( $item_1->{barcode}, $library->{branchcode},
        undef, undef, dt_from_string );
    $debarments = Koha::Patron::Debarments::GetDebarments(
        { borrowernumber => $patron->{borrowernumber}, type => 'SUSPENSION' } );
    is( scalar(@$debarments), 1 );
    $expected_expiration = output_pref(
        {
            dt         => dt_from_string->add( days => ( 5 - 1 ) * 2 ),
            dateformat => 'sql',
            dateonly   => 1
        }
    );
    is( $debarments->[0]->{expiration}, $expected_expiration );

    AddReturn( $item_2->{barcode}, $library->{branchcode},
        undef, undef, dt_from_string );
    $debarments = Koha::Patron::Debarments::GetDebarments(
        { borrowernumber => $patron->{borrowernumber}, type => 'SUSPENSION' } );
    is( scalar(@$debarments), 1 );
    $expected_expiration = output_pref(
        {
            dt => dt_from_string->add( days => ( 5 - 1 ) * 2 + ( 10 - 1 ) * 2 ),
            dateformat => 'sql',
            dateonly   => 1
        }
    );
    is( $debarments->[0]->{expiration}, $expected_expiration );
};

subtest 'SendCirculationAlert test' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_preference('ValidatePhoneNumber', '');

    my $library = $builder->build( { source => 'Branch' } );
    my $patron  = $builder->build( { source => 'Borrower', value => {
        email => 'nobody@example.com'
    } } );
    my $attribute = Koha::Patron::Message::Attributes->find({
        message_name => 'Item_Checkout',
    });
    Koha::Patron::Message::Preference->new({
        borrowernumber => $patron->{'borrowernumber'},
        message_attribute_id => $attribute->message_attribute_id,
        days_in_advance => undef,
        wants_digest => 0,
        message_transport_types => ['email'],
    })->store;
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

    my $old_message = C4::Message->find_last_message($patron, 'CHECKOUT', 'email');
    $old_message->{'message_id'} = 0 unless $old_message;
    is(C4::Circulation::SendCirculationAlert({
        type     => 'CHECKOUT',
        item     => $item_1,
        borrower => $patron,
        branch   => $library->{'branchcode'},
    }), undef, "SendCirculationAlert called.");
    my $new_message = C4::Message->find_last_message($patron, 'CHECKOUT', 'email');
    ok($old_message->{'message_id'} != $new_message->{'message_id'}, "New message has appeared.");
    is($new_message->{'letter_code'}, 'CHECKOUT', "New message letter code is CHECKOUT.");
    is($new_message->{'borrowernumber'}, $patron->{'borrowernumber'}, "New message is to our test patron.");
};

sub set_userenv {
    my ( $library ) = @_;
    C4::Context->set_userenv(0,0,0,'firstname','surname', $library->{branchcode}, $library->{branchname}, '', '', '');
}
