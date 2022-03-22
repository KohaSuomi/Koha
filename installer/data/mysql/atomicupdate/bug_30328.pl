use Modern::Perl;

return {
    bug_number => "30328",
    description => "Add option to create barcode with branch specific prefix",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        # Do you stuffs here
        $dbh->do(q{ UPDATE IGNORE systempreferences SET options = 'incremental|annual|hbyymmincr|EAN13|preyyyymmincr|OFF' , explanation = 'Used to autogenerate a barcode: incremental will be of the form 1, 2, 3; annual of the form 2007-0001, 2007-0002; hbyymmincr of the form HB08010001 where HB=Home Branch; preyyyymmincr of the form PRE2021030001 where PRE = branch specific prefix set on systempreference BarcodePrefix' WHERE variable = 'autoBarcode'});
        $dbh->do(q{ INSERT IGNORE INTO systempreferences ( variable, value, options, explanation, type ) VALUES ('BarcodePrefix','','','Defines the barcode prefixes when the autoBarcode value is set as preyyyymmincr','Free')});
        # Print useful stuff here
        say $out "Update is going well so far";
    },
};
