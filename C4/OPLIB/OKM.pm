package C4::OPLIB::OKM;

# Copyright KohaSuomi
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
#use open qw( :std :encoding(UTF-8) );
#binmode( STDOUT, ":encoding(UTF-8)" );
use Carp;

use Data::Dumper;
use URI::Escape;
use File::Temp;
use File::Basename qw( dirname );
use YAML::XS;

use DateTime;

use C4::Items;
use C4::OPLIB::OKMLibraryGroup;
use C4::OPLIB::OKMLogs;
use C4::Context;
use C4::Templates qw(gettemplate);

use Koha::BiblioDataElements;
use Koha::ItemTypes;
use Koha::AuthorisedValues;

use Koha::Exception::BadSystemPreference;
use Koha::Exception::FeatureUnavailable;

=head new

    my $okm = C4::OPLIB::OKM->new($log, $timeperiod, $limit, $individualBranches, $verbose);
    $okm->createStatistics();

@PARAM1 ARRAYRef of Strings, OPTIONAL, all notifications are collected here in addition to being printed to STDOUT.
                OKM creates an internal Array to store log entries, but you can reuse on big log for multiple OKMs by giving it to them explicitly.
@PARAM4 String, a .csv-row with each element as a branchcode
                'JOE_JOE,JOE_RAN,[...]'
                or
                '_A' which means ALL BRANCHES. Then the function fetches all the branchcodes from DB.

=cut

use Koha::Libraries;
use Koha::LibraryCategories;

sub new {
    my ($class, $log, $timeperiod, $limit, $individualBranches, $verbose) = @_;

    my $self = {};
    bless($self, $class);

    $self->{verbose} = $verbose if $verbose;
    $self->{logs} = $log || [];
    $self->loadConfiguration();

    if ($self->isExecutionBlocked()) {
        Koha::Exception::FeatureUnavailable->throw(error => __PACKAGE__.":> Execution prevented by the System preference 'OKM's 'blockStatisticsGeneration'-flag.");
    }

    my $libraryGroups;
    if ($individualBranches) {
        $libraryGroups = $self->setLibraryGroups(  $self->createLibraryGroupsFromIndividualBranches($individualBranches)  );
        $self->{individualBranches} = $individualBranches;
    }
    else {
        $libraryGroups = $self->setLibraryGroups(  $self->getOKMBranchCategoriesAndBranches()  );
    }

    my ($startDate, $endDate) = StandardizeTimeperiodParameter($timeperiod);
    $self->{startDate} = $startDate;
    $self->{startDateISO} = $startDate->iso8601();
    $self->{endDate} = $endDate;
    $self->{endDateISO} = $endDate->iso8601();
    $self->{limit} = $limit; #Set the SQL LIMIT. Used in testing to generate statistics faster.

    return $self;
}

sub createStatistics {
    my ($self) = @_;

    my $libraryGroups = $self->getLibraryGroups();
    my $patronCategories = $self->{conf}->{patronCategories};
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        print '    #'.DateTime->now()->iso8601()."# Starting $groupcode #\n" if $self->{verbose};

        $self->statisticsBranchCounts( $libraryGroup, 1); #We have one main library here.

        #Calculate collections and acquisitions
        my $itemBomb = $self->fetchItemsDataMountain($libraryGroup);
        foreach my $itemnumber (sort {$a <=> $b} keys %$itemBomb) {
            $self->_processItemsDataRow( $libraryGroup, $itemBomb->{$itemnumber} );
        }
        #calculate issues
        my $issuesBomb = $self->fetchIssuesDataMountain($libraryGroup, $patronCategories);
        foreach my $itemnumber (sort {$a <=> $b} keys %$issuesBomb) {
            $self->_processIssuesDataRow( $libraryGroup, $issuesBomb->{$itemnumber} );
        }

        $self->statisticsSubscriptions( $libraryGroup );
        $self->statisticsDiscards( $libraryGroup );
        $self->statisticsActiveBorrowers( $libraryGroup );

        $self->tidyStatistics( $libraryGroup );
    }
}

=head _processItemsDataRow

    _processItemsDataRow( $row );

@DUPLICATES _processIssuesDataRow(), almost completely.
            But it was decided to duplicate the statistical category if-else-forest instead of adding another
            layer of complexity to the 'collections, acquisitions, issues'-counter, because this module is complex enough as it is.

=cut

sub _processItemsDataRow {
    my ($self, $libraryGroup, $row) = @_;
    my $statCat = $self->getItypeToOKMCategory($row->{itype});
    return undef if (!defined $statCat || $statCat eq 'Electronic');
    unless ($statCat) {
        $self->log("Couldn't get the statistical category for this item:<br/> - biblionumber => ".$row->{biblionumber}."<br/> - itemnumber => ".$row->{itemnumber}."<br/> - itype => ".$row->{itype}."<br/>Using category 'Other'.");
        $statCat = 'Other';
    }

    my $stats = $libraryGroup->getStatistics();

    my $deleted = $row->{deleted}; #These inlcude also Issues for Items outside of this libraryGroup.
    my $primaryLanguage = $row->{primary_language};
    my $isChildrensMaterial = $self->isItemChildrens($row);
    my $isFiction = $row->{fiction};
    my $isMusicalRecording = $row->{musical};
    my $isAcquired = (not($deleted)) ? $self->isItemAcquired($row) : undef; #If an Item is deleted, omit the acquisitions calculations because they wouldn't be accurate. Default to not acquired.
    my $itemtype = $row->{itemtype};
    my $issues = $row->{issuesQuery}->{issues} || 0;
    my $serial = ($statCat eq "Serials") ? 1 : 0; #Is the item type considered to be a serial or a magazine?

    #Increase the collection for every Item found
    $stats->{collection}++ if not($deleted) && not($serial);
    $stats->{acquisitions}++ if $isAcquired && not($serial);
    $stats->{expenditureAcquisitions} += $row->{price} if $isAcquired && not($serial) && $row->{price};

    if ($statCat eq "Books") {

        $stats->{'collection'.$statCat.'Total'}++ if not($deleted);
        $stats->{'acquisitions'.$statCat.'Total'}++ if $isAcquired;
        $stats->{'expenditureAcquisitions'.$statCat} += $row->{price} if $isAcquired && $row->{price};

        if (not(defined($primaryLanguage)) || $primaryLanguage eq 'fin') {
            $stats->{'collection'.$statCat.'Finnish'}++ if not($deleted);
            $stats->{'acquisitions'.$statCat.'Finnish'}++ if $isAcquired;
        }
        elsif ($primaryLanguage eq 'swe') {
            $stats->{'collection'.$statCat.'Swedish'}++ if not($deleted);
            $stats->{'acquisitions'.$statCat.'Swedish'}++ if $isAcquired;
        }
        else {
            $stats->{'collection'.$statCat.'OtherLanguage'}++ if not($deleted);
            $stats->{'acquisitions'.$statCat.'OtherLanguage'}++ if $isAcquired;
        }

        if ($isFiction) {
            if ($isChildrensMaterial) {
                $stats->{'collection'.$statCat.'FictionJuvenile'}++ if not($deleted);
                $stats->{'acquisitions'.$statCat.'FictionJuvenile'}++ if $isAcquired;
            }
            else { #Adults fiction
                $stats->{'collection'.$statCat.'FictionAdult'}++ if not($deleted);
                $stats->{'acquisitions'.$statCat.'FictionAdult'}++ if $isAcquired;
            }
        }
        else { #Non-Fiction
            if ($isChildrensMaterial) {
                $stats->{'collection'.$statCat.'NonFictionJuvenile'}++ if not($deleted);
                $stats->{'acquisitions'.$statCat.'NonFictionJuvenile'}++ if $isAcquired;
            }
            else { #Adults Non-fiction
                $stats->{'collection'.$statCat.'NonFictionAdult'}++ if not($deleted);
                $stats->{'acquisitions'.$statCat.'NonFictionAdult'}++ if $isAcquired;
            }
        }
    }
    elsif ($statCat eq 'Recordings') {
        if ($isMusicalRecording) {
            $stats->{'collectionMusicalRecordings'}++ if not($deleted);
            $stats->{'acquisitionsMusicalRecordings'}++ if $isAcquired;
        }
        else {
            $stats->{'collectionOtherRecordings'}++ if not($deleted);
            $stats->{'acquisitionsOtherRecordings'}++ if $isAcquired;
        }
    }
    elsif ($serial || $statCat eq 'Other') {
        $stats->{'collectionOther'}++ if not($deleted) && not($serial);
        $stats->{'acquisitionsOther'}++ if $isAcquired && not($serial);
        #Serials and magazines are collected from the subscriptions-table using statisticsSubscriptions()
        #Don't count them for the collection or acquisitions. Serials must be included in the cumulative Issues.
    }
    else {
        $stats->{'collection'.$statCat}++ if not($deleted);
        $stats->{'acquisitions'.$statCat}++ if $isAcquired;
    }
}

