package C4::KohaSuomi::FinnaMaterialType;

use strict;

use vars qw(@ISA @EXPORT);

BEGIN {
	require Exporter;
    @ISA = qw( Exporter );

    # function exports
    @EXPORT = qw(
        getFinnaMaterialType
    );
}

my %FinnaMaterialLang = (

    'Article' => { 'fi_FI' => 'ARTIKKELI' },
    'Atlas' => { 'fi_FI' => 'ATLAS' },
    'BluRay' => { 'fi_FI' => 'BLURAY' },
    'BookSection' => { 'fi_FI' => 'KIRJA' },
    'Book' => { 'fi_FI' => 'KIRJA' },
    'Braille' => { 'fi_FI' => 'BRAILLE' },
    'CDROM' => { 'fi_FI' => 'CDROM' },
    'CD' => { 'fi_FI' => 'CD' },
    'ChipCartridge' => { 'fi_FI' => 'PIIRIKOT' },
    'Drawing' => { 'fi_FI' => 'PIIRROS' },
    'DVD' => { 'fi_FI' => 'DVD' },
    'eBookSection' => { 'fi_FI' => 'EKIRJA' },
    'eBook' => { 'fi_FI' => 'EKIRJA' },
    'Electronic' => { 'fi_FI' => 'ELEKTRON' },
    'Journal' => { 'fi_FI' => 'ALEHTI' },
    'Kit' => { 'fi_FI' => 'MONIVIES' },
    'Manuscript' => { 'fi_FI' => 'KASIKIRJ' },
    'Map' => { 'fi_FI' => 'KARTTA' },
    'Microfilm' => { 'fi_FI' => 'MIKROF' },
    'MusicalScore' => { 'fi_FI' => 'NUOTTI' },
    'MusicRecording' => { 'fi_FI' => 'MUSATAL' },
    'Newspaper' => { 'fi_FI' => 'SLEHTI' },
    'NonmusicalCassette' => { 'fi_FI' => 'PUHEKAS' },
    'NonmusicalCD' => { 'fi_FI' => 'PUHECD' },
    'NonmusicalDisc' => { 'fi_FI' => 'PUHELEVY' },
    'NonmusicalRecording' => { 'fi_FI' => 'PUHETAL' },
    'OnlineVideo' => { 'fi_FI' => 'EVIDEO' },
    'Painting' => { 'fi_FI' => 'MAALAUS' },
    'Photo' => { 'fi_FI' => 'VALOKUVA' },
    'PhysicalObject' => { 'fi_FI' => 'ESINE' },
    'Print' => { 'fi_FI' => 'MUUPAINATE' },
    'eSerial' => { 'fi_FI' => 'KAUSIJULK' },
    'Serial' => { 'fi_FI' => 'KAUSIJULK' },
    'Slide' => { 'fi_FI' => 'DIA' },
    'SoundCassette' => { 'fi_FI' => 'AANIKAS' },
    'SoundDisc' => { 'fi_FI' => 'AANILEVY' },
    'SoundRecording' => { 'fi_FI' => 'AANITALL' },
    'TechnicalDrawing' => { 'fi_FI' => 'TYOPIIR' },
    'VideoCassette' => { 'fi_FI' => 'VIDEOKAS' },
    'VideoDisc' => { 'fi_FI' => 'VIDEOLEVY' },
    'Video' => { 'fi_FI' => 'VIDEO' },
    'ConsoleGame' => { 'fi_FI' => 'KONSOLIP' },
    'TapeCartridge' => { 'fi_FI' => 'NAUHAKAS' },
    'DiscCartridge' => { 'fi_FI' => 'OPTINEN' },
    'TapeCasette' => { 'fi_FI' => 'DATKAS' },
    'TapeReel' => { 'fi_FI' => 'MAGNEETTI' },
    'FloppyDisc' => { 'fi_FI' => 'LEVYKE' },
    'Filmstrip' => { 'fi_FI' => 'RAINA' },
    'Transparency' => { 'fi_FI' => 'KALVO' },
    'Collage' => { 'fi_FI' => 'KOLLAASI' },
    'Photonegative' => { 'fi_FI' => 'NEGATIIVI' },
    'Flashcard' => { 'fi_FI' => 'KORTTI' },
    'Chart' => { 'fi_FI' => 'KAAVIO' },
    'MotionPicture' => { 'fi_FI' => 'ELOKUVA' },
    'SensorImage' => { 'fi_FI' => 'KAUKOKART' },
    'VideoCartridge' => { 'fi_FI' => 'VIDEOSILM' },
    'VideoReel' => { 'fi_FI' => 'VIDEOKELA' },
    'Collection' => { 'fi_FI' => 'KOKOELMA' },
    'SubUnit' => { 'fi_FI' => 'SARJANOSA' },
    'ContinuouslyUpdatedRecource' => { 'fi_FI' => 'PAIVITTYVA' },
    'Other' => { 'fi_FI' => 'MUU' },

    );

