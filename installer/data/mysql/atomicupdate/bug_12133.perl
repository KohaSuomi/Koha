$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    # you can use $dbh here like:
    $dbh->do( q{
        INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)
        VALUES('ChildNeedsGuarantor', 0, 'If ON, a child patron must have a guarantor when adding the patron.', '', 'YesNo');
    } );
    $dbh->do( q{
        INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type)
        VALUES('GuarantorHasToBePatron', 0, 'If ON guarantor has to be a patron.', '', 'YesNo')
    } );
    # or perform some test and warn
    # if( !column_exists( 'biblio', 'biblionumber' ) ) {
    #    warn "There is something wrong";
    # }

    # Always end with this (adjust the bug info)
    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 12133 - Guarantor requirements when registering a patron)\n";
}
