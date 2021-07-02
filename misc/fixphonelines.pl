#!/usr/bin/perl
#-----------------------------------
# Copyright 2008 LibLime
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#-----------------------------------

=head1 NAME
fixphonefields.pl  cron script to move mobile and landline phone numbers to their own fields (borrowers.phone, borrowers.mobile) with numbers cleanup
=cut

use strict;
use warnings;


BEGIN {
  # find Koha's Perl modules
  # test carefully before changing this
  use FindBin;
  eval { require "$FindBin::Bin/../kohalib.pl" };
}
use C4::Context;
use Getopt::Long;

my ($help, $verbose, $fixfields, $commit, $tidy);

GetOptions('help|h' => \$help, 'verbose|v' => \$verbose, 'fixfields' => \$fixfields, 'commit' => \$commit, 'tidy' => \$tidy,);

my $usage = << 'ENDUSAGE';
fixphonefields.pl  cron script to move mobile and landline phone numbers to their own fields (borrowers.phone, borrowers.mobile)

This script takes the following parameters :
    --verbose | v       verbose
    --help | h          This help screen
    --fixfields         Move stray mobile and landline numbers to their designated fields and clean them up.
    --tidy              Tidy/clean up all landline(phone) and mobile(mobile) numbers in database (remove all non-digit chars but "+")
    --commit            Update changes to database
ENDUSAGE


if ($help) {
  print $usage;
}

my $dbh = C4::Context->dbh();

#Get the borrowers phone numbers (landline + mobile)
my $sth = $dbh->prepare("SELECT borrowernumber, phone, mobile FROM borrowers");
$sth->execute();

#Prepare the UPDATE statement for mobile
my $uph = $dbh->prepare("UPDATE borrowers SET mobile = ? WHERE borrowernumber = ?");

#Prepare the UPDATE statement for landline
my $uph2 = $dbh->prepare("UPDATE borrowers SET phone = ? WHERE borrowernumber = ?");

my @borrowers = @{$sth->fetchall_arrayref({})};
exit 0 unless scalar(@borrowers);    #Exit cleanly if there are no numbers to fix

my $mobile_switched    = 0;
my $landline_switched  = 0;
my $no_numbers         = 0;
my $borrower_numbers   = 0;
my $cleanded_up        = 0;
my $numbers_swapped    = 0;
my $numbers_skipped    = 0;
my $duplicate_mobile   = 0;
my $duplicate_landline = 0;

