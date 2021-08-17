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
use Koha::Biblios;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case);
use Koha::Biblio::Metadatas;
use Digest::SHA qw(hmac_sha256_hex);
use Mojolicious::Lite;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Koha::DateUtils qw( dt_from_string );
use MARC::Record;
use Fcntl qw( :DEFAULT :flock :seek );


my $logdir = C4::Context->config('logdir');

my $pidfile = "$logdir/broadcastbiblios.pid";

my $pid_handle = check_pidfile();


my $help = 0;
my $dt = strftime "%Y-%m-%d %H:%M:%S", ( localtime(time - 5*60) );
my $chunks = 200;
my $active = 0;
my $all = 0;
my $biblionumber;
my $verbose = 0;
my $limit = 0;
my $interface;
my $batchdate = strftime "%Y-%m-%d", ( localtime );
my $staged = 0;
my $stage_type;
my $target_field;
my $target_subfield = "";
my $field_check;
my $lastrecord = 0;
my $identifier_fetch = 0;

GetOptions(
    'h|help'                     => \$help,
    'v|verbose'                  => \$verbose,
    'c|chunks:i'                 => \$chunks,
    'a|active'                   => \$active,
    'all'                        => \$all,
    'b|biblionumber:i'           => \$biblionumber,
    'l|limit:i'                  => \$limit,
    'i|interface:s'              => \$interface,
    's|staged'                   => \$staged,
    'batchdate:s'                => \$batchdate,
    't|type:s'                   => \$stage_type,
    'f|field:s'                  => \$target_field,
    'subfield:s'                 => \$target_subfield,
    'check:s'                    => \$field_check,
    'lastrecord'                 => \$lastrecord,
    'identifier'                 => \$identifier_fetch,

);

my $usage = <<USAGE;
    Broadcast biblios to REST endpoint

    -h, --help              This message.
    -v, --verbose           Verbose.
    -c, --chunks            Process biblios in chunks, default is 200.
    -a, --active            Send active biblios.
    --all                   Send all biblios, default sends biblios from today.
    -b, --biblionumber      Start sending from defined biblionumber.
    -l, --limit             Limiting the results of biblios.
    -i, --interface         Interface name: with active add your system interface and with staged add remote.
    -s, --staged            Export staged records to interface.
    --batchdate             Import batch date, used with 'staged' parameter. Default is today.
    -t, --type              Stage type, used with 'staged' parameter. Add or update, default is add.
    -f, --field             Find target id from marcxml, used with 'staged' parameter and update type.
    --check                 Check that field contains some spesific identifier.
    --lastrecord            Automatically check which is lastly activated record.
    --identifier            Push to active records with identifier.

USAGE

if ($help) {
    print $usage;
    exit 0;
}

if (!$interface && ($active || $staged)) {
    print "Remote interface name is missing!\n";
    exit 0;
}

if ($biblionumber && !$active) {
    print "Use biblionumber only with active parameter\n";
    exit 0;
}

if ($staged && $stage_type eq "update" && !$target_field && !$field_check) {
    print "Target id field and check are missing!\n";
    exit 0;
}

my $configPath = $ENV{"KOHA_CONF"};
my($file, $path, $ext) = fileparse($configPath);
my $config = plugin Config => {file => $path.'broadcast-config.conf'};

my $params = {
    datetime => $dt,
    chunks => $chunks,
    page => 1
};

