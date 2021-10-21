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

BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Context;
use C4::Members;
use Getopt::Long;
use Pod::Usage;
use C4::Log;

=head1 NAME

change_patron_at_age.pl - Change patron categorycode at patron age

=head1 SYNOPSIS

change_patron_at_age.pl --fromcat=LAPSI --tocat=LAOMATOIMI --age=16

 Options:
   --help
   --man
       Show help or man page.

   --confirm
       Without confirm, shows patrons this would change.

   --fromcat=PATRONCAT
       Change patron from this category. Required.

   --tocat=PATRONCAT
       Change patron to this category. Required.

   --branch=BRANCHCODE
       Limit to patrons from this branch.

   --age=INT
       Limit to patrons with this age. Required.

=cut

my $help     = 0;
my $man      = 0;
my $verbose  = 0;
my $confirm  = 0;
my $patronage = -1;
my $mybranch;
my $fromcat;
my $tocat;

GetOptions(
    'help|?'     => \$help,
    'man'        => \$man,
    'confirm'    => \$confirm,
    'fromcat=s'  => \$fromcat,
    'tocat=s'    => \$tocat,
    'branch=s'   => \$mybranch,
    'age=i'      => \$patronage,
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage( -verbose => 2 ) if $man;

if ( not $fromcat && $tocat ) {    #make sure we've specified the info we need.
    print "please specify -help for usage tips.\n";
    exit;
}

if ( $patronage < 1 ) {
    print "Need --age\n";
    exit;
}

cronlogaction();

my $dbh = C4::Context->dbh;

my $query;
my @params;

if ( $confirm ) {
    $query = "UPDATE borrowers SET categorycode = ?";
    push(@params, $tocat);
} else {
    $query = qq|SELECT firstname,
                       surname,
                       cardnumber,
                       branchcode,
                       dateofbirth,
                       TIMESTAMPDIFF(YEAR, dateofbirth, CURDATE()) as age
                FROM borrowers|;
}

$query .= " WHERE TIMESTAMPDIFF(YEAR, dateofbirth, CURDATE()) = ? AND categorycode = ?";

push(@params, $patronage);
push(@params, $fromcat);

if ($mybranch) {
    $query .= " AND branchcode = ?";
    push(@params, $mybranch);
}

if ( $confirm ) {
    print "Updating patrons $fromcat to $tocat, age $patronage";
    print ", branch $mybranch" if ($mybranch);
    print "\n";

    my $sth = $dbh->prepare($query);
    my $res = $sth->execute(@params) or die "can't execute";

    if ( $res eq '0E0' ) {
        print "No patrons updated\n";
    } else {
        print "Updated $res patrons\n";
    }
} else {
    my $sth = $dbh->prepare($query);
    $sth->execute(@params)
        or die "Couldn't execute statement: " . $sth->errstr;

    while ( my @res = $sth->fetchrow_array() ) {
        my $firstname = $res[0];
        my $surname   = $res[1];
        my $barcode   = $res[2];
        my $branch    = $res[3];
        my $birthday  = $res[4];
        my $age       = $res[5];
        print "$firstname\t$surname\t$barcode\t$branch\t$birthday\t$age\n";
    }
}
