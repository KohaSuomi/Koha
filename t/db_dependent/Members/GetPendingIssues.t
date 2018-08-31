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

use Test::More tests => 20;
use Test::MockModule;

use t::lib::TestBuilder;

use C4::Biblio;
use C4::Items;
use C4::Members;
use C4::Circulation;
use Koha::Library;
use MARC::Record;

my $schema = Koha::Database->schema;
my $dbh = C4::Context->dbh;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

$dbh->do(q|DELETE FROM issues|);
$dbh->do(q|DELETE FROM borrowers|);
$dbh->do(q|DELETE FROM items|);
$dbh->do(q|DELETE FROM branches|);
$dbh->do(q|DELETE FROM biblio|);
$dbh->do(q|DELETE FROM categories|);

my $branchcode   = $builder->build( { source => 'Branch' } )->{branchcode};
my $categorycode = $builder->build( { source => 'Category' } )->{categorycode};
my $itemtype     = $builder->build( { source => 'Itemtype' } )->{itemtype};

my %item_infos = (
    homebranch    => $branchcode,
    holdingbranch => $branchcode,
    itype         => $itemtype
);


my ($biblionumber1) = AddBiblio( MARC::Record->new, '' );
my $itemnumber1 =
  AddItem( { barcode => '0101', %item_infos }, $biblionumber1 );
my $itemnumber2 =
  AddItem( { barcode => '0102', %item_infos }, $biblionumber1 );

my ($biblionumber2) = AddBiblio( MARC::Record->new, '' );
my $itemnumber3 =
  AddItem( { barcode => '0203', %item_infos }, $biblionumber2 );

my $borrowernumber1 =
  AddMember( categorycode => $categorycode, branchcode => $branchcode );
my $borrowernumber2 =
  AddMember( categorycode => $categorycode, branchcode => $branchcode );
my $borrower1 = GetMember( borrowernumber => $borrowernumber1 );
my $borrower2 = GetMember( borrowernumber => $borrowernumber2 );

my $module = new Test::MockModule('C4::Context');
$module->mock( 'userenv', sub { { branch => $branchcode } } );

my $issues =
  C4::Members::GetPendingIssues( $borrowernumber1, $borrowernumber2 );
is( @$issues, 0, 'GetPendingIssues returns the correct number of elements' );

AddIssue( $borrower1, '0101' );
$issues = C4::Members::GetPendingIssues($borrowernumber1);
is( @$issues, 1, 'GetPendingIssues returns the correct number of elements' );
is( $issues->[0]->{itemnumber},
    $itemnumber1, 'GetPendingIssues returns the itemnumber correctly' );
my $issues_bis =
  C4::Members::GetPendingIssues( $borrowernumber1, $borrowernumber2 );
is_deeply( $issues, $issues_bis, 'GetPendingIssues functions correctly' );
$issues = C4::Members::GetPendingIssues($borrowernumber2);
is( @$issues, 0, 'GetPendingIssues returns the correct number of elements' );

AddIssue( $borrower1, '0102' );
$issues = C4::Members::GetPendingIssues($borrowernumber1);
is( @$issues, 2, 'GetPendingIssues returns the correct number of elements' );
is( $issues->[0]->{itemnumber},
    $itemnumber1, 'GetPendingIssues returns the itemnumber correctly' );
is( $issues->[1]->{itemnumber},
    $itemnumber2, 'GetPendingIssues returns the itemnumber correctly' );
$issues_bis =
  C4::Members::GetPendingIssues( $borrowernumber1, $borrowernumber2 );
is_deeply( $issues, $issues_bis, 'GetPendingIssues functions correctly' );
$issues = C4::Members::GetPendingIssues($borrowernumber2);
is( @$issues, 0, 'GetPendingIssues returns the correct number of elements' );

AddIssue( $borrower2, '0203' );
$issues = C4::Members::GetPendingIssues($borrowernumber2);
is( @$issues, 1, 'GetAllIssues returns the correct number of elements' );
is( $issues->[0]->{itemnumber},
    $itemnumber3, 'GetPendingIssues returns the itemnumber correctly' );
$issues = C4::Members::GetPendingIssues($borrowernumber1);
is( @$issues, 2, 'GetPendingIssues returns the correct number of elements' );
is( $issues->[0]->{itemnumber},
    $itemnumber1, 'GetPendingIssues returns the itemnumber correctly' );
is( $issues->[1]->{itemnumber},
    $itemnumber2, 'GetPendingIssues returns the itemnumber correctly' );
$issues = C4::Members::GetPendingIssues( $borrowernumber1, $borrowernumber2 );
is( @$issues, 3, 'GetPendingIssues returns the correct number of elements' );
is( $issues->[0]->{itemnumber},
    $itemnumber1, 'GetPendingIssues returns the itemnumber correctly' );
is( $issues->[1]->{itemnumber},
    $itemnumber2, 'GetPendingIssues returns the itemnumber correctly' );
is( $issues->[2]->{itemnumber},
    $itemnumber3, 'GetPendingIssues returns the itemnumber correctly' );

$issues = C4::Members::GetPendingIssues();
is( @$issues, 0,
    'GetPendingIssues without borrower numbers returns an empty array' );

$schema->storage->txn_begin;

