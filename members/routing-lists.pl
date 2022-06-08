#!/usr/bin/perl

# Copyright 2012 Prosentient Systems
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

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Output qw( output_and_exit_if_error output_and_exit output_html_with_http_headers );
use C4::Auth qw( get_template_and_user );
use C4::Members;
use C4::Context;
use C4::Serials;
use Koha::Patrons;
use CGI::Session;

my $query = CGI->new;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user (
    {
        template_name   => 'members/routing-lists.tt',
        query           => $query,
        type            => "intranet",
        flagsrequired   => { circulate => 'circulate_remaining_permissions' },
    }
);

my $findborrower = $query->param('findborrower');
$findborrower =~ s|,| |g;

my $borrowernumber = $query->param('borrowernumber');

my $branch = C4::Context->userenv->{'branch'};

my $logged_in_user = Koha::Patrons->find( $loggedinuser );
my $patron         = Koha::Patrons->find( $borrowernumber );
output_and_exit_if_error( $query, $cookie, $template, { module => 'members', logged_in_user => $logged_in_user, current_patron => $patron } );

$template->param(
    patron            => $patron,
    findborrower      => $findborrower,
    branch            => $branch, # FIXME This is confusing
    routinglistview   => 1,
);

C4::Log::logaction("MEMBERS", "VIEW", $borrowernumber, "Routing lists page") if C4::Context->preference("BorrowersViewLog");

output_html_with_http_headers $query, $cookie, $template->output;
