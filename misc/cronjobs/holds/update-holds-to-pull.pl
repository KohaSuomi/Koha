#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
# Copyright 2016-2022 Koha-Suomi Oy
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

use Modern::Perl;
use C4::Context;
use Koha::Biblios;
use Koha::DateUtils qw (dt_from_string output_pref);
use Koha::CirculationRules qw ( get_effective_rule );
use DateTime::Duration;
use Storable;

use constant PULL_INTERVAL => 2;

my $dbh = C4::Context->dbh;
my @query_params = ();

my $today = dt_from_string;

# Find two days ago for the default shelf pull start date, unless HoldsToPullStartDate sys pref is set.
my $startdate = $today - DateTime::Duration->new( days => C4::Context->preference('HoldsToPullStartDate') || PULL_INTERVAL );
my $startdate_iso = output_pref({ dt => $startdate, dateformat => 'iso', dateonly => 1 });
push @query_params, $startdate_iso;

#similarly: calculate end date with ConfirmFutureHolds (days)
my $enddate = $today + DateTime::Duration->new( days => C4::Context->preference('ConfirmFutureHolds') || 0 );
my $enddate_iso   = output_pref({ dt => $enddate, dateformat => 'iso', dateonly => 1 });
push @query_params, $enddate_iso;

my @reservedata;

my $strsth =
    "SELECT min(reservedate)        AS l_reservedate,
            reserves.borrowernumber AS borrowernumber,
            reserves.branchcode     AS l_branch,
            reserves.biblionumber,

            GROUP_CONCAT(DISTINCT items.holdingbranch  ORDER BY items.itemnumber SEPARATOR '|')          l_holdingbranch,
            GROUP_CONCAT(DISTINCT items.itype          ORDER BY items.itemnumber SEPARATOR '|')          l_itype,
            GROUP_CONCAT(DISTINCT items.location       ORDER BY items.itemnumber SEPARATOR '|')          l_location,
            GROUP_CONCAT(DISTINCT items.sub_location   ORDER BY items.itemnumber SEPARATOR '|')          l_sub_location,
            GROUP_CONCAT(DISTINCT items.ccode          ORDER BY items.itemnumber SEPARATOR '|')          l_ccode,
            GROUP_CONCAT(DISTINCT items.cn_sort        ORDER BY items.itemnumber SEPARATOR '|')          l_itemcallnumber,
            GROUP_CONCAT(DISTINCT items.enumchron      ORDER BY items.itemnumber SEPARATOR '<br/>')      l_enumchron,
            GROUP_CONCAT(DISTINCT items.copynumber     ORDER BY items.itemnumber SEPARATOR '<br/>')      l_copynumber,
            GROUP_CONCAT(DISTINCT items.itemnotes      ORDER BY items.itemnumber SEPARATOR '|')          l_itemnotes,
            GROUP_CONCAT(DISTINCT items.itemnumber     ORDER BY items.itemnumber SEPARATOR '|')          l_itemnumbers,
            GROUP_CONCAT(DISTINCT biblioitems.itemtype ORDER BY items.itemnumber SEPARATOR '|')          l_mtype,

            biblioitems.collectiontitle,
            biblioitems.collectionvolume,
            biblioitems.editionstatement,
            biblioitems.number,

            biblio.title,
            biblio.author,

            COUNT(DISTINCT items.itemnumber)    AS icount,
            COUNT(DISTINCT reserves.reserve_id) AS rcount,

            borrowers.othernames othernames

    FROM reserves

            LEFT JOIN items           ON items.biblionumber=reserves.biblionumber
            LEFT JOIN biblio          ON reserves.biblionumber=biblio.biblionumber
            LEFT JOIN biblioitems     ON reserves.biblionumber=biblioitems.biblionumber
            LEFT JOIN branchtransfers ON items.itemnumber=branchtransfers.itemnumber
            LEFT JOIN issues          ON items.itemnumber=issues.itemnumber
            LEFT JOIN borrowers       ON reserves.borrowernumber=borrowers.borrowernumber

    WHERE reserves.found IS NULL

            AND reservedate >= ?
            AND reservedate <= ?
            AND (reserves.itemnumber IS NULL OR reserves.itemnumber = items.itemnumber)
            AND items.itemnumber NOT IN (SELECT itemnumber FROM branchtransfers WHERE datearrived IS NULL)
            AND items.itemnumber NOT IN (SELECT itemnumber FROM reserves WHERE found IS NOT NULL)
            AND issues.itemnumber IS NULL
            AND reserves.priority <> 0
            AND reserves.suspend = 0
            AND notforloan = 0 AND damaged = 0 AND itemlost = 0 AND withdrawn = 0
    
    GROUP BY reserves.biblionumber ORDER BY biblio.title
    ";

    # GROUP BY reserves.biblionumber allows only items that are not checked out, else multiples occur when
    #    multiple patrons have a hold on an item


