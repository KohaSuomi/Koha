#!/usr/bin/perl
package Koha::Procurement::Overlay;

use Mojolicious::Lite;
use Mojo::UserAgent;
use Digest::SHA qw(hmac_sha256_hex);
use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;

my $singleton;

sub new {
    my $class = shift;
    $singleton ||= bless {}, $class;
}

sub setToActiveRecords{
    my ($self, $config, $marcxml, $biblionumber) = @_;

    my $path = $config->{overlay}->{path};
    my $apikey = Digest::SHA::hmac_sha256_hex($config->{overlay}->{apikey});
    my $headers = {"Authorization" => $apikey};
    my $params = {
        marcxml => $marcxml,
        interface_name => $config->{overlay}->{interface_name},
        target_id => $biblionumber};
    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->post($path => $headers => json => $params);
    my $response = decode_json($tx->res->body);
}

1;
