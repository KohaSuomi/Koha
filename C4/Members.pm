package C4::Members;

# Copyright 2000-2003 Katipo Communications
# Copyright 2010 BibLibre
# Parts Copyright 2010 Catalyst IT
#
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
#use warnings; FIXME - Bug 2505
use C4::Context;
use String::Random qw( random_string );
use Scalar::Util qw( looks_like_number );
use Date::Calc qw/Today check_date Date_to_Days/;
use App::Genpass;
use C4::Log; # logaction
use C4::Overdues;
use C4::Reserves;
use C4::Accounts;
use C4::Biblio;
use C4::Letters;
use C4::Members::Attributes qw(SearchIdMatchingAttribute UpdateBorrowerAttribute);
use C4::NewsChannels; #get slip news
use DateTime;
use Koha::Database;
use Koha::DateUtils;
use Text::Unaccent qw( unac_string );
use Koha::AuthUtils qw(hash_password);
use Koha::Database;
use Koha::Holds;
use Koha::List::Patron;
use Koha::Patrons;
use Koha::Patron::Categories;
use Koha::Patron::Message::Preferences;
use Koha::Schema;

our (@ISA,@EXPORT,@EXPORT_OK,$debug);

use Module::Load::Conditional qw( can_load );
if ( ! can_load( modules => { 'Koha::NorwegianPatronDB' => undef } ) ) {
   $debug && warn "Unable to load Koha::NorwegianPatronDB";
}


BEGIN {
    $debug = $ENV{DEBUG} || 0;
    require Exporter;
    @ISA = qw(Exporter);
    #Get data
    push @EXPORT, qw(
        &GetMember

        &GetPendingIssues
        &GetAllIssues

        &GetFirstValidEmailAddress
        &GetNoticeEmailAddress

        &GetMemberAccountRecords
        &GetBorNotifyAcctRecord

        &GetBorrowersToExpunge

        &IssueSlip
        &FineSlip
        &CheckInSlip

        GetOverduesForPatron

        &GenMemberPasswordSuggestion
        &ValidateMemberPassword
        &minPasswordLength
        &getModifiedPatronFieldsForLogs
    );

    #Modify data
    push @EXPORT, qw(
        &ModMember
        &changepassword
    );

    #Insert data
    push @EXPORT, qw(
        &AddMember
    &AddMember_Auto
        &AddMember_Opac
    );

    #Check data
    push @EXPORT, qw(
        &checkuniquemember
        &checkuserpassword
        &Check_Userid
        &Generate_Userid
        &fixup_cardnumber
        &checkcardnumber
    );
}

=head1 NAME

C4::Members - Perl Module containing convenience functions for member handling

=head1 SYNOPSIS

use C4::Members;

=head1 DESCRIPTION

This module contains routines for adding, modifying and deleting members/patrons/borrowers 

=head1 FUNCTIONS

=head2 patronflags

 $flags = &patronflags($patron);

This function is not exported.

The following will be set where applicable:
 $flags->{CHARGES}->{amount}        Amount of debt
 $flags->{CHARGES}->{noissues}      Set if debt amount >$5.00 (or syspref noissuescharge)
 $flags->{CHARGES}->{message}       Message -- deprecated

 $flags->{CREDITS}->{amount}        Amount of credit
 $flags->{CREDITS}->{message}       Message -- deprecated

 $flags->{  GNA  }                  Patron has no valid address
 $flags->{  GNA  }->{noissues}      Set for each GNA
 $flags->{  GNA  }->{message}       "Borrower has no valid address" -- deprecated

 $flags->{ LOST  }                  Patron's card reported lost
 $flags->{ LOST  }->{noissues}      Set for each LOST
 $flags->{ LOST  }->{message}       Message -- deprecated

 $flags->{DBARRED}                  Set if patron debarred, no access
 $flags->{DBARRED}->{noissues}      Set for each DBARRED
 $flags->{DBARRED}->{message}       Message -- deprecated

 $flags->{ NOTES }
 $flags->{ NOTES }->{message}       The note itself.  NOT deprecated

 $flags->{ ODUES }                  Set if patron has overdue books.
 $flags->{ ODUES }->{message}       "Yes"  -- deprecated
 $flags->{ ODUES }->{itemlist}      ref-to-array: list of overdue books
 $flags->{ ODUES }->{itemlisttext}  Text list of overdue items -- deprecated

 $flags->{WAITING}                  Set if any of patron's reserves are available
 $flags->{WAITING}->{message}       Message -- deprecated
 $flags->{WAITING}->{itemlist}      ref-to-array: list of available items

=over 

=item C<$flags-E<gt>{ODUES}-E<gt>{itemlist}> is a reference-to-array listing the
overdue items. Its elements are references-to-hash, each describing an
overdue item. The keys are selected fields from the issues, biblio,
biblioitems, and items tables of the Koha database.

=item C<$flags-E<gt>{ODUES}-E<gt>{itemlisttext}> is a string giving a text listing of
the overdue items, one per line.  Deprecated.

=item C<$flags-E<gt>{WAITING}-E<gt>{itemlist}> is a reference-to-array listing the
available items. Each element is a reference-to-hash whose keys are
fields from the reserves table of the Koha database.

=back

All the "message" fields that include language generated in this function are deprecated, 
because such strings belong properly in the display layer.

The "message" field that comes from the DB is OK.

=cut

