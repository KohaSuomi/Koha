=head IN THIS FILE
This module extends the SMS::Send::Driver interface
to implement a driver compatible with the Arena Interactive SMS Gateway HTTP interface.
Module parameters are sanitated against injection attacks.
Arena responds:
    success
phone-number OK message-count description
+358401234567 OK 1 message accepted for sending
    failure
phone-number ERROR error-code message-count description
e.g: 12345 ERROR 2 1 message failed: Too short phone number
=cut

package SMS::Send::DNA::Driver;
#use Modern::Perl; #Can't use this since SMS::Send uses hash keys starting with _
use utf8;
use SMS::Send::Driver ();
use Mojo::UserAgent;
use MIME::Base64;
use URI::Escape;
use C4::Context;
use Encode;
use Koha::Exception::ConnectionFailed;
use Koha::Exception::SMSDeliveryFailure;
use Koha::Notice::Messages;
use Mojo::JSON qw(from_json);
use Mojo::URL;
use POSIX;

use Try::Tiny;

use vars qw{$VERSION @ISA};
BEGIN {
        $VERSION = '0.06';
                @ISA     = 'SMS::Send::Driver';
}


#####################################################################
# Constructor

sub new {
        my $class = shift;
        my $params = {@_};

        my $username = $params->{_login} ? $params->{_login} : C4::Context->config('smsProviders')->{'dna'}->{'user'};
        my $password = $params->{_password} ? $params->{_password} : C4::Context->config('smsProviders')->{'dna'}->{'passwd'};

        my $from = $params->{_from};

        if (! defined $username ) {
            warn "->send_sms(_login) must be defined!";
            return;
        }
        if (! defined $password ) {
            warn "->send_sms(_password) must be defined!";
            return;
        }

        #Prevent injection attack
        $self->{_login} =~ s/'//g;
        $self->{_password} =~ s/'//g;
        $self->{_from} =~ s/'//g;

        # Create the object
        my $self = bless {}, $class;

        $self->{_login} = $username;
        $self->{_password} = $password;
        $self->{_from} = $from;

        return $self;
}

# get config value for smsProviders->dna, first trying smsProviders->dna->FULL_BRANCH->foo,
# then smsProviders->dna->FIRST_3_LETTERS_OF_BRANCH->foo, and finally
# smsProviers->dna->foo
sub _get_dna_config {
    my ($branch, $cnf) = @_;
    my $br3 = substr($branch, 0, 3);

    my $value = C4::Context->config('smsProviders')->{'dna'}->{$branch}->{$cnf} || C4::Context->config('smsProviders')->{'dna'}->{$br3}->{$cnf} || C4::Context->config('smsProviders')->{'dna'}->{$cnf};

    return $value;
}

sub _rest_call {
    my ($url, $headers, $authorization, $params) = @_;
    
    my $ua = Mojo::UserAgent->new;
    my $tx;
    if ($authorization) {
        $url = Mojo::URL->new($url)->userinfo($authorization);
        $tx = $ua->post($url => $headers => form => $params);
    } else {
        $tx = $ua->post($url => $headers => json => $params);
    }
    if ($tx->error) {
        return ($tx->error, undef);
    } else {
        return (undef, from_json($tx->res->body));
    }

    
}

sub send_sms {
    my $self    = shift;
    my $params = {@_};
    my $message = $params->{text};
    my $recipientNumber = $params->{to};

    my $dbh=C4::Context->dbh;
    my $branches=$dbh->prepare("SELECT branchcode FROM branches WHERE branchemail = ?;");
    $branches->execute($self->{_from});
    my $branch = $branches->fetchrow;

    my $appid = _get_dna_config($branch, 'appId');

    if (! defined $message ) {
        warn "->send_sms(text) must be defined!";
        return;
    }
    if (! defined $recipientNumber ) {
        warn "->send_sms(to) must be defined!";
        return;
    }

    if (! defined $appid ) {
        warn "->send_sms(appId) must be defined!";
        return;
    }

    #Prevent injection attack!
    $recipientNumber =~ s/'//g;
    substr($recipientNumber, 0, 1, "+358") unless "+" eq substr($recipientNumber, 0, 1);
    $message =~ s/(")|(\$\()|(`)/\\"/g; #Sanitate " so it won't break the system( iconv'ed curl command )
    my $fragment_length = 160;
    if($message =~ /[^\@£\$¥èéùìòÇØøÅå&#916;_&#934;&#915;&#923;&#937;&#928;&#936;&#931;&#920;&#926;ÆæßÉ !"#¤%\&\'\(\)\*\+\,\-\.\/0-9:;<=>\?¡A-ZÄÖÑÜ§¿a-zäöñüà]/ ) {
        $fragment_length = 70;
    }
    my $gsm0338 = encode("gsm0338", $message);
    my $message_length = length($gsm0338);

    my $fragments;
    if ($message_length > $fragment_length) {
        $fragments = ceil($message_length / $fragment_length);
    } else {
        $fragments = 1;
    }

    if ($fragments > 10) {
        Koha::Exception::SMSDeliveryFailure->throw(error => "message content is too big!");
        return;
    }

    my $base_url = _get_dna_config($branch, 'baseUrl');

    my $authorization = $self->{_login}.":".$self->{_password};
    my $headers = {'Content-Type' => 'application/x-www-form-urlencoded'};
    my ($error, $token, $res, $revoke);
    ($error, $token) = _rest_call($base_url.$appid.'/token', $headers, $authorization, {grant_type => 'client_credentials'});

    if ($error) {
        Koha::Exception::SMSDeliveryFailure->throw(error => $error->{message});
        return;
    }

    $headers = {Authorization => "Bearer $token->{access_token}", 'Content-Type' => 'application/json'};

    my $params = {
        recipient => {number => $recipientNumber},
        data => {message => $message, allowed_fragments => $fragments }
    };

    ($error, $res) = _rest_call($base_url.$appid.'/sms', $headers, undef, $params);

    if ($error) {
        Koha::Exception::SMSDeliveryFailure->throw(error => $error->{message});
        return;
    }
    elsif ($res->{status} eq "error") {
        Koha::Exception::SMSDeliveryFailure->throw(error => $res->{error});
        return;
    } else {
        return 1;
    }
}
1;
