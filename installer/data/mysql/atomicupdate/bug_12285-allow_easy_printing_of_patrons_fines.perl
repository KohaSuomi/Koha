$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    # you can use $dbh here like:
    # $dbh->do( "ALTER TABLE biblio ADD COLUMN badtaste int" );

    $dbh->do( qq| INSERT IGNORE INTO letter (module, code, branchcode, name, is_html, title, content, message_transport_type) VALUES ( "circulation", "FINESLIP", "", "Patron fines -slip", "1", "Fines and fees slip", "<<borrowers.firstname>> <<borrowers.surname>><br><<borrowers.cardnumber>><br>Fines: <<total.fines>><ul><fines><li><<fines.date_due>>, <<fines.amount>><br>Barcode: <<items.barcode>><br><<fines.description>></li></fines></ul>Total: <<total.amount>>", "print")| );

    # Always end with this (adjust the bug info)
    NewVersion( $DBversion, 12285, "Allow easy printing of patron's fines");
}
