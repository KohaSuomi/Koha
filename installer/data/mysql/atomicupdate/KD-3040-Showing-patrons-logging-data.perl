$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do("INSERT INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('LogInterface','local','local|remote','for fetching patrons logging data.', 'Choice')");
    $dbh->do("INSERT INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('RemoteInterfaceURL',NULL,NULL,'Add used remote JSON interface url.', 'Free')");

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-3040 - Showing patron's logging data)\n";
}