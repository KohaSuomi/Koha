package C4::AuthExtra;

=expl
get_timeout returns timeout based on user's category
value is in sysprefs variable BorrowerCategoryTimeout
value is in yaml-format example:

---
USERCATEGORY1: 600
AUTOMAT: 31536000
DEFAULT: 1200
=cut

use C4::Context;
use Try::Tiny;
use YAML;
use Koha::Config;
use Digest::MD5 qw(md5_base64);

##################################
#gets timeout based on borrower's category
sub get_timeout {
    my $error;
    my ($cardnumber,$timeout) = @_;
    
    my $dbh   = C4::Context->dbh;
    my $valueyaml;
    my $retval = $timeout;
 
    try {

        #get catgorycode
        my $categorycode = "DEFAULT";

        if ($cardnumber) {
            $cardnumber = trim($cardnumber);            
            my $sql = "select categorycode from borrowers where trim(cardnumber)='".$cardnumber."'";
            my $sth = $dbh->prepare($sql);
            $sth->execute();        
            while (@row = $sth->fetchrow_array()) {
                $categorycode = $row[0];
            }
            $sth->finish();
        }
 
        #get timeout's valueyaml from systempreferences
        $valueyaml = Koha::Config::SysPrefs->find('BorrowerCategoryTimeout')->value;
      
        #get category's timeout
        if($valueyaml) {
            my $timeouts = Load($valueyaml);
            my $newtimeout = $timeouts->{$categorycode};
            if($newtimeout > 0) {
                $retval = $newtimeout;
            }
        }
    }
    catch {
       $error = $_;
    };

    if($error) {
        $retval = $timeout;
    }

    return($retval);
}


#removes spaces from start and end
sub trim {
    my ($retval) = @_;
    $retval =~ s/^\s+|\s+$//g;
    return($retval);
}

=expl2
checksum_userjs checks the md5 hashes of intranetUserJS
and OPACUserJS if the hashes are stored in koha-conf.

A small tweak in Auth.pm will prevent using the Koha SC
when the calculate hashes don't match the stored ones.
=cut

sub checksum_userjs {
    if (C4::Context->config('intranetuserjschecksum')) {
        unless ( md5_base64(C4::Context->preference('IntranetUserJS')) eq C4::Context->config('intranetuserjschecksum') ) {
          warn "IntranetUserJS checksum mismatch, check the system preference and your Koha configuration";
          return 0;
        }
    }
    if (C4::Context->config('opacuserjschecksum')) {
        unless ( md5_base64(C4::Context->preference('OPACUserJS')) eq C4::Context->config('opacuserjschecksum') ) {
          warn "OPACUserJS checksum mismatch, check the system preference and your Koha configuration";
          return 0;
        }
    }
    return 1;
}

1;
