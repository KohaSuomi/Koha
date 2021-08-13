package C4::OPLIB::OKMGroupStatistics;

# Copyright KohaSuomi
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
use Carp;

use Koha::Libraries;

sub new {
    my ($class) = @_;

    my $self = {};
    bless($self, $class);

    $self->{branchCategory} = 0;
#    $self->{mainLibraries} = 0;
#    $self->{branchLibraries} = 0;
#    $self->{institutionalLibraries} = 0;
#    $self->{bookmobiles} = 0;
#    $self->{bookboats} = 0;
    $self->{collection} = 0;
    $self->{collectionBooksTotal} = 0;
    $self->{collectionBooksFinnish} = 0;
    $self->{collectionBooksSwedish} = 0;
    $self->{collectionBooksOtherLanguage} = 0;
    $self->{collectionBooksFictionAdult} = 0;
    $self->{collectionBooksFictionJuvenile} = 0;
    $self->{collectionBooksNonFictionAdult} = 0;
    $self->{collectionBooksNonFictionJuvenile} = 0;
    $self->{collectionSheetMusicAndScores} = 0;
    $self->{collectionMusicalRecordings} = 0;
    $self->{collectionOtherRecordings} = 0;
    $self->{collectionVideos} = 0;
#    $self->{collectionCDROMs} = 0;
#    $self->{collectionDVDsAndBluRays} = 0;
    $self->{collectionCelia} = 0;
    $self->{collectionOther} = 0;
    $self->{acquisitions} = 0;
    $self->{acquisitionsBooksTotal} = 0;
    $self->{acquisitionsBooksFinnish} = 0;
    $self->{acquisitionsBooksSwedish} = 0;
    $self->{acquisitionsBooksOtherLanguage} = 0;
    $self->{acquisitionsBooksFictionAdult} = 0;
    $self->{acquisitionsBooksFictionJuvenile} = 0;
    $self->{acquisitionsBooksNonFictionAdult} = 0;
    $self->{acquisitionsBooksNonFictionJuvenile} = 0;
    $self->{acquisitionsSheetMusicAndScores} = 0;
    $self->{acquisitionsMusicalRecordings} = 0;
    $self->{acquisitionsOtherRecordings} = 0;
    $self->{acquisitionsVideos} = 0;
#    $self->{acquisitionsCDROMs} = 0;
#    $self->{acquisitionsDVDsAndBluRays} = 0;
    $self->{acquisitionsCelia} = 0;
    $self->{acquisitionsOther} = 0;
    $self->{issues} = 0;
    $self->{issuesBooksTotal} = 0;
    $self->{issuesBooksFinnish} = 0;
    $self->{issuesBooksSwedish} = 0;
    $self->{issuesBooksOtherLanguage} = 0;
    $self->{issuesBooksFictionAdult} = 0;
    $self->{issuesBooksFictionJuvenile} = 0;
    $self->{issuesBooksNonFictionAdult} = 0;
    $self->{issuesBooksNonFictionJuvenile} = 0;
    $self->{issuesSheetMusicAndScores} = 0;
    $self->{issuesMusicalRecordings} = 0;
    $self->{issuesOtherRecordings} = 0;
    $self->{issuesVideos} = 0;
#    $self->{issuesCDROMs} = 0;
#    $self->{issuesDVDsAndBluRays} = 0;
    $self->{issuesCelia} = 0;
    $self->{issuesOther} = 0;
    $self->{newspapers} = 0;
    $self->{magazines} = 0;
    $self->{discards} = 0;
    $self->{activeBorrowers} = 0;
    $self->{expenditureAcquisitions} = 0;
    $self->{expenditureAcquisitionsBooks} = 0;

    my @printOrder = (
        'branchCategory',
       # 'mainLibraries',
       # 'branchLibraries',
       # 'institutionalLibraries',
       # 'bookmobiles',
       # 'bookboats',
        'collection',
        'collectionBooksTotal',
        'collectionBooksFinnish',
        'collectionBooksSwedish',
        'collectionBooksOtherLanguage',
        'collectionBooksFictionAdult',
        'collectionBooksFictionJuvenile',
        'collectionBooksNonFictionAdult',
        'collectionBooksNonFictionJuvenile',
        'collectionSheetMusicAndScores',
        'collectionMusicalRecordings',
        'collectionOtherRecordings',
        'collectionVideos',
#        'collectionCDROMs',
#        'collectionDVDsAndBluRays',
        'collectionCelia',
        'collectionOther',
        'acquisitions',
        'acquisitionsBooksTotal',
        'acquisitionsBooksFinnish',
        'acquisitionsBooksSwedish',
        'acquisitionsBooksOtherLanguage',
        'acquisitionsBooksFictionAdult',
        'acquisitionsBooksFictionJuvenile',
        'acquisitionsBooksNonFictionAdult',
        'acquisitionsBooksNonFictionJuvenile',
        'acquisitionsSheetMusicAndScores',
        'acquisitionsMusicalRecordings',
        'acquisitionsOtherRecordings',
        'acquisitionsVideos',
#        'acquisitionsCDROMs',
#        'acquisitionsDVDsAndBluRays',
        'acquisitionsCelia',
        'acquisitionsOther',
        'issues',
        'issuesBooksTotal',
        'issuesBooksFinnish',
        'issuesBooksSwedish',
        'issuesBooksOtherLanguage',
        'issuesBooksFictionAdult',
        'issuesBooksFictionJuvenile',
        'issuesBooksNonFictionAdult',
        'issuesBooksNonFictionJuvenile',
        'issuesSheetMusicAndScores',
        'issuesMusicalRecordings',
        'issuesOtherRecordings',
        'issuesVideos',
#        'issuesCDROMs',
#        'issuesDVDsAndBluRays',
        'issuesCelia',
        'issuesOther',
        'newspapers',
        'magazines',
        'discards',
        'activeBorrowers',
        'expenditureAcquisitions',
        'expenditureAcquisitionsBooks',
    );
    $self->{printOrder} = \@printOrder;
    return $self;
}


sub asHtmlHeader {
    my ($self) = @_;

    my @sb;
    push @sb, '<thead><tr>';
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, "<td>$key</td>";
    }
    push @sb, '</tr></thead>';

    return join("\n", @sb);
}
sub asHtml {
    my ($self) = @_;

    my @sb;
    push @sb, '<tr>';
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, '<td>'.$self->{$key}.'</td>';
    }
    push @sb, '</tr>';

    return join("\n", @sb);
}

sub asCsvHeader {
    my ($self, $separator) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, "\"$key\"";
    }
    return join($separator, @sb);
}
sub asCsv {
    my ($self, $separator) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, '"'.$self->{$key}.'"';
    }

    return join($separator, @sb);
}

=head getPrintOrder

    $stats->getPrintOrder();

@RETURNS Array of Strings, all the statistical keys/columnsHeaders in the desired order.
=cut
sub getPrintOrder {
    my ($self) = @_;

    return $self->{printOrder};
}

=head getPrintOrderElements

    $stats->getPrintOrderElements();

Gets all the calculated statistical elements in the defined printOrder.
@RETURNS Pointer to an Array of Statistical Floats.
=cut
sub getPrintOrderElements {
    my ($self) = @_;

    my @sb;
    for (my $i=0 ; $i<@{$self->{printOrder}} ; $i++) {
        my $key = $self->{printOrder}->[$i];
        push @sb, $self->{$key};
    }

    return \@sb;
}

1; #Jep hep gep
