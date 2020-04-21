$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    # you can use $dbh here like:
    use Koha::Auth::PermissionManager;
    my $pm = Koha::Auth::PermissionManager->new();
    $pm->addPermission({module => 'editcatalogue', code => 'add_holding', description => "Allows to create a new holding record"});
    $pm->addPermission({module => 'editcatalogue', code => 'edit_holding', description => "Allows to update a holding record"});
    $pm->addPermission({module => 'editcatalogue', code => 'delete_holding', description => "Allows to delete a holding record"});

    # Add add_holding permission to everyone who has add_catalogue permission
    my $add_catalogue = $pm->getPermission('add_catalogue');
    my $add_holding = $pm->getPermission('add_holding');
    if ($add_catalogue) {
        my $add_catalogue_id = $add_catalogue->permission_id;
        my $add_holding_id = $add_holding->permission_id;

        my $sth = $dbh->prepare(qq|
            INSERT INTO borrower_permissions (borrowernumber, permission_module_id, permission_id)
                SELECT borrowernumber, permission_module_id, ? FROM borrower_permissions WHERE permission_id = ?
        |);

        $sth->execute($add_holding_id, $add_catalogue_id);
    }

    # Add edit_holding permission to everyone who has edit_catalogue permission
    my $edit_catalogue = $pm->getPermission('edit_catalogue');
    my $edit_holding = $pm->getPermission('edit_holding');
    if ($edit_catalogue) {
        my $edit_catalogue_id = $edit_catalogue->permission_id;
        my $edit_holding_id = $edit_holding->permission_id;

        my $sth = $dbh->prepare(qq|
            INSERT INTO borrower_permissions (borrowernumber, permission_module_id, permission_id)
                SELECT borrowernumber, permission_module_id, ? FROM borrower_permissions WHERE permission_id = ?
        |);

        $sth->execute($edit_holding_id, $edit_catalogue_id);
    }

    # Add delete_holding permission to everyone who has delete_catalogue permission
    my $delete_catalogue = $pm->getPermission('delete_catalogue');
    my $delete_holding = $pm->getPermission('delete_holding');
    if ($delete_catalogue) {
        my $delete_catalogue_id = $delete_catalogue->permission_id;
        my $delete_holding_id = $delete_holding->permission_id;

        my $sth = $dbh->prepare(qq|
            INSERT INTO borrower_permissions (borrowernumber, permission_module_id, permission_id)
                SELECT borrowernumber, permission_module_id, ? FROM borrower_permissions WHERE permission_id = ?
        |);

        $sth->execute($delete_holding_id, $delete_catalogue_id);
    }

    # Always end with this (adjust the bug info)
    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 24751: Add [add|edit|delete]_catalogue permissions)\n";
}
