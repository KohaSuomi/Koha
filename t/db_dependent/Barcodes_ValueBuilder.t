#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 12;
use Test::MockModule;
use t::lib::TestBuilder;

use Koha::Database;

use t::lib::Mocks;

BEGIN {
    use_ok('C4::Barcodes::ValueBuilder', qw( get_barcode ));
};

my $schema  = Koha::Database->new->schema;
$schema->storage->txn_begin;

my $builder = t::lib::TestBuilder->new;

my $dbh = C4::Context->dbh;
$dbh->do(q|DELETE FROM issues|);
$dbh->do(q|DELETE FROM items|);
my $item_1 = $builder->build_sample_item(
    {
        barcode => '33333074344563'
    }
);
my $item_2 = $builder->build_sample_item(
    {
        barcode => 'hb12070890'
    }
);
my $item_3 = $builder->build_sample_item(
    {
        barcode => '201200345'
    }
);
my $item_4 = $builder->build_sample_item(
    {
        barcode => '2012-0034'
    }
);

my %args = (
    year        => '2012',
    mon         => '07',
    day         => '30',
    tag         => '952',
    subfield    => 'p',
);

my ($nextnum, $scr) = C4::Barcodes::ValueBuilder::incremental::get_barcode(\%args);
is($nextnum, 33333074344564, 'incremental barcode');
is($scr, undef, 'incremental javascript');

($nextnum, $scr) = C4::Barcodes::ValueBuilder::hbyymmincr::get_barcode(\%args);
is($nextnum, '12070891', 'hbyymmincr barcode');
ok(length($scr) > 0, 'hbyymmincr javascript');

($nextnum, $scr) = C4::Barcodes::ValueBuilder::annual::get_barcode(\%args);
is($nextnum, '2012-0035', 'annual barcode');
is($scr, undef, 'annual javascript');

$dbh->do(q|DELETE FROM items|);
my $library_1 = $builder->build_object( { class => 'Koha::Libraries' } );

my $prefix_yaml = 'Default: DEF
'.$library_1->branchcode.': TEST';
t::lib::Mocks::mock_preference( 'BarcodePrefix', $prefix_yaml );

my $item_6 = $builder->build_sample_item(
    {
        barcode => 'TEST20120700001',
        homebranch   => $library_1->branchcode
    }
);

($args{branchcode}) = $library_1->branchcode;
($nextnum, $scr) = C4::Barcodes::ValueBuilder::preyyyymmincr::get_barcode(\%args);
is($nextnum, 'TEST20120700002', 'preyyyymmincr barcode test branch specific prefix');
ok(length($scr) > 0, 'preyyyymmincr javascript');

$dbh->do(q|DELETE FROM items|);
my $library_2 = $builder->build_object( { class => 'Koha::Libraries' } );

($args{branchcode}) = $library_2->branchcode;
($nextnum, $scr) = C4::Barcodes::ValueBuilder::preyyyymmincr::get_barcode(\%args);
is($nextnum, 'DEF20120700001', 'preyyyymmincr barcode test default prefix');

$schema->storage->txn_rollback;

