#!/usr/bin/perl

# Copyright 2014 Vaara-kirjastot
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use CGI qw ( -utf8 );
use C4::Auth qw/:DEFAULT get_session/;
use C4::Output;
use C4::OPLIB::OKM;
use C4::OPLIB::OKMLogs;

use Koha::DateUtils;

=head1 NAME

okm_reports.pl

=head1 DESCRIPTION

Collect the annual OKM-statistics using this tool

=cut

our $input = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "reports/okm_reports.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { reports => 'execute_reports' },
        debug           => 1,
    }
);
my $session = $cookie ? get_session($cookie->value) : undef;


my $op = $input->param('op') || '';
our $okm_statisticsId = $input->param('okm_statisticsId');

#Create an OKM-object just to see if the configurations are intact.
eval {
    my $okmTest = C4::OPLIB::OKM->new(undef, '2015', undef, undef, undef);
}; if ($@) {
    $template->param('okm_conf_errors' => $@);
}


if ($op eq 'show') {
    my $okm = C4::OPLIB::OKM::Retrieve( $okm_statisticsId );
    my ($html, $csv, $errors);
    unless ($okm) {
        push @$errors, "Couldn't retrieve the given okm_report with koha.okm_statistics.id = $okm_statisticsId";
    }
    $template->param('okm' => $okm) if $okm;
    $template->param('okm_report_errors' => $errors);
    $template->param('okm_statisticsId' => $okm_statisticsId);
    #TODO, this feature doesn't work ATM and better rules for cross-examining statistics is needed. $template->param('okm_report_errors' => join('<br/>',@$errors)) if scalar(@$errors) > 0;
}

if ($op eq 'export') {
    my $format = $input->param('format');
    my $error = export( $format );
    if ($error eq 'reportUnavailable') {
        $template->param('okm_report_errors' => '<h4>OKM statistics not yet generated. Generate it with the misc/statistics/generateOKMAnnualStatistics.pl -script</h4>');
    }
}

if ($op eq 'delete') {
    C4::OPLIB::OKM::Delete($okm_statisticsId);
}

if ($op eq 'deleteLogs') {
    C4::OPLIB::OKMLogs::deleteLogs();
}

my @bc = keys %{ C4::OPLIB::OKM::getOKMBranchCategories() };
$template->param(
    okm_statisticsId => $okm_statisticsId,
    branchCategories => \@bc,
    quote => getRandomQuote(),
    ready_okm_reports => prettifyOKM_reports(),
    okm_logs => C4::OPLIB::OKMLogs::loadLogs(),
);


output_html_with_http_headers $input, $cookie, $template->output;



sub export {
    my ($format) = @_;

    my $okm = C4::OPLIB::OKM::Retrieve( $okm_statisticsId );
    my ($csv, $errors);
    unless ($okm) {
        return 'reportUnavailable';
    }

    my ( $type, $content );
    if ($format eq 'tab') {
        $type = 'application/octet-stream';
        $content = $okm->asCsv("\t");
    }
    elsif ($format eq 'csv') {
        $type = 'application/csv';
        $content = $okm->asCsv(',');
    }
    elsif ( $format eq 'ods' ) {
        $type = 'application/vnd.oasis.opendocument.spreadsheet';
        $content = $okm->asOds();
    }

    print $input->header(
        -type => $type,
        -attachment=>"OKM_statistics_$okm_statisticsId.$format"
    );
    print $content;

    exit;
}

sub prettifyOKM_reports {
    my $okm_reports = C4::OPLIB::OKM::RetrieveAll();
    foreach my $okm_report (@$okm_reports) {

        #Standardize the dates
        my $startdate = Koha::DateUtils::dt_from_string( $okm_report->{startdate}, 'iso' );
        my $enddate   = Koha::DateUtils::dt_from_string( $okm_report->{enddate}, 'iso' );
        $okm_report->{startdate} = Koha::DateUtils::output_pref({ dt => $startdate, dateonly => 1});
        $okm_report->{enddate}   = Koha::DateUtils::output_pref({ dt => $enddate,   dateonly => 1});

        #Find the selected report
        if ($okm_statisticsId && $okm_report->{id} == $okm_statisticsId) {
            $okm_report->{selected} = 1;
        }
    }
    return $okm_reports;
}