# TODO: use {anonymous => hashes} instead of a dozen %flaginfo
# FIXME rename this function.
sub patronflags {
    my %flags;
    my ( $patroninformation) = @_;
    my $dbh=C4::Context->dbh;
    my ($balance, $owing) = GetMemberAccountBalance( $patroninformation->{'borrowernumber'});
    if ( $owing > 0 ) {
        my %flaginfo;
        my $noissuescharge = C4::Context->preference("noissuescharge") || 5;
        $flaginfo{'message'} = sprintf 'Patron owes %.02f', $owing;
        $flaginfo{'amount'}  = sprintf "%.02f", $owing;
        if ( $owing > $noissuescharge && !C4::Context->preference("AllowFineOverride") ) {
            $flaginfo{'noissues'} = 1;
        }
        $flags{'CHARGES'} = \%flaginfo;
    }
    elsif ( $balance < 0 ) {
        my %flaginfo;
        $flaginfo{'message'} = sprintf 'Patron has credit of %.02f', -$balance;
        $flaginfo{'amount'}  = sprintf "%.02f", $balance;
        $flags{'CREDITS'} = \%flaginfo;
    }

    # Check the debt of the guarntees of this patron
    my $no_issues_charge_guarantees = C4::Context->preference("NoIssuesChargeGuarantees");
    $no_issues_charge_guarantees = undef unless looks_like_number( $no_issues_charge_guarantees );
    if ( defined $no_issues_charge_guarantees ) {
        my $p = Koha::Patrons->find( $patroninformation->{borrowernumber} );
        my @guarantees = $p->guarantees();
        my $guarantees_non_issues_charges;
        foreach my $g ( @guarantees ) {
            my ( $b, $n, $o ) = C4::Members::GetMemberAccountBalance( $g->id );
            $guarantees_non_issues_charges += $n;
        }

        if ( $guarantees_non_issues_charges > $no_issues_charge_guarantees ) {
            my %flaginfo;
            $flaginfo{'message'} = sprintf 'patron guarantees owe %.02f', $guarantees_non_issues_charges;
            $flaginfo{'amount'}  = $guarantees_non_issues_charges;
            $flaginfo{'noissues'} = 1 unless C4::Context->preference("allowfineoverride");
            $flags{'CHARGES_GUARANTEES'} = \%flaginfo;
        }
    }

    if (   $patroninformation->{'gonenoaddress'}
        && $patroninformation->{'gonenoaddress'} == 1 )
    {
        my %flaginfo;
        $flaginfo{'message'}  = 'Borrower has no valid address.';
        $flaginfo{'noissues'} = 1;
        $flags{'GNA'}         = \%flaginfo;
    }
    if ( $patroninformation->{'lost'} && $patroninformation->{'lost'} == 1 ) {
        my %flaginfo;
        $flaginfo{'message'}  = 'Borrower\'s card reported lost.';
        $flaginfo{'noissues'} = 1;
        $flags{'LOST'}        = \%flaginfo;
    }
    if ( $patroninformation->{'debarred'} && check_date( split( /-/, $patroninformation->{'debarred'} ) ) ) {
        if ( Date_to_Days(Date::Calc::Today) < Date_to_Days( split( /-/, $patroninformation->{'debarred'} ) ) ) {
            my %flaginfo;
            $flaginfo{'debarredcomment'} = $patroninformation->{'debarredcomment'};
            $flaginfo{'message'}         = $patroninformation->{'debarredcomment'};
            $flaginfo{'noissues'}        = 1;
            $flaginfo{'dateend'}         = $patroninformation->{'debarred'};
            $flags{'DBARRED'}           = \%flaginfo;
        }
    }
    if (   $patroninformation->{'borrowernotes'}
        && $patroninformation->{'borrowernotes'} )
    {
        my %flaginfo;
        $flaginfo{'message'} = $patroninformation->{'borrowernotes'};
        $flags{'NOTES'}      = \%flaginfo;
    }
    my ( $odues, $itemsoverdue ) = C4::Overdues::checkoverdues($patroninformation->{'borrowernumber'});
    if ( $odues && $odues > 0 ) {
        my %flaginfo;
        $flaginfo{'message'}  = "Yes";
        $flaginfo{'itemlist'} = $itemsoverdue;
        foreach ( sort { $a->{'date_due'} cmp $b->{'date_due'} }
            @$itemsoverdue )
        {
            $flaginfo{'itemlisttext'} .=
              "$_->{'date_due'} $_->{'barcode'} $_->{'title'} \n";  # newline is display layer
        }
        $flags{'ODUES'} = \%flaginfo;
    }

    my $patron = Koha::Patrons->find( $patroninformation->{borrowernumber} );
    my $waiting_holds = $patron->holds->search({ found => 'W' });
    my $nowaiting = $waiting_holds->count;
    if ( $nowaiting > 0 ) {
        my %flaginfo;
        $flaginfo{'message'}  = "Reserved items available";
        $flaginfo{'itemlist'} = $waiting_holds->unblessed;
        $flags{'WAITING'}     = \%flaginfo;
    }
    return ( \%flags );
}


=head2 GetMember

  $borrower = &GetMember(%information);

Retrieve the first patron record meeting on criteria listed in the
C<%information> hash, which should contain one or more
pairs of borrowers column names and values, e.g.,

   $borrower = GetMember(borrowernumber => id);

C<&GetBorrower> returns a reference-to-hash whose keys are the fields of
the C<borrowers> table in the Koha database.

FIXME: GetMember() is used throughout the code as a lookup
on a unique key such as the borrowernumber, but this meaning is not
enforced in the routine itself.

=cut

#'
sub GetMember {
    my ( %information ) = @_;
    if (exists $information{borrowernumber} && !defined $information{borrowernumber}) {
        #passing mysql's kohaadmin?? Makes no sense as a query
        return;
    }
    my $dbh = C4::Context->dbh;
    my $select =
    q{SELECT borrowers.*, categories.category_type, categories.description
    FROM borrowers 
    LEFT JOIN categories on borrowers.categorycode=categories.categorycode WHERE };
    my $more_p = 0;
    my @values = ();
    for (keys %information ) {
        if ($more_p) {
            $select .= ' AND ';
        }
        else {
            $more_p++;
        }

        if (defined $information{$_}) {
            $select .= "$_ = ?";
            push @values, $information{$_};
        }
        else {
            $select .= "$_ IS NULL";
        }
    }
    $debug && warn $select, " ",values %information;
    my $sth = $dbh->prepare("$select");
    $sth->execute(@values);
    my $data = $sth->fetchall_arrayref({});
    #FIXME interface to this routine now allows generation of a result set
    #so whole array should be returned but bowhere in the current code expects this
    if (@{$data} ) {
        return $data->[0];
    }

    return;
}

=head2 ModMember

  my $success = ModMember(borrowernumber => $borrowernumber,
                                            [ field => value ]... );

Modify borrower's data.  All date fields should ALREADY be in ISO format.

return :
true on success, or false on failure

=cut

sub ModMember {
    my (%data) = @_;

    # trim whitespace from data which has some non-whitespace in it.
    foreach my $field_name (keys(%data)) {
        if ( defined $data{$field_name} && $data{$field_name} =~ /\S/ ) {
            $data{$field_name} =~ s/^\s*|\s*$//g;
        }
    }

    # test to know if you must update or not the borrower password
    if (exists $data{password}) {
        if ($data{password} eq '****' or $data{password} eq '') {
            delete $data{password};
        } else {
            if ( C4::Context->preference('NorwegianPatronDBEnable') && C4::Context->preference('NorwegianPatronDBEnable') == 1 ) {
                # Update the hashed PIN in borrower_sync.hashed_pin, before Koha hashes it
                Koha::NorwegianPatronDB::NLUpdateHashedPIN( $data{'borrowernumber'}, $data{password} );
            }
            $data{password} = hash_password($data{password});
        }
    }

    my $old_categorycode = Koha::Patrons->find( $data{borrowernumber} )->categorycode;

    # get only the columns of a borrower
    my $schema = Koha::Database->new()->schema;
    my @columns = $schema->source('Borrower')->columns;
    my $new_borrower = { map { join(' ', @columns) =~ /$_/ ? ( $_ => $data{$_} ) : () } keys(%data) };

    $new_borrower->{dateofbirth}     ||= undef if exists $new_borrower->{dateofbirth};
    $new_borrower->{dateenrolled}    ||= undef if exists $new_borrower->{dateenrolled};
    $new_borrower->{dateexpiry}      ||= undef if exists $new_borrower->{dateexpiry};
    $new_borrower->{debarred}        ||= undef if exists $new_borrower->{debarred};
    $new_borrower->{sms_provider_id} ||= undef if exists $new_borrower->{sms_provider_id};
    $new_borrower->{guarantorid}     ||= undef if exists $new_borrower->{guarantorid};

    my $patron = Koha::Patrons->find( $new_borrower->{borrowernumber} );

    delete $new_borrower->{userid} if exists $new_borrower->{userid} and not $new_borrower->{userid};
    my $logdata = getModifiedPatronFieldsForLogs($new_borrower);
    my $execute_success = $patron->store if $patron->set($new_borrower);

    if ($execute_success) { # only proceed if the update was a success
        # If the patron changes to a category with enrollment fee, we add a fee
        if ( $data{categorycode} and $data{categorycode} ne $old_categorycode ) {
            if ( C4::Context->preference('FeeOnChangePatronCategory') ) {
                $patron->add_enrolment_fee_if_needed;
            }
        }

        foreach my $pref (
            @{Koha::Patron::Message::Preferences->search({
                borrowernumber => $data{borrowernumber} })->as_list
            })
        {

            $pref->fix_misconfigured_preference;
        }

        # If NorwegianPatronDBEnable is enabled, we set syncstatus to something that a
        # cronjob will use for syncing with NL
        if ( C4::Context->preference('NorwegianPatronDBEnable') && C4::Context->preference('NorwegianPatronDBEnable') == 1 ) {
            my $borrowersync = Koha::Database->new->schema->resultset('BorrowerSync')->find({
                'synctype'       => 'norwegianpatrondb',
                'borrowernumber' => $data{'borrowernumber'}
            });
            # Do not set to "edited" if syncstatus is "new". We need to sync as new before
            # we can sync as changed. And the "new sync" will pick up all changes since
            # the patron was created anyway.
            if ( $borrowersync->syncstatus ne 'new' && $borrowersync->syncstatus ne 'delete' ) {
                $borrowersync->update( { 'syncstatus' => 'edited' } );
            }
            # Set the value of 'sync'
            $borrowersync->update( { 'sync' => $data{'sync'} } );
            # Try to do the live sync
            Koha::NorwegianPatronDB::NLSync({ 'borrowernumber' => $data{'borrowernumber'} });
        }
        logaction("MEMBERS", "MODIFY", $data{'borrowernumber'}, "UPDATED FIELD(S): $logdata") if C4::Context->preference("BorrowersLog") && $logdata;
    }
    return $execute_success;
}

