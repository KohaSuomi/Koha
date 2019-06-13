#!/usr/bin/perl


# Copyright 2000-2002 Katipo Communications
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
use warnings;
use CGI qw ( -utf8 );
use C4::Context;
use C4::Output;
use C4::Auth;
use C4::Biblio;
use C4::Circulation;
use C4::Members;
use Date::Calc qw(
  Today
  Add_Delta_Days
  Date_to_Days
);

use C4::Koha;
use C4::Reserves;
use Koha::Items;
use Koha::ItemTypes;
use Koha::Libraries;
use Koha::DateUtils;
use Koha::BiblioFrameworks;

my $input = new CGI;
my $itemnumber = $input->param('itemnumber');

my ( $template, $loggedinuser, $cookie, $flags ) = get_template_and_user(
    {
        template_name   => "circ/transferstoreceive.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
        debug           => 1,
    }
);

# set the userenv branch
my $default = C4::Context->userenv->{'branch'};

# get the all the branches for reference
my $libraries = Koha::Libraries->search({}, { order_by => 'branchname' });
my @branchesloop;
my $latetransfers;
while ( my $library = $libraries->next ) {
    my @transferloop;
    my %branchloop;
    my @gettransfers =
      GetTransfersFromTo( $library->branchcode, $default );

    if (@gettransfers) {
        $branchloop{'branchname'} = $library->branchname;
        $branchloop{'branchcode'} = $library->branchcode;
        foreach my $num (@gettransfers) {
            my %getransf;

            my ( $sent_year, $sent_month, $sent_day ) = split "-",
              $num->{'datesent'};
            $sent_day = ( split " ", $sent_day )[0];
            ( $sent_year, $sent_month, $sent_day ) =
              Add_Delta_Days( $sent_year, $sent_month, $sent_day,
                C4::Context->preference('TransfersMaxDaysWarning'));
            my $calcDate = Date_to_Days( $sent_year, $sent_month, $sent_day );
            my $today    = Date_to_Days(&Today);
			my $diff = $today - $calcDate;

            if ($today > $calcDate) {
				$latetransfers = 1;
                $getransf{'messcompa'} = 1;
				$getransf{'diff'} = $diff;
            }
            my $gettitle     = GetBiblioFromItemNumber( $num->{'itemnumber'} );
            my $itemtype = Koha::ItemTypes->find( (C4::Context->preference('item-level_itypes')) ? $gettitle->{'itype'} : $gettitle->{'itemtype'} );

            $getransf{'datetransfer'} = $num->{'datesent'};
            $getransf{'itemtype'} = $itemtype->description; # FIXME Should not it be translated_description?
			foreach (qw(title author biblionumber enumchron itemnumber barcode homebranch holdingbranch itemcallnumber)) {
            	$getransf{$_} = $gettitle->{$_};
			}

            my $record = GetMarcBiblio($gettitle->{'biblionumber'});
            $getransf{'subtitle'} = GetRecordValue('subtitle', $record, GetFrameworkCode($gettitle->{'biblionumber'}));

            # we check if we have a reserv for this transfer
            my $item = Koha::Items->find( $num->{itemnumber} );
            my $holds = $item->current_holds;
            if ( my $first_hold = $holds->next ) {
                my $getborrower = C4::Members::GetMember( borrowernumber => $first_hold->borrowernumber );
                $getransf{'borrowernum'}       = $getborrower->{'borrowernumber'};
                $getransf{'borrowername'}      = $getborrower->{'surname'};
                $getransf{'borrowerfirstname'} = $getborrower->{'firstname'};
                $getransf{'borrowermail'}      = $getborrower->{'email'} if $getborrower->{'email'};
                $getransf{'borrowerphone'}     = $getborrower->{'phone'};
            }
            push( @transferloop, \%getransf );
        }

      # 		If we have a return of reservloop we put it in the branchloop sequence
        $branchloop{'reserv'} = \@transferloop;
    }
    push( @branchesloop, \%branchloop ) if %branchloop;
}

$template->param(
    branchesloop => \@branchesloop,
    show_date    => output_pref({ dt => dt_from_string, dateformat => 'iso', dateonly => 1 }),
	TransfersMaxDaysWarning => C4::Context->preference('TransfersMaxDaysWarning'),
	latetransfers => $latetransfers ? 1 : 0,
);

# Checking if there is a Fast Cataloging Framework
$template->param( fast_cataloging => 1 ) if Koha::BiblioFrameworks->find( 'FA' );

output_html_with_http_headers $input, $cookie, $template->output;