## These quotes are from https://www.goodreads.com/quotes/tag/statistics
sub getRandomQuote {
    my @quotes = (
    "<div class='quoteText'>

          &ldquo;There are three types of lies -- lies, damn lies, and statistics.&rdquo;

      <br>  &#8213;

        <span class='author'>Benjamin Disraeli</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;Statistically speaking, there is a 65  percent chance that the love of your life is having an affair. Be very suspicious.&rdquo;

      <br>  &#8213;

        <span class='author'>Scott Dikkers</span>,

        <i>

          <span class='work'>You Are Worthless: Depressing Nuggets of Wisdom Sure to Ruin Your Day</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;A single death is a tragedy; a million deaths is a statistic.&rdquo;

      <br>  &#8213;

        <span class='author'>Joseph Stalin</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;A recent survey or North American males found 42% were overweight, 34% were critically obese and 8% ate the survey.&rdquo;

      <br>  &#8213;

        <span class='author'>Banksy</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;Facts are stubborn things, but statistics are pliable.&rdquo;

      <br>  &#8213;

        <span class='author'>Mark Twain</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;Most murders are committed by someone who is known to the victim.  In fact, you are most likely to be murdered by a member of your own family on Christmas day.&rdquo;

      <br>  &#8213;

        <span class='author'>Mark Haddon</span>,

        <i>

          <span class='work'>The Curious Incident Of The Dog In The Night Time</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;I couldn't claim that I was smarter than sixty-five other guys--but the average of sixty-five other guys, certainly!&rdquo;

      <br>  &#8213;

        <span class='author'>Richard P. Feynman</span>,

        <i>

          <span class='work'>Surely You're Joking, Mr. Feynman!: Adventures of a Curious Character</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Reports that say that something hasn't happened are always interesting to me, because as we know, there are known knowns; there are things we know we know. We also know there are known unknowns; that is to say we know there are some things we do not know. But there are also unknown unknowns- the ones we don't know we don't know.&rdquo;

      <br>  &#8213;

        <span class='author'>Donald Rumsfeld</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;All the statistics in the world can't measure the warmth of a smile.&rdquo;

      <br>  &#8213;

        <span class='author'>Chris Hart</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;The logic behind patriotism is a mystery. At least a man who believes that his own family or clan is superior to all others is familiar with more than 0.000003% of the people involved.&rdquo;

      <br>  &#8213;

        <span class='author'>Criss Jami</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;Another mistaken notion connected with the law of large numbers is the idea that an event is more or less likely to occur because it has or has not happened recently.  The idea that the odds of an event with a fixed probability increase or decrease depending on recent occurrences of the event is called the gambler's fallacy.  For example, if Kerrich landed, say, 44 heads in the first 100 tosses, the coin would not develop a bias towards the tails in order to catch up!  That's what is at the root of such ideas as 'her luck has run out' and 'He is due.' That does not happen.  For what it's worth, a good streak doesn't jinx you, and a bad one, unfortunately , does not mean better luck is in store.&rdquo;

      <br>  &#8213;

        <span class='author'>Leonard Mlodinow</span>,

        <i>

          <span class='work'>The Drunkard's Walk: How Randomness Rules Our Lives</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;We are not concerned with the very poor. They are unthinkable, and only to be approached by the statistician or the poet.&rdquo;

      <br>  &#8213;

        <span class='author'>E.M. Forster</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;All statistics have outliers.&rdquo;

      <br>  &#8213;

        <span class='author'>Nenia Campbell</span>,

        <i>

          <span class='work'>Terrorscape</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;I guess I think of lotteries as a tax on the mathematically challenged.&rdquo;

      <br>  &#8213;

        <span class='author'>Roger Jones</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;He could not believe that any of them might actually hit somebody. If one did, what a nowhere way to go: killed by accident; slain not as an individual but by sheer statistical probability, by the calculated chance of searching fire, even as he himself might be at any moment. Mathematics! Mathematics! Algebra! Geometry! When 1st and 3d Squads came diving and tumbling back over the tiny crest, Bell was content to throw himself prone, press his cheek to the earth, shut his eyes, and lie there. God, oh, God! Why am I <em>here</em>? Why am I <em>here</em>? After a moment's thought, he decided he better change it to: why are <em>we</em> here. That way, no agency of retribution could exact payment from him for being selfish.&rdquo;

      <br>  &#8213;

        <span class='author'>James Jones</span>,

        <i>

          <span class='work'>The Thin Red Line</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;If your experiment needs a statistician, you need a better experiment.&rdquo;

      <br>  &#8213;

        <span class='author'>Ernest Rutherford</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;Statistics show that the nature of English crime is reverting to its oldest habits. In a country where so many desire status and wealth, petty annoyances can spark disproportionately violent behaviour. We become frustrated because we feel powerless, invisible, unheard. We crave celebrity, but that’s not easy to come by, so we settle for notoriety. Envy and bitterness drive a new breed of lawbreakers, replacing the old motives of poverty and the need for escape. But how do you solve crimes which no longer have traditional motives?&rdquo;

      <br>  &#8213;

        <span class='author'>Christopher Fowler</span>,

        <i>

          <span class='work'>Ten Second Staircase</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Whenever I read statistical reports, I try to imagine my unfortunate contemporary, the Average Person, who, according to these reports, has 0.66 children, 0.032 cars, and 0.046 TVs.&rdquo;

      <br>  &#8213;

        <span class='author'>Kató Lomb</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;99 percent of all statistics only tell 49 percent of the story.&rdquo;

      <br>  &#8213;

        <span class='author'>Ron DeLegge II</span>,

        <i>

          <span class='work'>Gents with No Cents</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Of course, if 40% of women need oxytocin to progress normally, then something is wrong with the definition of normal.&rdquo;

      <br>  &#8213;

        <span class='author'>Henci Goer</span>,

        <i>

          <span class='work'>Obstetric Myths Versus Research Realities: A Guide to the Medical Literature</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Out  of a hundred people:<br>      Those who always know better- 52<br>    Doubting every step- all the rest<br>       Glad to lend a hand if it doesn’t take too long- as high as 49<br>      Always good, because they can’t be otherwise- 4 maybe 5<br> Able to admire without envy- 18<br>      Living in constant fear of something or someone- 77<br>    Capable of happiness- 20 something tops<br>     Harmless singly, savage in crowds- half at least<br>Wise after the fact- just a couple more than wise before it<br> Taking only things from life- 30 (I wish I were wrong)<br>  Righteous- 35, which is a lot<br>       Righteous and understanding- 3<br>      Worthy of compassion- 99<br>Mortal- 100 out of 100 (Thus far this figure still remains unchanged.)&rdquo;

      <br>  &#8213;

        <span class='author'>Wisława Szymborska</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;Statistics, likelihoods, and probabilities mean everything to men, nothing to God.&rdquo;

      <br>  &#8213;

        <span class='author'>Richelle E. Goodrich</span>,

        <i>

          <span class='work'>Smile Anyway: Quotes, Verse, &amp; Grumblings for Every Day of the Year</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Abstain from reading comedy or other government economic statistics.&rdquo;

      <br>  &#8213;

        <span class='author'>Jarod Kintz</span>,

        <i>

          <span class='work'>At even one penny, this book would be overpriced. In fact, free is too expensive, because you'd still waste time by reading it.</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;...that realisation that I was the oddity, the statistical probability, life was predictable.&rdquo;

      <br>  &#8213;

        <span class='author'>Ruth Dugdall</span>,

        <i>

          <span class='work'>The Sacrificial Man</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Nature has established patterns originating in the return of events, but only for the most part. New illnesses flood the human race, so that no matter how many experiments you have done on corpses, you have not thereby immposd a limit on the nature of events so that in the future they could not vary.&rdquo;

      <br>  &#8213;

        <span class='author'>Gottfried Leibniz</span>

    </div>",
    "<div class='quoteText'>

          &ldquo;...when one considers that there are more than 750,000 police officers in the United States and that these officers have tens of millions of interactions with citizens each year, it is clear that police shootings are extremely rare events and that few officers--less than one-half of 1 percent each year--ever shoot anyone.&rdquo;

      <br>  &#8213;

        <span class='author'>David Klinger</span>,

        <i>

          <span class='work'>Into the Kill Zone: A Cop's Eye View of Deadly Force</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;This book is an essay in what is derogatorily called 'literary economics,' as opposed to mathematical economics, econometrics, or (embracing them both) the 'new economic history.' A man does what he can, and in the more elegant - one is tempted to say 'fancier' - techniques I am, as one who received his formation in the 1930s, untutored. A colleague has offered to provide a mathematical model to decorate the work. It might be useful to some readers, but not to me. Catastrophe mathematics, dealing with such events as falling off a height, is a new branch of the discipline, I am told, which has yet to demonstrate its rigor or usefulness. I had better wait. Econometricians among my friends tell me that rare events such as panics cannot be dealt with by the normal techniques of regression, but have to be introduced exogenously as 'dummy variables.' The real choice open to me was whether to follow relatively simple statistical procedures, with an abundance of charts and tables, or not. In the event, I decided against it. For those who yearn for numbers, standard series on bank reserves, foreign trade, commodity prices, money supply, security prices, rate of interest, and the like are fairly readily available in the historical statistics.&rdquo;

      <br>  &#8213;

        <span class='author'>Charles P. Kindleberger</span>,

        <i>

          <span class='work'>Manias, Panics, and Crashes: A History of Financial Crises</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Why is your equation only for angels, Roger? Why can't we do something, down here? Couldn't there be an equation for us too, something to help us find a safer place?' <br>'Why am I surrounded,' his usual understanding self today, 'by statistical illiterates? There's no way, love, not as long as the mean density of strikes is constant.&rdquo;

      <br>  &#8213;

        <span class='author'>Thomas Pynchon</span>,

        <i>

          <span class='work'>Gravity's Rainbow</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Convincing - and confident - disciplines, say, physics, tend to use little statistical backup, while political science and economics, which have never produced anything of note, are full of elaborate statistics and statistical “evidence” (and you know that once you remove the smoke, the evidence is not evidence).&rdquo;

      <br>  &#8213;

        <span class='author'>Nassim Nicholas Taleb</span>,

        <i>

          <span class='work'>Antifragile: Things That Gain from Disorder</span>

        </i>

    </div>",
    "<div class='quoteText'>

          &ldquo;Black Swans and tail events run the socioeconomic world&rdquo;

      <br>  &#8213;

        <span class='author'>Nassim Nicholas Taleb</span>,

        <i>

          <span class='work'>Antifragile: Things That Gain from Disorder</span>

        </i>

    </div>",
    );
    return $quotes[ rand(scalar(@quotes)) ];
}
