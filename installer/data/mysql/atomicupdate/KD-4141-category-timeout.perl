$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do("INSERT INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('BorrowerCategoryTimeout',NULL,NULL,'Timeout based on borrowers category', 'Textarea')");

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-4141 - Category timeout)\n";
}






