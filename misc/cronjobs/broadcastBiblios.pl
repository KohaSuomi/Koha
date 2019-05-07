#!/usr/bin/perl

# Copyright 2018 KohaSuomi
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
use FindBin;
use POSIX 'strftime';
use Carp;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case);
use Koha::Biblio::Metadatas;
use Digest::SHA qw(hmac_sha256_hex);
use Mojolicious::Lite;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);

my $help = 0;
my $dt = strftime "%Y-%m-%d %H:%M:%S", ( localtime(time - 5*60) );
my $chunks = 200;
my $active = 0;
my $all = 0;
my $biblionumber;
my $verbose = 0;
my $limit = 0;

GetOptions(
    'h|help'                     => \$help,
    'v|verbose'                  => \$verbose,
    'c|chunks:i'                 => \$chunks,
    'a|active'                   => \$active,
    'all'                        => \$all,
    'b|biblionumber:i'           => \$biblionumber,
    'l|limit:i'                  => \$limit
);

my $usage = <<USAGE;
    Broadcast biblios to REST endpoint

    -h, --help              This message
    -v, --verbose           Verbose
    -c, --chunks            Process biblios in chunks, default is 200
    -a, --active            Send active biblios
    --all                   Send all biblios, default sends biblios from today
    -b, --biblionumber      Start sending from defined biblionumber
    -l, --limit             Limiting the results of biblios

USAGE

if ($help) {
    print $usage;
    exit 0;
}

my $configPath = $ENV{"KOHA_CONF"};
my($file, $path, $ext) = fileparse($configPath);
my $config = plugin Config => {file => $path.'broadcast_config.conf'};

my $params = {
    datetime => $dt,
    chunks => $chunks,
    page => 1
};


my $pageCount = 1;
my $ua = Mojo::UserAgent->new;
my $apikey = Digest::SHA::hmac_sha256_hex($config->{apiKey});
my $headers = {"Authorization" => $apikey};
my $endpoint  = $active ? $config->{activeEndpoint} : $config->{broadcastEndpoint};

while ($pageCount >= $params->{page}) {
    my $biblios = biblios($params);
    my $count = 0;
    my $lastnumber;
    foreach my $biblio (@{$biblios}) {
        my $tx = $ua->post($endpoint => $headers => json => endpointParams($biblio));
        my $response = decode_json($tx->res->body);
        if ($response->{error}) {
            print "$biblio->{biblionumber} biblio failed with: $response->{error}!\n";
        }
        if ($verbose && defined $response->{message} && $response->{message} eq "Success") {
            print "$biblio->{biblionumber} biblio added succesfully\n";
        }
        $count++;
        $lastnumber = $biblio->{biblionumber};
    }
    print "last processed biblio $lastnumber\n";
    print "$count biblios processed!\n";
    if ($count eq $params->{chunks}) {
        $pageCount++;
        $params->{page} = $pageCount;
    } else {
        $pageCount = 0;
    }
}


sub biblios {
    my ($params) = @_;
    print "Starting broadcasting offset $params->{page}!\n";
    my $terms;
    $terms = {timestamp => { '>=' => $params->{datetime} }} if !$all;
    $terms = {biblionumber => {'>=' => $biblionumber}} if $biblionumber;
    my $fetch = {
        page => $params->{page},
        rows => $params->{chunks}
    };
    $fetch = {rows => $limit} if defined $limit && $limit;

    my $biblios = Koha::Biblio::Metadatas->search($terms, $fetch)->unblessed;

    return $biblios;

}

sub endpointParams {
    my ($biblio) = @_;

    if ($active) {
        return {marcxml => $biblio->{metadata}, target_id => $biblio->{biblionumber}, interface_name => $config->{interfaceName}} if !$all;
        return {marcxml => $biblio->{metadata}, target_id => $biblio->{biblionumber}, interface_name => $config->{interfaceName}, updated => $biblio->{timestamp}};
    } else {
        return {marcxml => $biblio->{metadata}, source_id => $biblio->{biblionumber}, updated => $biblio->{timestamp}};
    }

}
