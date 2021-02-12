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

# Conversion of getFormat() in https://github.com/NatLibFi/RecordManager/blob/dev/src/RecordManager/Finna/Record/Marc.php
sub getFinnaMaterialType {
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

    return 'MusicalScore'   if ($typeOfRecord eq 'C' || $typeOfRecord eq 'D');
    return 'Map'            if ($typeOfRecord eq 'E' || $typeOfRecord eq 'F');
    return 'Slide'          if ($typeOfRecord eq 'G');
    return 'SoundRecording' if ($typeOfRecord eq 'I');
    return 'MusicRecording' if ($typeOfRecord eq 'J');
    return 'Photo'          if ($typeOfRecord eq 'K');
    return 'Electronic'     if ($typeOfRecord eq 'M');
    return 'Kit'            if ($typeOfRecord eq 'O' || $typeOfRecord eq 'P');
    return 'PhysicalObject' if ($typeOfRecord eq 'R');
    return 'Manuscript'     if ($typeOfRecord eq 'T');

    my $field008 = $record->field('008');
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

1;
