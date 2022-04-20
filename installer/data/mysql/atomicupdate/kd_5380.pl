use Modern::Perl;

return {
    bug_number => "5380",
    description => "Add syspref FloatRules",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT IGNORE INTO systempreferences ( variable, value, options, explanation, type ) VALUES ('FloatRules','','','Define float rules by items table columns and biblioitems table itemtype column','textarea')});
        # Print useful stuff here
        say $out "Update is going well so far";
    },
};