# Conversion of getFormat() in https://github.com/NatLibFi/RecordManager/blob/dev/src/RecordManager/Finna/Record/Marc.php
sub getFinnaMaterialType_core {
    my ($record) = @_;

    my $leader = $record->leader();

    my $typeOfRecord = uc(substr($leader, 6, 1));
    my $bibliographicLevel = uc(substr($leader, 7, 1));
    my $online = 0;

    foreach my $field ($record->field('007')) {
        my $contents = $field->data();
        my $format1 = uc(substr($contents, 0, 1)); # $formatCode
        my $format2 = uc(substr($contents, 1, 1)); # $formatCode2
        my $formats = uc(substr($contents, 0, 2)); # $formatCode + $formatCode2

        return 'Atlas' if ($formats eq 'AD');
        return 'Map'   if ($format1 eq 'A');

        return 'TapeCartridge' if ($formats eq 'CA');
        return 'ChipCartridge' if ($formats eq 'CB');
        return 'DiscCartridge' if ($formats eq 'CC');
        return 'TapeCassette'  if ($formats eq 'CF');
        return 'TapeReel'      if ($formats eq 'CH');
        return 'FloppyDisc'    if ($formats eq 'CJ');
        return 'CDROM'         if ($formats eq 'CM' || $formats eq 'CO');
        $online = 1            if ($formats eq 'CR');
        return 'Electronic'    if ($format1 eq 'C' && $formats ne 'CR');

        return 'Globe' if ($format1 eq 'D');

        return 'Braille' if ($format1 eq 'F');

        return 'Filmstrip'    if ($formats eq 'GC' || $formats eq 'GD');
        return 'Transparency' if ($formats eq 'GT');
        return 'Slide'        if ($format1 eq 'G');

        return 'Microfilm' if ($format1 eq 'H');

        return 'Collage'          if ($formats eq 'KC');
        return 'Drawing'          if ($formats eq 'KD');
        return 'Painting'         if ($formats eq 'KE');
        return 'Print'            if ($formats eq 'KF');
        return 'Photonegative'    if ($formats eq 'KG');
        return 'Print'            if ($formats eq 'KJ');
        return 'TechnicalDrawing' if ($formats eq 'KL');
        return 'Flashcard'        if ($formats eq 'KO');
        return 'Chart'            if ($formats eq 'KN');
        return 'Photo'            if ($format1 eq 'K');

        return 'VideoCassette' if ($formats eq 'MF');
        return 'Filmstrip'     if ($formats eq 'MR');
        return 'MotionPicture' if ($format1 eq 'M');

        return 'Kit' if ($format1 eq 'O');

        return 'MusicalScore' if ($format1 eq 'Q');

        return 'SensorImage' if ($format1 eq 'R');

        if ($formats eq 'SD') {
            my $size = uc(substr($contents, 6, 1));
            my $material = uc(substr($contents, 10, 1));
            my $soundTech = uc(substr($contents, 13, 1));
            return (($typeOfRecord eq 'I') ? 'NonmusicalCD' : 'CD') if ($soundTech eq 'D' || ($size eq 'G' && $material eq 'M'));
            return  ($typeOfRecord eq 'I') ? 'NonmusicalDisc' : 'SoundDisc';
        }
        return (($typeOfRecord eq 'I') ? 'NonmusicalCassette' : 'SoundCassette') if ($formats eq 'SS');
        return 'NonmusicalRecording' if ($format1 eq 'S' && $typeOfRecord eq 'I');
        return 'MusicRecording' if ($format1 eq 'S' && $typeOfRecord eq 'J');
        return 'SoundRecording' if ($format1 eq 'S');


        if ($format1 eq 'V') {
            my $videoFormat = uc(substr($contents, 4, 1));
            return 'BluRay' if ($videoFormat eq 'S');
            return 'DVD' if ($videoFormat eq 'V');
        }
        return 'VideoCartridge' if ($formats eq 'VC');
        return 'VideoDisc'      if ($formats eq 'VD');
        return 'VideoCassette'  if ($formats eq 'VF');
        return 'VideoReel'      if ($formats eq 'VR');
        return ($online ? 'OnlineVideo' : 'Video') if ($formats eq 'VZ');
        return 'Video'          if ($format1 eq 'V');

    } # 007 fields

    my $field008 = $record->field('008')->data() if $record->field('008');

    return 'MusicalScore'   if ($typeOfRecord eq 'C' || $typeOfRecord eq 'D');
    return 'Map'            if ($typeOfRecord eq 'E' || $typeOfRecord eq 'F');
    return 'Slide'          if ($typeOfRecord eq 'G');
    return 'SoundRecording' if ($typeOfRecord eq 'I');
    return 'MusicRecording' if ($typeOfRecord eq 'J');
    return 'Photo'          if ($typeOfRecord eq 'K');
    return 'ConsoleGame'    if ($typeOfRecord eq 'M' && uc(substr($field008, 26, 1)) eq 'G');
    return 'Electronic'     if ($typeOfRecord eq 'M');
    return 'Kit'            if ($typeOfRecord eq 'O' || $typeOfRecord eq 'P');
    return 'PhysicalObject' if ($typeOfRecord eq 'R');
    return 'Manuscript'     if ($typeOfRecord eq 'T');

    $online = (substr($field008, 23, 1) eq 'o' ? 1 : 0) if (!$online);

    return ($online ? 'eBook' : 'Book') if ($bibliographicLevel eq 'M');
    if ($bibliographicLevel eq 'S') {
        my $formatCode = uc(substr($field008, 21, 1));
        return ($online ? 'eNewspaper' : 'Newspaper') if ($formatCode eq 'N');
        return ($online ? 'eJournal' : 'Journal') if ($formatCode eq 'P');
        return ($online ? 'eSerial' : 'Serial');
    }
    return ($online ? 'eBookSection' : 'BookSection') if ($bibliographicLevel eq 'A');
    return ($online ? 'eArticle'     : 'Article')     if ($bibliographicLevel eq 'B');
    return 'Collection' if ($bibliographicLevel eq 'C');
    return 'SubUnit'    if ($bibliographicLevel eq 'D');
    return 'ContinuouslyUpdatedResource' if ($bibliographicLevel eq 'I');
    return 'Other';
};

sub getFinnaMaterialType {
    my ($record, $lang) = @_;

    $lang = 'en' if (!defined($lang));
    my $fmt = getFinnaMaterialType_core($record);
    return $FinnaMaterialLang{$fmt}{$lang} if (defined($FinnaMaterialLang{$fmt}) && defined($FinnaMaterialLang{$fmt}{$lang}));
    return $fmt;
}

1;
