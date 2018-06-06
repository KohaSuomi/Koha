package Koha::MongoDB::LogJson;

use MongoDB;
use Koha::MongoDB::Config;
use Koha::MongoDB::Users;
use Koha::MongoDB::Logs;
#use Data::Dumper;
use Try::Tiny;
#@ISA = qw(Exporter);
#@EXPORT = qw(logs_borrower);

########################################
# returns log markings about one borrower, json format
sub logs_borrower
{
   my @args=@_;
   my $borrowernumber=$args[1];
   my $config = new Koha::MongoDB::Config;
   my $logs = new Koha::MongoDB::Logs;
   my $client = $config->mongoClient();
   my $settings=$config->getSettings();
   my $user_logs=$client->ns($settings->{database}.'.user_logs');
   my @logArray;

   try
   {
     
     my $resultset=$user_logs->find({"objectborrowernumber" => $borrowernumber});
     while(my $row = $resultset->next)
     {
        my $jsonObject;
        $jsonObject->{cardnumber} = $row->{objectcardnumber};
        $jsonObject->{action} = $row->{action};
        $jsonObject->{info} = $row->{info};
        $jsonObject->{timestamp} = $row->{timestamp};
        push (@logArray, $jsonObject);

     }
   }
   catch
   {
      if (!$client) {
        Koha::Exception::ConnectionFailed->throw(error => $cal[3].'():>'."No MongoDB connection");
      }
      if (!$user_logs) {
        my @cal = caller(0);
        Koha::Exception::UnknownObject->throw(error => $cal[3].'():>'."Cannot fetch the patron data from MongoDB");
      } 
   };

   return(\@logArray);
}

1;
