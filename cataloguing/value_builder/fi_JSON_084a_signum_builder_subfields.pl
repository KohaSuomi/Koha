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

    my $f084a = $marc->subfield('084', 'a') || '';
    my $f100a = $marc->subfield('100', 'a') || '';
    my $f110a = $marc->subfield('110', 'a') || '';
    my $f111a = $marc->subfield('111', 'a') || '';
    my $f130a = $marc->subfield('130', 'a') || '';
    my $f245a = $marc->subfield('245', 'a') || '';

    my %ret = (
	'f084a' => $f084a,
	'f100a' => $f100a,
	'f110a' => $f110a,
    'f111a' => $f111a,
    'f130a' => $f130a,
    'f245a' => $f245a,
	);

    output_with_http_headers $input, undef, to_json(\%ret, { utf8 => 1}), 'json';
};

return { launcher => $launcher };
