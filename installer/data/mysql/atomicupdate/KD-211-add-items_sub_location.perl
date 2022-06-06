use Modern::Perl;

return {
    bug_number => "211",
    description => "Add items.sub_location",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{ALTER TABLE items ADD COLUMN sub_location VARCHAR(10) DEFAULT NULL AFTER new_status});
        $dbh->do(q{ALTER TABLE deleteditems ADD COLUMN sub_location VARCHAR(10) DEFAULT NULL AFTER new_status});
        # Print useful stuff here
        say $out "Update is going well so far";
    },
};
