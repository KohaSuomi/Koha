$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    # you can use $dbh here like:
    # $dbh->do( "ALTER TABLE biblio ADD COLUMN badtaste int" );

    $dbh->do("INSERT INTO systempreferences (variable, value, options, explanation, type) VALUES ('DebarmentsToLiftAfterPayment', '', '', 'Lift these debarments after Borrower has paid his/her fees', 'textarea')");

    # Always end with this (adjust the bug info)
    NewVersion( $DBversion, 16223, "Automatically remove any borrower debarments after a payment");
}
