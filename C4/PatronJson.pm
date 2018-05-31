package C4::PatronJson;
require Exporter;
use C4::Context;
use Try::Tiny;
use Encode;
use REST::Client;
use C4::PatronJson2;
@ISA = qw(Exporter);
@EXPORT = qw(makejson makesqlstring convertstring);


#################################################
# main function, collects "all" data about one patron, json format
sub  makejson {
  my @args=@_;
  my $borrowernumber=$args[1];
  my $jsonstring="{\n";
  my $cardnumber=get_card_number($borrowernumber);
  my $webkakecon = C4::Context->config("webkakecon");  

  #personal data
  $jsonstring.=personal_json($borrowernumber).",\n";

  #loans
  $jsonstring.=issues_json($borrowernumber).",\n";

  #former loans
  $jsonstring.=old_issues_json($borrowernumber).",\n";

  #reserves
  $jsonstring.=reserves_json($borrowernumber).",\n";

  #former reserves
  $jsonstring.=old_reserves_json($borrowernumber).",\n";

  #article requests
  #$jsonstring.=article_requests_json($borrowernumber);

  #interlibrary loans
  $jsonstring.=ill_json($cardnumber,$webkakecon,"0").",\n";

  #former interlibrary loans
  $jsonstring.=ill_json($cardnumber,$webkakecon,"1").",\n";

  #accountlines
  $jsonstring.=C4::PatronJson2::account_json($borrowernumber).",\n";

  #log-info
  $jsonstring.=C4::PatronJson2::log_json_mongo($borrowernumber).",\n";

  #messages
  $jsonstring.=C4::PatronJson2::messages_json($borrowernumber).",\n";

  #debarments
  $jsonstring.=C4::PatronJson2::debarment_json($borrowernumber).",\n";

  #suggestions
  $jsonstring.=C4::PatronJson2::suggestion_json($borrowernumber);


  $jsonstring.="\n}";
  
  return($jsonstring);
}

#################################################
#makes part of json, which will be inserted in patron's "all data" json
#gets data from webkake's rest
sub ill_json {
  my ($cardnumber,$mulfinna,$switch)=@_;
  my $jsonstring="";
  my $sourcejson;
  my $client=REST::Client->new();
  my $url;
  my $title="Kaukolainat ";

  try
  {
    #switch 0 current ill loans
    if($switch eq "0") {
      $url="https://webkake.kirjastot.fi/wrest/rest/wrest/ill_loans?mhknum=".$cardnumber."&mulfinna=".$mulfinna;
    }
    #swith 1 old ill loans
    elsif($switch eq "1") {
      $url="https://webkake.kirjastot.fi/wrest/rest/wrest/old_ill_loans?mhknum=".$cardnumber."&mulfinna=".$mulfinna;
      $title="Aiemmat kaukolainat";
    }

    #response to perl array
    $client->GET($url);
    $sourcejson=$client->responseContent();
    $jsonstring="\"".$title."\":".$sourcejson;

  }
  catch
  {
    $jsonstring="";
  };

  return($jsonstring);
}
  


##################################################
#collects loans of one patron
sub issues_json {
 
  my ($borrowernumber)=@_;
  my $jsonstring="\"Lainat\":[\n";
  my $sqlstring;
  try
  {
    $sqlstring=makesqlstring($borrowernumber,"1");
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

      # title
      $string1=$resultset[0];
      $string2=$resultset[1];
      if($string1 eq "")
      {
        $string1=$string2;
      }
      $string1=convertstring($string1);
      $jsonstring.="\"Julkaisu\":\"".$string1."\",\n";

      # author
      $string1=$resultset[2];
      $string1=convertstring($string1);
      $jsonstring.="\"Tekijä(t)\":\"".$string1."\",\n";

      # borrow date
      $string1=$resultset[3];
      $string1=convertstring($string1);
      $jsonstring.="\"Lainauspäivä\":\"".$string1."\",\n";

      # return date
      $string1=$resultset[4];
      $string1=convertstring($string1);
      $jsonstring.="\"Palautuspäivä\":\"".$string1."\",\n";

      # renewals count
      $string1=$resultset[5];
      $string1=convertstring($string1);
      $jsonstring.="\"Uusinnat\":\"".$string1."\"\n}";
      
      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring.="error";
  };
  
  return($jsonstring);
}

