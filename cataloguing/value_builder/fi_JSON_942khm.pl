#!/usr/bin/perl

# Copyright 2019 Koha-Suomi Oy
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
use CGI qw ( -utf8 );
use JSON;

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Output qw( output_with_http_headers );
use C4::Biblio qw( GetMarcBiblio );

my $launcher = sub {

    my ( $params ) = @_;
    my $input = $params->{cgi};
    my $biblionumber = $input->param("biblionumber") || '';

    return if (!$biblionumber);

    my ($template, $loggedinuser, $cookie) = get_template_and_user({
        template_name   => "cataloguing/value_builder/ajax.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => {editcatalogue => '*'},
        debug           => 1,
    });

    my $marc = GetMarcBiblio({ biblionumber => $biblionumber });
    return if (!$marc);

    my $f942k = $marc->subfield('942', 'k') || '';
    my $f942h = $marc->subfield('942', 'h') || '';
    my $f942m = $marc->subfield('942', 'm') || '';

    my %ret = (
	'f942k' => $f942k,
	'f942h' => $f942h,
	'f942m' => $f942m,
	);

    output_with_http_headers $input, undef, to_json(\%ret, { utf8 => 1}), 'json';
};

return { launcher => $launcher };
