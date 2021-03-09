#!/usr/bin/perl
use C4::Output;
use C4::Context;
use REST::Client;
use Try::Tiny;
use CGI qw('-no_undef_params' -utf8 );
use C4::Koha;
use C4::Auth;
use JSON;
use C4::Members;
my $template_name;
my $template_type;
my $cardnumber;
my $bnumber;
my $error;
my $cgi = new CGI;
my $ill_checkout_count;
my $ill_checkouts_ref;
my $borrower;

$template_name = 'circ/get_ill.tt';

# load the template
my ($template, $borrowernumber, $cookie) = get_template_and_user({
    template_name => $template_name,
    query => $cgi,
    type => "intranet",
    authnotrequired => 0,
    flagsrequired   => { catalogue => 1 },
    }
);

$bnumber = $cgi->param("bnumber");

if($bnumber) {
    try {
        
        $borrower = GetMember( borrowernumber => $bnumber );
        $cardnumber = $borrower->{cardnumber};

        # get ill_checkouts from webkake 
        my $restclient = REST::Client->new();
        my $consortium = C4::Context->config("webkakecon");
        
        if($consortium eq "__WEBKAKECON__") {
            $consortium = undef;
        }

        if($consortium) {
            my $resturl = "https://webkake.kirjastot.fi/wrest/rest/wrest/ill_loans?mhknum=".$cardnumber."&mulfinna=".$consortium;
            $restclient->setTimeout(5);
            $restclient->GET($resturl);
            my $json_string = $restclient->responseContent();
            my @ill_checkouts = @{decode_json($json_string)};
            $ill_checkout_count = scalar @ill_checkouts;
            $ill_checkouts_ref = \@ill_checkouts;
        }
    }
    catch {
        $error = $_;
    };
    
    if($error) {
        $ill_checkout_count = undef;
    }
}

$template->param(ill_checkout_count => $ill_checkout_count);
$template->param(ILLCHECKOUTS => $ill_checkouts_ref);


C4::Output::output_ajax($template->output);
#C4::Output::output_ajax("error ".$error);
