#!/usr/bin/perl
#
# This Koha test module is a stub!
# Add more tests here!!!

use strict;
use warnings;

use Test::More tests => 3;

BEGIN {
        use_ok('C4::ClassSortRoutine::OUTI');
}

my $cn_class = "My class ";
my $cn_item = " hellO";

my $cn_sort = C4::ClassSortRoutine::OUTI::get_class_sort_key($cn_class, $cn_item);

is($cn_sort,"CLASS   HELLO","testing cnsort");

$cn_sort = C4::ClassSortRoutine::OUTI::get_class_sort_key(undef, undef);

is($cn_sort,"","Testing blank cnsort");
