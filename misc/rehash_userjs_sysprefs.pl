#!/usr/bin/perl
# This script will recalculate IntranetUserJS and OPACUserJS
# checksums when they have been altered. New hashes will be
# stored in koha-conf.

# You will likely need to flush memcached and reload plack
# after running this script.

use C4::Context;
use Digest::MD5 qw(md5_base64);

die "No KOHA_CONF defined" unless $ENV{'KOHA_CONF'};

$intranethash=md5_base64(C4::Context->preference('IntranetUserJs'));
$opachash=md5_base64(C4::Context->preference('OPACUserJs'));

open $in,  '<',  "$ENV{'KOHA_CONF'}" or die "Can't read: $!";
while( <$in> ) {
    s/^[[:space:]]*<intranetuserjschecksum>.*<\/intranetuserjschecksum>/<intranetuserjschecksum>$intranethash<\/intranetuserjschecksum>/;
    s/^[[:space:]]*<opacuserjschecksum>.*<\/opacuserjschecksum>/<opacuserjschecksum>$opachash<\/opacuserjschecksum>/;
    push @modified, $_;
}
close $in;

open $out,  '>',  "$ENV{'KOHA_CONF'}" or die "Can't write: $!";
foreach ( @modified ) {
    print $out $_;
}
close $out;
