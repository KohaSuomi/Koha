$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do(q{
        ALTER TABLE items
            DROP COLUMN circulation_level
    });
    $dbh->do(q{
        ALTER TABLE deleteditems
            DROP COLUMN circulation_level
    });
    $dbh->do(q{
        DELETE FROM authorised_value_categories where category_name="CIRCULATION_LEVEL"
    });

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (KD-4363-1: Drop items.circulation_level and deleteditems.circulation_level\n";
}
