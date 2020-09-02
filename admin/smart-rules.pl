#!/usr/bin/perl
# Copyright 2000-2002 Katipo Communications
# copyright 2010 BibLibre
#
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

use strict;
use warnings;
use CGI qw ( -utf8 );
use C4::Context;
use C4::Output;
use C4::Auth;
use C4::Koha;
use C4::Debug;
use Koha::DateUtils;
use Koha::Database;
use Koha::IssuingRule;
use Koha::IssuingRules;
use Koha::Logger;
use Koha::RefundLostItemFeeRule;
use Koha::RefundLostItemFeeRules;
use Koha::Libraries;
use Koha::Patron::Categories;

my $input = CGI->new;
my $dbh = C4::Context->dbh;

# my $flagsrequired;
# $flagsrequired->{circulation}=1;
my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "admin/smart-rules.tt",
                            query => $input,
                            type => "intranet",
                            authnotrequired => 0,
                            flagsrequired => {parameters => 'manage_circ_rules'},
                            debug => 1,
                            });

my $type=$input->param('type');

my $branch = $input->param('branch');
unless ( $branch ) {
    if ( C4::Context->preference('DefaultToLoggedInLibraryCircRules') ) {
        $branch = Koha::Libraries->search->count() == 1 ? undef : C4::Context::mybranch();
    }
    else {
        $branch = C4::Context::only_my_library() ? ( C4::Context::mybranch() || '*' ) : '*';
    }
}
$branch = '*' if $branch eq 'NO_LIBRARY_SET';

my $op = $input->param('op') || q{};
my $language = C4::Languages::getlanguage();

