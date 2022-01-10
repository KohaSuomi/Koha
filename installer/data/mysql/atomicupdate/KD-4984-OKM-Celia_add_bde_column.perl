$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do( "ALTER TABLE biblio_data_elements ADD COLUMN celia tinyint(1)" );

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-4984-OKM-Celia_add_bde_column)\n";
}
