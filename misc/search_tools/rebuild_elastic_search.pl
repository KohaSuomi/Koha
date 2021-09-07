#!/usr/bin/perl

# This inserts records from a Koha database into elastic search

# Copyright 2014 Catalyst IT
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

=head1 NAME

rebuild_elastic_search.pl - inserts records from a Koha database into Elasticsearch

=head1 SYNOPSIS

B<rebuild_elastic_search.pl>
[B<-c|--commit>=C<count>]
[B<-v|--verbose>]
[B<-h|--help>]
[B<--man>]

=head1 DESCRIPTION

Inserts records from a Koha database into Elasticsearch.

=head1 OPTIONS

=over

=item B<-c|--commit>=C<count>

Specify how many records will be batched up before they're added to Elasticsearch.
Higher should be faster, but will cause more RAM usage. Default is 5000.

=item B<-d|--delete>

Delete the index and recreate it before indexing.

=item B<-a|--authorities>

Index the authorities only. Combining this with B<-b> is the same as
specifying neither and so both get indexed.

=item B<-b|--biblios>

Index the biblios only. Combining this with B<-a> is the same as
specifying neither and so both get indexed.

=item B<-bn|--bnumber>

Only index the supplied biblionumber, mostly for testing purposes. May be
repeated. This also applies to authorities via authid, so if you're using it,
you probably only want to do one or the other at a time.

=item B<-p|--processes>

Number of processes to use for indexing. This can be used to do more indexing
work in parallel on multicore systems. By default, a single process is used.

=item B<-v|--verbose>

By default, this program only emits warnings and errors. This makes it talk
more. Add more to make it even more wordy, in particular when debugging.

=item B<-h|--help>

Help!

=item B<--man>

Full documentation.

=back

=head1 IMPLEMENTATION

=cut

use autodie;
use Getopt::Long;
use C4::Context;
use Koha::MetadataRecord::Authority;
use Koha::BiblioUtils;
use Koha::SearchEngine::Elasticsearch::Indexer;
use MARC::Field;
use MARC::Record;
use Modern::Perl;
use Pod::Usage;

my $verbose = 0;
my $commit = 5000;
my ($delete, $help, $man, $processes);
my ($index_biblios, $index_authorities);
my (@record_numbers);

$|=1; # flushes output

GetOptions(
    'c|commit=i'    => \$commit,
    'd|delete'      => \$delete,
    'a|authorities' => \$index_authorities,
    'b|biblios'     => \$index_biblios,
    'bn|bnumber=i'  => \@record_numbers,
    'p|processes=i' => \$processes,
    'v|verbose+'    => \$verbose,
    'h|help'        => \$help,
    'man'           => \$man,
);

# Default is to do both
unless ($index_authorities || $index_biblios) {
    $index_authorities = $index_biblios = 1;
}

if ($processes && @record_numbers) {
    die "Argument p|processes cannot be combined with bn|bnumber";
}

pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;

_sanity_check();

_verify_index_state($Koha::SearchEngine::Elasticsearch::BIBLIOS_INDEX, $delete) if ($index_biblios);
_verify_index_state($Koha::SearchEngine::Elasticsearch::AUTHORITIES_INDEX, $delete) if ($index_authorities);

my $slice_index = 0;
my $slice_count = $processes // 1;
my %iterator_options;

if ($slice_count > 1) {
    # Fire up child processes for processing slices from 2 on. This main process will handle slice 1.
    $slice_index = 0;
    for (my $proc = 1; $proc < $slice_count; $proc++) {
        my $pid = fork();
        die "Failed to fork a child process\n" unless defined $pid;
        if ($pid == 0) {
            # Child process, give it a slice to process
            $slice_index = $proc;
            last;
        }
    }
    # Fudge the commit count a bit to spread out the Elasticsearch commits
    $commit *= 1 + 0.10 * $slice_index;
    _log(1, "Processing slice @{[$slice_index + 1]} of $slice_count\n");
    $iterator_options{slice} = { index => $slice_index, count => $slice_count };
}

my $next;
if ($index_biblios) {
    _log(1, "Indexing biblios\n");
    if (@record_numbers) {
        $next = sub {
            my $r = shift @record_numbers;
            return () unless defined $r;
            return ($r, Koha::BiblioUtils->get_from_biblionumber($r, item_data => 1 ));
        };
    } else {
        my $records = Koha::BiblioUtils->get_all_biblios_iterator(%iterator_options);
        $next = sub {
            $records->next();
        }
    }
    _do_reindex($next, $Koha::SearchEngine::Elasticsearch::BIBLIOS_INDEX);
}
if ($index_authorities) {
    _log(1, "Indexing authorities\n");
    if (@record_numbers) {
        $next = sub {
            my $r = shift @record_numbers;
            return () unless defined $r;
            my $a = Koha::MetadataRecord::Authority->get_from_authid($r);
            return ($r, $a->record);
        };
    } else {
        my $records = Koha::MetadataRecord::Authority->get_all_authorities_iterator(%iterator_options);
        $next = sub {
            $records->next();
        }
    }
    _do_reindex($next, $Koha::SearchEngine::Elasticsearch::AUTHORITIES_INDEX);
}

