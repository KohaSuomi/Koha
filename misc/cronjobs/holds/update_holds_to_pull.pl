#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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

use constant PULL_INTERVAL => 2;

use C4::Context;
use Koha::Biblios;
use C4::Debug;
use C4::RotatingCollections;
use Koha::DateUtils;
use DateTime::Duration;
use List::MoreUtils qw(uniq);
use Storable;

use C4::KohaSuomi::Tweaks;

my $starttime=time;
my @reservedata;
my @query_params = ();
my $borrowerinfo;
my $dbh;

foreach (@ARGV) {
    if ( $_ eq '--with-names') {
        $borrowerinfo.="CONCAT (borrowers.firstname, ' ', borrowers.surname, '<br/><br/>') names,\n";
    }
    elsif ( $_ eq '--with-othernames') {
        $borrowerinfo.="CONCAT (borrowers.othernames, '<br/><br/>') othernames,\n";
    }
    elsif ( $_ eq '--with-cardnumbers') {
        $borrowerinfo.="CONCAT (borrowers.cardnumber, '<br/><br/>') cardnumber,\n";
    }
    else {
        die "Unknown command line option.\n";
    }
}

$dbh=C4::KohaSuomi::Tweaks->dbh();

my $borrowersjoin = '';

if ($borrowerinfo) {
    $borrowersjoin="LEFT JOIN borrowers ON reserves.borrowernumber=borrowers.borrowernumber";
} else {
    $borrowerinfo="'*****' names,";
}

my $sqldatewhere;
my $today = dt_from_string;

# changed from delivered range of 10 years-yesterday to 2 days ago-today
# Find two days ago for the default shelf pull start date, unless HoldsToPullStartDate sys pref is set.
my $startdate = $today - DateTime::Duration->new( days => C4::Context->preference('HoldsToPullStartDate') || PULL_INTERVAL );
my $startdate_iso = output_pref({ dt => $startdate, dateformat => 'iso', dateonly => 1 });
push @query_params, $startdate_iso;

#similarly: calculate end date with ConfirmFutureHolds (days)
my $enddate = $today + DateTime::Duration->new( days => C4::Context->preference('ConfirmFutureHolds') || 0 );
my $enddate_iso   = output_pref({ dt => $enddate, dateformat => 'iso', dateonly => 1 });
push @query_params, $enddate_iso;

my $strsth =
    "SELECT min(reservedate) AS l_reservedate,
            reserves.borrowernumber AS borrowernumber,
            GROUP_CONCAT(DISTINCT items.holdingbranch
                    ORDER BY items.itemnumber SEPARATOR '|') l_holdingbranch,
            reserves.biblionumber,
            reserves.branchcode AS l_branch,
            GROUP_CONCAT(DISTINCT biblioitems.itemtype
                    ORDER BY items.itemnumber SEPARATOR '|') l_mtype,
            GROUP_CONCAT(DISTINCT items.itype
                    ORDER BY items.itemnumber SEPARATOR '|') l_itype,
            GROUP_CONCAT(DISTINCT items.location
                    ORDER BY items.itemnumber SEPARATOR '|') l_location,
            GROUP_CONCAT(DISTINCT items.cn_sort
                    ORDER BY items.itemnumber SEPARATOR '<br/>') l_itemcallnumber,
            GROUP_CONCAT(DISTINCT items.enumchron
                    ORDER BY items.itemnumber SEPARATOR '<br/>') l_enumchron,
            GROUP_CONCAT(DISTINCT items.copynumber
                    ORDER BY items.itemnumber SEPARATOR '<br/>') l_copynumber,
            GROUP_CONCAT(DISTINCT items.itemnotes
                    ORDER BY items.itemnumber SEPARATOR '<br/><br/>') l_itemnotes,
            biblio.title,
            biblio.author,
            biblioitems.collectiontitle,
            biblioitems.collectionvolume,
            biblioitems.editionstatement,
            biblioitems.number,
            COUNT(DISTINCT items.itemnumber) AS icount,
            COUNT(DISTINCT reserves.reserve_id) AS rcount,
            $borrowerinfo
            GROUP_CONCAT(DISTINCT items.itemnumber
                    ORDER BY items.itemnumber SEPARATOR '|') l_itemnumbers
    FROM reserves
        LEFT JOIN items ON items.biblionumber=reserves.biblionumber
        LEFT JOIN biblio ON reserves.biblionumber=biblio.biblionumber
        LEFT JOIN biblioitems ON reserves.biblionumber=biblioitems.biblionumber
        LEFT JOIN branchtransfers ON items.itemnumber=branchtransfers.itemnumber
        LEFT JOIN issues ON items.itemnumber=issues.itemnumber
        $borrowersjoin
    WHERE
    reserves.found IS NULL
    AND reservedate >= ?
    AND reservedate <= ?
    AND (reserves.itemnumber IS NULL OR reserves.itemnumber = items.itemnumber)
    AND items.itemnumber NOT IN (SELECT itemnumber FROM branchtransfers WHERE datearrived IS NULL)
    AND items.itemnumber NOT IN (SELECT itemnumber FROM reserves WHERE found IS NOT NULL)
    AND issues.itemnumber IS NULL
    AND reserves.priority <> 0
    AND reserves.suspend = 0
    AND notforloan = 0 AND damaged = 0 AND itemlost = 0 AND withdrawn = 0
    ";
    # GROUP BY reserves.biblionumber allows only items that are not checked out, else multiples occur when
    #    multiple patrons have a hold on an item

