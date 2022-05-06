use Modern::Perl;

return {
    bug_number => "29092",
    description => "Add timestamp to account-fines table column settings",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO columns_settings (module, page, tablename, columnname, cannot_be_toggled, is_hidden) VALUES ("members", "fines", "account-fines", "timestamp", 0, 0)});
        # Print useful stuff here
        say $out "Update is going well so far";
    },
};
