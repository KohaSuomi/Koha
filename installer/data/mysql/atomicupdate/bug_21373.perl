$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do(q{
        INSERT INTO systempreferences ( variable, value, options, explanation, type ) VALUES
        ('AllowCheckoutIfOtherItemsAvailable','0',NULL,'If enabled, allow a patron to checkout an item with unfilled holds if other available items can fill that hold.','YesNo')
    });
    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 21373 - Checkout not possible when biblio level hold but other items could satisfy it)\n";
}
