package Koha::MongoDB::Logs;

use Moose;
use Try::Tiny;
use MongoDB;
use Koha::MongoDB::Config;

has 'schema' => (
    is      => 'rw',
    isa => 'DBIx::Class::Schema',
    reader => 'getSchema',
    writer => 'setSchema'
);

has 'config' => (
    is      => 'rw',
    isa => 'Koha::MongoDB::Config',
    reader => 'getConfig',
    writer => 'setConfig'
);

sub BUILD {
    my $self = shift;
    my $args = shift;
    my $schema = Koha::Database->new()->schema();
    $self->setSchema($schema);
    $self->setConfig(new Koha::MongoDB::Config);
    my $dbh;
    if ($args->{dbh}) {
        $dbh = $args->{dbh};
    } else {
        $dbh = $self->getConfig->mongoClient();
    }
    $self->{dbh} = $dbh;
}

sub getActionLogs{
	my $self = shift;
    my ($startdate, $enddate) = @_;
    my @modules = ('MEMBERS', 'CIRCULATION', 'FINES', 'NOTICES', 'SS');
    my $dbh = C4::Context->dbh;
    my $query = "
    SELECT action, object, timestamp, user, info from action_logs 
    where module IN (" . join( ",", map { "?" } @modules ) . ") 
    and DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i') >= ? 
    and DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i') <= ?;";
    my $stmnt = $dbh->prepare($query);
    $stmnt->execute(@modules, $startdate, $enddate);

    my @logs;
    while ( my $row = $stmnt->fetchrow_hashref ) {
        push @logs, $row;
    }
    return \@logs;
}

#get all data from action_cache_logs;
sub getActionCacheLogs{
    my $self = shift;
    my ($params) = @_;
    my $dbh = C4::Context->dbh;
    my $query = "
    SELECT action_id,action, object, timestamp, user, info from action_logs_cache";
    if ($params->{order_by}) {
        $query .= " order by ".$params->{order_by};
    }
    if ($params->{limit}) {
        $query .= " limit ".$params->{limit};
    }
    my $stmnt = $dbh->prepare($query);
    $stmnt->execute();

    my @logs;
    while ( my $row = $stmnt->fetchrow_hashref ) {
        push @logs, $row;
    }
    return \@logs;
}

sub setUserLogs{
	my $self = shift;
	my ($actionlog, $sourceuserId, $objectuserId, $cardnumber, $borrowernumber) = @_;

    my $result = {
        sourceuser       => $sourceuserId,
        objectuser       => $objectuserId,
        objectcardnumber => $cardnumber,
        objectborrowernumber => $borrowernumber,
        action           => $actionlog->{action},
        info             => $actionlog->{info},
        timestamp        => $actionlog->{timestamp}

        };   

    return $result;
}

sub checkLog {
	my $self = shift;
	my ($actionlog, $sourceuserId, $objectuserId) = @_;

	my $client = $self->{dbh};
    my $settings = $self->getConfig->getSettings();

    my $logs = $client->ns($settings->{database}.'.user_logs');
    my $findlog = $logs->find_one({
        sourceuser => $sourceuserId->{_id}, 
        objectuser => $objectuserId->{_id}, 
        action => $actionlog->{action}, 
        timestamp => $actionlog->{timestamp}});

    return $findlog;
}

sub getUserLogs {
   my $self = shift;
   my ($borrowernumber)= @_;

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
        my @cal = caller(0);
        Koha::Exception::ConnectionFailed->throw(error => $cal[3].'():>'."No MongoDB connection");
      }
   };

   return(\@logArray);
}

1;