$strsth .= " GROUP BY reserves.biblionumber ORDER BY biblio.title ";

my $sth = $dbh->prepare($strsth);
$sth->execute(@query_params);

my $borrowerlink;

while ( my $data = $sth->fetchrow_hashref ) {

    $borrowerlink=$data->{names};
    $borrowerlink.=$data->{othernames} if $data->{othernames};
    $borrowerlink.=$data->{cardnumber} if ($data->{cardnumber});

    my $record = Koha::Biblios->find($data->{biblionumber});
    if ($record){
        $data->{subtitle} = [ $record->subtitles ];
    }
    $data = check_issuingrules($data);
    if ($data->{l_itemcallnumber}) {
        push(
            @reservedata, {
                reservedate     => $data->{l_reservedate},
                borrowerinfo    => $borrowerlink,
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
                itemcallnumber  => $data->{l_itemcallnumber},
                enumchron       => $data->{l_enumchron},
                copyno          => $data->{l_copynumber},
                itemnotes       => $data->{l_itemnotes},
                count           => $data->{icount},
                rcount          => $data->{rcount},
                itypes          => [split('\|', $data->{l_itype})],
                mtypes          => [split('\|', $data->{l_mtype})],
                pullcount       => $data->{icount} <= $data->{rcount} ? $data->{icount} : $data->{rcount},
                locations       => [split('\|', $data->{l_location})],
                sublocations    => [split('\|', $data->{l_sublocation})],
                ccodes          => [split('\|', $data->{l_ccode})],
                genres          => [split('\|', $data->{l_genre})],
            }
        );
    }
}
$sth->finish;

store \@reservedata, "/tmp/HoldsToPull";
utime (time, $starttime, "/tmp/HoldsToPull");

sub check_issuingrules {
    my ($data) = @_;

    my $borrower = Koha::Patrons->find($data->{borrowernumber});
    my @itemnumbers = split('\|', $data->{l_itemnumbers});
    my @itemcallnumbers;
    my @locations;
    my @sublocations;
    my @ccodes;
    my @genres;
    my @itypes;
    my @holdingbranches;
    my $count;
    my $rotColUrl = "/cgi-bin/koha/rotating_collections/addItems.pl?colId=";
    foreach my $itemnumber (@itemnumbers) {
        my $item = Koha::Items->find( $itemnumber );
        if (!defined($item)) {
            warn "item $itemnumber is not defined";
            next;
        }
        my $issuing_rule = Koha::IssuingRules->get_effective_issuing_rule(
            {   categorycode => $borrower->categorycode,
                itemtype     => $item->itype,
                branchcode   => $data->{l_branch},
                ccode        => $item->ccode,
                permanent_location => $item->permanent_location,
                sub_location => $item->sub_location,
                genre        => $item->genre,
                circulation_level => $item->circulation_level,
                reserve_level => $item->reserve_level,
            }
        );
        if (!defined($issuing_rule)) {
            warn "No issuing rule for itemnumber ".join(', ', $itemnumber, $borrower->categorycode||'', $data->{l_branch}||'');
            next;
        } elsif ($issuing_rule->reservesallowed && $issuing_rule->reservesallowed != 0) {
            my $colid = GetItemsCollection($itemnumber);
            my $cnsort = $item->cn_sort ? $item->cn_sort : ' ';
            if ($colid) {
                push @itemcallnumbers, $cnsort." <a href=".$rotColUrl.$colid.">Col. ".$colid."</a>";
            } else {
                push @itemcallnumbers, $cnsort;
            }
            if ($item->ccode) {
                push @ccodes, $item->ccode;
            }
            if ($item->sub_location) {
                push @sublocations, $item->sub_location;
            }
            if ($item->genre) {
                push @genres, $item->genre;
            }
            if ($item->location) {
                push @locations, $item->location;
            }
            push @itypes, $item->itype;
            push @holdingbranches, $item->holdingbranch;
            $count++;
        }

    }
    $data->{l_itemcallnumber} = join('<br/>', uniq(sort(@itemcallnumbers)));
    $data->{l_location} = join('|', uniq(sort(@locations)));
    $data->{l_sublocation} = join('|', uniq(sort(@sublocations)));
    $data->{l_ccode} = join('|', uniq(sort(@ccodes)));
    $data->{l_genre} = join('|', uniq(sort(@genres)));
    $data->{l_itype} = join('|', uniq(@itypes));
    $data->{l_holdingbranch} = join('|', uniq(sort(@holdingbranches)));
    $data->{icount} = $count;
    return $data

}
