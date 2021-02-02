#!/usr/bin/perl

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

use C4::Context;
use Koha::AtomicUpdater;

my $dbh = C4::Context->dbh();
my $atomicUpdater = Koha::AtomicUpdater->new();

unless($atomicUpdater->find('KD207-1')) {
    $dbh->do(q|
        CREATE TABLE `okm_statistics_logs` (
          `id` int(11) NOT NULL auto_increment,
          `entry` text NOT NULL,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    |);
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OKM','--- \nblockStatisticsGeneration: 1\nitemTypeToStatisticalCategory: \n  BK: Books\n  CF: Others\n  CR: Others\n  MU: Recordings\njuvenileShelvingLocations: \n  - CHILD\n  - AV\n',NULL,'OKM statistics configuration and statistical type mappings','Textarea')");
    print "Upgrade done (KD-207-1 - OKM annual statistics)\n";
}