=head _processIssuesDataRow

    _processIssuesDataRow( $row );

@DUPLICATES _processItemsDataRow(), almost completely.
            But it was decided to duplicate the statistical category if-else-forest instead of adding another
            layer of complexity to the 'collections, acquisitions, issues'-counter, because this module is complex enough as it is.

=cut

sub _processIssuesDataRow {
    my ($self, $libraryGroup, $row) = @_;
    my $statCat = $self->getItypeToOKMCategory($row->{itype});
    return undef if $statCat eq 'Electronic';
    unless ($statCat) {
        #Already logged in _processItemsDataRow()# $self->log("Couldn't get the statistical category for this item:<br/> - biblionumber => ".$row->{biblionumber}."<br/> - itemnumber => ".$row->{itemnumber}."<br/> - itype => ".$row->{itype}."<br/>Using category 'Other'.");
        $statCat = 'Other';
    }

    my $stats = $libraryGroup->getStatistics();

    my $deleted = $row->{deleted}; #These inlcude also Issues for Items outside of this libraryGroup.
    my $primaryLanguage = $row->{primary_language};
    my $isChildrensMaterial = $self->isItemChildrens($row);
    my $isFiction = $row->{fiction};
    my $isMusicalRecording = $row->{musical};
    my $itemtype = $row->{itype};
    my $issues = $row->{issues} || 0;
    my $serial = ($statCat eq "Serials") ? 1 : 0; #Is the item type considered to be a serial or a magazine?

    #Increase the issues for every Issue found
    $stats->{issues} += $issues; #Serials are included in the cumulative issues.
    if ($statCat eq "Books") {
        $stats->{'issues'.$statCat.'Total'} += $issues;

        if (not(defined($primaryLanguage)) || $primaryLanguage eq 'fin') {
            $stats->{'issues'.$statCat.'Finnish'} += $issues;
        }
        elsif ($primaryLanguage eq 'swe') {
            $stats->{'issues'.$statCat.'Swedish'} += $issues;
        }
        else {
            $stats->{'issues'.$statCat.'OtherLanguage'} += $issues;
        }

        if ($isFiction) {
            if ($isChildrensMaterial) {
                $stats->{'issues'.$statCat.'FictionJuvenile'} += $issues;
            }
            else { #Adults fiction
                $stats->{'issues'.$statCat.'FictionAdult'} += $issues;
            }
        }
        else { #Non-Fiction
            if ($isChildrensMaterial) {
                $stats->{'issues'.$statCat.'NonFictionJuvenile'} += $issues;
            }
            else { #Adults Non-fiction
                $stats->{'issues'.$statCat.'NonFictionAdult'} += $issues;
            }
        }
    }
    elsif ($statCat eq 'Recordings') {
        if ($isMusicalRecording) {
            $stats->{'issuesMusicalRecordings'} += $issues;
        }
        else {
            $stats->{'issuesOtherRecordings'} += $issues;
        }
    }
    elsif ($serial || $statCat eq 'Other') {
        $stats->{'issuesOther'} += $issues;
        #Serials and magazines are collected from the subscriptions-table using statisticsSubscriptions()
        #Don't count them for the collection or acquisitions. Serials must be included in the cumulative Issues.
    }
    else {
        $stats->{'issues'.$statCat} += $issues;
    }
}

=head fetchItemsDataMountain

    my $itemBomb = $okm->fetchItemsDataMountain();

Queries the DB for the required data elements and returns a Hash $itemBomb.
Collects the related acquisitions and collections data for the given timeperiod.

=cut