if ($fixfields) {

  foreach my $borrower (@borrowers) {
	$borrower_numbers++;

	#mobile in landline field
	if ((defined $borrower->{phone} && $borrower->{phone} =~ /^\(?04[0-9]|^\(?050/) && (!defined $borrower->{mobile} or $borrower->{mobile} eq "")){    #Simple sanity check. landline number starts with +358, 04(0-9) or 050 and mobile is not set.
	   #if (defined $borrower->{phone} && $borrower->{phone} =~ /^\+358|^04[0-9]|^050/ && (!defined $borrower->{mobile} or $borrower->{mobile} eq "")) { #Simple sanity check. landline number starts with +358, 04(0-9) or 050 and mobile is not set.
	  my $borrower_phone_cleaned = $borrower->{phone};

	  #$borrower_phone_cleaned =~ s/\s()-//g;  #Remove spaces AND ().            ?????if starts with (04 or (05 )????
	  $borrower_phone_cleaned =~ s/[^0-9+]//g;    #Remove non-digits


	  $uph->execute($borrower_phone_cleaned, $borrower->{borrowernumber}) if $commit;
	  $uph2->execute("", $borrower->{borrowernumber})                     if $commit;

	  print "Borrower number " . $borrower->{borrowernumber} . " : PHONE is mobile. Moved to MOBILE field " . $borrower_phone_cleaned . " => MOBILE " . "\n" if $verbose;
	  $mobile_switched++;
	}

	#landline in mobile field, all starting with 9 are old landline prefixes
	if ((defined $borrower->{mobile} && $borrower->{mobile} =~ /^02|^03|^05[1-9]|^06|^08|^09|^013|^014|^015|^016|^017|^018|^019|^9/) && (!defined $borrower->{phone} or $borrower->{phone} eq "")){    #Simple sanity check. number start is landline.
	  my $borrower_mobile_cleaned = $borrower->{mobile};
	  $borrower_mobile_cleaned =~ s/[^0-9+]//g;    #Remove non-digits

	  $uph2->execute($borrower_mobile_cleaned, $borrower->{borrowernumber}) if $commit;
	  $uph->execute("", $borrower->{borrowernumber})                        if $commit;

	  print "Borrower number " . $borrower->{borrowernumber} . " : MOBILE is landline. Moved to PHONE field " . $borrower_mobile_cleaned . " => PHONE " . "\n" if $verbose;
	  $landline_switched++;
	}

	#if different phone numbers in both fields
	if ((defined $borrower->{phone} && $borrower->{phone} ne "") && (defined $borrower->{mobile} && $borrower->{mobile} ne "")) {
	  if ($borrower->{phone} ne $borrower->{mobile}) {

		#if landline field has a mobile number and mobile has landline number (else both numbers/fields are set correctly and no processing is needed)
		if ($borrower->{phone} =~ /^\(?04[0-9]|^\(?050/ && $borrower->{mobile} =~ /^02|^03|^05[1-9]|^06|^08|^09|^013|^014|^015|^016|^017|^018|^019|^9/) {

		  my $borrower_phone_cleaned = $borrower->{phone};
		  #$borrower_phone_cleaned =~ s/\s()-//g;  #Remove spaces AND ().            ?????if starts with (04 or (05 )????
		  $borrower_phone_cleaned =~ s/[^0-9+]//g;    #Remove non-digits

		  my $borrower_mobile_cleaned = $borrower->{mobile};
		  $borrower_mobile_cleaned =~ s/[^0-9+]//g;    #Remove non-digits

		  $uph->execute($borrower_phone_cleaned, $borrower->{borrowernumber})   if $commit;
		  $uph2->execute($borrower_mobile_cleaned, $borrower->{borrowernumber}) if $commit;

		  $numbers_swapped++;

		  print "Borrower number " . $borrower->{borrowernumber} . " : MOBILE is landline and PHONE is mobile. Fields swapped.\n";

		} else {
		  print "Borrower number " . $borrower->{borrowernumber} . " : Unique numbers in both fields not paired as landline + mobile. Skipping.\n";
		  $numbers_skipped++;
		}
	  }
	}

	#if identical duplicate numbers
	if ((defined $borrower->{phone} && $borrower->{phone} ne "") && (defined $borrower->{mobile} && $borrower->{mobile} ne "")) {

	  if (($borrower->{phone} eq $borrower->{mobile}) && $borrower->{phone} =~ /^\(?04[0-9]|^\(?050/) {

		#remove duplicate mobile from landline
		$uph2->execute("", $borrower->{borrowernumber})                                                                                                    if $commit;
		print "Borrower number " . $borrower->{borrowernumber} . " : Both phone numbers exist and are identical mobile numbers. Landline cleared. " . "\n" if $verbose;
		$duplicate_mobile++;

	  } elsif (($borrower->{phone} eq $borrower->{mobile}) && $borrower->{mobile} =~ /^02|^03|^05[1-9]|^06|^08|^09|^013|^014|^015|^016|^017|^018|^019|^9/) {

		#remove duplicate landline from mobile
		$uph->execute("", $borrower->{borrowernumber})                                                                                                     if $commit;
		print "Borrower number " . $borrower->{borrowernumber} . " : Both phone numbers exist and are identical landline numbers. Mobile cleared. " . "\n" if $verbose;
		$duplicate_landline++;
	  }

	} elsif ((!defined $borrower->{mobile} or $borrower->{mobile} eq "") && (!defined $borrower->{phone} or $borrower->{phone} eq "")) {
	  print "Borrower number " . $borrower->{borrowernumber} . " : No phone numbers set! Skipping. " . "\n" if $verbose;
	  $no_numbers++;
	}
  }
}

if ($tidy) {

  @borrowers = ();

  #Get the borrowers phone numbers (landline + mobile)
  $sth->execute();

  @borrowers = @{$sth->fetchall_arrayref({})};
  exit 0 unless scalar(@borrowers);    #Exit cleanly if there are no numbers to fix

  print "\nCleaning up phone number syntaxes if errors found: \n\n" if $verbose;

  foreach my $borrower (@borrowers) {

	if (defined $borrower->{mobile} && $borrower->{mobile} ne "") {    #Cleanup
	  my $borrower_mobile_cleaned = $borrower->{mobile};

	  #$borrower_mobile_cleaned =~ s/\s//g; #Remove spaces
	  # (\s|\(|\)|-) remove spaces, (, ), -
	  $borrower_mobile_cleaned =~ s/[^0-9+]//g;    #Remove non-digits excluding +

	  if ($borrower_mobile_cleaned ne $borrower->{mobile}) {
		$uph->execute($borrower_mobile_cleaned, $borrower->{borrowernumber})                                                                                 if $commit;
		print "Borrower number " . $borrower->{borrowernumber} . " : Mobile number fixed. " . $borrower->{mobile} . " => " . $borrower_mobile_cleaned . "\n" if $verbose;
		$cleanded_up++;
	  }
	}

	if (defined $borrower->{phone} && $borrower->{phone} ne "") {    #Cleanup
	  my $borrower_phone_cleaned = $borrower->{phone};

	  #$borrower_phone_cleaned =~ s/\s//g; #Remove spaces
	  # (\s|\(|\)|-) remove spaces, (, ), -
	  $borrower_phone_cleaned =~ s/[^0-9+]//g;    #Remove non-digits excluding +

	  if ($borrower_phone_cleaned ne $borrower->{phone}) {
		$uph2->execute($borrower_phone_cleaned, $borrower->{borrowernumber})                                                                                 if $commit;
		print "Borrower number " . $borrower->{borrowernumber} . " : Landline number fixed. " . $borrower->{phone} . " => " . $borrower_phone_cleaned . "\n" if $verbose;
		$cleanded_up++;
	  }
	}
  }
}

print "\nSummary: \n"                                                                                      if $verbose;
print "Borrower numbers handled: " . $borrower_numbers . "\n"                                              if $verbose;
print "Mobile numbers moved from landline (phone -> mobile): " . $mobile_switched . "\n"                   if $verbose;
print "Landline numbers moved from mobile (mobile -> phone): " . $landline_switched . "\n"                 if $verbose;
print "Mobile and landline number fields swapped: " . $numbers_swapped . "\n"                              if $verbose;
print "Unique numbers in both fields not paired as mobile + landline. Skipped: " . $numbers_skipped . "\n" if $verbose;
print "Duplicate landline numbers. Cleared mobile: " . $duplicate_landline . "\n"                          if $verbose;
print "Duplicate mobile numbers. Cleared landline: " . $duplicate_mobile . "\n"                            if $verbose;
print "No phone numbers set: " . $no_numbers . "\n"                                                        if $verbose;
print "Phone numbers cleaned up with --tidy: " . $cleanded_up . "\n";

