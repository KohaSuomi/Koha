$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    # you can use $dbh here like:
    $dbh->do( "INSERT INTO `borrower_attribute_types` (`code`, `description`, `unique_id`) VALUES ('LTOKEN','Token for sending logs to patrons',1)" );

    # Always end with this (adjust the bug info)
    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-3037 - Generic token link for patrons)\n";
}