sub fetchItemsDataMountain {
    my ($self, $libraryGroup) = @_;

    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();

    my $dbh = C4::Context->dbh();
    #Get all the Items' informations for Items residing in the libraryGroup.
    my $sth = $dbh->prepare("
        (
        SELECT  i.itemnumber, i.biblionumber, bi.itemtype as itype, i.location, i.price,
                ao.ordernumber, ao.datereceived, i.dateaccessioned,
                bde.primary_language, bde.fiction, bde.musical,
                0 as deleted
            FROM items i
            LEFT JOIN aqorders_items ai ON i.itemnumber = ai.itemnumber
            LEFT JOIN aqorders ao ON ai.ordernumber = ao.ordernumber LEFT JOIN statistics s ON s.itemnumber = i.itemnumber
            LEFT JOIN biblioitems bi ON i.biblionumber = bi.biblioitemnumber
            LEFT JOIN biblio_data_elements bde ON bi.biblioitemnumber = bde.biblioitemnumber
            WHERE i.homebranch $in_libraryGroupBranches
            GROUP BY i.itemnumber $limit
        )
        UNION
        (
        SELECT  di.itemnumber, di.biblionumber, bi.itemtype as itype, di.location, di.price,
                ao.ordernumber, ao.datereceived, di.dateaccessioned,
                bde.primary_language, bde.fiction, bde.musical,
                1 as deleted
            FROM deleteditems di
            LEFT JOIN aqorders_items ai ON di.itemnumber = ai.itemnumber
            LEFT JOIN aqorders ao ON ai.ordernumber = ao.ordernumber LEFT JOIN statistics s ON s.itemnumber = di.itemnumber
            LEFT JOIN biblioitems bi ON di.biblionumber = bi.biblioitemnumber
            LEFT JOIN biblio_data_elements bde ON bi.biblioitemnumber = bde.biblioitemnumber
            WHERE di.homebranch $in_libraryGroupBranches
            GROUP BY di.itemnumber $limit
        )
    ");
    $sth->execute(  ); #This will take some time.....
    if ($sth->err) {
        my @cc = caller(0);
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    my $itemBomb = $sth->fetchall_hashref('itemnumber');

    print '    #'.DateTime->now()->iso8601()."# Leaving ".$cc[3]." #\n" if $self->{verbose};
    return $itemBomb;
}

=head fetchItemsDataMountain

    my $itemBomb = $okm->fetchItemsDataMountain();

Queries the DB for the required data elements and returns a Hash $itemBomb.
Collects the related issuing data for the given timeperiod.

=cut

sub fetchIssuesDataMountain {
    my ($self, $libraryGroup, $patronCategories) = @_;

    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();

    my $dbh = C4::Context->dbh();
    #Get all the Issues informations. We can have issues for other branches Items' which are not included in the $sthItems and $sthDeleteditems -queries.
    #This means that Patrons can check-out Items whose homebranch is not in this libraryGroup, but whom are checked out/renewed from this libraryGroup.
    my $sth = $dbh->prepare("
        (
        SELECT s.itemnumber, i.biblionumber, bi.itemtype as itype, i.location, 0 as deleted, COUNT(s.itemnumber) as issues,
               bde.primary_language, bde.fiction, bde.musical
            FROM statistics s
            LEFT JOIN items i ON s.itemnumber = i.itemnumber
            LEFT JOIN biblioitems bi ON i.biblionumber = bi.biblioitemnumber
            LEFT JOIN biblio_data_elements bde ON bi.biblioitemnumber = bde.biblioitemnumber
            WHERE s.branch $in_libraryGroupBranches
            AND s.type IN ('issue','renew')
            AND s.datetime BETWEEN ? AND ?
            AND s.usercode IN(" . join(",", map {"?"} @{$patronCategories}).")
            AND i.itemnumber IS NOT NULL
            GROUP BY s.itemnumber $limit
        )
        UNION
        (
        SELECT s.itemnumber, di.biblionumber, bi.itemtype as itype, di.location, 1 as deleted, COUNT(s.itemnumber) as issues,
               bde.primary_language, bde.fiction, bde.musical
            FROM statistics s
            LEFT JOIN deleteditems di ON s.itemnumber = di.itemnumber
            LEFT JOIN biblioitems bi ON di.biblionumber = bi.biblioitemnumber
            LEFT JOIN biblio_data_elements bde ON bi.biblioitemnumber = bde.biblioitemnumber
            WHERE s.branch $in_libraryGroupBranches
            AND s.type IN ('issue','renew')
            AND s.datetime BETWEEN ? AND ?
            AND s.usercode IN(" . join(",", map {"?"} @{$patronCategories}).")
            AND di.itemnumber IS NOT NULL
            GROUP BY s.itemnumber $limit
        )");
    $sth->execute(  $self->{startDateISO}, $self->{endDateISO}, @{$patronCategories}, $self->{startDateISO}, $self->{endDateISO}, @{$patronCategories}  ); #This will take some time.....
    if ($sth->err) {
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    my $issuesBomb = $sth->fetchall_hashref('itemnumber');

    print '    #'.DateTime->now()->iso8601()."# Leaving ".$cc[3]." #\n" if $self->{verbose};
    return $issuesBomb;
}

=head getBranchCounts

    getBranchCounts( $branchcode, $mainLibrariesCount );

Fills OKM columns "Pääkirjastoja, Sivukirjastoja, Laitoskirjastoja, Kirjastoautoja"
1. SELECTs all branches we have.
2. Finds bookmobiles by the regexp /AU$/ in the branchcode
3. Finds bookboats by the regexp /VE$/ in the branchcode
4. Institutional libraries by /JOE_(LA)KO/, where LA stand for LaitosKirjasto.
5. Main libraries cannot be differentiated from branch libraries so this is fed as a parameter to the script.
6. Branch libraries are what is left after picking all previously mentioned branch types.
=cut

sub statisticsBranchCounts {
    my ($self, $libraryGroup, $mainLibrariesCount) = (@_);

    my $stats = $libraryGroup->getStatistics();

    foreach my $branchcode (sort keys %{$libraryGroup->{branches}}) {
        #Get them bookmobiles!
        if ($branchcode =~ /^\w\w\w_\w\w\wAU$/) {  #JOE_JOEAU, JOE_LIPAU
            $stats->{bookmobiles}++;
        }
        #Get them bookboats!
        elsif ($branchcode =~ /^\w\w\w_\w\w\wVE$/) {  #JOE_JOEVE, JOE_LIPVE
            $stats->{bookboats}++;
        }
        #Get them institutional libraries!
        elsif ($branchcode =~ /^\w\w\w_LA\w\w$/) {  #JOE_LAKO, JOE_LASI
            $stats->{institutionalLibraries}++;
        }
        #Get them branch libraries!
        else {
            $stats->{branchLibraries}++;
        }
    }
    #After all is counted, we remove the given main branches from branch libraries and set the main libraries count.
    $stats->{branchLibraries} = $stats->{branchLibraries} - $mainLibrariesCount;
    $stats->{mainLibraries} = $mainLibrariesCount;
}

sub statisticsSubscriptions {
    my ($self, $libraryGroup) = (@_);
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};

    my $dbh = C4::Context->dbh();
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();
    my $sth = $dbh->prepare(
               "SELECT COUNT(subscriptionid) AS count,
                       SUM(IF(  metadata REGEXP '  <controlfield tag=\"008\">.....................n..................</controlfield>'  ,1,0)) AS newspapers,
                       SUM(IF(  metadata REGEXP '  <controlfield tag=\"008\">.....................p..................</controlfield>'  ,1,0)) AS magazines
                FROM subscription s LEFT JOIN biblioitems bi ON bi.biblionumber = s.biblionumber
                LEFT JOIN biblio_metadata bi_me ON bi_me.biblionumber = bi.biblionumber
                WHERE branchcode $in_libraryGroupBranches AND
                       NOT (? < startdate AND enddate < ?) $limit");
    #The SQL WHERE-clause up there needs a bit of explaining:
    # Here we find if a subscription intersects with the given timeperiod of our report.
    # Using this algorithm we can define whether two lines are on top of each other in a 1-dimensional space.
    # Think of two lines:
    #   sssssssssssssssssssssss   (subscription duration (s))
    #           tttttttttttttttttttttttttttt   (timeperiod of the report (t))
    # They cannot intersect if t.end < s.start AND s.end < t.start
    $sth->execute( $self->{endDateISO}, $self->{startDateISO} );
    if ($sth->err) {
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    my $retval = $sth->fetchrow_hashref();

    my $stats = $libraryGroup->getStatistics();
    $stats->{newspapers} = $retval->{newspapers} ? $retval->{newspapers} : 0;
    $stats->{magazines} = $retval->{magazines} ? $retval->{magazines} : 0;
    $stats->{count} = $retval->{count} ? $retval->{count} : 0;

    if ($stats->{newspapers} + $stats->{magazines} != $stats->{count}) {
        carp "Calculating subscriptions, total count ".$stats->{count}." is not the same as newspapers ".$stats->{newspapers}." and magazines ".$stats->{magazines}." combined!";
    }
    print '    #'.DateTime->now()->iso8601()."# Leaving ".$cc[3]." #\n" if $self->{verbose};
}
sub statisticsDiscards {
    my ($self, $libraryGroup) = (@_);
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};

    #Do not statistize these itemtypes as item discard:
    my $excludedItemTypes = $self->getItemtypesByStatisticalCategories('Serials', 'Electronic');
    my $dbh = C4::Context->dbh();
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();
    my $sql =  "SELECT count(*) FROM biblio_data_elements bde LEFT JOIN deleteditems ON bde.biblioitemnumber = deleteditems.biblioitemnumber ".
               "WHERE homebranch $in_libraryGroupBranches ".
               "  AND timestamp >= ? AND timestamp <= ? ".
               "  AND itemtype NOT IN (".join(',', map {"'$_'"} @$excludedItemTypes).") ".
#                 AND itype != 'SL' AND itype != 'AL'
               "  $limit; ";

    my $sth = $dbh->prepare($sql);

    $sth->execute( $self->{startDateISO}, $self->{endDateISO} );
    if ($sth->err) {
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    my $discards = $sth->fetchrow;

    my $stats = $libraryGroup->getStatistics();
    $stats->{discards} = $discards;
    print '    #'.DateTime->now()->iso8601()."# Leaving ".$cc[3]." #\n" if $self->{verbose};
}
sub statisticsActiveBorrowers {
    my ($self, $libraryGroup) = (@_);
    #_statisticsOurBorrowersWhoHaveCirculatedInAnyBranch($self, $libraryGroup);
    _statisticsBorrowersWhoCirculatedInOurBranches($self, $libraryGroup);
}
sub _statisticsOurActiveBorrowersWhoHaveCirculatedInAnyBranch {
    my ($self, $libraryGroup) = (@_);
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};

    my $dbh = C4::Context->dbh();
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();
    my $sth = $dbh->prepare(
                "SELECT COUNT(stat.borrowernumber) FROM borrowers b
                 LEFT JOIN (
                    SELECT borrowernumber
                    FROM statistics s WHERE s.type IN ('issue','renew') AND datetime >= ? AND datetime <= ?
                    GROUP BY s.borrowernumber
                 )
                 AS stat ON stat.borrowernumber = b.borrowernumber
                 WHERE b.branchcode $in_libraryGroupBranches $limit");
    $sth->execute( $self->{startDateISO}, $self->{endDateISO} );
    if ($sth->err) {
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    my $activeBorrowers = $sth->fetchrow;

    my $stats = $libraryGroup->getStatistics();
    $stats->{activeBorrowers} = $activeBorrowers;
    print '    #'.DateTime->now()->iso8601()."# Leaving ".$cc[3]." #\n" if $self->{verbose};
}
sub _statisticsBorrowersWhoCirculatedInOurBranches {
    my ($self, $libraryGroup) = (@_);
    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};

    my $dbh = C4::Context->dbh();
    my $in_libraryGroupBranches = $libraryGroup->getBranchcodesINClause();
    my $limit = $self->getLimit();
    my $sth = $dbh->prepare("
        SELECT COUNT(DISTINCT(borrowernumber))
        FROM statistics s
        WHERE s.type IN ('issue','renew') AND
              s.datetime BETWEEN ? AND ? AND
              s.branch $in_libraryGroupBranches $limit
    ");
    $sth->execute( $self->{startDateISO}, $self->{endDateISO} );
    if ($sth->err) {
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    my $activeBorrowers = $sth->fetchrow;

    my $stats = $libraryGroup->getStatistics();
    $stats->{activeBorrowers} = $activeBorrowers;
    print '    #'.DateTime->now()->iso8601()."# Leaving ".$cc[3]." #\n" if $self->{verbose};
}
sub tidyStatistics {
    my ($self, $libraryGroup) = (@_);
    my $stats = $libraryGroup->getStatistics();
    $stats->{expenditureAcquisitionsBooks} = sprintf("%.2f", $stats->{expenditureAcquisitionsBooks});
    $stats->{expenditureAcquisitions}      = sprintf("%.2f", $stats->{expenditureAcquisitions});
}

sub getLibraryGroups {
    my $self = shift;

    return $self->{lib_groups};
}

=head setLibraryGroups

    setLibraryGroups( $libraryGroups );

=cut

sub setLibraryGroups {
    my ($self, $libraryGroups) = @_;

    croak '$libraryGroups parameter is not a HASH of groups of branchcodes!' unless (ref $libraryGroups eq 'HASH');
    $self->{lib_groups} = $libraryGroups;

    foreach my $groupname (sort keys %$libraryGroups) {
        $libraryGroups->{$groupname} = C4::OPLIB::OKMLibraryGroup->new(  $groupname, $libraryGroups->{$groupname}->{branches}  );
    }
    return $self->{lib_groups};
}

=head createLibraryGroupsFromIndividualBranches

    $okm->createLibraryGroupsFromIndividualBranches($individualBranches);

@PARAM1 String, a .csv-row with each element as a branchcode
                'JOE_JOE,JOE_RAN,[...]'
                or
                '_A' which means ALL BRANCHES. Then the function fetches all the branchcodes from DB.
@RETURNS a HASH of library monstrosity
=cut

sub createLibraryGroupsFromIndividualBranches {
    my ($self, $individualBranches) = @_;
    my @iBranchcodes;

    if ($individualBranches eq '_A') {
        my @branchcodes = Koha::Libraries->search();
        foreach my $branchcode (@branchcodes){
            push @iBranchcodes, $branchcode->branchcode;
        }
    }
    else {
        @iBranchcodes = split(',',$individualBranches);
        for(my $i=0 ; $i<@iBranchcodes ; $i++) {
            my $bc = $iBranchcodes[$i];
            $bc =~ s/\s//g; #Trim all whitespace
            $iBranchcodes[$i] = $bc;
        }
    }

    my $libraryGroups = {};
    foreach my $branchcode (@iBranchcodes) {
        $libraryGroups->{$branchcode}->{branches} = {$branchcode => 1};
    }
    return $libraryGroups;
}

=head asHtml

    my $html = $okm->asHtml();

Returns an HTML table header and rows for each library group with statistical categories as columns.
=cut

sub asHtml {
    my $self = shift;
    my $libraryGroups = $self->getLibraryGroups();

    my @sb;

    push @sb, '<table>';
    my $firstrun = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        push @sb, $stat->asHtmlHeader() if $firstrun-- > 0;

        push @sb, $stat->asHtml();
    }
    push @sb, '</table>';

    return join("\n", @sb);
}

=head asCsv

    my $csv = $okm->asCsv();

Returns a csv header and rows for each library group with statistical categories as columns.

@PARAM1 Char, The separator to use to separate columns. Defaults to ','
=cut

sub asCsv {
    my ($self, $separator) = @_;
    my @sb;
    my $a;
    $separator = ',' unless $separator;

    my $libraryGroups = $self->getLibraryGroups();

    my $firstrun = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        push @sb, $stat->asCsvHeader($separator) if $firstrun-- > 0;

        push @sb, $stat->asCsv($separator);
    }

    return join("\n", @sb);
}

=head asOds

=cut

sub asOds {
    my $self = shift;

    my $ods_fh = File::Temp->new( UNLINK => 0 );
    my $ods_filepath = $ods_fh->filename;

    use OpenOffice::OODoc;
    my $tmpdir = dirname $ods_filepath;
    odfWorkingDirectory( $tmpdir );
    my $container = odfContainer( $ods_filepath, create => 'spreadsheet' );
    my $doc = odfDocument (
        container => $container,
        part      => 'content'
    );
    my $table = $doc->getTable(0);
    my $libraryGroups = $self->getLibraryGroups();

    my $firstrun = 1;
    my $row_i = 1;
    foreach my $groupcode (sort keys %$libraryGroups) {
        my $libraryGroup = $libraryGroups->{$groupcode};
        my $stat = $libraryGroup->getStatistics();

        my $headers = $stat->getPrintOrder() if $firstrun > 0;
        my $columns = $stat->getPrintOrderElements();

        if ($firstrun-- > 0) { #Set the table size and print the header!
            $doc->expandTable( $table, scalar(keys(%$libraryGroups))+1, scalar(@$headers) );
            my $row = $doc->getRow( $table, 0 );
            for (my $j=0 ; $j<@$headers ; $j++) {
                $doc->cellValue( $row, $j, $headers->[$j] );
            }
        }

        my $row = $doc->getRow( $table, $row_i++ );
        for (my $j=0 ; $j<@$columns ; $j++) {
            my $value = Encode::encode( 'UTF8', $columns->[$j] );
            $doc->cellValue( $row, $j, $value );
        }
    }

    $doc->save();
    binmode(STDOUT);
    open $ods_fh, '<', $ods_filepath;
    my @content = <$ods_fh>;
    unlink $ods_filepath;
    return join('', @content);
}

=head getOKMBranchCategories

    C4::OPLIB::OKM::getOKMBranchCategories();
    $okm->getOKMBranchCategories();

Searches Koha for branchcategories ending to letters "_OKM".
These branchcategories map to a OKM annual statistics row.

@RETURNS a hash of branchcategories.categorycode = 1
=cut

sub getOKMBranchCategories {
    my $self = shift;
    my $libraryGroups = {};

    my @library_categories = Koha::LibraryCategories->search();

    foreach my $library_category (@library_categories){
        my $code = $library_category->categorycode;
        if ( $code =~ /_OKM$/ ) { #Catch branchcategories which are OKM statistical groups.
            #HASHify the categorycodes for easy access
            $libraryGroups->{$code} = $library_category;
        }       
    }
    return $libraryGroups;
}

=head getOKMBranchCategoriesAndBranches

    C4::OPLIB::OKM::getOKMBranchCategoriesAndBranches();
    $okm->getOKMBranchCategoriesAndBranches();

Calls getOKMBranchCategories() to find the branchCategories and then finds which branchcodes are mapped to those categories.

@RETURNS a hash of branchcategories.categorycode -> branches.branchcode = 1
=cut

sub getOKMBranchCategoriesAndBranches {
    my $self = shift;
    my $libraryGroups = $self->getOKMBranchCategories();
    
    foreach my $categoryCode (keys %{$libraryGroups}) {
        my @branchcodes = Koha::LibraryCategories->find($categoryCode)->libraries;
        if (not(@branchcodes) || scalar(@branchcodes) <= 0) {
            $self->log("Statistical library group $categoryCode has no libraries, removing it from OKM statistics");
            delete $libraryGroups->{$categoryCode};
            next();
        }

        #HASHify the branchcodes for easy access
        $libraryGroups->{$categoryCode} = {}; #CategoryCode used to be 1, which makes for a poor HASH reference.
        $libraryGroups->{$categoryCode}->{branches} = {};
        my $branches = $libraryGroups->{$categoryCode}->{branches};
        foreach my $branchcode (@branchcodes){
            grep { $branches->{$_} = 1 } $branchcode->branchcode;
        }
    }
    return $libraryGroups;
}

=head FindMarcField

Static method

    my $subfieldContent = FindMarcField('041', 'a', $marcxml);

Finds a single subfield effectively.
=cut

sub FindMarcField {
    my ($tagid, $subfieldid, $marcxml) = @_;
    if ($marcxml =~ /<(data|control)field tag="$tagid".*?>(.*?)<\/(data|control)field>/s) {
        my $fieldStr = $2;
        if ($fieldStr =~ /<subfield code="$subfieldid">(.*?)<\/subfield>/s) {
            return $1;
        }
    }
}

=head isItemChildrens

    $row->{location} = 'LAP';
    my $isChildrens = $okm->isItemChildrens($row);
    assert($isChildrens == 1);

@PARAM1 hash, containing the koha.items.location as location-key
=cut

sub isItemChildrens {
    my ($self, $row) = @_;
    my $juvenileShelvingLocations = $self->{conf}->{juvenileShelvingLocations};

    return 1 if $row->{location} && $juvenileShelvingLocations->{$row->{location}};
    return 0;
}

sub IsItemFiction {
    my ($marcxml) = @_;

    my $sf = FindMarcField('084','a', $marcxml);
    if ($sf =~/^8[0-5].*/) { #ykl numbers 80.* to 85.* are fiction.
        return 1;
    }
    return 0;
}

sub IsItemMusicalRecording {
    my ($marcxml) = @_;

    my $sf = FindMarcField('084','a', $marcxml);
    if ($sf =~/^78.*/) { #ykl number 78 is a musical recording.
        return 1;
    }
    return 0;
}

sub isItemAcquired {
    my ($self, $row) = @_;

    my $startEpoch = $self->{startDate}->epoch();
    my $endEpoch = $self->{endDate}->epoch();
    my $receivedEpoch    = 0;
    my $accessionedEpoch = 0;
    if ($row->{datereceived} && $row->{datereceived} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) { #Parse ISO date
        eval { $receivedEpoch = DateTime->new(year => $1, month => $2, day => $3, time_zone => C4::Context->tz())->epoch(); };
        if ($@) { #Sometimes the DB has datetimes 0000-00-00 which is not nice for DateTime.
            $receivedEpoch = 0;
        }

    }
    if ($row->{dateaccessioned} && $row->{dateaccessioned} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) { #Parse ISO date
        eval { $accessionedEpoch = DateTime->new(year => $1, month => $2, day => $3, time_zone => C4::Context->tz())->epoch(); };
        if ($@) { #Sometimes the DB has datetimes 0000-00-00 which is not nice for DateTime.
            $accessionedEpoch = 0;
        }
    }

    #This item has been received from the vendor.
    if ($receivedEpoch) {
        return 1 if $startEpoch <= $receivedEpoch && $endEpoch >= $receivedEpoch;
        return 0; #But this item is not received during the requested timeperiod :(
    }
    #This item has been added to Koha via acquisitions, but the order hasn't been received during the requested timeperiod
    elsif ($row->{ordernumber}) {
        return 0;
    }
    #This item has been added to Koha outside of the acquisitions module
    elsif ($startEpoch <= $accessionedEpoch && $endEpoch >= $accessionedEpoch) {
        return 1; #And this item is added during the requested timeperiod
    }
    else {
        return 0;
    }
}

=head getLimit

    my $limit = $self->getLimit();

Gets the SQL LIMIT clause used in testing this feature faster (but not more accurately). It can be passed to the OKM->new() constructor.
=cut

sub getLimit {
    my $self = shift;
    my $limit = '';
    $limit = 'LIMIT '.$self->{limit} if $self->{limit};
    return $limit;
}

=head save

    $okm->save();

Serializes this object and saves it to the koha.okm_statistics-table

@RETURNS the DBI->error() -text.

=cut

sub save {
    my $self = shift;

    my @cc = caller(0);
    print '    #'.DateTime->now()->iso8601()."# Starting ".$cc[3]." #\n" if $self->{verbose};

    C4::OPLIB::OKMLogs::insertLogs($self->flushLogs());
    #Clean some cumbersome Entities which make serialization quite messy.
    $self->{endDate} = undef; #Like DateTime-objects which serialize quite badly.
    $self->{startDate} = undef;

    $Data::Dumper::Indent = 0;
    $Data::Dumper::Purity = 1;
    my $serialized_self = Data::Dumper::Dumper( $self );

    #See if this yearly OKM is already serialized
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT id FROM okm_statistics WHERE startdate = ? AND enddate = ? AND individualbranches = ?');
    $sth->execute( $self->{startDateISO}, $self->{endDateISO}, $self->{individualBranches} );
    if ($sth->err) {
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    if (my $id = $sth->fetchrow()) { #Exists in DB
        $sth = $dbh->prepare('UPDATE okm_statistics SET okm_serialized = ? WHERE id = ?');
        $sth->execute( $serialized_self, $id );
    }
    else {
        $sth = $dbh->prepare('INSERT INTO okm_statistics (startdate, enddate, individualbranches, okm_serialized) VALUES (?,?,?,?)');
        $sth->execute( $self->{startDateISO}, $self->{endDateISO}, $self->{individualBranches}, $serialized_self );
    }
    if ($sth->err) {
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    return undef;
}

=head Retrieve

    my $okm = C4::OPLIB::OKM::Retrieve( $okm_statisticsId, $startDateISO, $endDateISO, $individualBranches );

Gets an OKM-object from the koha.okm_statistics-table.
Either finds the OKM-object by the id-column, or by checking the startdate, enddate and individualbranches.
The latter is used when calculating new statistics, and firstly precalculated values are looked for. If a report
matching the given values is found, then we don't need to rerun it.

Generally you should just pass the parameters given to the OKM-object during initialization here to see if a OKM-report already exists.

@PARAM1 long, okm_statistics.id
@PARAM2 ISO8601 datetime, the start of the statistical reporting period.
@PARAM3 ISO8601 datetime, the end of the statistical reporting period.
@PARAM4 Comma-separated String, list of branchcodes to run statistics of if using the librarygroups is not desired.
=cut
sub Retrieve {
    my ($okm_statisticsId, $timeperiod, $individualBranches) = @_;

    my $okm_serialized;
    if ($okm_statisticsId) {
        $okm_serialized = _RetrieveById($okm_statisticsId);
    }
    else {
        my ($startDate, $endDate) = StandardizeTimeperiodParameter($timeperiod);
        $okm_serialized = _RetrieveByParams($startDate->iso8601(), $endDate->iso8601(), $individualBranches);
    }
    return _deserialize($okm_serialized) if $okm_serialized;
    return undef;
}
sub _RetrieveById {
    my ($id) = @_;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT okm_serialized FROM okm_statistics WHERE id = ?');
    $sth->execute( $id );
    return $sth->fetchrow();
}
sub _RetrieveByParams {
    my ($startDateISO, $endDateISO, $individualBranches) = @_;

    my $dbh = C4::Context->dbh();
    # $individualBranches might be undef. DBI doesn't handle undef values well so check is needed.
    # https://metacpan.org/pod/DBI#SQL-A-Query-Language
    my $individualBranches_clause = defined $individualBranches? "individualbranches = ?" : "individualbranches IS NULL";
    my $sth = $dbh->prepare(qq{SELECT okm_serialized FROM okm_statistics WHERE startdate = ? AND enddate = ? AND $individualBranches_clause});
    $sth->execute( $startDateISO, $endDateISO, defined $individualBranches ? $individualBranches : () );
    return $sth->fetchrow();
}
sub RetrieveAll {
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('SELECT * FROM okm_statistics ORDER BY enddate DESC');
    $sth->execute(  );
    return $sth->fetchall_arrayref({});
}
sub _deserialize {
    my $serialized = shift;
    my $VAR1;
    eval $serialized if $serialized;

    #Rebuild some cumbersome objects
    if ($VAR1) {
        my ($startDate, $endDate) = C4::OPLIB::OKM::StandardizeTimeperiodParameter($VAR1->{startDateISO}.'-'.$VAR1->{endDateISO});
        $VAR1->{startDate} = $startDate;
        $VAR1->{endDate} = $endDate;
        return $VAR1;
    }

    return undef;
}
=head Delete

    C4::OPLIB::OKM::Delete($id);

@PARAM1 Long, The koha.okm_statistics.id of the statistical row to delete.
@RETURNS DBI::Error if database errors, otherwise undef.
=cut
sub Delete {
    my $id = shift;

    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare('DELETE FROM okm_statistics WHERE id = ?');
    $sth->execute( $id );
    if ( $sth->err ) {
        return $sth->err;
    }
    return undef;
}

=head _loadConfiguration

    $self->_loadConfiguration();

Loads the configuration YAML from sysprefs and parses it to a Hash.
=cut

sub loadConfiguration {
    my ($self) = @_;

    my $yaml = C4::Context->preference('OKM');
    utf8::encode( $yaml );
    $self->{conf} = YAML::XS::Load($yaml);

    ##Make 'juvenileShelvingLocations' more searchable
    my $juvShelLocs = $self->{conf}->{juvenileShelvingLocations};
    $self->{conf}->{juvenileShelvingLocations} = {};
    foreach my $loc (@{$juvShelLocs}) {
        $self->{conf}->{juvenileShelvingLocations}->{$loc} = 1;
    }

    $self->_validateConfigurationAndPreconditions();
    $self->_makeStatisticalCategoryToItemTypesMap();
}

sub getItemtypesByStatisticalCategories {
    my ($self, @statCats) = @_;
    my @itypes;
    foreach my $sc (@statCats) {
        my $category = $self->{conf}->{statisticalCategoryToItemTypes}->{$sc};
        if($category){
            push(@itypes, @{$category});
        }
    }
    return \@itypes;
}

=head _validateConfigurationAndPreconditions
Since this is a bit complex feature. Check for correct configurations here.
Also make sure system-wide preconditions and precalculations are in place.
=cut

sub _validateConfigurationAndPreconditions {
    my ($self) = @_;

    ##Make sanity checks for the config and throw an error to tell the user that the config needs fixing.
    my @statCatKeys = ();
    my @juvenileShelLocKeys = ();
    if (ref $self->{conf}->{itemTypeToStatisticalCategory} eq 'HASH') {
        @statCatKeys = keys(%{$self->{conf}->{itemTypeToStatisticalCategory}});
    }
    if (ref $self->{conf}->{juvenileShelvingLocations} eq 'HASH') {
        @juvenileShelLocKeys = keys(%{$self->{conf}->{juvenileShelvingLocations}});
    }
    unless (scalar(@statCatKeys)) {
        my @cc = caller(0);
        Koha::Exception::BadSystemPreference->throw(
            error => $cc[3]."():> System preference 'OKM' is missing YAML-parameter 'itemTypeToStatisticalCategory'.\n".
                     "It should look something like this: \n".
                     "itemTypeToStatisticalCategory: \n".
                     "  BK: Books \n".
                     "  MU: Recordings \n");
    }
    unless (scalar(@juvenileShelLocKeys)) {
        my @cc = caller(0);
        Koha::Exception::BadSystemPreference->throw(
            error => $cc[3]."():> System preference 'OKM' is missing YAML-parameter 'juvenileShelvingLocations'.\n".
                     "It should look something like this: \n".
                     "juvenileShelvingLocations: \n".
                     "  - CHILD \n".
                     "  - AV \n");
    }
    
    my @authorised_values_by_category = Koha::AuthorisedValues->new->search( { category => 'MTYPE' } );

    my @loop_data = ();
    # builds value list
    for my $av ( @authorised_values_by_category ) {
        my %row_data;  # get a fresh hash for the row data
        #$row_data{category}              = $av->category;
        $row_data{authorised_value}      = $av->authorised_value;
        #$row_data{branches}              = $av->branch_limitations;
        #$row_data{id}                    = $av->id;
        #$row_data{lib}                   = $av->lib;
        push(@loop_data, \%row_data);
    }

    my $itemcount = scalar (@loop_data);

    my @itypes = ();

    for (my $i=0; $i < $itemcount; $i++) {
      push ( @itypes, $loop_data [$i]{authorised_value} );
   }

    #Old itemtypes were collected like this
    #my @itypes = Koha::ItemTypes->search();

    ##Check that we haven't accidentally mapped any itemtypes that don't actually exist in our database
    my %mappedItypes = map {$_ => 1} @statCatKeys; #Copy the itemtypes-as-keys
    my @preconditionerr = ();

    ##Check that all itemtypes and statistical categories are mapped
    my %statCategories = ( "Books" => 0, "SheetMusicAndScores" => 0,
                        "Recordings" => 0, "Videos" => 0, "Other" => 0, 
                        "Serials" => 0, "Celia" => 0, "Online" => 0,
                        "Electronic" => 0);
    
    foreach my $itype (@itypes) {
        
            my $it = $itype;
            my $mapping = $self->getItypeToOKMCategory($it);
                    
            unless ($mapping) { #Is itemtype mapped?
                my @cc = caller(0);
                push (@preconditionerr, $cc[3]."():> System preference 'OKM' has an unmapped itemtype '" . $itype . "'. Put it under 'itemTypeToStatisticalCategory'."."\n");
            }
            else {
                delete $mappedItypes{$it};
            }
            if(exists($statCategories{$mapping})) {
                $statCategories{$mapping} = 1; #Mark this mapping as used.
            }
            else { #Do we have extra statistical mappings we dont care of?
               my @cc = caller(0);
               my @statCatKeys = keys(%statCategories);
               push (@preconditionerr, $cc[3]."():> System preference 'OKM' has an unknown mapping '$mapping'. Allowed statistical categories under 'itemTypeToStatisticalCategory' are @statCatKeys");
            } 
    }
    
    
    #Do we have extra mapped item types?
    if (scalar(keys(%mappedItypes))) {
        #my @cc = caller(0);
        my @itypes = keys(%mappedItypes);
        my @cc = caller(0);
        push (@preconditionerr, $cc[3]."():> System preference 'OKM' has mapped itemtypes '@itypes' that don't exist in your database itemtypes-listing?");
    }

    #Check that all statistical categories are mapped
    while (my ($k, $v) = each(%statCategories)) {
        unless ($v) {
            my @cc = caller(0);
            push (@preconditionerr, $cc[3]."():> System preference 'OKM' has an unmapped statistical category '$k'. Map it to the 'itemTypeToStatisticalCategory'");
        }
    }

    ##Check that koha.biblio_data_elements -table is being updated regularly.
    my $staletest = Koha::BiblioDataElements::verifyFeatureIsInUse;
     #push (@unmappederr, "Staletest: ". $staletest);
    if (!$staletest){
        my @cc = caller(0);
         push (@preconditionerr, $cc[3]."():> koha.biblio_data_elements-table is stale. You must configure cronjob 'update_biblio_data_elements.pl' to run daily.");
    }
    
    #Show all errors
    if (@preconditionerr) {
        Koha::Exception::BadSystemPreference->throw(error => "@preconditionerr");
    }
}

sub _makeStatisticalCategoryToItemTypesMap {
    my ($self) = @_;
    my %statisticalCategoryToItemTypes;
    while (my ($itype, $statCat) = each(%{$self->{conf}->{itemTypeToStatisticalCategory}})) {
        $statisticalCategoryToItemTypes{$statCat} = [] unless $statisticalCategoryToItemTypes{$statCat};
        push(@{$statisticalCategoryToItemTypes{$statCat}}, $itype);
    }
    $self->{conf}->{statisticalCategoryToItemTypes} = \%statisticalCategoryToItemTypes;
}

=head getItypeToOKMCategory

    my $category = $okm->getItypeToOKMCategory('BK'); #Returns 'Books'

Takes an Itemtype and converts it based on the mapping rules to an OKM statistical
category type, like 'Books'.

@PARAM1 String, itemtype
@RETURNS String, OKM category type or undef
=cut

sub getItypeToOKMCategory {
    my ($self, $itemtype) = @_;
    return $self->{conf}->{itemTypeToStatisticalCategory}->{$itemtype};
}

sub isExecutionBlocked {
    return shift->{conf}->{blockStatisticsGeneration};
}

=head StandardizeTimeperiodParameter

    my ($startDate, $endDate) = C4::OPLIB::OKM::StandardizeTimeperiodParameter($timeperiod);

@PARAM1 String, The timeperiod definition. Supported values are:
                1. "YYYY-MM-DD - YYYY-MM-DD" (start to end, inclusive)
                   "YYYY-MM-DDThh:mm:ss - YYYY-MM-DDThh:mm:ss" is also accepted, but only the YYYY-MM-DD-portion is used.
                2. "YYYY" (desired year)
                3. "MM" (desired month, of the current year)
                4. "lastyear" (Calculates the whole last year)
                5. "lastmonth" (Calculates the whole previous month)
                Kills the process if no timeperiod is defined or if it is unparseable!
@RETURNS Array of DateTime, or die
=cut
sub StandardizeTimeperiodParameter {
    my ($timeperiod) = @_;

    my ($startDate, $endDate);

    if ($timeperiod =~ /^(\d\d\d\d)-(\d\d)-(\d\d)([Tt ]\d\d:\d\d:\d\d)?-(\d\d\d\d)-(\d\d)-(\d\d)([Tt ]\d\d:\d\d:\d\d)?$/) {
        #Make sure the values are correct by casting them into a DateTime
        $startDate = DateTime->new(year => $1, month => $2, day => $3, time_zone => C4::Context->tz());
        $endDate = DateTime->new(year => $5, month => $6, day => $7, time_zone => C4::Context->tz());
    }
    elsif ($timeperiod =~ /^(\d\d\d\d)$/) {
        $startDate = DateTime->from_day_of_year(year => $1, day_of_year => 1, time_zone => C4::Context->tz());
        $endDate = ($startDate->is_leap_year()) ?
                            DateTime->from_day_of_year(year => $1, day_of_year => 366, time_zone => C4::Context->tz()) :
                            DateTime->from_day_of_year(year => $1, day_of_year => 365, time_zone => C4::Context->tz());
    }
    elsif ($timeperiod =~ /^(\d\d)$/) {
        $startDate = DateTime->new( year => DateTime->now()->year(),
                                    month => $1,
                                    day => 1,
                                    time_zone => C4::Context->tz(),
                                   );
        $endDate = DateTime->last_day_of_month( year => $startDate->year(),
                                                month => $1,
                                                time_zone => C4::Context->tz(),
                                              ) if $startDate;
    }
    elsif ($timeperiod =~ 'lastyear') {
        $startDate = DateTime->now(time_zone => C4::Context->tz())->subtract(years => 1)->set_month(1)->set_day(1);
        $endDate = ($startDate->is_leap_year()) ?
                DateTime->from_day_of_year(year => $startDate->year(), day_of_year => 366, time_zone => C4::Context->tz()) :
                DateTime->from_day_of_year(year => $startDate->year(), day_of_year => 365, time_zone => C4::Context->tz()) if $startDate;
    }
    elsif ($timeperiod =~ 'lastmonth') {
        $startDate = DateTime->now(time_zone => C4::Context->tz())->subtract(months => 1)->set_day(1);
        $endDate = DateTime->last_day_of_month( year => $startDate->year(),
                                                month => $startDate->month(),
                                                time_zone => $startDate->time_zone(),
                                              ) if $startDate;
    }

    if ($startDate && $endDate) {
        #Check if startdate is smaller than enddate, if not fix it.
        if (DateTime->compare($startDate, $endDate) == 1) {
            my $temp = $startDate;
            $startDate = $endDate;
            $endDate = $temp;
        }

        #Make sure the HMS portion also starts from 0 and ends at the end of day. The DB usually does timeformat casting in such a way that missing
        #complete DATETIME elements causes issues when they are automaticlly set to 0.
        $startDate->truncate(to => 'day');
        $endDate->set_hour(23)->set_minute(59)->set_second(59);
        return ($startDate, $endDate);
    }
    die "OKM->_standardizeTimeperiodParameter($timeperiod): Timeperiod '$timeperiod' could not be parsed.";
}

=head log

    $okm->log("Something is wrong, why don't you fix it?");
    my $logArray = $okm->getLog();

=cut

sub log {
    my ($self, $message) = @_;
    push @{$self->{logs}}, $message;
    print $message."\n" if $self->{verbose};
}
sub flushLogs {
    my ($self) = @_;
    my $logs = $self->{logs};
    delete $self->{logs};
    return $logs;
}
1; #Happy happy joy joy!
