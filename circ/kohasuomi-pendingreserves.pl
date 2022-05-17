#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
# Copyright 2016-2022 Koha-Suomi Oy
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

use C4::Context;
use C4::Output qw( output_html_with_http_headers );
use CGI qw ( -utf8 );
use C4::Auth qw( get_template_and_user );
# use C4::Debug;
use File::stat;
use Time::localtime;
use Time::Piece;
use Storable;

my $input = new CGI;

my $theme = $input->param('theme');    # only used if allowthemeoverride is set

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "circ/kohasuomi-pendingreserves.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { circulate => "circulate_remaining_permissions" },
        debug           => 1,
    }
);

my $reporteddate = "UNKNOWN";
my @reservedata;

if ( -e '/tmp/pendingreserves.tmp' ) {
    my $stored=retrieve('/tmp/pendingreserves.tmp');
    # $reporteddate = ctime(stat('/tmp/pendingreserves.tmp')->mtime);
	$reporteddate = Time::Piece->strptime(ctime(stat('/tmp/pendingreserves.tmp')->mtime), '%a %b %d %H:%M:%S %Y')->strftime('%Y-%m-%d %H:%M:%S');
    @reservedata=@{$stored};
}

$template->param(
    reporteddate        => $reporteddate,
    reserveloop         => \@reservedata,
    "BiblioDefaultView".C4::Context->preference("BiblioDefaultView") => 1,
);

output_html_with_http_headers $input, $cookie, $template->output;
