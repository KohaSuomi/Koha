package C4::PatronJson2;
require Exporter;
use C4::Context;
use Try::Tiny;
use C4::PatronJson;
use MongoDB;
use Koha::MongoDB::Config;
use Koha::MongoDB::Users;
use Koha::MongoDB::Logs;

@ISA = qw(Exporter);
@EXPORT = qw(account_json log_json messages_json);

######################################
#collects patron's account info to json
#result will be part of "all data" json in PatronJson.pm
sub account_json {
 
  my @args=@_;
  my $borrowernumber=$args[0];
  my $jsonstring="\"Laskut\":[\n";
  my $sqlstring;
  try
  {
    $sqlstring=C4::PatronJson::makesqlstring($borrowernumber,"6");
    my $dbh=C4::Context->dbh();
    my $query=$dbh->prepare($sqlstring);
    my $i=0;    
    my $string1;
    my $string2;
  
    $query->execute() or die;

    while(my @resultset=$query->fetchrow_array())
    {
      $string1="";
      $string2="";

      if($i > 0)
      {
        $jsonstring.="\n,\n";
      }
      $jsonstring.="{\n";

      # account date
      $string1=$resultset[2];
      $string1=(C4::PatronJson::convertstring($string1));
      $jsonstring.="\"Päiväys\":\"".$string1."\",\n";

      # amount
      $string1=$resultset[1];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Summa\":\"".$string1."\",\n";

      # title
      $string1=$resultset[4];
      $string2=$resultset[5];
      if($string1 eq "")
      {
        $string1=$string2;
      }
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Julkaisu\":\"".$string1."\",\n";

      # description
      $string1=$resultset[0];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Kuvaus\":\"".$string1."\"\n}";

      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring.=$sqlstring;
  };

  return($jsonstring);
}

######################################
#log about changes made in patron's personal info
#result will be part of "all data" json in PatronJson.pm
sub log_json_db {
  my @args=@_;
  my $borrowernumber=$args[0];
  my $jsonstring="\"Lokimerkinnät\":[\n";
  my $sqlstring="";
  try
  {
    $sqlstring=C4::PatronJson::makesqlstring($borrowernumber,"7");
    my $dbh=C4::Context->dbh();
    my $query=$dbh->prepare($sqlstring);
    my $i=0;
    my $string1;

    $query->execute() or die;

    while(my @resultset=$query->fetchrow_array())
    {
      $string1="";
      $string2="";

      if($i > 0)
      {
        $jsonstring.="\n,\n";
      }
      $jsonstring.="{\n";

      # change's date
      $string1=$resultset[0];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Päiväys\":\"".$string1."\",\n";

      # module
      $string1=$resultset[1];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Moduli\":\"".$string1."\",\n";

      # action code
      $string1=$resultset[2];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Toiminto\":\"".$string1."\",\n";

      # info
      $string1=$resultset[3];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Info\":\"".$string1."\",\n";
      
      # interface       
      $string1=$resultset[4];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Inteface\":\"".$string1."\"\n}";

      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring="";
  };

  return($jsonstring);
}

######################################
#collects patron's messages
#result will be part of "all data" json in PatronJson.pm
sub messages_json {

  my @args=@_;
  my $borrowernumber=$args[0];
  my $jsonstring="\"Saadut viestit\":[\n";
  my $sqlstring;
  try
  {
    $sqlstring=C4::PatronJson::makesqlstring($borrowernumber,"8");
    my $dbh=C4::Context->dbh();
    my $query=$dbh->prepare($sqlstring);
    my $i=0;
    my $string1;

    $query->execute() or die;

    while(my @resultset=$query->fetchrow_array())
    {
      $string1="";

      if($i > 0)
      {
        $jsonstring.="\n,\n";
      }

      $jsonstring.="{\n";
      $string1=$resultset[0];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Päiväys\":\"".$string1."\",\n";

      $string1=$resultset[1];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Viesti\":\"".$string1."\"\n}";

      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring="";
  };

  return($jsonstring);
}

########################################
# returns log markings about one borrower from MongoDB
sub log_json_mongo
{
   my @args=@_;
   my $borrowernumber=$args[0];
   my $config = new Koha::MongoDB::Config;
   my $logs = new Koha::MongoDB::Logs;
   my $jsonstring="";
   my $count=0;

   try
   {
     my $client = $config->mongoClient();
     my $settings=$config->getSettings();
     my $user_logs=$client->ns($settings->{database}.'.user_logs');
     my $resultset=$user_logs->find({"objectborrowernumber" => $borrowernumber});
     $jsonstring="\"Lokimerkinnät\":[";
     while(my $row = $resultset->next)
     {
       if($count > 0)
       {
          $jsonstring.="\n,\n";
       }
       $jsonstring.="{\n";
       $jsonstring.="\"päiväys\":\"".$row->{timestamp}."\",\n";
       $jsonstring.="\"toiminta\":\"".$row->{action}."\",\n";
       $jsonstring.="\"info\":\"".$row->{info}."\"\n";
       $jsonstring.="}";
       $count++; 
     }
     $jsonstring.="\n]";
   }
   catch
   {
     $jsonstring="error";
   };
  
   return($jsonstring);
}


########################################################
# debarments
sub debarment_json 
{
  my @args=@_;
  my $borrowernumber=$args[0];
  my $jsonstring="\"Rajoitteet\":[\n";
  my $sqlstring;
  try
  {
    $sqlstring=C4::PatronJson::makesqlstring($borrowernumber,"9");
    my $dbh=C4::Context->dbh();
    my $query=$dbh->prepare($sqlstring);
    my $i=0;
    my $string1;

    $query->execute() or die;

    while(my @resultset=$query->fetchrow_array())
    {
      $string1="";

      if($i > 0)
      {
        $jsonstring.="\n,\n";
      }

      $jsonstring.="{\n";
      $string1=$resultset[0];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Tyyppi\":\"".$string1."\",\n";

      $string1=$resultset[1];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Kommentti\":\"".$string1."\",\n";

      $string1=$resultset[2];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Alku\":\"".$string1."\",\n";

      $string1=$resultset[3];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Päivitetty\":\"".$string1."\",\n";

      $string1=$resultset[4];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Loppu\":\"".$string1."\"\n}";

      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring="";
  };

  return($jsonstring);
}


#########################################################
# suggestions
sub suggestion_json
{
  my @args=@_;
  my $borrowernumber=$args[0];
  my $jsonstring="\"Hankintaehdotukset\":[\n";
  my $sqlstring;
  try
  {
    $sqlstring=C4::PatronJson::makesqlstring($borrowernumber,"10");
    my $dbh=C4::Context->dbh();
    my $query=$dbh->prepare($sqlstring);
    my $i=0;
    my $string1;

    $query->execute() or die;

    while(my @resultset=$query->fetchrow_array())
    {
      $string1="";

      if($i > 0)
      {
        $jsonstring.="\n,\n";
      }

      $jsonstring.="{\n";
      $string1=$resultset[0];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Julkaisu\":\"".$string1."\",\n";

      $string1=$resultset[1];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Tekijä\":\"".$string1."\",\n";

      $string1=$resultset[2];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Ehdotettu\":\"".$string1."\",\n";

      $string1=$resultset[3];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Käsitelty\":\"".$string1."\",\n";

      $string1=$resultset[4];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Hyväksytty\":\"".$string1."\",\n";

      $string1=$resultset[5];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Hylätty\":\"".$string1."\",\n";

      $string1=$resultset[6];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Tila\":\"".$string1."\",\n";

      $string1=$resultset[7];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Ehdottajan syy\":\"".$string1."\",\n";
      
      $string1=$resultset[8];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Syy\":\"".$string1."\",\n";

      $string1=$resultset[9];
      $string1=C4::PatronJson::convertstring($string1);
      $jsonstring.="\"Huom\":\"".$string1."\"\n}";

      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring="";
  };

  return($jsonstring);
}

1;
 

