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

unless($atomicUpdater->find('KD207')) {
    $dbh->do(q|
        CREATE TABLE `okm_statistics` (
            `id` int(11) NOT NULL default 0,
            `startdate` datetime default NULL,
            `enddate` datetime default NULL,
            `individualbranches` text default NULL, -- a comma separated list of branchcodes of grouping was not us$
            `okm_serialized` LONGTEXT default NULL, -- the C4::OPLIB::OKM-object serialized.
            `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    |);
    print "Upgrade done (KD-207 - OKM annual statistics)\n";
}
