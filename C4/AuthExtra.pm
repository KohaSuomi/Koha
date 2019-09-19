package C4::AuthExtra;

=expl
get_timeout returns timeout based on user's category
value is in sysprefs variable BorrowerCategoryTimeout
value is in yaml-format example:

---
USERCATEGORY1: 600
AUTOMAT: 31536000

=cut

use C4::Context;
use Try::Tiny;
use YAML;

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
            my $sql="select categorycode from borrowers where trim(cardnumber)='".$cardnumber."'";
            my $sth=$dbh->prepare($sql);
            $sth->execute();        
            while (@row=$sth->fetchrow_array()) {
                $categorycode=$row[0];
            }
            $sth->finish();
        } 
        #get timeout's valueyaml from systempreferences
        $sql="select value from systempreferences where variable='BorrowerCategoryTimeout'";
        $sth=$dbh->prepare($sql);
        $sth->execute();
        while (@row=$sth->fetchrow_array()) {
            $valueyaml=$row[0];
        }
        $sth->finish();

        #get category's timeout
        my $timeouts=Load($valueyaml);
        my $newtimeout=$timeouts->{$categorycode};
        if($newtimeout > 0) {
            $retval=$newtimeout;
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


##############################################
sub trim {
    my ($retval)=@_;
    $retval =~ s/^\s+|\s+$//g;
    return($retval);
}

1;



