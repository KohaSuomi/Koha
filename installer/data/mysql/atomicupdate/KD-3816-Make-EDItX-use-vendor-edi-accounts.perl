$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {

    # Make the conversion from procurement_bookseller_link to vendor_edi_accounts if we have old procurement_bookseller_link table

    my $sth_booksellerlink=$dbh->prepare('SHOW TABLES LIKE "procurement_bookseller_link";');
    $sth_booksellerlink->execute();
    if ( $sth_booksellerlink->fetch() ) {
        $dbh->do("INSERT INTO vendor_edi_accounts (description, vendor_id, san, id_code_qualifier, transport, orders_enabled) SELECT 'Procurement Bookseller Link', aqbooksellers_id, vendor_assigned_id, '91', 'FILE', '1' FROM procurement_bookseller_link;");

        # Then check that it went ok before dropping the old procurement_bookseller_link table

        $sth_booksellerlink=$dbh->prepare ( "SELECT COUNT(*) FROM procurement_bookseller_link;" );
        $sth_booksellerlink->execute();

        my @booksellerlink = $sth_booksellerlink->fetchrow_array();

        my $sth_ediaccounts=$dbh->prepare ( "SELECT COUNT(*) FROM vendor_edi_accounts WHERE description='Procurement Bookseller Link'" );
        $sth_ediaccounts->execute();

        my @ediaccounts = $sth_ediaccounts->fetchrow_array();
        $sth_ediaccounts->finish();

        if ($booksellerlink[0] == $ediaccounts[0]) {
            $dbh->do("DROP TABLE procurement_bookseller_link;");
        } else {
            warn "The count of lines in vendor_edi_accounts doesn't look right, will not drop procurement_bookseller_link.\n";
        }
    }
    $sth_booksellerlink->finish();

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-3816-Make-EDItX-use-vendor-edi-accounts)\n";
}
