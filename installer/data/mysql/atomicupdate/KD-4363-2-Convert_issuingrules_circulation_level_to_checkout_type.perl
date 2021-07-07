$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do(q{
        ALTER TABLE issuingrules
            DROP INDEX issuingrules_selects
    });
    $dbh->do(q{
        ALTER TABLE issuingrules
            CHANGE COLUMN circulation_level checkout_type varchar(10) NOT NULL DEFAULT '*' AFTER `genre`
    });
    $dbh->do("ALTER TABLE issuingrules
        ADD UNIQUE KEY `issuingrules_selects` (`branchcode`,`categorycode`,`itemtype`,`ccode`,`permanent_location`,`sub_location`,`genre`,`checkout_type`,`reserve_level`),
        ADD KEY `checkout_type` (`checkout_type`)
    ");
    $dbh->do("UPDATE issuingrules SET checkout_type='*' WHERE checkout_type IS NULL");

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-4363-2: Convert issuingrules.circulation_level to issuingrules.checkout_type\n";
}