##################################################
#gets card number by borrowernumber
sub get_card_number {

  my ($borrowernumber)=@_;
  my $retval="";
  try
  {
    $sqlstring="select cardnumber from borrowers where borrowernumber=".$borrowernumber;
    my $dbh=C4::Context->dbh();
    my $query=$dbh->prepare($sqlstring);
    $query->execute() or die;

    while(my @resultset=$query->fetchrow_array())
    {
      $retval=$resultset[0];
    }
    $dbh->disconnect(); 
  }
  catch
  {
    $retval="";
  };
  return($retval);
}

##################################################
#collects former loans of one patron
sub old_issues_json {
 
  my $borrowernumber=@_;
  my $jsonstring="\"Aiemmat lainat\":[\n";
  my $sqlstring;
  try
  {
    $sqlstring=makesqlstring($borrowernumber,"2");
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

      # title
      $string1=$resultset[0];
      $string2=$resultset[1];
      if($string1 eq "")
      {
        $string1=$string2;
      }
      $string1=convertstring($string1);
      $jsonstring.="\"Julkaisu\":\"".$string1."\",\n";

      # author
      $string1=$resultset[2];
      $string1=convertstring($string1);
      $jsonstring.="\"Tekijä(t)\":\"".$string1."\",\n";

      # borrow date
      $string1=$resultset[3];
      $string1=convertstring($string1);
      $jsonstring.="\"Lainauspäivä\":\"".$string1."\",\n";

      # return date
      $string1=$resultset[4];
      $string1=convertstring($string1);
      $jsonstring.="\"Palautuspäivä\":\"".$string1."\",\n";

      # renewals count
      $string1=$resultset[5];
      $string1=convertstring($string1);
      $jsonstring.="\"Uusinnat\":\"".$string1."\"\n}";
      
      $i++;
    }
   
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring.="error in former loans";
  };

  return($jsonstring);
}


##################################################
#collects reserves of one patron
sub reserves_json {
 
  my $borrowernumber=@_;
  my $jsonstring="\"Varaukset\":[\n";
  my $sqlstring;
  #select biblio.unititle,biblio.title,biblio.author,reserves.reservedate,branches.branchname
  try
  {
    $sqlstring=makesqlstring($borrowernumber,"3");
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

      # title
      $string1=$resultset[0];
      $string2=$resultset[1];
      if($string1 eq "")
      {
        $string1=$string2;
      }
      $string1=convertstring($string1);
      $jsonstring.="\"Julkaisu\":\"".$string1."\",\n";

      # author
      $string1=$resultset[2];
      $string1=convertstring($string1);
      $jsonstring.="\"Tekijä(t)\":\"".$string1."\",\n";

      # reserve date
      $string1=$resultset[3];
      $string1=convertstring($string1);
      $jsonstring.="\"Varauspäivä\":\"".$string1."\",\n";

      # library
      $string1=$resultset[4];
      $string1=convertstring($string1);
      $jsonstring.="\"Kirjasto\":\"".$string1."\"\n}";
      
      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring.="error";
  };
  
  return($jsonstring);
}

