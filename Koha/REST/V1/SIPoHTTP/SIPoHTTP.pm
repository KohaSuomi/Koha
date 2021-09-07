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
use XML::LibXML;
use IO::Socket::INET;
use IO::Socket qw(AF_INET AF_UNIX SOCK_STREAM SHUT_WR);
use Socket qw(:crlf);
use Try::Tiny;
use Mojo::Log;
use File::Basename;
use C4::Context;
use Encode;
use utf8;
use strict;
use warnings qw( all );
use Log::Log4perl;

my $CONFPATH = dirname($ENV{'KOHA_CONF'});
my $KOHAPATH = C4::Context->config('intranetdir');

# Initialize Logger
my $log_conf = $CONFPATH . "/log4perl.conf";
Log::Log4perl::init($log_conf);
my $log = Log::Log4perl->get_logger('sipohttp');

#This gets called from REST api
sub process {

    my $c = shift->openapi->valid_input or return;

    my $body       = $c->req->body;
    my $xmlrequest = $c->param('query') || $body || '';

    $log->info("Request received.");
    
    $log->debug("Received request XML: ". $xmlrequest);
    
    #my $validation = validateXml( $c, $xmlrequest );
    my $validation = 1;

    if ($validation != 1) {

        $c->render(text => "Invalid Request. XML Validation failed.", status => 400);

        return;
    }

    #process sip here
    my ($login, $password) = getLogin($xmlrequest);

    if (!$login or !$password) {

        $log->error("Invalid request. Missing login/pw in XML.");

        $c->render(text => "Invalid request. Missing login/pw in XML.", status => 400);
        return;
    }
    
    my $sipmes = extractSip($xmlrequest, $c);

    unless ($sipmes) {

        $log->error("Invalid request. Missing SIP Request in XML.");

        $c->render(text => "Invalid request. Missing SIP Request in XML.", status => 400);
        return;
    }

    my ($siphost, $sipport) = extractServer($xmlrequest, $c);

    unless ($siphost && $sipport) {

        $log->error("No config found for login device. ");

        return $c->render(text => "No config found for login device. ", status => 400);
    }

    my $sipresponse = tradeSip($login, $password, $siphost, $sipport, $sipmes, $c);

    #remove carriage return/line feed from response
    $sipresponse =~ s/\r//g;
    $sipresponse =~ s/\n//g;

    my $xmlresponse = buildXml($sipresponse);

    return try {
        $c->render(status => 200, text => $xmlresponse);
        $log->info("XML response passed to endpoint.");
    } catch {
        Koha::Exceptions::rethrow_exception($_);
    }
}

sub tradeSip {

    my ($login, $password, $host, $port, $command_message, $c) = @_;

    my $sipsock = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp')
        or die $log->fatal("Can't create a socket for sipserver. Sipserver down?");

    $sipsock->autoflush(1);

    my $loginsip = buildLogin($login, $password);

    my $terminator = q{};
    $terminator = ($terminator eq 'CR') ? $CR : $CRLF;

    # Set perl to expect the same record terminator it is sending
    $/ = $terminator;

    $log->info("Trying login: $loginsip");

    my $respdata = "";
    
    print $sipsock $loginsip . $terminator;
    
    $log->debug($login . " ---> ". $loginsip);

    $sipsock->recv($respdata, 1024);
    
    $log->debug($login . " <--- " . $respdata);
    
    $sipsock->flush;
    
    #remove carriage return/line feed from response
    $respdata =~ s/\r//g;
    $respdata =~ s/\n//g;
    
    $respdata = substr($respdata, 0, 3);
    
    if ($respdata eq '941') {

        $log->info("Login OK. Sending: $command_message");

        print $sipsock $command_message . $terminator;
        
        $log->debug($login . " ---> ". $command_message);

        $sipsock->recv($respdata, 1024);
        
        $log->debug($login . " <--- ". $respdata);
        
        $sipsock->flush;

        $sipsock->shutdown(SHUT_WR);
        $sipsock->shutdown(SHUT_RDWR);    # we stopped using this socket
        $sipsock->close;
        $log->info("Received: $respdata");

        return $respdata;
    }
    
    $log->error("Login failed for $login. Sip server response: '$respdata'. Expected '941'. Can't process attached SIP message.");

    $sipsock->flush;
    $sipsock->shutdown(SHUT_WR);
    $sipsock->shutdown(SHUT_RDWR);    # we stopped using this socket
    $sipsock->close;

    return $respdata;
}