=head2 AddMember

  $borrowernumber = &AddMember(%borrower);

insert new borrower into table

(%borrower keys are database columns. Database columns could be
different in different versions. Please look into database for correct
column names.)

Returns the borrowernumber upon success

Returns as undef upon any db error without further processing

=cut

#'
sub AddMember {
    my (%data) = @_;
    my $dbh = C4::Context->dbh;
    my $schema = Koha::Database->new()->schema;

    # trim whitespace from data which has some non-whitespace in it.
    foreach my $field_name (keys(%data)) {
        if ( defined $data{$field_name} && $data{$field_name} =~ /\S/ ) {
            $data{$field_name} =~ s/^\s*|\s*$//g;
        }
    }

    # generate a proper login if none provided
    $data{'userid'} = Generate_Userid( $data{'borrowernumber'}, $data{'firstname'}, $data{'surname'} )
      if ( $data{'userid'} eq '' || !Check_Userid( $data{'userid'} ) );

    # add expiration date if it isn't already there
    $data{dateexpiry} ||= Koha::Patron::Categories->find( $data{categorycode} )->get_expiry_date;

    # add enrollment date if it isn't already there
    unless ( $data{'dateenrolled'} ) {
        $data{'dateenrolled'} = output_pref( { dt => dt_from_string, dateonly => 1, dateformat => 'iso' } );
    }

    if ( C4::Context->preference("autoMemberNum") ) {
        if ( not exists $data{cardnumber} or not defined $data{cardnumber} or $data{cardnumber} eq '' ) {
            $data{cardnumber} = fixup_cardnumber( $data{cardnumber} );
        }
    }

    my $patron_category = $schema->resultset('Category')->find( $data{'categorycode'} );
    $data{'privacy'} =
        $patron_category->default_privacy() eq 'default' ? 1
      : $patron_category->default_privacy() eq 'never'   ? 2
      : $patron_category->default_privacy() eq 'forever' ? 0
      :                                                    undef;

    $data{'privacy_guarantor_checkouts'} = 0 unless defined( $data{'privacy_guarantor_checkouts'} );

    # Make a copy of the plain text password for later use
    my $plain_text_password = $data{'password'};

    # create a disabled account if no password provided
    $data{'password'} = ($data{'password'})? hash_password($data{'password'}) : '!';

    # we don't want invalid dates in the db (mysql has a bad habit of inserting 0000-00-00
    $data{'dateofbirth'}     = undef if ( not $data{'dateofbirth'} );
    $data{'debarred'}        = undef if ( not $data{'debarred'} );
    $data{'sms_provider_id'} = undef if ( not $data{'sms_provider_id'} );
    $data{'guarantorid'}     = undef if ( not $data{'guarantorid'} );

    # get only the columns of Borrower
    # FIXME Do we really need this check?
    my @columns = $schema->source('Borrower')->columns;
    my $new_member = { map { join(' ',@columns) =~ /$_/ ? ( $_ => $data{$_} )  : () } keys(%data) } ;

    delete $new_member->{borrowernumber};

    my $patron = Koha::Patron->new( $new_member )->store;
    $data{borrowernumber} = $patron->borrowernumber;

    # If NorwegianPatronDBEnable is enabled, we set syncstatus to something that a
    # cronjob will use for syncing with NL
    if ( exists $data{'borrowernumber'} && C4::Context->preference('NorwegianPatronDBEnable') && C4::Context->preference('NorwegianPatronDBEnable') == 1 ) {
        Koha::Database->new->schema->resultset('BorrowerSync')->create({
            'borrowernumber' => $data{'borrowernumber'},
            'synctype'       => 'norwegianpatrondb',
            'sync'           => 1,
            'syncstatus'     => 'new',
            'hashed_pin'     => Koha::NorwegianPatronDB::NLEncryptPIN( $plain_text_password ),
        });
    }

    logaction("MEMBERS", "CREATE", $data{'borrowernumber'}, "") if C4::Context->preference("BorrowersLog");

    $patron->add_enrolment_fee_if_needed;

    return $data{borrowernumber};
}

=head2 Check_Userid

    my $uniqueness = Check_Userid($userid,$borrowernumber);

    $borrowernumber is optional (i.e. it can contain a blank value). If $userid is passed with a blank $borrowernumber variable, the database will be checked for all instances of that userid (i.e. userid=? AND borrowernumber != '').

    If $borrowernumber is provided, the database will be checked for every instance of that userid coupled with a different borrower(number) than the one provided.

    return :
        0 for not unique (i.e. this $userid already exists)
        1 for unique (i.e. this $userid does not exist, or this $userid/$borrowernumber combination already exists)

=cut

sub Check_Userid {
    my ( $uid, $borrowernumber ) = @_;

    return 0 unless ($uid); # userid is a unique column, we should assume NULL is not unique

    return 0 if ( $uid eq C4::Context->config('user') );

    my $rs = Koha::Database->new()->schema()->resultset('Borrower');

    my $params;
    $params->{userid} = $uid;
    $params->{borrowernumber} = { '!=' => $borrowernumber } if ($borrowernumber);

    my $count = $rs->count( $params );

    return $count ? 0 : 1;
}

=head2 Generate_Userid

    my $newuid = Generate_Userid($borrowernumber, $firstname, $surname);

    Generate a userid using the $surname and the $firstname (if there is a value in $firstname).

    $borrowernumber is optional (i.e. it can contain a blank value). A value is passed when generating a new userid for an existing borrower. When a new userid is created for a new borrower, a blank value is passed to this sub.

    return :
        new userid ($firstname.$surname if there is a $firstname, or $surname if there is no value in $firstname) plus offset (0 if the $newuid is unique, or a higher numeric value if Check_Userid finds an existing match for the $newuid in the database).

