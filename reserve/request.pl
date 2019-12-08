#!/usr/bin/perl


#written 2/1/00 by chris@katipo.oc.nz
# Copyright 2000-2002 Katipo Communications
# Parts Copyright 2011 Catalyst IT
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

=head1 request.pl

script to place reserves/requests

=cut

use Modern::Perl;

use CGI qw ( -utf8 );
use List::MoreUtils qw/uniq/;
use Date::Calc qw/Date_to_Days/;
use POSIX;
use C4::Output;
use C4::Auth;
use C4::Reserves;
use C4::Biblio;
use C4::Items;
use C4::Koha;
use C4::Circulation;
use Koha::DateUtils;
use C4::Utils::DataTables::Members;
use C4::Members;
use C4::Search;		# enabled_staff_search_views
use Koha::DateUtils;
use Koha::Holds;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Libraries;
use Koha::Patrons;

my $dbh = C4::Context->dbh;
my $input = new CGI;
my ( $template, $borrowernumber, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => "reserve/request.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { reserveforothers => 'place_holds' },
    }
);

my $multihold = $input->param('multi_hold');
$template->param(multi_hold => $multihold);
my $showallitems = $input->param('showallitems');

my $itemtypes = { map { $_->{itemtype} => $_ } @{ Koha::ItemTypes->search_with_localization->unblessed } };

# Select borrowers infos
my $findborrower = $input->param('findborrower');
$findborrower = '' unless defined $findborrower;
$findborrower =~ s|,| |g;
my $borrowernumber_hold = $input->param('borrowernumber') || '';
my $page = $input->param('page') || 1;
my $messageborrower;
my $warnings;
my $messages;
my $exceeded_maxreserves;
my $exceeded_holds_per_record;

my $date = output_pref({ dt => dt_from_string, dateformat => 'iso', dateonly => 1 });
my $action = $input->param('action');
$action ||= q{};

if ( $action eq 'move' ) {
  my $where = $input->param('where');
  my $reserve_id = $input->param('reserve_id');
  AlterPriority( $where, $reserve_id );
} elsif ( $action eq 'cancel' ) {
  my $reserve_id = $input->param('reserve_id');
  CancelReserve({ reserve_id => $reserve_id });
} elsif ( $action eq 'setLowestPriority' ) {
  my $reserve_id = $input->param('reserve_id');
  ToggleLowestPriority( $reserve_id );
} elsif ( $action eq 'toggleSuspend' ) {
  my $reserve_id = $input->param('reserve_id');
  my $suspend_until  = $input->param('suspend_until');
  ToggleSuspend( $reserve_id, $suspend_until );
}

if ($findborrower) {
    my $borrower = C4::Members::GetMember( cardnumber => $findborrower );
    if ( $borrower ) {
        $borrowernumber_hold = $borrower->{borrowernumber};
    } else {
        my $dt_params = { iDisplayLength => 100 };
        my $results = C4::Utils::DataTables::Members::search(
            {
                searchmember => $findborrower,
                dt_params => $dt_params,
            }
        );
        my $borrowers = $results->{patrons};
        if ( scalar @$borrowers == 1 ) {
            $borrowernumber_hold = $borrowers->[0]->{borrowernumber};
        } elsif ( @$borrowers ) {
            $template->param( borrowers => $borrowers );
        } else {
            $messageborrower = "'$findborrower'";
        }
    }
}

my @biblionumbers = ();
my $biblionumbers = $input->param('biblionumbers');
if ($multihold) {
    @biblionumbers = split '/', $biblionumbers;
} else {
    push @biblionumbers, $input->multi_param('biblionumber');
}


