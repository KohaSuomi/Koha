$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {

    $dbh->do(
        "INSERT INTO message_transport_types (message_transport_type) VALUES ('invoice');"
    );

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-4707 - Invoice REST endpoint)\n";
}