=cut

sub Generate_Userid {
  my ($borrowernumber, $firstname, $surname) = @_;
  my $newuid;
  my $offset = 0;
  #The script will "do" the following code and increment the $offset until Check_Userid = 1 (i.e. until $newuid comes back as unique)
  do {
    $firstname =~ s/[[:digit:][:space:][:blank:][:punct:][:cntrl:]]//g;
    $surname =~ s/[[:digit:][:space:][:blank:][:punct:][:cntrl:]]//g;
    $newuid = lc(($firstname)? "$firstname.$surname" : $surname);
    $newuid = unac_string('utf-8',$newuid);
    $newuid .= $offset unless $offset == 0;
    $offset++;

   } while (!Check_Userid($newuid,$borrowernumber));

   return $newuid;
}

=head2 fixup_cardnumber

Warning: The caller is responsible for locking the members table in write
mode, to avoid database corruption.

=cut

use vars qw( @weightings );
my @weightings = ( 8, 4, 6, 3, 5, 2, 1 );

sub fixup_cardnumber {
    my ($cardnumber) = @_;
    my $autonumber_members = C4::Context->boolean_preference('autoMemberNum') || 0;

    # Find out whether member numbers should be generated
    # automatically. Should be either "1" or something else.
    # Defaults to "0", which is interpreted as "no".

    #     if ($cardnumber !~ /\S/ && $autonumber_members) {
    ($autonumber_members) or return $cardnumber;
    my $checkdigit = C4::Context->preference('checkdigit');
    my $dbh = C4::Context->dbh;
    if ( $checkdigit and $checkdigit eq 'katipo' ) {

        # if checkdigit is selected, calculate katipo-style cardnumber.
        # otherwise, just use the max()
        # purpose: generate checksum'd member numbers.
        # We'll assume we just got the max value of digits 2-8 of member #'s
        # from the database and our job is to increment that by one,
        # determine the 1st and 9th digits and return the full string.
        my $sth = $dbh->prepare(
            "select max(substring(borrowers.cardnumber,2,7)) as new_num from borrowers"
        );
        $sth->execute;
        my $data = $sth->fetchrow_hashref;
        $cardnumber = $data->{new_num};
        if ( !$cardnumber ) {    # If DB has no values,
            $cardnumber = 1000000;    # start at 1000000
        } else {
            $cardnumber += 1;
        }

        my $sum = 0;
        for ( my $i = 0 ; $i < 8 ; $i += 1 ) {
            # read weightings, left to right, 1 char at a time
            my $temp1 = $weightings[$i];

            # sequence left to right, 1 char at a time
            my $temp2 = substr( $cardnumber, $i, 1 );

            # mult each char 1-7 by its corresponding weighting
            $sum += $temp1 * $temp2;
        }

        my $rem = ( $sum % 11 );
        $rem = 'X' if $rem == 10;

        return "V$cardnumber$rem";
     } else {

        my $sth = $dbh->prepare(
            'SELECT MAX( CAST( cardnumber AS SIGNED ) ) FROM borrowers WHERE cardnumber REGEXP "^-?[0-9]+$"'
        );
        $sth->execute;
        my ($result) = $sth->fetchrow;
        return $result + 1;
    }
    return $cardnumber;     # just here as a fallback/reminder 
}

=head2 GetPendingIssues

  my $issues = &GetPendingIssues(@borrowernumber);

Looks up what the patron with the given borrowernumber has borrowed.

C<&GetPendingIssues> returns a
reference-to-array where each element is a reference-to-hash; the
keys are the fields from the C<issues>, C<biblio>, and C<items> tables.
The keys include C<biblioitems> fields.

=cut

sub GetPendingIssues {
    my @borrowernumbers = @_;

    unless (@borrowernumbers ) { # return a ref_to_array
        return \@borrowernumbers; # to not cause surprise to caller
    }

    # Borrowers part of the query
    my $bquery = '';
    for (my $i = 0; $i < @borrowernumbers; $i++) {
        $bquery .= ' issues.borrowernumber = ?';
        if ($i < $#borrowernumbers ) {
            $bquery .= ' OR';
        }
    }

    # FIXME: namespace collision: each table has "timestamp" fields.  Which one is "timestamp" ?
    # FIXME: circ/ciculation.pl tries to sort by timestamp!
    # FIXME: namespace collision: other collisions possible.
    # FIXME: most of this data isn't really being used by callers.
    my $query =
   "SELECT issues.*,
            items.*,
           biblio.*,
           biblioitems.volume,
           biblioitems.number,
           biblioitems.itemtype,
           biblioitems.isbn,
           biblioitems.issn,
           biblioitems.publicationyear,
           biblioitems.publishercode,
           biblioitems.volumedate,
           biblioitems.volumedesc,
           biblioitems.lccn,
           biblioitems.url,
           borrowers.firstname,
           borrowers.surname,
           borrowers.cardnumber,
           issues.timestamp AS timestamp,
           issues.renewals  AS renewals,
           issues.borrowernumber AS borrowernumber,
            items.renewals  AS totalrenewals
    FROM   issues
    LEFT JOIN items       ON items.itemnumber       =      issues.itemnumber
    LEFT JOIN biblio      ON items.biblionumber     =      biblio.biblionumber
    LEFT JOIN biblioitems ON items.biblioitemnumber = biblioitems.biblioitemnumber
    LEFT JOIN borrowers ON issues.borrowernumber = borrowers.borrowernumber
    WHERE
      $bquery
    ORDER BY issues.issuedate"
    ;

    my $sth = C4::Context->dbh->prepare($query);
    $sth->execute(@borrowernumbers);
    my $data = $sth->fetchall_arrayref({});
    my $today = dt_from_string;
    foreach (@{$data}) {
        if ($_->{issuedate}) {
            $_->{issuedate} = dt_from_string($_->{issuedate}, 'sql');
        }
        $_->{date_due_sql} = $_->{date_due};
        # FIXME no need to have this value
        $_->{date_due} or next;
        $_->{date_due_sql} = $_->{date_due};
        # FIXME no need to have this value
        $_->{date_due} = dt_from_string($_->{date_due}, 'sql');
        if ( DateTime->compare($_->{date_due}, $today) == -1 ) {
            $_->{overdue} = 1;
        }
    }
    return $data;
}

=head2 GetAllIssues

  $issues = &GetAllIssues($borrowernumber, $sortkey, $limit);

Looks up what the patron with the given borrowernumber has borrowed,
and sorts the results.

C<$sortkey> is the name of a field on which to sort the results. This
should be the name of a field in the C<issues>, C<biblio>,
C<biblioitems>, or C<items> table in the Koha database.

C<$limit> is the maximum number of results to return.

C<&GetAllIssues> an arrayref, C<$issues>, of hashrefs, the keys of which
are the fields from the C<issues>, C<biblio>, C<biblioitems>, and
C<items> tables of the Koha database.

=cut