##################################################
#collects former reserves of one patron
sub old_reserves_json {
 
  my $borrowernumber=@_;
  my $jsonstring="\"Aiemmat varaukset\":[\n";
  my $sqlstring;
  #select biblio.unititle,biblio.title,biblio.author,reserves.reservedate,branches.branchname
  try
  {
    $sqlstring=makesqlstring($borrowernumber,"4");
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

      # title
      $string1=$resultset[0];
      $string2=$resultset[1];
      if($string1 eq "")
      {
        $string1=$string2;
      }
      $string1=convertstring($string1);
      $jsonstring.="\"Julkaisu\":\"".$string1."\",\n";

      # author
      $string1=$resultset[2];
      $string1=convertstring($string1);
      $jsonstring.="\"Tekijä(t)\":\"".$string1."\",\n";

      # reserve date
      $string1=$resultset[3];
      $string1=convertstring($string1);
      $jsonstring.="\"Varauspäivä\":\"".$string1."\",\n";

      # library
      $string1=$resultset[4];
      $string1=convertstring($string1);
      $jsonstring.="\"Kirjasto\":\"".$string1."\"\n}";
      
      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring.="error";
  };
  
  return($jsonstring);
}

##################################################
#collects article_requests of one patron
sub article_requests_json {
 
  my $borrowernumber=@_;
  my $jsonstring="\"Artikkelipyynnöt\":[\n";
  my $sqlstring;


  try
  {
    $sqlstring=makesqlstring($borrowernumber,"5");
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

      # article title
      $string1=$resultset[0];
      $string1=convertstring($string1);
      $jsonstring.="\"Artikkeli\":\"".$string1."\",\n";

      # author
      $string1=$resultset[1];
      $string1=convertstring($string1);
      $jsonstring.="\"Tekijä(t)\":\"".$string1."\",\n";

      # volume
      $string1=$resultset[2];
      $string1=convertstring($string1);
      $jsonstring.="\"Vol\":\"".$string1."\",\n";

      # issue
      $string1=$resultset[3];
      $string1=convertstring($string1);
      $jsonstring.="\"Aihe\":\"".$string1."\"\n}";

      # date
      $string1=$resultset[4];
      $string1=convertstring($string1);
      $jsonstring.="\"Päiväys\":\"".$string1."\"\n}";

      # pages
      $string1=$resultset[5];
      $string1=convertstring($string1);
      $jsonstring.="\"Sivut\":\"".$string1."\"\n}";

      # chapters
      $string1=$resultset[6];
      $string1=convertstring($string1);
      $jsonstring.="\"Kappaleet\":\"".$string1."\"\n}";

      # status
      $string1=$resultset[7];
      $string1=convertstring($string1);
      $jsonstring.="\"Tila\":\"".$string1."\"\n}";

      # note
      $string1=$resultset[8];
      $string1=convertstring($string1);
      $jsonstring.="\"Huomautus\":\"".$string1."\"\n}";

      # library
      $string1=$resultset[9];
      $string1=convertstring($string1);
      $jsonstring.="\"Kirjasto\":\"".$string1."\"\n}";
      
      $i++;
    }
    $dbh->disconnect();
    $jsonstring.="]\n";
  }
  catch
  {
    $jsonstring.="error";
  };
  
  return($jsonstring);
}