if ($op eq 'delete') {
    my $itemtype     = $input->param('itemtype');
    my $categorycode = $input->param('categorycode');
    my $ccode        = $input->param('ccode');
    my $permanent_location = $input->param('permanent_location');
    my $sub_location = $input->param('sub_location');
    my $genre        = $input->param('genre');
    my $checkout_type = $input->param('checkout_type');
    my $reserve_level = $input->param('reserve_level');
    $debug and warn "deleting $1 $2 $branch";

    my $sth_Idelete = $dbh->prepare("delete from issuingrules
        where branchcode=?
        and categorycode=?
        and itemtype=?
        and ccode=?
        and permanent_location=?
        and sub_location=?
        and genre=?
        and checkout_type=?
        and reserve_level=?
    ");
    $sth_Idelete->execute($branch, $categorycode, $itemtype,
                          $ccode, $permanent_location, $sub_location,
                          $genre, $checkout_type, $reserve_level);
}
elsif ($op eq 'delete-branch-cat') {
    my $categorycode  = $input->param('categorycode');
    if ($branch eq "*") {
        if ($categorycode eq "*") {
            my $sth_delete = $dbh->prepare("DELETE FROM default_circ_rules");
            $sth_delete->execute();
        } else {
            my $sth_delete = $dbh->prepare("DELETE FROM default_borrower_circ_rules
                                            WHERE categorycode = ?");
            $sth_delete->execute($categorycode);
        }
    } elsif ($categorycode eq "*") {
        my $sth_delete = $dbh->prepare("DELETE FROM default_branch_circ_rules
                                        WHERE branchcode = ?");
        $sth_delete->execute($branch);
    } else {
        my $sth_delete = $dbh->prepare("DELETE FROM branch_borrower_circ_rules
                                        WHERE branchcode = ?
                                        AND categorycode = ?");
        $sth_delete->execute($branch, $categorycode);
    }
}
elsif ($op eq 'delete-branch-item') {
    my $itemtype  = $input->param('itemtype');
    if ($branch eq "*") {
        if ($itemtype eq "*") {
            my $sth_delete = $dbh->prepare("DELETE FROM default_circ_rules");
            $sth_delete->execute();
        } else {
            my $sth_delete = $dbh->prepare("DELETE FROM default_branch_item_rules
                                            WHERE itemtype = ?");
            $sth_delete->execute($itemtype);
        }
    } elsif ($itemtype eq "*") {
        my $sth_delete = $dbh->prepare("DELETE FROM default_branch_circ_rules
                                        WHERE branchcode = ?");
        $sth_delete->execute($branch);
    } else {
        my $sth_delete = $dbh->prepare("DELETE FROM branch_item_rules
                                        WHERE branchcode = ?
                                        AND itemtype = ?");
        $sth_delete->execute($branch, $itemtype);
    }
}
# save the values entered
elsif ($op eq 'add') {
    my $br = $branch; # branch
    my $bor  = $input->param('categorycode'); # borrower category
    my $itemtype  = $input->param('itemtype');     # item type
    my $ccode = $input->param('ccode');
    my $permanent_location = $input->param('permanent_location');
    my $sub_location = $input->param('sub_location');
    my $genre        = $input->param('genre');
    my $checkout_type = $input->param('checkout_type');
    my $reserve_level = $input->param('reserve_level');
    my $fine = $input->param('fine');
    my $finedays     = $input->param('finedays');
    my $maxsuspensiondays = $input->param('maxsuspensiondays');
    $maxsuspensiondays = undef if $maxsuspensiondays eq q||;
    my $firstremind  = $input->param('firstremind');
    my $chargeperiod = $input->param('chargeperiod');
    my $chargeperiod_charge_at = $input->param('chargeperiod_charge_at');
    my $maxissueqty  = $input->param('maxissueqty');
    my $maxonsiteissueqty  = $input->param('maxonsiteissueqty');
    my $renewalsallowed  = $input->param('renewalsallowed');
    my $renewalperiod    = $input->param('renewalperiod');
    my $norenewalbefore  = $input->param('norenewalbefore');
    $norenewalbefore = undef if $norenewalbefore =~ /^\s*$/;
    my $auto_renew = $input->param('auto_renew') eq 'yes' ? 1 : 0;
    my $no_auto_renewal_after = $input->param('no_auto_renewal_after');
    $no_auto_renewal_after = undef if $no_auto_renewal_after =~ /^\s*$/;
    my $no_auto_renewal_after_hard_limit = $input->param('no_auto_renewal_after_hard_limit') || undef;
    $no_auto_renewal_after_hard_limit = eval { dt_from_string( $input->param('no_auto_renewal_after_hard_limit') ) } if ( $no_auto_renewal_after_hard_limit );
    $no_auto_renewal_after_hard_limit = output_pref( { dt => $no_auto_renewal_after_hard_limit, dateonly => 1, dateformat => 'iso' } ) if ( $no_auto_renewal_after_hard_limit );
    my $reservesallowed  = $input->param('reservesallowed');
    my $holds_per_record  = $input->param('holds_per_record');
    my $hold_max_pickup_delay = $input->param('hold_max_pickup_delay');
    my $hold_expiration_charge = $input->param('hold_expiration_charge');
    my $onshelfholds     = $input->param('onshelfholds') || 0;
    $maxissueqty =~ s/\s//g;
    $maxissueqty = undef if $maxissueqty !~ /^\d+/;
    $maxonsiteissueqty =~ s/\s//g;
    $maxonsiteissueqty = undef if $maxonsiteissueqty !~ /^\d+/;
    my $issuelength  = $input->param('issuelength');
    $issuelength = $issuelength eq q{} ? undef : $issuelength;
    my $lengthunit  = $input->param('lengthunit');
    my $hardduedate = $input->param('hardduedate') || undef;
    $hardduedate = eval { dt_from_string( $input->param('hardduedate') ) } if ( $hardduedate );
    $hardduedate = output_pref( { dt => $hardduedate, dateonly => 1, dateformat => 'iso' } ) if ( $hardduedate );
    my $hardduedatecompare = $input->param('hardduedatecompare');
    my $rentaldiscount = $input->param('rentaldiscount');
    my $opacitemholds = $input->param('opacitemholds') || 0;
    my $article_requests = $input->param('article_requests') || 'no';
    my $overduefinescap = $input->param('overduefinescap') || undef;
    my $cap_fine_to_replacement_price = $input->param('cap_fine_to_replacement_price') eq 'on';
    $debug and warn "Adding $br, $bor, $itemtype, $ccode, $permanent_location, $sub_location, $genre, $checkout_type, $reserve_level, $fine, $maxissueqty, $maxonsiteissueqty, $cap_fine_to_replacement_price";

    # disable hold rules for checkout types
    if ($checkout_type && $checkout_type ne '*') {
        $reservesallowed        = 0;
        $holds_per_record       = 0;
        $hold_max_pickup_delay  = 0;
        $hold_expiration_charge = 0;
        $onshelfholds           = 0;
    }

    my $params = {
        branchcode                    => $br,
        categorycode                  => $bor,
        itemtype                      => $itemtype,
        ccode                         => $ccode,
        permanent_location            => $permanent_location,
        sub_location                  => $sub_location,
        genre                         => $genre,
        checkout_type             => $checkout_type,
        reserve_level                 => $reserve_level,
        fine                          => $fine,
        finedays                      => $finedays,
        maxsuspensiondays             => $maxsuspensiondays,
        firstremind                   => $firstremind,
        chargeperiod                  => $chargeperiod,
        chargeperiod_charge_at        => $chargeperiod_charge_at,
        maxissueqty                   => $maxissueqty,
        maxonsiteissueqty             => $maxonsiteissueqty,
        renewalsallowed               => $renewalsallowed,
        renewalperiod                 => $renewalperiod,
        norenewalbefore               => $norenewalbefore,
        auto_renew                    => $auto_renew,
        no_auto_renewal_after         => $no_auto_renewal_after,
        no_auto_renewal_after_hard_limit => $no_auto_renewal_after_hard_limit,
        reservesallowed               => $reservesallowed,
        holds_per_record              => $holds_per_record,
        hold_max_pickup_delay         => $hold_max_pickup_delay,
        hold_expiration_charge        => $hold_expiration_charge,
        issuelength                   => $issuelength,
        lengthunit                    => $lengthunit,
        hardduedate                   => $hardduedate,
        hardduedatecompare            => $hardduedatecompare,
        rentaldiscount                => $rentaldiscount,
        onshelfholds                  => $onshelfholds,
        opacitemholds                 => $opacitemholds,
        overduefinescap               => $overduefinescap,
        cap_fine_to_replacement_price => $cap_fine_to_replacement_price,
        article_requests              => $article_requests,
    };

    my $issuingrule = Koha::IssuingRules->find({
        categorycode => $bor,
        itemtype => $itemtype,
        branchcode => $br,
        ccode => $ccode,
        permanent_location => $permanent_location,
        sub_location => $sub_location,
        genre => $genre,
        checkout_type => $checkout_type,
        reserve_level => $reserve_level,
    });
    if ($issuingrule) {
        $issuingrule->set($params)->store();
    } else {
        Koha::IssuingRule->new()->set($params)->store();
    }

}
elsif ($op eq "set-branch-defaults") {
    my $categorycode  = $input->param('categorycode');
    my $maxissueqty   = $input->param('maxissueqty');
    my $maxonsiteissueqty = $input->param('maxonsiteissueqty');
    my $holdallowed   = $input->param('holdallowed');
    my $hold_fulfillment_policy = $input->param('hold_fulfillment_policy');
    my $returnbranch  = $input->param('returnbranch');
    $maxissueqty =~ s/\s//g;
    $maxissueqty = undef if $maxissueqty !~ /^\d+/;
    $maxonsiteissueqty =~ s/\s//g;
    $maxonsiteissueqty = undef if $maxonsiteissueqty !~ /^\d+/;
    $holdallowed =~ s/\s//g;
    $holdallowed = undef if $holdallowed !~ /^\d+/;

    if ($branch eq "*") {
        my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                        FROM default_circ_rules");
        my $sth_insert = $dbh->prepare("INSERT INTO default_circ_rules
                                        (maxissueqty, maxonsiteissueqty, holdallowed, hold_fulfillment_policy, returnbranch)
                                        VALUES (?, ?, ?, ?, ?)");
        my $sth_update = $dbh->prepare("UPDATE default_circ_rules
                                        SET maxissueqty = ?, maxonsiteissueqty = ?, holdallowed = ?, hold_fulfillment_policy = ?, returnbranch = ?");

        $sth_search->execute();
        my $res = $sth_search->fetchrow_hashref();
        if ($res->{total}) {
            $sth_update->execute($maxissueqty, $maxonsiteissueqty, $holdallowed, $hold_fulfillment_policy, $returnbranch);
        } else {
            $sth_insert->execute($maxissueqty, $maxonsiteissueqty, $holdallowed, $hold_fulfillment_policy, $returnbranch);
        }
    } else {
        my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                        FROM default_branch_circ_rules
                                        WHERE branchcode = ?");
        my $sth_insert = $dbh->prepare("INSERT INTO default_branch_circ_rules
                                        (branchcode, maxissueqty, maxonsiteissueqty, holdallowed, hold_fulfillment_policy, returnbranch)
                                        VALUES (?, ?, ?, ?, ?, ?)");
        my $sth_update = $dbh->prepare("UPDATE default_branch_circ_rules
                                        SET maxissueqty = ?, maxonsiteissueqty = ?, holdallowed = ?, hold_fulfillment_policy = ?, returnbranch = ?
                                        WHERE branchcode = ?");
        $sth_search->execute($branch);
        my $res = $sth_search->fetchrow_hashref();
        if ($res->{total}) {
            $sth_update->execute($maxissueqty, $maxonsiteissueqty, $holdallowed, $hold_fulfillment_policy, $returnbranch, $branch);
        } else {
            $sth_insert->execute($branch, $maxissueqty, $maxonsiteissueqty, $holdallowed, $hold_fulfillment_policy, $returnbranch);
        }
    }
}
elsif ($op eq "add-branch-cat") {
    my $categorycode  = $input->param('categorycode');
    my $maxissueqty   = $input->param('maxissueqty');
    my $maxonsiteissueqty = $input->param('maxonsiteissueqty');
    $maxissueqty =~ s/\s//g;
    $maxissueqty = undef if $maxissueqty !~ /^\d+/;
    $maxonsiteissueqty =~ s/\s//g;
    $maxonsiteissueqty = undef if $maxonsiteissueqty !~ /^\d+/;

    if ($branch eq "*") {
        if ($categorycode eq "*") {
            my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                            FROM default_circ_rules");
            my $sth_insert = $dbh->prepare(q|
                INSERT INTO default_circ_rules
                    (maxissueqty, maxonsiteissueqty)
                    VALUES (?, ?)
            |);
            my $sth_update = $dbh->prepare(q|
                UPDATE default_circ_rules
                SET maxissueqty = ?,
                    maxonsiteissueqty = ?
            |);

            $sth_search->execute();
            my $res = $sth_search->fetchrow_hashref();
            if ($res->{total}) {
                $sth_update->execute($maxissueqty, $maxonsiteissueqty);
            } else {
                $sth_insert->execute($maxissueqty, $maxonsiteissueqty);
            }
        } else {
            my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                            FROM default_borrower_circ_rules
                                            WHERE categorycode = ?");
            my $sth_insert = $dbh->prepare(q|
                INSERT INTO default_borrower_circ_rules
                    (categorycode, maxissueqty, maxonsiteissueqty)
                    VALUES (?, ?, ?)
            |);
            my $sth_update = $dbh->prepare(q|
                UPDATE default_borrower_circ_rules
                SET maxissueqty = ?,
                    maxonsiteissueqty = ?
                WHERE categorycode = ?
            |);
            $sth_search->execute($branch);
            my $res = $sth_search->fetchrow_hashref();
            if ($res->{total}) {
                $sth_update->execute($maxissueqty, $maxonsiteissueqty, $categorycode);
            } else {
                $sth_insert->execute($categorycode, $maxissueqty, $maxonsiteissueqty);
            }
        }
    } elsif ($categorycode eq "*") {
        my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                        FROM default_branch_circ_rules
                                        WHERE branchcode = ?");
        my $sth_insert = $dbh->prepare(q|
            INSERT INTO default_branch_circ_rules
            (branchcode, maxissueqty, maxonsiteissueqty)
            VALUES (?, ?, ?)
        |);
        my $sth_update = $dbh->prepare(q|
            UPDATE default_branch_circ_rules
            SET maxissueqty = ?,
                maxonsiteissueqty = ?
            WHERE branchcode = ?
        |);
        $sth_search->execute($branch);
        my $res = $sth_search->fetchrow_hashref();
        if ($res->{total}) {
            $sth_update->execute($maxissueqty, $maxonsiteissueqty, $branch);
        } else {
            $sth_insert->execute($branch, $maxissueqty, $maxonsiteissueqty);
        }
    } else {
        my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                        FROM branch_borrower_circ_rules
                                        WHERE branchcode = ?
                                        AND   categorycode = ?");
        my $sth_insert = $dbh->prepare(q|
            INSERT INTO branch_borrower_circ_rules
            (branchcode, categorycode, maxissueqty, maxonsiteissueqty)
            VALUES (?, ?, ?, ?)
        |);
        my $sth_update = $dbh->prepare(q|
            UPDATE branch_borrower_circ_rules
            SET maxissueqty = ?,
                maxonsiteissueqty = ?
            WHERE branchcode = ?
            AND categorycode = ?
        |);

        $sth_search->execute($branch, $categorycode);
        my $res = $sth_search->fetchrow_hashref();
        if ($res->{total}) {
            $sth_update->execute($maxissueqty, $maxonsiteissueqty, $branch, $categorycode);
        } else {
            $sth_insert->execute($branch, $categorycode, $maxissueqty, $maxonsiteissueqty);
        }
    }
}
elsif ($op eq "add-branch-item") {
    my $itemtype                = $input->param('itemtype');
    my $holdallowed             = $input->param('holdallowed');
    my $hold_fulfillment_policy = $input->param('hold_fulfillment_policy');
    my $returnbranch            = $input->param('returnbranch');

    $holdallowed =~ s/\s//g;
    $holdallowed = undef if $holdallowed !~ /^\d+/;

    if ($branch eq "*") {
        if ($itemtype eq "*") {
            my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                            FROM default_circ_rules");
            my $sth_insert = $dbh->prepare("INSERT INTO default_circ_rules
                                            (holdallowed, hold_fulfillment_policy, returnbranch)
                                            VALUES (?, ?, ?)");
            my $sth_update = $dbh->prepare("UPDATE default_circ_rules
                                            SET holdallowed = ?, hold_fulfillment_policy = ?, returnbranch = ?");

            $sth_search->execute();
            my $res = $sth_search->fetchrow_hashref();
            if ($res->{total}) {
                $sth_update->execute($holdallowed, $hold_fulfillment_policy, $returnbranch);
            } else {
                $sth_insert->execute($holdallowed, $hold_fulfillment_policy, $returnbranch);
            }
        } else {
            my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                            FROM default_branch_item_rules
                                            WHERE itemtype = ?");
            my $sth_insert = $dbh->prepare("INSERT INTO default_branch_item_rules
                                            (itemtype, holdallowed, hold_fulfillment_policy, returnbranch)
                                            VALUES (?, ?, ?, ?)");
            my $sth_update = $dbh->prepare("UPDATE default_branch_item_rules
                                            SET holdallowed = ?, hold_fulfillment_policy = ?, returnbranch = ?
                                            WHERE itemtype = ?");
            $sth_search->execute($itemtype);
            my $res = $sth_search->fetchrow_hashref();
            if ($res->{total}) {
                $sth_update->execute($holdallowed, $hold_fulfillment_policy, $returnbranch, $itemtype);
            } else {
                $sth_insert->execute($itemtype, $holdallowed, $hold_fulfillment_policy, $returnbranch);
            }
        }
    } elsif ($itemtype eq "*") {
        my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                        FROM default_branch_circ_rules
                                        WHERE branchcode = ?");
        my $sth_insert = $dbh->prepare("INSERT INTO default_branch_circ_rules
                                        (branchcode, holdallowed, hold_fulfillment_policy, returnbranch)
                                        VALUES (?, ?, ?, ?)");
        my $sth_update = $dbh->prepare("UPDATE default_branch_circ_rules
                                        SET holdallowed = ?, hold_fulfillment_policy = ?, returnbranch = ?
                                        WHERE branchcode = ?");
        $sth_search->execute($branch);
        my $res = $sth_search->fetchrow_hashref();
        if ($res->{total}) {
            $sth_update->execute($holdallowed, $hold_fulfillment_policy, $returnbranch, $branch);
        } else {
            $sth_insert->execute($branch, $holdallowed, $hold_fulfillment_policy, $returnbranch);
        }
    } else {
        my $sth_search = $dbh->prepare("SELECT count(*) AS total
                                        FROM branch_item_rules
                                        WHERE branchcode = ?
                                        AND   itemtype = ?");
        my $sth_insert = $dbh->prepare("INSERT INTO branch_item_rules
                                        (branchcode, itemtype, holdallowed, hold_fulfillment_policy, returnbranch)
                                        VALUES (?, ?, ?, ?, ?)");
        my $sth_update = $dbh->prepare("UPDATE branch_item_rules
                                        SET holdallowed = ?, hold_fulfillment_policy = ?, returnbranch = ?
                                        WHERE branchcode = ?
                                        AND itemtype = ?");

        $sth_search->execute($branch, $itemtype);
        my $res = $sth_search->fetchrow_hashref();
        if ($res->{total}) {
            $sth_update->execute($holdallowed, $hold_fulfillment_policy, $returnbranch, $branch, $itemtype);
        } else {
            $sth_insert->execute($branch, $itemtype, $holdallowed, $hold_fulfillment_policy, $returnbranch);
        }
    }
}
elsif ( $op eq 'mod-refund-lost-item-fee-rule' ) {

    my $refund = $input->param('refund');

    if ( $refund eq '*' ) {
        if ( $branch ne '*' ) {
            # only do something for $refund eq '*' if branch-specific
            eval {
                # Delete it so it picks the default
                Koha::RefundLostItemFeeRules->find({
                    branchcode => $branch
                })->delete;
            };
        }
    } else {
        my $refundRule =
                Koha::RefundLostItemFeeRules->find({
                    branchcode => $branch
                }) // Koha::RefundLostItemFeeRule->new;
        $refundRule->set({
            branchcode => $branch,
                refund => $refund
        })->store;
    }
}

my $refundLostItemFeeRule = Koha::RefundLostItemFeeRules->find({ branchcode => $branch });
$template->param(
    refundLostItemFeeRule => $refundLostItemFeeRule,
    defaultRefundRule     => Koha::RefundLostItemFeeRules->_default_rule
);

my $patron_categories = Koha::Patron::Categories->search({}, { order_by => ['description'] });

my @row_loop;
my $itemtypes = Koha::ItemTypes->search_with_localization;
my $ccodes = Koha::AuthorisedValues->search({
    category => 'CCODE',
    branchcode => $branch eq '*' ? undef : $branch
});
my $locations = Koha::AuthorisedValues->search({
    category => 'LOC',
    branchcode => $branch eq '*' ? undef : $branch
});
my $sub_locations = Koha::AuthorisedValues->search({
    category => 'SUBLOC',
    branchcode => $branch eq '*' ? undef : $branch
});
my $genres = Koha::AuthorisedValues->search({
    category => 'GENRE',
    branchcode => $branch eq '*' ? undef : $branch
});
my $reservelevels = Koha::AuthorisedValues->search({
    category => 'RESERVE_LEVEL',
    branchcode => $branch eq '*' ? undef : $branch
});

my $sth2 = $dbh->prepare("
    SELECT DISTINCT issuingrules.*,
            itemtypes.description AS humanitemtype,
            categories.description AS humancategorycode,
            COALESCE( localization.translation, itemtypes.description ) AS translated_description,
            a1.lib AS humanccode,
            a2.lib AS humanpermanent_location,
            a3.lib AS humansub_location,
            a4.lib AS humangenre,
            a5.lib AS humanreserve_level
    FROM issuingrules
    LEFT JOIN itemtypes
        ON (itemtypes.itemtype = issuingrules.itemtype)
    LEFT JOIN categories
        ON (categories.categorycode = issuingrules.categorycode)
    LEFT JOIN localization ON issuingrules.itemtype = localization.code
        AND localization.entity = 'itemtypes'
        AND localization.lang = ?
    LEFT JOIN authorised_values a1 ON issuingrules.ccode = a1.authorised_value AND a1.category = 'CCODE'
    LEFT JOIN authorised_values a2 ON issuingrules.permanent_location = a2.authorised_value AND a2.category = 'LOC'
    LEFT JOIN authorised_values a3 ON issuingrules.sub_location = a3.authorised_value AND a3.category = 'SUBLOC'
    LEFT JOIN authorised_values a4 ON issuingrules.genre = a4.authorised_value AND a4.category = 'GENRE'
    LEFT JOIN authorised_values a5 ON issuingrules.reserve_level = a5.authorised_value AND a5.category = 'RESERVE_LEVEL'
    WHERE issuingrules.branchcode = ?
");
$sth2->execute($language, $branch);

while (my $row = $sth2->fetchrow_hashref) {
    $row->{'current_branch'} ||= $row->{'branchcode'};
    $row->{humanitemtype} ||= $row->{itemtype};
    $row->{default_translated_description} = 1 if $row->{humanitemtype} eq '*';
    $row->{'humancategorycode'} ||= $row->{'categorycode'};
    $row->{'humanccode'} ||= $row->{'ccode'};
    $row->{'humanpermanent_location'} ||= $row->{'permanent_location'};
    $row->{'humansub_location'} ||= $row->{'sub_location'};
    $row->{'humangenre'} ||= $row->{'genre'};
    $row->{'humancheckout_type'} ||= $row->{'checkout_type'};
    $row->{'humanreserve_level'} ||= $row->{'reserve_level'};
    $row->{'default_humancategorycode'} = 1 if $row->{'humancategorycode'} eq '*';
    $row->{'default_ccode'} = 1 if $row->{'ccode'} eq '*';
    $row->{'default_permanent_location'} = 1 if $row->{'permanent_location'} eq '*';
    $row->{'default_sub_location'} = 1 if $row->{'sub_location'} eq '*';
    $row->{'default_genre'} = 1 if $row->{'genre'} eq '*';
    $row->{'default_checkout_type'} = 1 if $row->{'checkout_type'} eq '*';
    $row->{'default_reserve_level'} = 1 if $row->{'reserve_level'} eq '*';
    $row->{'fine'} = sprintf('%.2f', $row->{'fine'});
    if ($row->{'hardduedate'} && $row->{'hardduedate'} ne '0000-00-00') {
       my $harddue_dt = eval { dt_from_string( $row->{'hardduedate'} ) };
       $row->{'hardduedate'} = eval { output_pref( { dt => $harddue_dt, dateonly => 1 } ) } if ( $harddue_dt );
       $row->{'hardduedatebefore'} = 1 if ($row->{'hardduedatecompare'} == -1);
       $row->{'hardduedateexact'} = 1 if ($row->{'hardduedatecompare'} ==  0);
       $row->{'hardduedateafter'} = 1 if ($row->{'hardduedatecompare'} ==  1);
    } else {
       $row->{'hardduedate'} = 0;
    }
    if ($row->{no_auto_renewal_after_hard_limit}) {
       my $dt = eval { dt_from_string( $row->{no_auto_renewal_after_hard_limit} ) };
       $row->{no_auto_renewal_after_hard_limit} = eval { output_pref( { dt => $dt, dateonly => 1 } ) } if $dt;
    }

    push @row_loop, $row;
}

my @sorted_row_loop = sort by_category_and_itemtype @row_loop;

my $sth_branch_cat;
if ($branch eq "*") {
    $sth_branch_cat = $dbh->prepare("
        SELECT default_borrower_circ_rules.*, categories.description AS humancategorycode
        FROM default_borrower_circ_rules
        JOIN categories USING (categorycode)

    ");
    $sth_branch_cat->execute();
} else {
    $sth_branch_cat = $dbh->prepare("
        SELECT branch_borrower_circ_rules.*, categories.description AS humancategorycode
        FROM branch_borrower_circ_rules
        JOIN categories USING (categorycode)
        WHERE branch_borrower_circ_rules.branchcode = ?
    ");
    $sth_branch_cat->execute($branch);
}

my @branch_cat_rules = ();
while (my $row = $sth_branch_cat->fetchrow_hashref) {
    push @branch_cat_rules, $row;
}
my @sorted_branch_cat_rules = sort { $a->{'humancategorycode'} cmp $b->{'humancategorycode'} } @branch_cat_rules;

# note undef maxissueqty so that template can deal with them
foreach my $entry (@sorted_branch_cat_rules, @sorted_row_loop) {
    $entry->{unlimited_maxissueqty} = 1 unless defined($entry->{maxissueqty});
    $entry->{unlimited_maxonsiteissueqty} = 1 unless defined($entry->{maxonsiteissueqty});
}

@sorted_row_loop = sort by_category_and_itemtype @row_loop;

my $sth_branch_item;
if ($branch eq "*") {
    $sth_branch_item = $dbh->prepare("
        SELECT default_branch_item_rules.*,
            COALESCE( localization.translation, itemtypes.description ) AS translated_description
        FROM default_branch_item_rules
        JOIN itemtypes USING (itemtype)
        LEFT JOIN localization ON itemtypes.itemtype = localization.code
            AND localization.entity = 'itemtypes'
            AND localization.lang = ?
    ");
    $sth_branch_item->execute($language);
} else {
    $sth_branch_item = $dbh->prepare("
        SELECT branch_item_rules.*,
            COALESCE( localization.translation, itemtypes.description ) AS translated_description
        FROM branch_item_rules
        JOIN itemtypes USING (itemtype)
        LEFT JOIN localization ON itemtypes.itemtype = localization.code
            AND localization.entity = 'itemtypes'
            AND localization.lang = ?
        WHERE branch_item_rules.branchcode = ?
    ");
    $sth_branch_item->execute($language, $branch);
}

my @branch_item_rules = ();
while (my $row = $sth_branch_item->fetchrow_hashref) {
    push @branch_item_rules, $row;
}
my @sorted_branch_item_rules = sort { lc $a->{translated_description} cmp lc $b->{translated_description} } @branch_item_rules;

# note undef holdallowed so that template can deal with them
foreach my $entry (@sorted_branch_item_rules) {
    $entry->{holdallowed_any}  = 1 if ( $entry->{holdallowed} == 2 );
    $entry->{holdallowed_same} = 1 if ( $entry->{holdallowed} == 1 );
}

$template->param(show_branch_cat_rule_form => 1);
$template->param(branch_item_rule_loop => \@sorted_branch_item_rules);
$template->param(branch_cat_rule_loop => \@sorted_branch_cat_rules);

my $sth_defaults;
if ($branch eq "*") {
    $sth_defaults = $dbh->prepare("
        SELECT *
        FROM default_circ_rules
    ");
    $sth_defaults->execute();
} else {
    $sth_defaults = $dbh->prepare("
        SELECT *
        FROM default_branch_circ_rules
        WHERE branchcode = ?
    ");
    $sth_defaults->execute($branch);
}

my $defaults = $sth_defaults->fetchrow_hashref;

if ($defaults) {
    $template->param( default_holdallowed_none => 1 ) if ( $defaults->{holdallowed} == 0 );
    $template->param( default_holdallowed_same => 1 ) if ( $defaults->{holdallowed} == 1 );
    $template->param( default_holdallowed_any  => 1 ) if ( $defaults->{holdallowed} == 2 );
    $template->param( default_hold_fulfillment_policy => $defaults->{hold_fulfillment_policy} );
    $template->param( default_maxissueqty      => $defaults->{maxissueqty} );
    $template->param( default_maxonsiteissueqty => $defaults->{maxonsiteissueqty} );
    $template->param( default_returnbranch      => $defaults->{returnbranch} );
}

$template->param(default_rules => ($defaults ? 1 : 0));

$template->param(
    patron_categories => $patron_categories,
                        itemtypeloop => $itemtypes,
                        ccodeloop => $ccodes,
                        locloop => $locations,
                        sublocloop => $sub_locations,
                        genreloop => $genres,
                        reservelevelloop => $reservelevels,
                        rules => \@sorted_row_loop,
                        humanbranch => ($branch ne '*' ? $branch : ''),
                        current_branch => $branch,
                        definedbranch => scalar(@sorted_row_loop)>0
                        );
output_html_with_http_headers $input, $cookie, $template->output;

exit 0;

# sort by patron category, then item type, putting
# default entries at the bottom
sub by_category_and_itemtype {
    unless (by_category($a, $b)) {
        return by_itemtype($a, $b);
    }
}

sub by_category {
    my ($a, $b) = @_;
    if ($a->{'default_humancategorycode'}) {
        return ($b->{'default_humancategorycode'} ? 0 : 1);
    } elsif ($b->{'default_humancategorycode'}) {
        return -1;
    } else {
        return $a->{'humancategorycode'} cmp $b->{'humancategorycode'};
    }
}

sub by_itemtype {
    my ($a, $b) = @_;
    if ($a->{default_translated_description}) {
        return ($b->{'default_translated_description'} ? 0 : 1);
    } elsif ($b->{'default_translated_description'}) {
        return -1;
    } else {
        return lc $a->{'translated_description'} cmp lc $b->{'translated_description'};
    }
}