#'
sub GetAllIssues {
    my ( $borrowernumber, $order, $limit ) = @_;

    return unless $borrowernumber;
    $order = 'date_due desc' unless $order;

    my $dbh = C4::Context->dbh;
    my $query =
'SELECT *, issues.timestamp as issuestimestamp, issues.renewals AS renewals,items.renewals AS totalrenewals,items.timestamp AS itemstimestamp
  FROM issues 
  LEFT JOIN items on items.itemnumber=issues.itemnumber
  LEFT JOIN biblio ON items.biblionumber=biblio.biblionumber
  LEFT JOIN biblioitems ON items.biblioitemnumber=biblioitems.biblioitemnumber
  WHERE borrowernumber=? 
  UNION ALL
  SELECT *, old_issues.timestamp as issuestimestamp, old_issues.renewals AS renewals,items.renewals AS totalrenewals,items.timestamp AS itemstimestamp 
  FROM old_issues 
  LEFT JOIN items on items.itemnumber=old_issues.itemnumber
  LEFT JOIN biblio ON items.biblionumber=biblio.biblionumber
  LEFT JOIN biblioitems ON items.biblioitemnumber=biblioitems.biblioitemnumber
  WHERE borrowernumber=? AND old_issues.itemnumber IS NOT NULL
  order by ' . $order;
    if ($limit) {
        $query .= " limit $limit";
    }

    my $sth = $dbh->prepare($query);
    $sth->execute( $borrowernumber, $borrowernumber );
    return $sth->fetchall_arrayref( {} );
}


=head2 GetMemberAccountRecords

  ($total, $acctlines, $count) = &GetMemberAccountRecords($borrowernumber);

Looks up accounting data for the patron with the given borrowernumber.

C<&GetMemberAccountRecords> returns a three-element array. C<$acctlines> is a
reference-to-array, where each element is a reference-to-hash; the
keys are the fields of the C<accountlines> table in the Koha database.
C<$count> is the number of elements in C<$acctlines>. C<$total> is the
total amount outstanding for all of the account lines.

=cut