# If we have the borrowernumber because we've performed an action, then we
# don't want to try to place another reserve.
if ($borrowernumber_hold && !$action) {
    my $borrowerinfo = GetMember( borrowernumber => $borrowernumber_hold );
    my $diffbranch;

    # we check the reserves of the user, and if they can reserve a document
    # FIXME At this time we have a simple count of reservs, but, later, we could improve the infos "title" ...

    my $reserves_count =
      GetReserveCount( $borrowerinfo->{'borrowernumber'} );

    my $new_reserves_count = scalar( @biblionumbers );

    my $maxreserves = C4::Context->preference('maxreserves');
    if ( $maxreserves
        && ( $reserves_count + $new_reserves_count > $maxreserves ) )
    {
        my $new_reserves_allowed =
            $maxreserves - $reserves_count > 0
          ? $maxreserves - $reserves_count
          : 0;
        $warnings             = 1;
        $exceeded_maxreserves = 1;
        $template->param(
            new_reserves_allowed => $new_reserves_allowed,
            new_reserves_count   => $new_reserves_count,
            reserves_count       => $reserves_count,
            maxreserves          => $maxreserves,
        );
    }

    # we check the date expiry of the borrower (only if there is an expiry date, otherwise, set to 1 (warn)
    my $expiry_date = $borrowerinfo->{dateexpiry};
    my $expiry = 0; # flag set if patron account has expired
    if ($expiry_date and $expiry_date ne '0000-00-00' and
        Date_to_Days(split /-/,$date) > Date_to_Days(split /-/,$expiry_date)) {
        $expiry = 1;
    }

    # check if the borrower make the reserv in a different branch
    if ( $borrowerinfo->{'branchcode'} ne C4::Context->userenv->{'branch'} ) {
        $diffbranch = 1;
    }

    my $is_debarred = Koha::Patrons->find( $borrowerinfo->{borrowernumber} )->is_debarred;
    $template->param(
                borrowernumber      => $borrowerinfo->{'borrowernumber'},
                borrowersurname     => $borrowerinfo->{'surname'},
                borrowerfirstname   => $borrowerinfo->{'firstname'},
                borrowerstreetaddress   => $borrowerinfo->{'address'},
                borrowercity        => $borrowerinfo->{'city'},
                borrowerphone       => $borrowerinfo->{'phone'},
                borrowermobile      => $borrowerinfo->{'mobile'},
                borrowerfax         => $borrowerinfo->{'fax'},
                borrowerphonepro    => $borrowerinfo->{'phonepro'},
                borroweremail       => $borrowerinfo->{'email'},
                borroweremailpro    => $borrowerinfo->{'emailpro'},
                borrowercategory    => $borrowerinfo->{'category'},
                cardnumber          => $borrowerinfo->{'cardnumber'},
                expiry              => $expiry,
                diffbranch          => $diffbranch,
                messages            => $messages,
                warnings            => $warnings,
                restricted          => $is_debarred,
                amount_outstanding  => GetMemberAccountRecords($borrowerinfo->{borrowernumber}),
    );
}

$template->param( messageborrower => $messageborrower );

# FIXME launch another time GetMember perhaps until
my $borrowerinfo = GetMember( borrowernumber => $borrowernumber_hold );

my $logged_in_patron = Koha::Patrons->find( $borrowernumber );

