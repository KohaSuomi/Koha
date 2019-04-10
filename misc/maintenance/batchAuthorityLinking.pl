#!/usr/bin/perl

#-----------------------------------
# Copyright 2019 Koha-Suomi Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#-----------------------------------

use Modern::Perl;
use Getopt::Long;

use C4::Context;
use C4::Biblio;
use C4::Record;
use MARC::Field;

my ($help, $confirm, $verbose);
my $flavour = 'MARC21';
my $chunks = 500;

GetOptions(
  'h|help'      => \$help,
  'v|verbose:i' => \$verbose,
  'c|confirm'   => \$confirm,
  'f|format:s'  => \$flavour,
  'chunks:i'    => \$chunks,
);

my $usage = << 'ENDUSAGE';

Changes authority linking field from 9 to 0

  -h --help      This nice help!

  -v --verbose   More chatty output.

  -c --confirm   Confirm that you want to mangle your bibliographic records

  -f --flavour   Select MARC flavour, MARC21 or NORMARC. Default is MARC21

  --chunks       Increase processed chunks


EXAMPLE:

perl batchAuthorityLinking.pl -v -c
perl batchAuthorityLinking.pl -v -c -f NORMARC
perl batchAuthorityLinking.pl -v --chunks 1000

ENDUSAGE

if ($help) {
    print $usage;
    exit 0;
}

our $marc21Authorityfields = {
    '100' => 1,
    '110' => 1,
    '111' => 1,
    '130' => 1,
    '245' => 1,
    '400' => 1,
    '410' => 1,
    '440' => 1,
    '490' => 1,
    '600' => 1,
    '610' => 1,
    '611' => 1,
    '630' => 1,
    '650' => 1,
    '651' => 1,
    '652' => 1,
    '653' => 1,
    '654' => 1,
    '655' => 1,
    '656' => 1,
    '657' => 1,
    '690' => 1,
    '700' => 1,
    '710' => 1,
    '711' => 1,
    '730' => 1,
    '751' => 1,
    '800' => 1,
    '810' => 1,
    '811' => 1,
    '830' => 1
    };

our $normarcAuthorityfields = {
    '100' => 1,
    '110' => 1,
    '111' => 1,
    '130' => 1,
    '245' => 1,
    '440' => 1,
    '490' => 1,
    '600' => 1,
    '610' => 1,
    '611' => 1,
    '630' => 1,
    '650' => 1,
    '651' => 1,
    '652' => 1,
    '653' => 1,
    '654' => 1,
    '655' => 1,
    '656' => 1,
    '657' => 1,
    '690' => 1,
    '700' => 1,
    '710' => 1,
    '711' => 1,
    '730' => 1,
    '800' => 1,
    '810' => 1,
    '811' => 1,
    '830' => 1
};

my $params = {
    chunks => $chunks,
    page => 1
};


my $pageCount = 1;
my $authorityfields = $flavour eq 'NORMARC' ? $normarcAuthorityfields : $marc21Authorityfields;

while ($pageCount >= $params->{page}) {
    my $biblios = biblios($params);
    my $count = 0;
    my $lastnumber = 0;
    foreach my $biblio (@{$biblios}) {
        my $record = C4::Record::marcxml2marc($biblio->{metadata});
        foreach my $field ($record->fields) {
            my @subfield_data;
            if ($authorityfields->{$field->tag}) {
                if ($field->subfields) {
                    for my $subfield ($field->subfields) {
                        if ($subfield->[0] eq "9") {
                            $subfield->[0] = "0";
                            print "Changed $flavour 9 field to 0 from ".$biblio->{biblionumber}."\n" if (defined $verbose);
                        }
                        push @subfield_data, $subfield->[0], $subfield->[1];
                    }
                }
            }
            $field->replace_with(MARC::Field->new(
                $field->tag(), $field->indicator(1), $field->indicator(2),
                @subfield_data)
            ) if @subfield_data; 
        }
        my $frameworkcode = C4::Biblio::GetFrameworkCode( $biblio->{biblionumber} );
        C4::Biblio::ModBiblio($record, $biblio->{biblionumber}, $frameworkcode) if $confirm;
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
    print "Starting to change offset $params->{page}!\n";
    my $biblios = Koha::Biblio::Metadatas->search({format => 'marcxml', marcflavour => $flavour},
    {
        page => $params->{page},
        rows => $params->{chunks}
    }
    )->unblessed;

    return $biblios;

}
