#!/usr/bin/perl

# Copyright Koha-Suomi Oy 2018
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
use C4::Auth;
use C4::Output;
use C4::Templates qw/gettemplate/;
use JSON;
use Koha::Auth::Token;
use Koha::Patron::Attribute;

use Koha;

my $input = new CGI;

my $token   = $input->param("token");
my $bornumber     = $input->param("borrowernumber");

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "mydata.tt",
        query           => $input,
        type            => "opac",
        authnotrequired => 0,
    }
);
my $tokenizer = new Koha::Auth::Token;
my $resultSet = Koha::Database->new()->schema()->resultset(Koha::Patron::Attribute->_type());

my $tokenParams = {};
$tokenParams->{borrowernumber} = $bornumber;
$tokenParams->{code} = 'LTOKEN';

my $dbtoken = $tokenizer->getToken($resultSet, $tokenParams);

if ( $token eq $dbtoken && $bornumber eq $borrowernumber) {

	my $interface = C4::Context->preference("LogInterface");
	my $interfaceUrl;
	my @logdata;

	if ($interface eq "local") {

		my $logs = C4::Log::GetLogs(undef, undef, undef, undef , undef, $bornumber, undef);
		foreach my $log (@${logs}) {
			my $parselog;
			$parselog->{action} = $log->{action};
			$parselog->{timestamp} = $log->{timestamp};
			$parselog->{info} = $log->{info};
			if ($log->{info} =~ m/VAR/) {
				$log->{info} =~ tr/\/\'//d;
				$log->{info} =~ tr/,//d;
				my @info = $log->{info} =~ /action => (.*?)\n/;
				$parselog->{info} = $info[0];
			}
			$parselog->{info} =~ tr/'//d;
			push (@logdata, $parselog);
		}

	} else {
		$interfaceUrl = C4::Context->preference("RemoteInterfaceUrl");
	}
	$template->param(url =>, $interfaceUrl, logdata => encode_json(\@logdata));

    $tokenizer->delete($resultSet, $tokenParams);

	output_html_with_http_headers $input, '', $template->output;
} else {
	print $input->redirect("/cgi-bin/koha/opac-main.pl");
}

1;