$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
	$dbh->do("ALTER TABLE map_productform ADD COLUMN productform_alternative varchar(10);");

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-5068-EditX_import_Support_for_alternative_onix-code_mappings)\n";
}