sub GetMemberAccountRecords {
    my ($borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my @acctlines;
    my $numlines = 0;
    my $strsth      = qq(
                        SELECT * 
                        FROM accountlines 
                        WHERE borrowernumber=?);
    $strsth.=" ORDER BY accountlines_id desc";
    my $sth= $dbh->prepare( $strsth );
    $sth->execute( $borrowernumber );

    my $total = 0;
    while ( my $data = $sth->fetchrow_hashref ) {
        if ( $data->{itemnumber} ) {
            my $biblio = GetBiblioFromItemNumber( $data->{itemnumber} );
            $data->{biblionumber} = $biblio->{biblionumber};
            $data->{title}        = $biblio->{title};
        }
        $acctlines[$numlines] = $data;
        $numlines++;
        $total += sprintf "%.0f", 1000*$data->{amountoutstanding}; # convert float to integer to avoid round-off errors
    }
    $total /= 1000;
    return ( $total, \@acctlines,$numlines);
}

=head2 GetMemberAccountBalance

  ($total_balance, $non_issue_balance, $other_charges) = &GetMemberAccountBalance($borrowernumber);

Calculates amount immediately owing by the patron - non-issue charges.
Based on GetMemberAccountRecords.
Charges exempt from non-issue are:
* Res (reserves)
* Rent (rental) if RentalsInNoissuesCharge syspref is set to false
* Manual invoices if ManInvInNoissuesCharge syspref is set to false

=cut

sub GetMemberAccountBalance {
    my ($borrowernumber) = @_;

    my $ACCOUNT_TYPE_LENGTH = 5; # this is plain ridiculous...

    my @not_fines;
    push @not_fines, 'Res' unless C4::Context->preference('HoldsInNoissuesCharge');
    push @not_fines, 'Rent' unless C4::Context->preference('RentalsInNoissuesCharge');
    unless ( C4::Context->preference('ManInvInNoissuesCharge') ) {
        my $dbh = C4::Context->dbh;
        my $man_inv_types = $dbh->selectcol_arrayref(qq{SELECT authorised_value FROM authorised_values WHERE category = 'MANUAL_INV'});
        push @not_fines, map substr($_, 0, $ACCOUNT_TYPE_LENGTH), @$man_inv_types;
    }
    my %not_fine = map {$_ => 1} @not_fines;

    my ($total, $acctlines) = GetMemberAccountRecords($borrowernumber);
    my $other_charges = 0;
    foreach (@$acctlines) {
        $other_charges += $_->{amountoutstanding} if $not_fine{ substr($_->{accounttype}, 0, $ACCOUNT_TYPE_LENGTH) };
    }

    return ( $total, $total - $other_charges, $other_charges);
}

=head2 GetBorNotifyAcctRecord

  ($total, $acctlines, $count) = &GetBorNotifyAcctRecord($params,$notifyid);

Looks up accounting data for the patron with the given borrowernumber per file number.

C<&GetBorNotifyAcctRecord> returns a three-element array. C<$acctlines> is a
reference-to-array, where each element is a reference-to-hash; the
keys are the fields of the C<accountlines> table in the Koha database.
C<$count> is the number of elements in C<$acctlines>. C<$total> is the
total amount outstanding for all of the account lines.

=cut

sub GetBorNotifyAcctRecord {
    my ( $borrowernumber, $notifyid ) = @_;
    my $dbh = C4::Context->dbh;
    my @acctlines;
    my $numlines = 0;
    my $sth = $dbh->prepare(
            "SELECT * 
                FROM accountlines 
                WHERE borrowernumber=? 
                    AND notify_id=? 
                    AND amountoutstanding != '0' 
                ORDER BY notify_id,accounttype
                ");

    $sth->execute( $borrowernumber, $notifyid );
    my $total = 0;
    while ( my $data = $sth->fetchrow_hashref ) {
        if ( $data->{itemnumber} ) {
            my $biblio = GetBiblioFromItemNumber( $data->{itemnumber} );
            $data->{biblionumber} = $biblio->{biblionumber};
            $data->{title}        = $biblio->{title};
        }
        $acctlines[$numlines] = $data;
        $numlines++;
        $total += int(100 * $data->{'amountoutstanding'});
    }
    $total /= 100;
    return ( $total, \@acctlines, $numlines );
}

sub checkcardnumber {
    my ( $cardnumber, $borrowernumber ) = @_;

    # If cardnumber is null, we assume they're allowed.
    return 0 unless defined $cardnumber;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT * FROM borrowers WHERE cardnumber=?";
    $query .= " AND borrowernumber <> ?" if ($borrowernumber);
    my $sth = $dbh->prepare($query);
    $sth->execute(
        $cardnumber,
        ( $borrowernumber ? $borrowernumber : () )
    );

    return 1 if $sth->fetchrow_hashref;

    my ( $min_length, $max_length ) = get_cardnumber_length();
    return 2
        if length $cardnumber > $max_length
        or length $cardnumber < $min_length;

    return 0;
}

=head2 get_cardnumber_length

    my ($min, $max) = C4::Members::get_cardnumber_length()

Returns the minimum and maximum length for patron cardnumbers as
determined by the CardnumberLength system preference, the
BorrowerMandatoryField system preference, and the width of the
database column.

=cut

sub get_cardnumber_length {
    my ( $min, $max ) = ( 0, 16 ); # borrowers.cardnumber is a nullable varchar(16)
    $min = 1 if C4::Context->preference('BorrowerMandatoryField') =~ /cardnumber/;
    if ( my $cardnumber_length = C4::Context->preference('CardnumberLength') ) {
        # Is integer and length match
        if ( $cardnumber_length =~ m|^\d+$| ) {
            $min = $max = $cardnumber_length
                if $cardnumber_length >= $min
                    and $cardnumber_length <= $max;
        }
        # Else assuming it is a range
        elsif ( $cardnumber_length =~ m|(\d*),(\d*)| ) {
            $min = $1 if $1 and $min < $1;
            $max = $2 if $2 and $max > $2;
        }

    }
    my $borrower = Koha::Schema->resultset('Borrower');
    my $field_size = $borrower->result_source->column_info('cardnumber')->{size};
    $min = $field_size if $min > $field_size;
    return ( $min, $max );
}

=head2 GetFirstValidEmailAddress

  $email = GetFirstValidEmailAddress($borrowernumber);

Return the first valid email address for a borrower, given the borrowernumber.  For now, the order 
is defined as email, emailpro, B_email.  Returns the empty string if the borrower has no email 
addresses.

=cut

sub GetFirstValidEmailAddress {
    my $borrowernumber = shift;

    my $borrower = Koha::Patrons->find( $borrowernumber );

    return $borrower->first_valid_email_address();
}

=head2 GetNoticeEmailAddress

  $email = GetNoticeEmailAddress($borrowernumber);

Return the email address of borrower used for notices, given the borrowernumber.
Returns the empty string if no email address.

=cut

sub GetNoticeEmailAddress {
    my $borrowernumber = shift;

    my $which_address = C4::Context->preference("AutoEmailPrimaryAddress");
    # if syspref is set to 'first valid' (value == OFF), look up email address
    if ( $which_address eq 'OFF' ) {
        return GetFirstValidEmailAddress($borrowernumber);
    }
    # specified email address field
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare( qq{
        SELECT $which_address AS primaryemail
        FROM borrowers
        WHERE borrowernumber=?
    } );
    $sth->execute($borrowernumber);
    my $data = $sth->fetchrow_hashref;
    return $data->{'primaryemail'} || '';
}

=head2 GetBorrowersToExpunge

  $borrowers = &GetBorrowersToExpunge(
      not_borrowed_since => $not_borrowed_since,
      expired_before       => $expired_before,
      category_code        => $category_code,
      patron_list_id       => $patron_list_id,
      branchcode           => $branchcode
  );

  This function get all borrowers based on the given criteria.

=cut

sub GetBorrowersToExpunge {

    my $params = shift;
    my $filterdate       = $params->{'not_borrowed_since'};
    my $filterexpiry     = $params->{'expired_before'};
    my $filterlastseen   = $params->{'last_seen'};
    my $filtercategory   = $params->{'category_code'};
    my $filterbranch     = $params->{'branchcode'} ||
                        ((C4::Context->preference('IndependentBranches')
                             && C4::Context->userenv 
                             && !C4::Context->IsSuperLibrarian()
                             && C4::Context->userenv->{branch})
                         ? C4::Context->userenv->{branch}
                         : "");  
    my $filterpatronlist = $params->{'patron_list_id'};

    my $dbh   = C4::Context->dbh;
    my $query = q|
        SELECT borrowers.borrowernumber,
               MAX(old_issues.timestamp) AS latestissue,
               MAX(issues.timestamp) AS currentissue
        FROM   borrowers
        JOIN   categories USING (categorycode)
        LEFT JOIN (
            SELECT guarantorid
            FROM borrowers
            WHERE guarantorid IS NOT NULL
                AND guarantorid <> 0
        ) as tmp ON borrowers.borrowernumber=tmp.guarantorid
        LEFT JOIN old_issues USING (borrowernumber)
        LEFT JOIN issues USING (borrowernumber)|;
    if ( $filterpatronlist  ){
        $query .= q| LEFT JOIN patron_list_patrons USING (borrowernumber)|;
    }
    $query .= q| WHERE  category_type <> 'S'
        AND tmp.guarantorid IS NULL
   |;
    my @query_params;
    if ( $filterbranch && $filterbranch ne "" ) {
        $query.= " AND borrowers.branchcode = ? ";
        push( @query_params, $filterbranch );
    }
    if ( $filterexpiry ) {
        $query .= " AND dateexpiry < ? ";
        push( @query_params, $filterexpiry );
    }
    if ( $filterlastseen ) {
        $query .= ' AND lastseen < ? ';
        push @query_params, $filterlastseen;
    }
    if ( $filtercategory ) {
        $query .= " AND categorycode = ? ";
        push( @query_params, $filtercategory );
    }
    if ( $filterpatronlist ){
        $query.=" AND patron_list_id = ? ";
        push( @query_params, $filterpatronlist );
    }
    $query.=" GROUP BY borrowers.borrowernumber HAVING currentissue IS NULL ";
    if ( $filterdate ) {
        $query.=" AND ( latestissue < ? OR latestissue IS NULL ) ";
        push @query_params,$filterdate;
    }
    warn $query if $debug;

    my $sth = $dbh->prepare($query);
    if (scalar(@query_params)>0){  
        $sth->execute(@query_params);
    }
    else {
        $sth->execute;
    }
    
    my @results;
    while ( my $data = $sth->fetchrow_hashref ) {
        push @results, $data;
    }
    return \@results;
}

=head2 IssueSlip

  IssueSlip($branchcode, $borrowernumber, $quickslip)

  Returns letter hash ( see C4::Letters::GetPreparedLetter )

  $quickslip is boolean, to indicate whether we want a quick slip

  IssueSlip populates ISSUESLIP and ISSUEQSLIP, and will make the following expansions:

  Both slips:

      <<branches.*>>
      <<borrowers.*>>

  ISSUESLIP:

      <checkedout>
         <<biblio.*>>
         <<items.*>>
         <<biblioitems.*>>
         <<issues.*>>
      </checkedout>

      <overdue>
         <<biblio.*>>
         <<items.*>>
         <<biblioitems.*>>
         <<issues.*>>
      </overdue>

      <news>
         <<opac_news.*>>
      </news>

  ISSUEQSLIP:

      <checkedout>
         <<biblio.*>>
         <<items.*>>
         <<biblioitems.*>>
         <<issues.*>>
      </checkedout>

  NOTE: Not all table fields are available, pleasee see GetPendingIssues for a list of available fields.

=cut

sub IssueSlip {
    my ($branch, $borrowernumber, $quickslip) = @_;

    # FIXME Check callers before removing this statement
    #return unless $borrowernumber;

    my $patron = Koha::Patrons->find( $borrowernumber );
    return unless $patron;

    my @issues = @{ GetPendingIssues($borrowernumber) };

    for my $issue (@issues) {
        $issue->{date_due_orig} = $issue->{date_due};
        $issue->{date_due} = $issue->{date_due_sql};
        if ($quickslip) {
            my $today = output_pref({ dt => dt_from_string, dateformat => 'iso', dateonly => 1 });
            if ( substr( $issue->{issuedate}, 0, 10 ) eq $today
                or substr( $issue->{lastreneweddate}, 0, 10 ) eq $today ) {
                  $issue->{now} = 1;
            };
        }
    }

    # Sort on timestamp then on issuedate (useful for tests and could be if modified in a batch
    @issues = sort {
        my $s = $a->{date_due_orig} <=> $b->{date_due_orig};
        $s == 0 ?
             $b->{timestamp} <=> $a->{timestamp} : $s;
        $s == 0 ?
             $b->{issuedate} <=> $a->{issuedate} : $s;
    } @issues;

    my ($letter_code, %repeat);
    if ( $quickslip ) {
        $letter_code = 'ISSUEQSLIP';
        %repeat =  (
            'checkedout' => [ map {
                'biblio'       => $_,
                'items'        => $_,
                'biblioitems'  => $_,
                'issues'       => $_,
            }, grep { $_->{'now'} } @issues ],
        );
    }
    else {
        $letter_code = 'ISSUESLIP';
        %repeat =  (
            'checkedout' => [ map {
                'biblio'       => $_,
                'items'        => $_,
                'biblioitems'  => $_,
                'issues'       => $_,
            }, grep { !$_->{'overdue'} } @issues ],

            'overdue' => [ map {
                'biblio'       => $_,
                'items'        => $_,
                'biblioitems'  => $_,
                'issues'       => $_,
            }, grep { $_->{'overdue'} } @issues ],

            'news' => [ map {
                $_->{'timestamp'} = $_->{'newdate'};
                { opac_news => $_ }
            } @{ GetNewsToDisplay("slip",$branch) } ],
        );
    }

    my %substitutes = ();
    foreach my $subkey (keys(%repeat)) {
        $substitutes{$subkey."_count"} = "".scalar(@{$repeat{$subkey}});
    }

    return  C4::Letters::GetPreparedLetter (
        module => 'circulation',
        letter_code => $letter_code,
        branchcode => $branch,
        lang => $patron->lang,
        tables => {
            'branches'    => $branch,
            'borrowers'   => $borrowernumber,
        },
        repeat => \%repeat,
        substitute => \%substitutes,
    );
}

sub GetBorrowerFines {
    my ($borrowernumber) = @_;
    my $dbh       = C4::Context->dbh;
    my $query = qq{
        SELECT * FROM accountlines
        LEFT JOIN borrowers ON borrowers.borrowernumber = accountlines.borrowernumber
        LEFT JOIN items ON accountlines.itemnumber = items.itemnumber
        WHERE accountlines.borrowernumber = ?
        ORDER BY accountlines.timestamp
    };
    my $sth = $dbh->prepare( $query );
    $sth->execute( $borrowernumber );
    my $data = $sth->fetchall_arrayref({});
    return $data;
}

sub FineSlip {
    my ($borrowernumber, $branch) = @_;

    #my $now       = POSIX::strftime("%Y-%m-%d", localtime);
    my $patron = Koha::Patrons->find( $borrowernumber );
    return unless $patron;

    my $fineslist = GetBorrowerFines($borrowernumber); #Gets all the fines
    my @unpaidFinesList; #Collect Fines which haven't been paid yet here

    my $total = 0.0;

    foreach my $it (@$fineslist){
        next if ($it->{amountoutstanding} =~ /^0.0+$/); #Skip fines which have been paid already or are payments in itself.
        
        my $dt = dt_from_string( $it->{'date'} );
        $it->{'date_due'} = output_pref({ dt => $dt, dateonly => 1 });
        $it->{'amount'} = sprintf('%.2f', $it->{'amount'});
        $it->{'amountoutstanding'} = sprintf('%.2f', $it->{'amountoutstanding'});
        $total = $total + $it->{'amountoutstanding'};
        $it->{'barcode'} = '-' if (!defined($it->{'barcode'}));
        push @unpaidFinesList, $it;
    }
    @unpaidFinesList = sort { $b->{'timestamp'} <=> $a->{'timestamp'} } @unpaidFinesList;

    my %repeat = (
        'fines' => [ map {
            'fines' => $_,
            'borrowers' => $_,
            'items' => $_
                     }, @unpaidFinesList ],
        );

    return C4::Letters::GetPreparedLetter (
        module => 'circulation',
        letter_code => 'FINESLIP',
        branchcode => $branch,
        lang => $patron->lang,
        tables => {
            'branches'    => $branch,
            'borrowers'   => $borrowernumber,
        },
        substitute => {
            'total.amount' => sprintf('%.2f', $total),
            'total.fines' => scalar(@unpaidFinesList)
        },
        repeat => \%repeat,
        message_transport_type => 'print',
    );
}

=head2 GetTodaysReturnsForBorrower

    $returns = GetTodaysReturnsForBorrower($borrowernumber, $branch);

Return a list of items borrower has checked-in today in any branch.

=cut

sub GetTodaysReturnsForBorrower {
    my ($borrowernumber, $branch) = @_;
    my $dbh  = C4::Context->dbh;
    my $date = POSIX::strftime("%Y-%m-%d",localtime());

    my $query = "
       SELECT itemnumber
       FROM old_issues
       WHERE DATE(returndate) = ?
         AND borrowernumber = ?
    ";

    my $sth = $dbh->prepare($query);
    $sth->execute($date, $borrowernumber);
    my @results;

    while ( my $data = $sth->fetchrow_hashref ) {
        my $bibdata = GetBiblioFromItemNumber($data->{itemnumber});
        push @results, $bibdata;
    }
    return \@results;
}

=head2 CheckInSlip

    $letter = CheckInSlip($borrowernumber, $branch [, $message_transport_type ] );

Returns the prepared letter data for items patron checked-in today in branch.
message_transport_type defaults to 'print'.

=cut

sub CheckInSlip {
    my ($borrowernumber, $branch, $mtt) = @_;

    my $patron = Koha::Patrons->find( $borrowernumber );
    return unless $patron;

    my $issues = GetTodaysReturnsForBorrower($borrowernumber, $branch);
    my %repeat = (
            'checkedin' => [ map {
                'biblio' => $_,
                'items'  => $_,
                'issues' => $_,
            }, @$issues ],
        );

    return  C4::Letters::GetPreparedLetter (
        module => 'circulation',
        letter_code => 'CHECKINSLIP',
        branchcode => $branch,
        lang => $patron->lang,
        tables => {
            'branches'    => $branch,
            'borrowers'   => $borrowernumber,
        },
        repeat => \%repeat,
        message_transport_type => $mtt || 'print',
    );
}

=head2 AddMember_Auto

=cut

sub AddMember_Auto {
    my ( %borrower ) = @_;

    $borrower{'cardnumber'} ||= fixup_cardnumber();

    $borrower{'borrowernumber'} = AddMember(%borrower);

    return ( %borrower );
}

=head2 AddMember_Opac

=cut

sub AddMember_Opac {
    my ( %borrower ) = @_;

    $borrower{'categorycode'} //= C4::Context->preference('PatronSelfRegistrationDefaultCategory');
    if (not defined $borrower{'password'}){
        my $sr = new String::Random;
        $sr->{'A'} = [ 'A'..'Z', 'a'..'z' ];
        my $password = $sr->randpattern("AAAAAAAAAA");
        $borrower{'password'} = $password;
    }

    %borrower = AddMember_Auto(%borrower);

    return ( $borrower{'borrowernumber'}, $borrower{'password'} );
}

=head2 DeleteExpiredOpacRegistrations

    Delete accounts that haven't been upgraded from the 'temporary' category
    Returns the number of removed patrons

=cut

sub DeleteExpiredOpacRegistrations {

    my $delay = C4::Context->preference('PatronSelfRegistrationExpireTemporaryAccountsDelay');
    my $category_code = C4::Context->preference('PatronSelfRegistrationDefaultCategory');

    return 0 if not $category_code or not defined $delay or $delay eq q||;

    my $query = qq|
SELECT borrowernumber
FROM borrowers
WHERE categorycode = ? AND DATEDIFF( NOW(), dateenrolled ) > ? |;

    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute( $category_code, $delay );
    my $cnt=0;
    while ( my ($borrowernumber) = $sth->fetchrow_array() ) {
        Koha::Patrons->find($borrowernumber)->delete;
        $cnt++;
    }
    return $cnt;
}

=head2 DeleteUnverifiedOpacRegistrations

    Delete all unverified self registrations in borrower_modifications,
    older than the specified number of days.

=cut

sub DeleteUnverifiedOpacRegistrations {
    my ( $days ) = @_;
    my $dbh = C4::Context->dbh;
    my $sql=qq|
DELETE FROM borrower_modifications
WHERE borrowernumber = 0 AND DATEDIFF( NOW(), timestamp ) > ?|;
    my $cnt=$dbh->do($sql, undef, ($days) );
    return $cnt eq '0E0'? 0: $cnt;
}

sub GetOverduesForPatron {
    my ( $borrowernumber ) = @_;

    my $sql = "
        SELECT *
        FROM issues, items, biblio, biblioitems
        WHERE items.itemnumber=issues.itemnumber
          AND biblio.biblionumber   = items.biblionumber
          AND biblio.biblionumber   = biblioitems.biblionumber
          AND issues.borrowernumber = ?
          AND date_due < NOW()
    ";

    my $sth = C4::Context->dbh->prepare( $sql );
    $sth->execute( $borrowernumber );

    return $sth->fetchall_arrayref({});
}

=head2 GenMemberPasswordSuggestion

    $password = GenMemberPasswordSuggestion($borrowernumber);

Returns a new patron password suggestion based on borrowers password policy from categories

=cut

sub GenMemberPasswordSuggestion {
    my $categorycode = shift;
    my $categoryinfo = Koha::Patron::Categories->find($categorycode);
    my $policycode = $categoryinfo->passwordpolicy;
    my $minpasslength = minPasswordLength($categorycode);

    my $pass;

    # KD#1454 - Changed in order to generate exactly $minpasslength long passwords
    # longer ones would cause problems with self-service library use
    my $length = $minpasslength ? $minpasslength : 4;

    if ($policycode) {
        # Generates complex passwords with numbers and uppercase, lowercase and special characters
        if ($policycode eq "complex") {
            my $specials = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_'];
            $pass = App::Genpass->new(specials => $specials, readable => 0, length => $length);
        }

        # Generates simple passwords with numbers and uppercase and lowercase characters
        elsif ($policycode eq "alphanumeric") {
            $pass = App::Genpass->new(length => $length);
        }

        # Generates passwords with digits 0-9 only
        else {
            # verify => 0 due to a bug in generate() (workaround)
            $pass = App::Genpass->new(lowercase => [], uppercase => [], verify => 0, length => $length);
        }
    }
    # Defaults to empty constuctor which gives readable complex passwords
    else {
        $pass = App::Genpass->new(length => $length, lowercase => [], uppercase => [], verify => 0);
    }

    return $pass->generate();
}

=head2 ValidateMemberPassword

    ($success, $errorcode, $errormessage) = ValidateMemberPassword($categorycode, $newpassword1, $newpassword2);

Validates a member's password based on category password policy and/or minPasswordLength

=cut

sub ValidateMemberPassword {
    my ($categorycode, $newpassword1, $newpassword2) = @_;
    if (!$categorycode) {
        return (0, ,"NOCATEGORY", "No category given");
    }
    my $categoryinfo = Koha::Patron::Categories->find($categorycode);
    my $passwordpolicy = $categoryinfo->passwordpolicy;
    my $minpasslength = minPasswordLength($categorycode);
    # KD#1454 - Add individual minimum password lengths for different policies (validate)
    if ($newpassword1 eq $newpassword2) {
        if ($newpassword1 =~ m|^\s+| or $newpassword1 =~ m|\s+$|) {
            return (0, "WHITESPACEMATCH", "Password policy: password contains leading or trailing whitespace");
        } else {
            if ($passwordpolicy) {
                if ($passwordpolicy eq "complex") {
                    unless ($newpassword1 =~ /[0-9]/
                            && $newpassword1 =~ /[a-zåäö]/
                            && $newpassword1 =~ /[A-ZÅÄÖ]/
                            && $newpassword1 =~ /[\|\[\]\{\}!@#\$%\^&\*\(\)_\-\+\?]/
                            && length($newpassword1) >= $minpasslength ) {
                        return (0, "NOCOMPLEXPOLICYMATCH", "Password policy: password must contain numbers, lower and uppercase characters and special characters and must be at least $minpasslength characters long");
                    }

                }
                elsif ($passwordpolicy eq "alphanumeric") {
                   unless ($newpassword1 =~ /[0-9]/
                            && $newpassword1 =~ /[a-zA-ZöäåÖÄÅ]/
                            && $newpassword1 !~ /\W/
                            && $newpassword1 !~ /[_-]/
                            && length($newpassword1) >= $minpasslength ) {
                        return (0, "NOALPHAPOLICYMATCH", "Password policy: password must contain both numbers and non-special characters and must be at least $minpasslength characters long");
                    }
                }
                else {
                    if ($newpassword1 !~ /^[0-9]+$/ || length($newpassword1) < $minpasslength) {
                        return (0, "NOSIMPLEPOLICYMATCH", "Password policy: password can only contain digits 0-9 and must be at least $minpasslength characters long");
                    }
                }
            } elsif (defined $minpasslength && length($newpassword1) < $minpasslength) {
                return (0, "NOLENGTHMATCH", "Password policy: password must be at least $minpasslength characters long");
            }
        }
    } else {
        return (0, "NOPASSWORDMATCH", "The passwords do not match.");
    }
    return 1;
}

=head2 minPasswordLength

    $minpasslength = minPasswordLength($categorycode);

Returns correct minPasswordLength

=cut

sub minPasswordLength {
    my $categorycode = shift;
    my $categoryinfo = Koha::Patron::Categories->find($categorycode);
    my $passwordpolicy = $categoryinfo->passwordpolicy if $categoryinfo;
    my $minpasslen;
    if ($passwordpolicy eq "complex") {
        $minpasslen = C4::Context->preference("minComplexPasswordLength");
    }elsif ($passwordpolicy eq "alphanumeric") {
        $minpasslen = C4::Context->preference("minAlnumPasswordLength");
    }else {
        $minpasslen = C4::Context->preference("minPasswordLength");
    }
    return $minpasslen;
}


=head2 getModifiedPatronFieldsForLogs

    $updatedfields = getModifiedPatronFieldsForLogs($data);

Returns string of fields that will be changed

=cut

sub getModifiedPatronFieldsForLogs {
    my ($data, $olddata) = @_;

    my $logdata;
    $olddata //= Koha::Patrons->find( $data->{borrowernumber} )->unblessed;

    foreach my $key ( keys %$data ) {
        my $od = defined $olddata->{$key} ? $olddata->{$key} : 'undef';
        my $nd = defined $data->{$key} ? $data->{$key} : 'undef';
        $logdata .= $key.": $od => $nd, " if ( $olddata->{$key} ne $data->{$key});
    }

    $logdata =~ s/,\s+$//;

    return $logdata;
}


END { }    # module clean-up code here (global destructor)

1;

__END__

=head1 AUTHOR

Koha Team

=cut