my $sth = $dbh->prepare($strsth);
$sth->execute(@query_params);

while ( my $data = $sth->fetchrow_hashref ) {

    my $record = Koha::Biblios->find($data->{biblionumber});
    $data = check_issuingrules($data);

    # Not every item has collection and sub-location, so set them empty in those cases to prevent
    # warnings on split below. We'll probs want warnings on missing itypes, mtypes, locations and such, so
    # leave them undefined.

    $data->{subtitle} = [ $record->subtitle ] if $record;
    $data->{l_sub_location}='' unless $data->{l_sub_location};
    $data->{l_ccode}='' unless $data->{l_ccode};
    $data->{l_itemnotes}='' unless $data->{l_itemnotes};

    if ($data->{l_itemcallnumber}) {
        push(
            @reservedata, {
                reservedate     => $data->{l_reservedate},
                borrowerinfo    => $data->{othernames},
                title           => $data->{title},
                editionstatement=> $data->{editionstatement},
                number          => $data->{number},
                subtitle        => $data->{subtitle},
                author          => $data->{author},
                collectiontitle => $data->{collectiontitle},
                collectionvolume=> $data->{collectionvolume},
                borrowernumber  => $data->{borrowernumber},
                biblionumber    => $data->{biblionumber},
                holdingbranches => [split('\|', $data->{l_holdingbranch})],
                branch          => $data->{l_branch},
                itemcallnumber  => [split('\|', $data->{l_itemcallnumber})],
                enumchron       => $data->{l_enumchron},
                copyno          => $data->{l_copynumber},
                itemnotes       => [split('\|', $data->{l_itemnotes})],
                count           => $data->{icount},
                rcount          => $data->{rcount},
                itypes          => [split('\|', $data->{l_itype})],
                mtypes          => [split('\|', $data->{l_mtype})],
                pullcount       => $data->{icount} <= $data->{rcount} ? $data->{icount} : $data->{rcount},
                locations       => [split('\|', $data->{l_location})],
                sublocations    => [split('\|', $data->{l_sub_location})],
                ccodes          => [split('\|', $data->{l_ccode})]
            }
        );
    }
}
$sth->finish;

store \@reservedata, "/tmp/kohasuomi-pendingreserves.tmp";

sub check_issuingrules {
    my ($data) = @_;

    my $borrower = Koha::Patrons->find($data->{borrowernumber});
    my @itemnumbers = split('\|', $data->{l_itemnumbers});
    my @itypes;
    my @holdingbranches;
    my $count;

    foreach my $itemnumber (@itemnumbers) {
        my $item = Koha::Items->find( $itemnumber );
        if (!defined($item)) {
            warn "item $itemnumber is not defined";
            next;
        }
        my $issuing_rule = Koha::CirculationRules->get_effective_rule(
            {   categorycode => $borrower->categorycode,
                itemtype     => $item->itype,
                branchcode   => $data->{l_branch},
                ccode        => $item->ccode,
                permanent_location => $item->permanent_location,
                rule_name    => 'holdallowed',
            }
        );
        push @itypes, $item->itype;
        push @holdingbranches, $item->holdingbranch;
        $count++;
    }

    return $data
}