####################################################
#collects personal data about one patron
sub personal_json {
  
  my @args = @_;
  my $borrowernumber = $args[0];


  my $jsonstring="\"Henkilötiedot\":{\n";  
  my $sqlsring;

  try
  {
    
    $sqlstring=makesqlstring($borrowernumber,"0");
    my $dbh=C4::Context->dbh();
    my $query=$dbh->prepare($sqlstring);
    my $i=0;
    my $string1;

    $query->execute() or die;

    #should be only 1 row in resultset
    while(my @resultset=$query->fetchrow_array())
    {
      $string1=$resultset[0];
      $string1=convertstring($string1);
      $jsonstring.="\"Järjestelmän numero\":\"".$string1."\",\n";
      
      $string1="";
      $string1=$resultset[1];
      $string1=convertstring($string1);
      $jsonstring.="\"Sukunimi\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[2];
      $string1=convertstring($string1);
      $jsonstring.="\"Etunimi\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[3];
      $string1=convertstring($string1);
      $jsonstring.="\"Titteli\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[4];
      $string1=convertstring($string1);
      $jsonstring.="\"Muut nimet\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[5];
      $string1=convertstring($string1);
      $jsonstring.="\"Nimikirjaimet\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[6];
      $string1=convertstring($string1);
      $jsonstring.="\"Kadun numero\":\"".$string1."\",\n";
      
      $string1="";
      $string1=$resultset[8];
      $string1=convertstring($string1);
      $jsonstring.="\"Osoite\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[9];
      $string1=convertstring($string1);
      $jsonstring.="\"2. osoite\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[10];
      $string1=convertstring($string1);
      $jsonstring.="\"Kaupunki\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[12];
      $string1=convertstring($string1);
      $jsonstring.="\"Postinumero\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[13];
      $string1=convertstring($string1);
      $jsonstring.="\"Maa\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[14];
      $string1=convertstring($string1);
      $jsonstring.="\"Sähköposti\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[15];
      $string1=convertstring($string1);
      $jsonstring.="\"Lankapuhelin\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[16];
      $string1=convertstring($string1);
      $jsonstring.="\"Puhelin\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[17];
      $string1=convertstring($string1);
      $jsonstring.="\"Faksi\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[18];
      $string1=convertstring($string1);
      $jsonstring.="\"Työsähköposti\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[19];
      $string1=convertstring($string1);
      $jsonstring.="\"Työpuhelin\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[22];
      $string1=convertstring($string1);
      $jsonstring.="\"B-osoite\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[23];
      $string1=convertstring($string1);
      $jsonstring.="\"2. B-osoite\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[24];
      $string1=convertstring($string1);
      $jsonstring.="\"B-kaupunki\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[26];
      $string1=convertstring($string1);
      $jsonstring.="\"B-postinumero\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[27];
      $string1=convertstring($string1);
      $jsonstring.="\"B-maa\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[28];
      $string1=convertstring($string1);
      $jsonstring.="\"B-sähköposti\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[29];
      $string1=convertstring($string1);
      $jsonstring.="\"B-puhelin\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[30];
      $string1=convertstring($string1);
      $jsonstring.="\"Syntymäaika\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[33];
      $string1=convertstring($string1);
      $jsonstring.="\"Alkupvm\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[34];
      $string1=convertstring($string1);
      $jsonstring.="\"Loppupvm\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[35];
      $string1=convertstring($string1);
      $jsonstring.="\"Uusittu\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[36];
      $string1=convertstring($string1);
      $jsonstring.="\"Väliaikainen osoite\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[37];
      $string1=convertstring($string1);
      $jsonstring.="\"Kadonnut\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[38];
      $string1=convertstring($string1);
      $jsonstring.="\"Kielto\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[39];
      $string1=convertstring($string1);
      $jsonstring.="\"Kiellon selitys\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[40];
      $string1=convertstring($string1);
      $jsonstring.="\"Takaajan sukunimi\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[41];
      $string1=convertstring($string1);
      $jsonstring.="\"Takaajan etunimi\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[42];
      $string1=convertstring($string1);
      $jsonstring.="\"Takaajan titteli\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[43];
      $string1=convertstring($string1);
      $jsonstring.="\"Takaajan numero\":\"".$string1."\",\n";

      #$string1="";
      #$string1=$resultset[44];
      #$jsonstring.="\"Huomautus\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[45];
      $string1=convertstring($string1);
      $jsonstring.="\"Takaajan suhde\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[46];
      $string1=convertstring($string1);
      $jsonstring.="\"Sukupuoli\":\"".$string1."\",\n";

      #$string1="";
      #$string1=$resultset[47];
      #$string1=convertstring($string1);
      #$jsonstring.="\"Flag\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[48];
      $string1=convertstring($string1);
      $jsonstring.="\"Käyttäjänumero\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[49];
      $string1=convertstring($string1);
      $jsonstring.="\"Huomautus\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[50];
      $string1=convertstring($string1);
      $jsonstring.="\"Yhteyshenkilön huom\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[53];
      $string1=convertstring($string1);
      $jsonstring.="\"VE etunimi\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[54];
      $string1=convertstring($string1);
      $jsonstring.="\"VE sukunimi\":\"".$string1."\",\n";
 
      $string1="";
      $string1=$resultset[55];
      $string1=convertstring($string1);
      $jsonstring.="\"VE osoite\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[56];
      $string1=convertstring($string1);
      $jsonstring.="\"VE 2. osoite\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[57];
      $string1=convertstring($string1);
      $jsonstring.="\"VE 3. osoite\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[59];
      $string1=convertstring($string1);
      $jsonstring.="\"VE postinumero\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[60];
      $string1=convertstring($string1);
      $jsonstring.="\"VE maa\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[61];
      $string1=convertstring($string1);
      $jsonstring.="\"Väliaikainen osoite 2\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[62];
      $string1=convertstring($string1);
      $jsonstring.="\"Tekstiviestihälytys\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[64];
      $string1=convertstring($string1);
      $jsonstring.="\"Yksityisyys\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[65];
      $string1=convertstring($string1);
      $jsonstring.="\"Yksityisyyden takaaja\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[66];
      $string1=convertstring($string1);
      $jsonstring.="\"Päivitys\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[67];
      $string1=convertstring($string1);
      $jsonstring.="\"Nähty viimeksi\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[68];
      $string1=convertstring($string1);
      $jsonstring.="\"Kieli\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[69];
      $string1=convertstring($string1);
      $jsonstring.="\"Kirjautumisyritykset\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[71];
      $string1=convertstring($string1);
      $jsonstring.="\"Kirjasto\":\"".$string1."\",\n";

      $string1="";
      $string1=$resultset[72];
      $string1=convertstring($string1);
      $jsonstring.="\"Luokittelu\":\"".$string1."\"\n";

      
    }
    
    $dbh->disconnect();

    $jsonstring.="\n}";
  }
  catch
  {
    $jsonstring="";
  };
 
  return($jsonstring);
} 