if ($slice_index == 0) {
    # Main process, wait for children
    if ( $processes ) {
        for (my $proc = 1; $proc < $processes; $proc++) {
            wait();
        }
    }
}

=head1 INTERNAL METHODS

=head2 _verify_index_state

    _verify_index_state($Koha::SearchEngine::Elasticsearch::BIBLIOS_INDEX, 1);

Checks the index state and recreates it if requested.

=cut

sub _verify_index_state {
    my ( $index_name, $recreate ) = @_;

    _log(1, "Checking state of $index_name index\n");
    my $indexer = Koha::SearchEngine::Elasticsearch::Indexer->new( { index => $index_name } );

    if ($recreate) {
        _log(1, "Dropping and recreating $index_name index\n");
        $indexer->drop_index() if $indexer->index_exists();
        $indexer->create_index();
    }
    elsif (!$indexer->index_exists) {
        # Create index if does not exist
        $indexer->create_index();
    } elsif ($indexer->is_index_status_ok) {
        # Update mapping unless index is some kind of problematic state
        $indexer->update_mappings();
    } elsif ($indexer->is_index_status_recreate_required) {
        warn qq/Index "$index_name" has status "recreate required", suggesting it should be recreated/;
    }
}

=head2 _do_reindex

    _do_reindex($callback, $Koha::SearchEngine::Elasticsearch::BIBLIOS_INDEX);

Does the actual reindexing. $callback is a function that always returns the next record.
For each index we iterate through the records, committing at specified count

=cut

sub _do_reindex {
    my ( $next, $index_name ) = @_;

    my $indexer = Koha::SearchEngine::Elasticsearch::Indexer->new( { index => $index_name } );

    my $count        = 0;
    my $commit_count = $commit;
    my ( @id_buffer, @commit_buffer );
    while ( my $record = $next->() ) {
        my $id     = $record->id;
        my $record = $record->record;
        $count++;
        if ( $verbose == 1 ) {
            _log( 1, "$count records processed\n" ) if ( $count % 1000 == 0);
        } else {
            _log( 2, "$id\n" );
        }

        push @id_buffer,     $id;
        push @commit_buffer, $record;
        if ( !( --$commit_count ) ) {
            _log( 1, "Committing $commit records...\n" );
            my $response = $indexer->update_index( \@id_buffer, \@commit_buffer );
            _handle_response($response);
            $commit_count  = $commit;
            @id_buffer     = ();
            @commit_buffer = ();
            _log( 1, "Commit complete\n" );
        }
    }

    # There are probably uncommitted records
    _log( 1, "Committing final records...\n" );
    my $response = $indexer->update_index( \@id_buffer, \@commit_buffer );
    _handle_response($response);
    _log( 1, "Total $count records indexed\n" );
}

=head2 _sanity_check

    _sanity_check();

Checks some basic stuff to ensure that it's sane before we start.

=cut

sub _sanity_check {
    # Do we have an elasticsearch block defined?
    my $conf = C4::Context->config('elasticsearch');
    die "No 'elasticsearch' block is defined in koha-conf.xml.\n" if ( !$conf );
}

=head2 _handle_response

Parse the return from update_index and display errors depending on verbosity of the script

=cut

sub _handle_response {
    my ($response) = @_;
    if( $response->{errors} && $response->{errors} eq 'true' ){
        _log( 1, "There were errors during indexing\n" );
        if ( $verbose > 1 ){
            foreach my $item (@{$response->{items}}){
                next unless defined $item->{index}->{error};
                print "Record #" . $item->{index}->{_id} . " " .
                      $item->{index}->{error}->{reason} . " (" . $item->{index}->{error}->{type} . ") : " .
                      $item->{index}->{error}->{caused_by}->{type} . " (" . $item->{index}->{error}->{caused_by}->{reason} . ")\n";
            }
        }
    }
}

=head2 _log

    _log($level, "Message\n");

Output progress information.

Will output the message if verbosity level is set to $level or more. Will not
include a trailing newline automatically.

=cut

sub _log {
    my ($level, $msg) = @_;

    print "[$$] $msg" if ($verbose >= $level);
}
