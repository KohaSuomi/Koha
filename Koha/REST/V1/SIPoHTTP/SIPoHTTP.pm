package Koha::REST::V1::SIPoHTTP::SIPoHTTP;

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

use Mojo::Base 'Mojolicious::Controller';

use FindBin qw($Bin);
use lib "$Bin";
use Koha::Exceptions;
use Koha::Logger;
use XML::LibXML;
use IO::Socket::INET;
use IO::Socket qw(AF_INET AF_UNIX SOCK_STREAM SHUT_WR);
use Socket qw(:crlf);
use Try::Tiny;
use Mojo::Log;
use File::Basename;
use C4::Context;

use strict;
use warnings qw( all );

my $CONFPATH = dirname( $ENV{'KOHA_CONF'} );
my $KOHAPATH = C4::Context->config('intranetdir');

my $log = Koha::Logger->get();

#This gets called from REST api
sub process {

	my $c = shift->openapi->valid_input or return;

	my $body          = $c->req->body;
	my $xmlrequest = $body;

	$log->info("Request received.");

	my $validation = validateXml( $c, $xmlrequest );

	if ( $validation != 1 ) {

		$c->render(
			text   => "Invalid Request. XML Validation failed.",
			status => 400
		);

		return;
	}

	#process sip here
	my ( $login, $password ) = getLogin($xmlrequest);

	if ( !$login or !$password ) {

		$log->error("Invalid request. Missing login/pw in XML.");

		$c->render(
			text   => "Invalid request. Missing login/pw in XML.",
			status => 400
		);
		return;
	}
	my $sipmes = extractSip( $xmlrequest, $c );

	unless ($sipmes) {

		$log->error("Invalid request. Missing SIP Request in XML.");

		$c->render(
			text   => "Invalid request. Missing SIP Request in XML.",
			status => 400
		);
		return;
	}

	my ( $siphost, $sipport ) = extractServer( $xmlrequest, $c );

	unless ( $siphost && $sipport ) {

		$log->error("No config found for login device. ");

		return $c->render(
			text   => "No config found for login device. ",
			status => 400
		);

	}

	my $sipresponse =
	  tradeSip( $login, $password, $siphost, $sipport, $sipmes, $c );

	#remove carriage return from response (\r)
	$sipresponse =~ s/\r//g;

	my $xmlresponse = buildXml($sipresponse);

	return try {
		$c->render( status => 200, text => $xmlresponse );
		$log->info("XML response passed to endpoint.");

	}
	catch {
		Koha::Exceptions::rethrow_exception($_);
	}
}

sub tradeSip {

	my ( $login, $password, $host, $port, $command_message, $c ) = @_;

	my $sipsock = IO::Socket::INET->new(
		PeerAddr => $host,
		PeerPort => $port,
		Proto    => 'tcp'
	) or die $log->fatal("Can't create a socket for sipserver. Sipserver down?");

	$sipsock->autoflush(1);

	my $loginsip = buildLogin( $login, $password );

	my $terminator = q{};
	$terminator = ( $terminator eq 'CR' ) ? $CR : $CRLF;

	# Set perl to expect the same record terminator it is sending
	$/ = $terminator;

	$log->info("Trying login: $loginsip");

	my $respdata;

	print $sipsock $loginsip . $terminator;

	$sipsock->recv( $respdata, 1024 );
	$sipsock->flush;

	if ( $respdata eq "941" ) {

		$log->info("Login OK. Sending: $command_message");

		print $sipsock $command_message . $terminator;

		$sipsock->recv( $respdata, 1024 );
		$sipsock->flush;

		$sipsock->shutdown(SHUT_WR);
		$sipsock->shutdown(SHUT_RDWR);    # we stopped using this socket
		$sipsock->close;

		my $respmes = $respdata;
		$respmes =~ s/.{1}$//;

		$log->info("Received: $respmes");

		return $respdata;
	}

	chomp $respdata;
	$log->error(
"Unauthorized login for $login: $respdata. Can't process attached SIP message."
	);

	return $respdata;
}

sub buildLogin {

	my ( $login, $password ) = @_;

	my $siptempl = "9300CN<SIPDEVICE>|CO<SIPDEVICEPASS>|CPSIPLOCATION|";
	return "9300CN" . shift . "|CO" . shift . "|CPSIP2OHTTP|";
}

sub buildXml {

	my $responsemessage = shift;

	my $respxml = '<?xml version="1.0" encoding="UTF-8"?>

<ns1:sip xsi:schemaLocation="https://koha-suomi.fi/sipschema.xsd" xmlns:ns1="https://koha-suomi.fi/sipschema.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

           <response><TMPL_VAR_MESSAGE></response>

</ns1:sip>';

	$respxml =~ s|<TMPL_VAR_MESSAGE>|$responsemessage|;

	return $respxml;
}

sub extractSip {

	my ( $xmlmessage, $c ) = @_;

	my $parser = XML::LibXML->new();
	my $xmldoc = $parser->load_xml( string => $xmlmessage );
	my $xc     = XML::LibXML::XPathContext->new( $xmldoc->documentElement() );

	my ($node) = $xc->findnodes('//request');

	my $sample = $node->textContent;
	return $sample;

}

sub getLogin {

	#Retrieve the self check machine login info from XML
	my $xmlmessage = shift;

	my ( $login, $passw );

	my $parser = XML::LibXML->new();
	my $doc    = $parser->load_xml( string => $xmlmessage );
	my $xc     = XML::LibXML::XPathContext->new( $doc->documentElement() );

	my ($node) = $xc->findnodes('//ns1:sip');

	try {
		$login = $node->getAttribute("login");
		$passw = $node->getAttribute("password");

		return $login, $passw;
	}
	catch {
		return 0;
	}

}

sub extractServer {

	my ( $host, $port );

	my ( $xmlmessage, $c )    = @_;
	my ( $term,       $pass ) = getLogin($xmlmessage);
        my $configfile = 'sip2ohttp-config.xml';

	my $doc =
	  XML::LibXML->load_xml( location => $CONFPATH . '/' . $configfile );
	my $xc = XML::LibXML::XPathContext->new( $doc->documentElement() );

	my ($node) = $xc->findnodes( '//' . $term );

	unless ($node) {
		$log->error(
			"Missing server config parameters for $term in $configfile");
		return 0;
	}

	$host = $node->findvalue('./host');
	$port = $node->findvalue('./port');
	return $host, $port;

}

sub validateXml {

	#For validating the content of the XML SIP message
	my ( $c, $xmlbody ) = @_;
	my $parser = XML::LibXML->new();

	# parse and validate the xml against sipschema
	# https://koha-suomi.fi/sipschema.xsd
	my $schema =
	  XML::LibXML::Schema->new(
		location => $KOHAPATH . '/koha-tmpl/sipschema.xsd' );

	try {

		my $xmldoc = $parser->load_xml( string => $xmlbody );
		$schema->validate($xmldoc);
		$log->info("XML Validated OK.");
		return 1;
	}
	catch {
		$log->error("Could not validate XML - @_");
		return 0;

	};

}

1;