####################################
#converts string
sub convertstring {
  my @args=@_;
  my $orig=$args[0];
  my $retval=$orig;

  if(length($retval) > 0)
  {
     $retval=encode("utf-8",$orig); 
     $retval=~s/\"/\'/g;
     $retval=~s/\r?\n/ /g;
  }
  return($retval);
}

#####################################
#returns sql string for different purposes
sub makesqlstring {
  my ($p0,$switch)=@_;
  my $sqlstring;

  #switch 0 personal data sql
  if($switch eq "0")
  {
    $sqlstring="select borrowers.borrowernumber,borrowers.surname,borrowers.firstname,borrowers.title,"
              ."borrowers.othernames,borrowers.initials,borrowers.streetnumber,borrowers.streettype,borrowers.address,"
              ."borrowers.address2,borrowers.city,borrowers.state,borrowers.zipcode,borrowers.country,borrowers.email,"
              ."borrowers.phone,borrowers.mobile,borrowers.fax,borrowers.emailpro,borrowers.phonepro,borrowers.B_streetnumber,"
              ."borrowers.B_streettype,borrowers.B_address,borrowers.B_address2,borrowers.B_city,borrowers.B_state,"
              ."borrowers.B_zipcode,borrowers.B_country,borrowers.B_email,borrowers.B_phone,borrowers.dateofbirth,"
              ."borrowers.branchcode,borrowers.categorycode,borrowers.dateenrolled,borrowers.dateexpiry,'-' as date_renewed,"
              ."borrowers.gonenoaddress,borrowers.lost,borrowers.debarred,borrowers.debarredcomment,"
              ."borrowers2.surname as contactname,borrowers2.firstname as contactfirstname,borrowers2.title as contacttitle,borrowers.guarantorid,"
              ."borrowers.borrowernotes,borrowers.relationship,borrowers.sex,'hjoo' as flags,borrowers.userid,"
              ."borrowers.opacnote,borrowers.contactnote,borrowers.sort1,borrowers.sort2,borrowers.altcontactfirstname,"
              ."borrowers.altcontactsurname,borrowers.altcontactaddress1,borrowers.altcontactaddress2,borrowers.altcontactaddress3,"
              ."borrowers.altcontactstate,borrowers.altcontactzipcode,borrowers.altcontactcountry,"
              ."borrowers.altcontactphone,borrowers.smsalertnumber,borrowers.sms_provider_id,borrowers.privacy,"
              ."borrowers.privacy_guarantor_checkouts,borrowers.updated_on,borrowers.lastseen,borrowers.lang,borrowers.login_attempts,"
              ."borrowers.overdrive_auth_token,branches.branchname,categories.description"
              ." from borrowers,branches,categories,borrowers as borrowers2"
              ." where borrowers.branchcode=branches.branchcode"
              ." and borrowers.categorycode=categories.categorycode"
              ." and borrowers.guarantorid=borrowers2.borrowernumber"
              ." and borrowers.borrowernumber=".$p0;
    $sqlstring.=" union select borrowers.borrowernumber,borrowers.surname,borrowers.firstname,borrowers.title,"
              ."borrowers.othernames,borrowers.initials,borrowers.streetnumber,borrowers.streettype,borrowers.address,"
              ."borrowers.address2,borrowers.city,borrowers.state,borrowers.zipcode,borrowers.country,borrowers.email,"
              ."borrowers.phone,borrowers.mobile,borrowers.fax,borrowers.emailpro,borrowers.phonepro,borrowers.B_streetnumber,"
              ."borrowers.B_streettype,borrowers.B_address,borrowers.B_address2,borrowers.B_city,borrowers.B_state,"
              ."borrowers.B_zipcode,borrowers.B_country,borrowers.B_email,borrowers.B_phone,borrowers.dateofbirth,"
              ."borrowers.branchcode,borrowers.categorycode,borrowers.dateenrolled,borrowers.dateexpiry,'-' as date_renewed,"
              ."borrowers.gonenoaddress,borrowers.lost,borrowers.debarred,borrowers.debarredcomment,"
              ."'' as contactname,'' as contactfirstname,'' as contacttitle,borrowers.guarantorid,"
              ."borrowers.borrowernotes,borrowers.relationship,borrowers.sex,'hjoo' as flags,borrowers.userid,"
              ."borrowers.opacnote,borrowers.contactnote,borrowers.sort1,borrowers.sort2,borrowers.altcontactfirstname,"
              ."borrowers.altcontactsurname,borrowers.altcontactaddress1,borrowers.altcontactaddress2,borrowers.altcontactaddress3,"
              ."borrowers.altcontactstate,borrowers.altcontactzipcode,borrowers.altcontactcountry,"
              ."borrowers.altcontactphone,borrowers.smsalertnumber,borrowers.sms_provider_id,borrowers.privacy,"
              ."borrowers.privacy_guarantor_checkouts,borrowers.updated_on,borrowers.lastseen,borrowers.lang,borrowers.login_attempts,"
              ."borrowers.overdrive_auth_token,branches.branchname,categories.description"
              ." from borrowers,branches,categories"
              ." where borrowers.branchcode=branches.branchcode"
              ." and borrowers.categorycode=categories.categorycode"
              ." and borrowers.guarantorid is null"
              ." and borrowers.borrowernumber=".$p0;
  }
  #switch 1 loans
  elsif($switch eq "1")
  {
    $sqlstring="select distinct biblio.unititle,biblio.title,biblio.author,issues.issuedate,issues.returndate,issues.renewals"
              ." from issues,items,biblio"
              ." where biblio.biblionumber=items.biblionumber"
              ." and items.itemnumber=issues.itemnumber"
              ." and issues.borrowernumber=".$p0." order by 4 desc";
  }
  #switch 2 former loans
  elsif($switch eq "2")
  {
    $sqlstring="select distinct biblio.unititle,biblio.title,biblio.author,old_issues.issuedate,old_issues.returndate,old_issues.renewals"
              ." from old_issues,items,biblio"
              ." where biblio.biblionumber=items.biblionumber"
              ." and items.itemnumber=old_issues.itemnumber"
              ." and old_issues.borrowernumber=".$p0." order by 4";
  } 
  #switch 3 reserves
  elsif($switch eq "3")
  {
    $sqlstring="select distinct biblio.unititle,biblio.title,biblio.author,reserves.reservedate,branches.branchname"
              ." from reserves,biblio,branches"
              ." where biblio.biblionumber=reserves.biblionumber"
              ." and reserves.branchcode=branches.branchcode"
              ." and reserves.borrowernumber=".$p0." order by 4 desc";
  }
  #switch 4 former reserves
  elsif($switch eq "4")
  {
    $sqlstring="select distinct biblio.unititle,biblio.title,biblio.author,old_reserves.reservedate,branches.branchname"
              ." from old_reserves,biblio,branches"
              ." where biblio.biblionumber=old_reserves.biblionumber"
              ." and old_reserves.branchcode=branches.branchcode"
              ." and old_reserves.borrowernumber=".$p0." order by 4 desc";
  }
  #switch 5 article requests
  elsif($switch eq "5")
  {
    $sqlstring="select article_requests.title,article_requests.author,article_requests.volume,"
              ."article_requests.issue,article_requests.date,article_requests.pages,"
              ."article_requests.chapters,article_requests.status,article_requests.notes,"
              ."branches.branchname"
              ." from article_requests,branches"
              ." where article_requests.branchcode=branches.branchcode"
              ." and article_requests.borrowernumber=".$p0;
  }
  #switch 6 accounts
  elsif($switch eq "6")
  {
    $sqlstring="select accountlines.description,accountlines.amount,accountlines.date,"
              ."accountlines.note,biblio.unititle,biblio.title"
              ." from accountlines,items,biblio"
              ." where accountlines.itemnumber=items.itemnumber"
              ." and items.biblionumber=biblio.biblionumber"
              ." and accountlines.borrowernumber=".$p0;
    $sqlstring.=" union select accountlines.description,accountlines.amount,accountlines.date,"
              ."accountlines.note,'' as unititle,'' as title"
              ." from accountlines"
              ." where accountlines.itemnumber is null"
              ." and accountlines.borrowernumber=".$p0." order by 3 desc";
  }
  #switch 7 change log
  elsif($switch eq "7")
  {
    $sqlstring="select distinct timestamp,module,action,info,interface from action_logs where object=".$p0." order by 1 desc";
  }
  #switch 8 messages
  elsif($switch eq "8")
  {
    $sqlstring="select distinct messages.message_date,message_queue.content"
              ." from messages,message_queue"
              ." where messages.message_id=message_queue.message_id"
              ." and messages.message_type='B'"
              ." and message_queue.borrowernumber=".$p0
              ." order by 1 desc";
  }
  #switch 9 debarment
  elsif($switch eq "9")
  {
    $sqlstring="select distinct type,comment,created,updated,expiration"
              ." from borrower_debarments"
              ." where borrowernumber=".$p0
              ." order by 3 desc";
  }
  #switch 10 suggestions
  elsif($switch eq "10")
  {
    $sqlstring="select title,author,suggesteddate,manageddate,accepteddate,rejecteddate,status,patronreason,reason,note"
              ." from suggestions"
              ." where suggestedby=".$p0
              ." order by 3 desc";
  }
  
  return($sqlstring);
}

1;

