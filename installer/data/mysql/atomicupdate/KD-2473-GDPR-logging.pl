use Modern::Perl;

return {
    bug_number => "2473",
    description => "GDRP logging",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{INSERT INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ('BorrowersViewLog','0',NULL,'If ON, log view actions on patron data','YesNo');});
        # Print useful stuff here
        say $out "KD-2473 - GDRP logging";
    },
};