my $pageCount = 1;
my $ua = Mojo::UserAgent->new;
my $apikey = Digest::SHA::hmac_sha256_hex($config->{apiKey});
my $headers = {"Authorization" => $apikey};
my $last_itemnumber;
if ($lastrecord && $all && $active) {
    my $tx = $ua->get($config->{activeEndpoint}.'/lastrecord' => $headers => form => {interface => $interface});
    my $response = decode_json($tx->res->body);
    unless ($biblionumber) {
        $biblionumber = $response->{target_id};
    }
}
my $endpoint;
if ($staged) {
    $endpoint = $config->{exportEndpoint};
    my @biblios = import_records();
    my $count = 0;
    foreach my $biblio (@biblios) {
        my $parameters;
        if ($stage_type eq "update") {
            my $record = MARC::Record::new_from_xml($biblio->{marcxml}, 'UTF-8');
            if($record->field($target_field)) {
                my $target_id = $record->field($target_field)->subfield($target_subfield);
                if ($target_id =~ /$field_check/) {
                    print "Target id ($target_id) found from $biblio->{biblionumber}!\n";
                    $target_id =~ s/\D//g;
                    $parameters = {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, target_id => $target_id, interface => $interface, check => Mojo::JSON->true};
                }
            }
        } else {
            $parameters = $biblio->{parent_id} ? {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, interface => $interface, parent_id => $biblio->{parent_id}, force => 1} : {marc => $biblio->{marcxml}, source_id => $biblio->{biblionumber}, interface => $interface};
        }
        if ($parameters) {
            my $tx = $ua->post($endpoint => $headers => json => $parameters);
            my $response = decode_json($tx->res->body);
            my $error = $response->{error} || $tx->res->error->{message} if $response->{error} || $tx->res->error;
            if ($error) {
                print "$biblio->{biblionumber} biblio failed with: $error!\n";
            }
            if ($verbose && defined $response->{message} && $response->{message} eq "Success") {
                print "$biblio->{biblionumber} biblio added succesfully\n";
            }
            $count++;
        }
    }

    print "$count biblios processed!\n";

} else {
    $endpoint = $active ? $config->{activeEndpoint} : $config->{broadcastEndpoint};
    $endpoint = $identifier_fetch && $active ? $endpoint.'/identifier' : $endpoint;
    while ($pageCount >= $params->{page}) {
        my $biblios = biblios($params);
        my $count = 0;
        my $lastnumber;
        foreach my $biblio (@{$biblios}) {
            my $params = endpointParams($biblio);
            if ($params) {
                my $tx = $ua->post($endpoint => $headers => json => $params);
                my $response = decode_json($tx->res->body);
                if ($response->{error}) {
                    print "$biblio->{biblionumber} biblio failed with: $response->{error}!\n";
                }
                if ($verbose && defined $response->{message} && $response->{message} eq "Success") {
                    print "$biblio->{biblionumber} biblio added succesfully\n";
                }
            } else {
                print "$biblio->{biblionumber} biblio failed with: No valid identifier!\n";
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

sub import_records {
    print "Fetch imported records from $batchdate\n";
    my $marcflavour = C4::Context->preference('marcflavour');
    my $start = dt_from_string($batchdate.' 00:00:00');
    my $end = dt_from_string($batchdate.' 23:59:00');
    my $schema = Koha::Database->new->schema;
    my $type = $stage_type eq "update" ? 'match_applied' : 'no_match';
    my $dtf = Koha::Database->new->schema->storage->datetime_parser;
    my @biblios = $schema->resultset('ImportRecord')->search({status => 'imported', overlay_status => $type, upload_timestamp => {-between => [
                $dtf->format_datetime( $start ),
                $dtf->format_datetime( $end ),
            ]}});
    
    my @data;
    my @components;
    foreach my $rs (@biblios) {
        my $cols = { $rs->get_columns };
        $cols->{biblionumber} = $schema->resultset('ImportBiblio')->search({import_record_id => $cols->{import_record_id}})->get_column("matched_biblionumber")->next;
        if ($cols->{biblionumber}) {
            $cols->{marcxml} = Koha::Biblio::Metadatas->find({biblionumber => $cols->{biblionumber}})->metadata;
            my $componentparts = Koha::Biblios->find( {biblionumber => $cols->{biblionumber}} )->componentparts;
            if ($componentparts) {
                foreach my $componentpart (@{$componentparts}) {
                    push @components, {biblionumber => $componentpart->{biblionumber}, parent_id => $cols->{biblionumber}};
                }
            }
            push @data, {marcxml => $cols->{marcxml}, biblionumber => $cols->{biblionumber}};
        }
    }
    foreach my $componentpart (@components) {
        my $index;
        foreach my $d (@data) {
            if ($componentpart->{biblionumber} eq $d->{biblionumber}) {
                $data[$index]->{parent_id} = $componentpart->{parent_id};
            }
            $index++;
        }
    }
    return @data;
}

sub endpointParams {
    my ($biblio) = @_;

    if ($active) {
        if ($identifier_fetch) {
            my ($identifier, $identifier_field) = active_field($biblio);
            return unless $identifier && $identifier_field;
            return {identifier => $identifier, identifier_field => $identifier_field, target_id => $biblio->{biblionumber}, interface_name => $interface} if !$all;
            return {identifier => $identifier, identifier_field => $identifier_field, target_id => $biblio->{biblionumber}, interface_name => $interface, updated => $biblio->{timestamp}};
        } else {
            return {marcxml => $biblio->{metadata}, target_id => $biblio->{biblionumber}, interface_name => $interface} if !$all;
            return {marcxml => $biblio->{metadata}, target_id => $biblio->{biblionumber}, interface_name => $interface, updated => $biblio->{timestamp}};
        }
    } else {
        return {marcxml => $biblio->{metadata}, source_id => $biblio->{biblionumber}, updated => $biblio->{timestamp}};
    }

}

sub active_field {
    my ($biblio) = @_;
    my $record = MARC::Record::new_from_xml($biblio->{metadata}, 'UTF-8');
    my $activefield;
    my $fieldname;

    if ($record->field('035')) {
        my @f035 = $record->field( '035' );
        foreach my $f035 (@f035) {
            if($f035->subfield('a') =~ /FI-MELINDA/) {
                $activefield = $f035->subfield('a');
                $fieldname = '035a';
            }
        }
    }

    if ($record->field('020') && !$activefield) {
        my @f020 = $record->field( '020' );
        foreach my $f020 (@f020) {
            if ($f020->subfield('a')) {
                $activefield = $f020->subfield('a');
                $fieldname = '020a';
            }
        }

    }

    if ($record->field( '024') && !$activefield) {
        my @f024 = $record->field( '024' );
        foreach my $f024 (@f024) {
            if ($f024->subfield('a') && $f024->indicator('1') eq '3') {
                $activefield = $f024->subfield('a');
                $fieldname = '024a';
                last;
            } elsif ($f024->subfield('a')) {
                $activefield = $f024->subfield('a');
                $fieldname = '024a';
                last;
            }
        }
    }
    if ($record->field( '003')->data =~ /FI-BTJ/ && !$activefield) {
        $activefield = $record->field( '003')->data.'|'.$record->field( '001')->data;
        $fieldname = '003|001';
    }

    return ($activefield, $fieldname);
}

if ( close $pid_handle ) {
    unlink $pidfile;
    exit 0;
} else {
    warn "Error on pidfile close\n";
    exit 1;
}

sub check_pidfile {

    # sysopen my $fh, $pidfile, O_EXCL | O_RDWR or log_exit "$0 already running"
    sysopen my $fh, $pidfile, O_RDWR | O_CREAT;
    flock $fh => LOCK_EX;

    sysseek $fh, 0, SEEK_SET;
    truncate $fh, 0;
    print $fh "$$\n";

    return $fh;
}