sub buildLogin {

    my ($login, $password, $c) = @_;
    
    my $login_mes = "9300CN" . shift . "|CO" . shift . "|CPSIP2OHTTP|" . "AY0AZ";
    
    #from https://fossies.org/linux/koha/C4/SIP/Sip/Checksum.pm
    my $checksum = (-unpack('%16C*', $login_mes) & 0xFFFF);
    my $fullpkt = sprintf("%s%4X", $login_mes, $checksum);
    
    $log->info("sip message with checksum: $fullpkt");
    
    return $fullpkt;
}

sub verify_cksum {
     my $debug;
     my $pkt = shift;
     my $cksum;
     my $shortsum;
 
     if ($pkt =~ /AZ(....)$/) {
         $debug and warn "verify_cksum: sum ($1) detected";
     } else {
         warn "verify_cksum: no sum detected";
         return 0; # No checksum at end
     }
     # return 0 if (substr($pkt, -6, 2) ne "AZ");
 
     # Convert the checksum back to hex and calculate the sum of the
     # pack without the checksum.
     $cksum = hex($1);
     $shortsum = unpack("%16C*", substr($pkt, 0, -4));
 
     # The checksum is valid if the hex sum, plus the checksum of the 
     # base packet short when truncated to 16 bits.
     return (($cksum + $shortsum) & 0xFFFF) == 0;
}

sub buildXml {

    my $responsemessage = shift;
    
	my $doc = XML::LibXML::Document->new('1.0', 'utf-8');

	my $root = $doc->createElement('ns1:sip');

	$root->setAttribute('xsi:schemaLocation'=> 'https://koha-suomi.fi/sipschema.xsd');
	$root->setAttribute('xmlns:ns1'=> 'https://koha-suomi.fi/sipschema.xsd');
	$root->setAttribute('xmlns:xsi'=> 'http://www.w3.org/2001/XMLSchema-instance');
	my %tags = (
    	response => $responsemessage,
	);

	for my $name (keys %tags) {
    	my $tag = $doc->createElement($name);
    	my $value = $tags{$name};
    	$tag->appendTextNode($value);
    	$root->appendChild($tag);
	}

	$doc->setDocumentElement($root);

	print $doc->toString();

    $doc = decode_utf8($doc);

    return $doc;
}

sub extractSip {

    my ($xmlmessage, $c) = @_;

    my $parser = XML::LibXML->new();
    my $xmldoc = $parser->load_xml(string => $xmlmessage);
    my $xc     = XML::LibXML::XPathContext->new($xmldoc->documentElement());

    my ($node) = $xc->findnodes('//request');

    my $siprequest = $node->textContent;
    
    #remove carriage return/line feed from request
    $siprequest =~ s/\r//g;
    $siprequest =~ s/\n//g;

    return $siprequest;
}

sub getLogin {

    #Retrieve the self check machine login info from XML
    my $xmlmessage = shift;

    my ($login, $passw);

    my $parser = XML::LibXML->new();
    my $doc    = $parser->load_xml(string => $xmlmessage);
    my $xc     = XML::LibXML::XPathContext->new($doc->documentElement());

    my ($node) = $xc->findnodes('//ns1:sip');

    try {
        $login = $node->getAttribute("login");
        $passw = $node->getAttribute("password");

        return $login, $passw;
    } catch {
        return 0;
    }
}

sub extractServer {

    my ($host, $port);

    my ($xmlmessage, $c)    = @_;
    my ($term,       $pass) = getLogin($xmlmessage);
    my $configfile = 'sip2ohttp-config.xml';

    my $doc = XML::LibXML->load_xml(location => $CONFPATH . '/' . $configfile);
    my $xc  = XML::LibXML::XPathContext->new($doc->documentElement());

    my ($node) = $xc->findnodes('//' . $term);

    unless ($node) {
        $log->error("Missing server config parameters for $term in $configfile");
        return 0;
    }

    $host = $node->findvalue('./host');
    $port = $node->findvalue('./port');
    return $host, $port;
}

sub validateXml {

    #For validating the content of the XML SIP message
    my ($c, $xmlbody) = @_;
    my $parser = XML::LibXML->new();

    # parse and validate the xml against sipschema
    # https://koha-suomi.fi/sipschema.xsd
    my $schema = XML::LibXML::Schema->new(location => $KOHAPATH . '/koha-tmpl/sipschema.xsd');

    try {
        my $xmldoc = $parser->load_xml(string => $xmlbody);
        $schema->validate($xmldoc);
        $log->info("XML Validated OK.");
        return 1;
    } catch {
        $log->error("Could not validate XML - @_");
        return 0;
    };
}

1;