my $itemdata_enumchron = 0;
my @biblioloop = ();
foreach my $biblionumber (@biblionumbers) {
    next unless $biblionumber =~ m|^\d+$|;

    my %biblioloopiter = ();

    my $dat = GetBiblioData($biblionumber);

    my $force_hold_level;
    if ( $borrowerinfo ) {
        my $canReserve = CanBookBeReserved( $borrowerinfo->{borrowernumber}, $biblionumber );
        $canReserve //= '';
        if ( $canReserve eq 'OK' ) {

            #All is OK and we can continue
        }
        elsif ( $canReserve eq 'tooManyReserves' ) {
            $exceeded_maxreserves = 1;
        }
        elsif ( $canReserve eq 'tooManyHoldsForThisRecord' ) {
            $exceeded_holds_per_record = 1;
            $biblioloopiter{$canReserve} = 1;
        }
        elsif ( $canReserve eq 'ageRestricted' ) {
            $template->param( $canReserve => 1 );
            $biblioloopiter{$canReserve} = 1;
        }
        else {
            $biblioloopiter{$canReserve} = 1;
        }

        if ( $borrowerinfo->{borrowernumber} ) {
            # For multiple holds per record, if a patron has previously placed a hold,
            # the patron can only place more holds of the same type. That is, if the
            # patron placed a record level hold, all the holds the patron places must
            # be record level. If the patron placed an item level hold, all holds
            # the patron places must be item level
            my $holds = Koha::Holds->search(
                {
                    borrowernumber => $borrowerinfo->{borrowernumber},
                    biblionumber   => $biblionumber,
                    found          => undef,
                }
            );
            $force_hold_level = $holds->forced_hold_level();
            $biblioloopiter{force_hold_level} = $force_hold_level;
            $template->param( force_hold_level => $force_hold_level );

            # For a librarian to be able to place multiple record holds for a patron for a record,
            # we must find out what the maximum number of holds they can place for the patron is
            my $max_holds_for_record = GetMaxPatronHoldsForRecord( $borrowerinfo->{borrowernumber}, $biblionumber );
            my $remaining_holds_for_record = $max_holds_for_record - $holds->count();
            $biblioloopiter{remaining_holds_for_record} = $max_holds_for_record;
            $template->param( max_holds_for_record => $max_holds_for_record );
            $template->param( remaining_holds_for_record => $remaining_holds_for_record );
        }

        # Check to see if patron is allowed to place holds on records where the
        # patron already has an item from that record checked out
        my $alreadypossession;
        if ( !C4::Context->preference('AllowHoldsOnPatronsPossessions')
            && CheckIfIssuedToPatron( $borrowerinfo->{borrowernumber}, $biblionumber ) )
        {
            $template->param( alreadypossession => $alreadypossession, );
        }
    }

    my $count = Koha::Holds->search( { biblionumber => $biblionumber } )->count();
    my $totalcount = $count;

    # FIXME think @optionloop, is maybe obsolete, or  must be switchable by a systeme preference fixed rank or not
    # make priorities options

    my @optionloop;
    for ( 1 .. $count + 1 ) {
        push(
             @optionloop,
             {
              num      => $_,
              selected => ( $_ == $count + 1 ),
             }
            );
    }
    # adding a fixed value for priority options
    my $fixedRank = $count+1;

    my %itemnumbers_of_biblioitem;

    my @hostitems = get_hostitemnumbers_of($biblionumber);
    my @itemnumbers;
    if (@hostitems){
        $template->param('hostitemsflag' => 1);
        push(@itemnumbers, @hostitems);
    }

    my $items = Koha::Items->search({ -or => { biblionumber => $biblionumber, itemnumber => { in => \@itemnumbers } } });

    unless ( $items->count ) {
        # FIXME Then why do we continue?
        $template->param('noitems' => 1);
        $biblioloopiter{noitems} = 1;
    }

    ## Here we go backwards again to create hash of biblioitemnumber to itemnumbers,
    ## when by definition all of the itemnumber have the same biblioitemnumber
    my ( $iteminfos_of );
    while ( my $item = $items->next ) {
        $item = $item->unblessed;
        my $biblioitemnumber = $item->{biblioitemnumber};
        my $itemnumber = $item->{itemnumber};
        push( @{ $itemnumbers_of_biblioitem{$biblioitemnumber} }, $itemnumber );
        $iteminfos_of->{$itemnumber} = $item;
    }

    ## Should be same as biblionumber
    my @biblioitemnumbers = keys %itemnumbers_of_biblioitem;

    ## Hash of biblioitemnumber to 'biblioitem' table records
    my $biblioiteminfos_of  = GetBiblioItemInfosOf(@biblioitemnumbers);

    my $frameworkcode = GetFrameworkCode( $biblionumber );
    my @notforloan_avs = Koha::AuthorisedValues->search_by_koha_field({ kohafield => 'items.notforloan', frameworkcode => $frameworkcode });
    my $notforloan_label_of = { map { $_->authorised_value => $_->lib } @notforloan_avs };

    my @bibitemloop;

    my @available_itemtypes;
    foreach my $biblioitemnumber (@biblioitemnumbers) {
        my $biblioitem = $biblioiteminfos_of->{$biblioitemnumber};
        my $num_available = 0;
        my $num_override  = 0;
        my $hiddencount   = 0;

        $biblioitem->{force_hold_level} = $force_hold_level;

        if ( $biblioitem->{biblioitemnumber} ne $biblionumber ) {
            $biblioitem->{hostitemsflag} = 1;
        }

        $biblioloopiter{description} = $biblioitem->{description};
        $biblioloopiter{itypename}   = $biblioitem->{description};
        if ( $biblioitem->{itemtype} ) {

            $biblioitem->{description} =
              $itemtypes->{ $biblioitem->{itemtype} }{description};

            $biblioloopiter{imageurl} =
              getitemtypeimagelocation( 'intranet',
                $itemtypes->{ $biblioitem->{itemtype} }{imageurl} );
        }

        # this is hash cache for "if any unavailable" on-shelf holds check
        # in IsAvailableForItemLevelRequest sub should persist outside from the loop
        my %caches_avail_item_level;

        foreach my $itemnumber ( @{ $itemnumbers_of_biblioitem{$biblioitemnumber} } )    {
            my $item = $iteminfos_of->{$itemnumber};

            $item->{force_hold_level} = $force_hold_level;

            unless (C4::Context->preference('item-level_itypes')) {
                $item->{itype} = $biblioitem->{itemtype};
            }

            $item->{itypename} = $itemtypes->{ $item->{itype} }{description};
            $item->{imageurl} = getitemtypeimagelocation( 'intranet', $itemtypes->{ $item->{itype} }{imageurl} );
            $item->{homebranch} = $item->{homebranch};

            # if the holdingbranch is different than the homebranch, we show the
            # holdingbranch of the document too
            if ( $item->{homebranch} ne $item->{holdingbranch} ) {
                $item->{holdingbranch} = $item->{holdingbranch};
            }

		if($item->{biblionumber} ne $biblionumber){
			$item->{hostitemsflag}=1;
		        $item->{hosttitle} = GetBiblioData($item->{biblionumber})->{title};
		}
		
            # if the item is currently on loan, we display its return date and
            # change the background color
            my $issues= GetItemIssue($itemnumber);
            if ( $issues->{'date_due'} ) {
                $item->{date_due} = $issues->{date_due_sql};
                $item->{backgroundcolor} = 'onloan';
            }

            # checking reserve
            my $holds = Koha::Items->find( $itemnumber )->current_holds;
            if ( my $first_hold = $holds->next ) {
                my $ItemBorrowerReserveInfo = GetMember( borrowernumber => $first_hold->borrowernumber );

                $item->{backgroundcolor} = 'reserved';
                $item->{reservedate}     = output_pref({ dt => dt_from_string( $first_hold->reservedate ), dateonly => 1 }); # FIXME Should be formatted in the template
                $item->{ReservedForBorrowernumber}     = $first_hold->borrowernumber;
                $item->{ReservedForSurname}     = $ItemBorrowerReserveInfo->{'surname'};
                $item->{ReservedForFirstname}     = $ItemBorrowerReserveInfo->{'firstname'};
                $item->{ExpectedAtLibrary}     = $first_hold->branchcode;
                $item->{waitingdate} = $first_hold->waitingdate;
            }

            # Management of the notforloan document
            if ( $item->{notforloan} ) {
                $item->{backgroundcolor} = 'other';
                $item->{notforloanvalue} =
                  $notforloan_label_of->{ $item->{notforloan} };
            }

            # Management of lost or long overdue items
            if ( $item->{itemlost} ) {

                # FIXME localized strings should never be in Perl code
                $item->{message} =
                  $item->{itemlost} == 1 ? "(lost)"
                    : $item->{itemlost} == 2 ? "(long overdue)"
                      : "";
                $item->{backgroundcolor} = 'other';
                if ($logged_in_patron->category->hidelostitems && !$showallitems) {
                    $item->{hide} = 1;
                    $hiddencount++;
                }
            }

            # Check the transit status
            my ( $transfertwhen, $transfertfrom, $transfertto ) =
              GetTransfers($itemnumber);

            if ( defined $transfertwhen && $transfertwhen ne '' ) {
                $item->{transfertwhen} = output_pref({ dt => dt_from_string( $transfertwhen ), dateonly => 1 });
                $item->{transfertfrom} = $transfertfrom;
                $item->{transfertto} = $transfertto;
                $item->{nocancel} = 1;
            }

            # If there is no loan, return and transfer, we show a checkbox.
            $item->{notforloan} ||= 0;

            # if independent branches is on we need to check if the person can reserve
            # for branches they arent logged in to
            if ( C4::Context->preference("IndependentBranches") ) {
                if (! C4::Context->preference("canreservefromotherbranches")){
                    # cant reserve items so need to check if item homebranch and userenv branch match if not we cant reserve
                    my $userenv = C4::Context->userenv;
                    unless ( C4::Context->IsSuperLibrarian ) {
                        $item->{cantreserve} = 1 if ( $item->{homebranch} ne $userenv->{branch} );
                    }
                }
            }

            if ( $borrowerinfo ) {
                my $branch = C4::Circulation::_GetCircControlBranch($item, $borrowerinfo);

                my $branchitemrule = GetBranchItemRule( $branch, $item->{'itype'} );

                $item->{'holdallowed'} = $branchitemrule->{'holdallowed'};

                my $can_item_be_reserved = CanItemBeReserved( $borrowerinfo->{borrowernumber}, $itemnumber );
                $item->{not_holdable} = $can_item_be_reserved unless ( $can_item_be_reserved eq 'OK' );

                $item->{item_level_holds} = OPACItemHoldsAllowed( $item, $borrowerinfo );

                if (
                       !$item->{cantreserve}
                    && !$exceeded_maxreserves
                    && $can_item_be_reserved eq 'OK'
                    && IsAvailableForItemLevelRequest($item, $borrowerinfo, \%caches_avail_item_level)
                  )
                {
                    $item->{available} = 1;
                    $num_available++;

                    push( @available_itemtypes, $item->{itype} );
                }
                elsif ( C4::Context->preference('AllowHoldPolicyOverride') ) {
                    # If AllowHoldPolicyOverride is set, it should override EVERY restriction, not just branch item rules
                    $item->{override} = 1;
                    $num_override++;
                }

                # If none of the conditions hold true, then neither override nor available is set and the item cannot be checked

                # Show serial enumeration when needed
                if ($item->{enumchron}) {
                    $itemdata_enumchron = 1;
                }
            }

            push @{ $biblioitem->{itemloop} }, $item;
        }

        if ( $num_override == scalar( @{ $biblioitem->{itemloop} } ) ) { # That is, if all items require an override
            $template->param( override_required => 1 );
        } elsif ( $num_available == 0 ) {
            $template->param( none_available => 1 );
            $biblioloopiter{warn} = 1;
            $biblioloopiter{none_avail} = 1;
        }
        $template->param( hiddencount => $hiddencount);

        push @bibitemloop, $biblioitem;
    }

    @available_itemtypes = uniq( @available_itemtypes );
    $template->param( available_itemtypes => \@available_itemtypes );

    # existingreserves building
    my @reserveloop;
    my $rows = 50;
    my @reserves = Koha::Holds->search( { biblionumber => $biblionumber }, { order_by => 'priority', page => $page, rows => $rows } );
    foreach my $res (
        sort {
            my $a_found = $a->found() || '';
            my $b_found = $a->found() || '';
            $a_found cmp $b_found;
        } @reserves
      )
    {
        my $priority = $res->priority();
        my %reserve;
        my @optionloop;
        for ( my $i = 1 ; $i <= $totalcount ; $i++ ) {
            push(
                @optionloop,
                {
                    num      => $i,
                    selected => ( $i == $priority ),
                }
            );
        }

        if ( $res->is_found() ) {
            $reserve{'holdingbranch'} = $res->item()->holdingbranch();
            $reserve{'biblionumber'}  = $res->item()->biblionumber();
            $reserve{'barcodenumber'} = $res->item()->barcode();
            $reserve{'wbrcode'}       = $res->branchcode();
            $reserve{'itemnumber'}    = $res->itemnumber();
            $reserve{'wbrname'}       = $res->branch()->branchname();

            if ( $reserve{'holdingbranch'} eq $reserve{'wbrcode'} ) {

                # Just because the holdingbranch matches the reserve branch doesn't mean the item
                # has arrived at the destination, check for an open transfer for the item as well
                my ( $transfertwhen, $transfertfrom, $transferto ) =
                  C4::Circulation::GetTransfers( $res->itemnumber() );
                if ( not $transferto or $transferto ne $res->branchcode() ) {
                    $reserve{'atdestination'} = 1;
                }
            }

            # set found to 1 if reserve is waiting for patron pickup
            $reserve{'found'}     = $res->is_found();
            $reserve{'intransit'} = $res->is_in_transit();
        }
        elsif ( $res->priority() > 0 ) {
            if ( my $item = $res->item() )  {
                $reserve{'itemnumber'}      = $item->id();
                $reserve{'barcodenumber'}   = $item->barcode();
                $reserve{'item_level_hold'} = 1;
            }
        }

        #     get borrowers reserve info
        if ( C4::Context->preference('HidePatronName') ) {
            $reserve{'hidename'}   = 1;
            $reserve{'cardnumber'} = $res->borrower()->cardnumber();
        }
        $reserve{'expirationdate'} = output_pref( { dt => dt_from_string( $res->expirationdate ), dateonly => 1 } )
          unless ( !defined( $res->expirationdate ) || $res->expirationdate eq '0000-00-00' );
        $reserve{'date'}           = output_pref( { dt => dt_from_string( $res->reservedate ), dateonly => 1 } );
        $reserve{'borrowernumber'} = $res->borrowernumber();
        $reserve{'biblionumber'}   = $res->biblionumber();
        $reserve{'borrowernumber'} = $res->borrowernumber();
        $reserve{'firstname'}      = $res->borrower()->firstname();
        $reserve{'surname'}        = $res->borrower()->surname();
        $reserve{'notes'}          = $res->reservenotes();
        $reserve{'waiting_date'}   = $res->waitingdate();
        $reserve{'ccode'}          = $res->item() ? $res->item()->ccode() : undef;
        $reserve{'barcode'}        = $res->item() ? $res->item()->barcode() : undef;
        $reserve{'priority'}       = $res->priority();
        $reserve{'lowestPriority'} = $res->lowestPriority();
        $reserve{'optionloop'}     = \@optionloop;
        $reserve{'suspend'}        = $res->suspend();
        $reserve{'suspend_until'}  = $res->suspend_until();
        $reserve{'reserve_id'}     = $res->reserve_id();
        $reserve{itemtype}         = $res->itemtype();
        $reserve{branchcode}       = $res->branchcode();

        push( @reserveloop, \%reserve );
    }

    # get the time for the form name...
    my $time = time();

    $template->param(
                     time        => $time,
                     fixedRank   => $fixedRank,
                    );

    # display infos
    $template->param(
                     optionloop        => \@optionloop,
                     bibitemloop       => \@bibitemloop,
                     itemdata_enumchron => $itemdata_enumchron,
                     date              => $date,
                     biblionumber      => $biblionumber,
                     findborrower      => $findborrower,
                     title             => $dat->{title},
                     author            => $dat->{author},
                     holdsview => 1,
                     C4::Search::enabled_staff_search_views,
                    );
    if (defined $borrowerinfo && exists $borrowerinfo->{'branchcode'}) {
        $template->param( borrower_branchcode => $borrowerinfo->{'branchcode'},);
    }

    $biblioloopiter{biblionumber} = $biblionumber;
    $biblioloopiter{title} = $dat->{title};
    $biblioloopiter{rank} = $fixedRank;
    $biblioloopiter{reserveloop} = \@reserveloop;
    $biblioloopiter{pages} = pagination($totalcount, $page, 10, $rows);

    if (@reserveloop) {
        $template->param( reserveloop => \@reserveloop );
    }

    push @biblioloop, \%biblioloopiter;
}

