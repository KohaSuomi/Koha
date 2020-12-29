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

use strict;
use warnings;

use Modern::Perl;

use Getopt::Long;

use Koha::Database;
use Koha::DateUtils qw( dt_from_string );
use Koha::Holds;

my ( $help, $confirm );

GetOptions(
    'h|help'        => \$help,
    'c|confirm'     => \$confirm,
);

my $usage = << 'ENDUSAGE';

This script updates holds expiration date if none exists.
Expiration date will be set 2 years from the reserve date.

This script has the following parameters :
    -h --help: this message help message
    -c --confirm: run update (without this just number of holds
    to update is printed.)

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

my $dt = Koha::Database->new->schema->storage->datetime_parser;

my $holds = Koha::Holds->search({
    expirationdate => undef,
});

say "Found ". $holds->count ." hold(s) without expiration date.";

unless ($confirm) {
    say "Run again with -c or --confirm to update holds.";
}

if($confirm){
    while (my $hold = $holds->next){
        my $reservedate = $hold->reservedate;
        my $expirationdate = $dt->format_date(dt_from_string($reservedate)->add( years => 2 ));
        $hold->set({ expirationdate => $expirationdate })->store();
    }
}