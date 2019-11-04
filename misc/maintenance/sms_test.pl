#!/usr/bin/perl

# Copyright 2019 KohaSuomi
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

use open qw( :std :encoding(UTF-8) );
binmode( STDOUT, ":encoding(UTF-8)" );

use C4::SMS;

use Getopt::Long qw(:config no_ignore_case);

my ($help, $driver, $message, $number);

GetOptions(
    'h|help'             => \$help,
    'd|driver:s'         => \$driver,
    'm|message:s'        => \$message,
    'n|number:s'         => \$number,
);

my $usage = << 'ENDUSAGE';

Test SMS driver for real.

This script has the following parameters :
    -h --help         This help.

    -d --driver       SMS driver

    -m --message      SMS message
    -n --number       Recipient number

Example:

perl sms_test.pl --driver ArenaV2::Driver --message Hello --number +33123456789

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}
if (!$driver || !$message || $number) {
    print $usage;
    print "\nDefine all parameters!\n";
    exit 1;
}

my $success = C4::SMS->send_sms({
    destination => $number,
    message => $message,
    driver => $driver,
}

print "$success\n";
