package C4::OPLIB::OKMLogs;

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
use Carp;
use C4::Context;

sub loadLogs {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM okm_statistics_logs");
    $sth->execute();
    if ($sth->err) {
        my @cc = caller(0);
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    my $logs = $sth->fetchall_arrayref({});
    return $logs;
}

sub insertLogs {
    my ($logsArray) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("INSERT INTO okm_statistics_logs (entry) VALUE (?)");
    foreach my $entry (@$logsArray) {
        $sth->execute($entry);
        if ($sth->err) {
            my @cc = caller(0);
            Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
        }
    }
    return 1;
}

sub deleteLogs {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("DELETE FROM okm_statistics_logs");
    $sth->execute();
    if ($sth->err) {
        my @cc = caller(0);
        Koha::Exception::DB->throw(error => $cc[3]."():> ".$sth->errstr);
    }
    return 1;
}

1;