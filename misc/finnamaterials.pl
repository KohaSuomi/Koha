#!/usr/bin/perl

use strict;

use C4::Context;
use C4::Biblio;
use C4::KohaSuomi::FinnaMaterialType;

use Getopt::Long;
use MARC::Record;
use MARC::File::XML (BinaryEncoding => 'UTF-8');
use MARC::Charset;

my $help = 0;
my $verbose = 0;
my $confirm = 0;
my $field = '942c';
my $sqlquery = 'select biblionumber, metadata from biblio_metadata order by biblionumber asc';


GetOptions(
    'sql=s' => \$sqlquery,
    'field=s' => \$field,
    'v|verbose' => \$verbose,
    'confirm' => \$confirm,
    'help|h|?' => \$help,
    ) or die("Param Error"); 

if ($help) {
    my $msg = <<HELPPI;
    Change $field in records to Finna-compatible values.

    --sql='$sqlquery'
    --field=$field
    --verbose
    --confirm
    --help
  
    Without confirm, runs in a dry-run mode.
HELPPI
  print $msg;  
    exit;
}

my $dbh = C4::Context->dbh();

MARC::Charset->assume_unicode(1);

my $sth = $dbh->prepare($sqlquery);

$sth->execute();


my $updatesql = 'update biblio_metadata set timestamp=NOW(), metadata=? where biblionumber=?';
my $updsth = $dbh->prepare($updatesql);


my $realfield = substr($field, 0, 3);
my $subfield = substr($field, 3, 1) || '';

if ($subfield eq '') {
    die("Impossible: This script can only change subfields, not controlfields");
}

while (my $ref = $sth->fetchrow_hashref()) {
    if ($ref->{'biblionumber'}) {
	my $bn = $ref->{'biblionumber'};
	my $changed = 0;
	my $record;
	eval {
	    $record = MARC::Record->new_from_xml($ref->{'metadata'});
	};
	my $finnamaterial = getFinnaMaterialType($record);

	my @flds = $record->field($realfield);

	if (scalar(@flds) <= 0) {
	    print "biblionumber=$bn: $field nonexistent, added $finnamaterial.\n" if ($verbose);
	    my $newfield = MARC::Field->new($realfield, '', '', $subfield => $finnamaterial);
	    $record->insert_grouped_field($newfield);
	    $changed = 1;
	} else {
	    foreach my $fld (@flds) {
		my $sf = $fld->subfield($subfield);
		if ($sf) {
		    if ($sf ne $finnamaterial) {
			print "biblionumber=$bn: $field was $sf, changed to $finnamaterial.\n" if ($verbose);
			$fld->update($subfield => $finnamaterial);
			$changed = 1;
		    } else {
			print "biblionumber=$bn: $field is already $finnamaterial, skipping.\n" if ($verbose);
		    }
		} else {
		    print "biblionumber=$bn: $field was empty or nonexistent, changed to $finnamaterial.\n" if ($verbose);
		    $fld->update($subfield => $finnamaterial);
		    $changed = 1;
		}
	    }
	}

	if ($confirm && $changed) {
	    $updsth->execute($record->as_xml_record(), $bn);
	    C4::Biblio::ModZebra( $bn, "specialUpdate", "biblioserver" );
	}
    }
}