$template->param( biblioloop => \@biblioloop );
$template->param( biblionumbers => $biblionumbers );
$template->param( exceeded_maxreserves => $exceeded_maxreserves );
$template->param( exceeded_holds_per_record => $exceeded_holds_per_record );

if ($multihold) {
    $template->param( multi_hold => 1 );
}

if ( C4::Context->preference( 'AllowHoldDateInFuture' ) ) {
    $template->param( reserve_in_future => 1 );
}

$template->param(
    SuspendHoldsIntranet => C4::Context->preference('SuspendHoldsIntranet'),
    AutoResumeSuspendedHolds => C4::Context->preference('AutoResumeSuspendedHolds'),
);

# printout the page
output_html_with_http_headers $input, $cookie, $template->output;

sub sort_borrowerlist {
    my $borrowerslist = shift;
    my $ref           = [];
    push @{$ref}, sort {
        uc( $a->{surname} . $a->{firstname} ) cmp
          uc( $b->{surname} . $b->{firstname} )
    } @{$borrowerslist};
    return $ref;
}

sub pagination {
    my ($totalcount, $page, $shownpages, $rows) = @_;
    my $totalpages = $totalcount/$rows;
    $totalpages = ceil($totalpages);

    my $previous = $page-1 if $page > 1;
    my $next = $page+1 if $page < $totalpages;

    my @pagenumbers;

    for ( my $i = 1 ; $i <= $totalpages ; $i++ ) {
        push @pagenumbers, $i;
    }

    my $pagechunks = {};
    my $pagelist = {};
    my $pagecount = 1;
    while( my @lists = splice( @pagenumbers, 0, $shownpages ) ) {
         $pagechunks->{$pagecount} = \@lists ;
         foreach my $list (@lists) {
            $pagelist->{$list} = $pagecount;
         }
         $pagecount++;
    }

    my $pagegroup = $pagelist->{$page};

    my $pages = {};

    $pages->{group} = $pagechunks->{$pagegroup};
    $pages->{page} = $page;
    $pages->{lastpage} = $totalpages;
    $pages->{previous} = $previous;
    $pages->{next} = $next;


    return $pages;
}
