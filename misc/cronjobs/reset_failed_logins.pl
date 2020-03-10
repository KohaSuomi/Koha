#!/usr/bin/perl
# This cronjob will reset the amount of failed login attempts after
# specified amount of time. This will lift the bans caused by the
# user trying to log in with wrong password too many times.
# Resetting is done based on the borrowercategory.

# The cronjob will need be run at appropriate intervals depending
# on the desired length of the bans. For example to reset failed
# login attempts that are older than 3600 seconds every hour add
# this to your crontab:

# */60 * * * * $KOHA_PATH/misc/cronjobs/reset_failed_logins.pl 3600 CATEGORYCODE

# The time is calculated from the last time the user tried to log in,
# so each consecutive failed login while the account is locked
# will push the ban forward.

use utf8;
use strict;
use C4::Context;
use POSIX qw(strftime);

unless ( $ARGV[0] && $ARGV[1] ) {
    print "Enter block age in seconds and borrower categorycode to manage.\n";
    exit 1;
}

my $max_attempts = C4::Context->preference('FailedLoginAttempts');
my $dropbefore = strftime '%Y-%m-%d %H:%M:%S', localtime(time() - $ARGV[0]);

my $dbh=C4::Context->dbh();
my $sth_modify = $dbh->prepare( "SELECT borrowernumber FROM borrowers WHERE login_attempts>=? AND updated_on<? AND categorycode=?;" );
$sth_modify->execute($max_attempts, $dropbefore, $ARGV[1]);

while ( my @borrowernumber = $sth_modify->fetchrow_array ) {
    print strftime('%Y-%m-%d %H:%M:%S', localtime(time())) . " Resetting login attempts for borrower: $borrowernumber[0]\n";
    $dbh->do( "UPDATE borrowers SET login_attempts=0 WHERE borrowernumber='$borrowernumber[0]';" );
}
