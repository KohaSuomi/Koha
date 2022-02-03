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
        my $timestamp = Koha::DateUtils::dt_from_string( $okm_report->{timestamp}, 'iso' );
        my $startdate = Koha::DateUtils::dt_from_string( $okm_report->{startdate}, 'iso' );
        my $enddate   = Koha::DateUtils::dt_from_string( $okm_report->{enddate}, 'iso' );
        $okm_report->{timestamp} = Koha::DateUtils::output_pref({ dt => $timestamp, dateonly => 1});
        $okm_report->{startdate} = Koha::DateUtils::output_pref({ dt => $startdate, dateonly => 1});
        $okm_report->{enddate}   = Koha::DateUtils::output_pref({ dt => $enddate,   dateonly => 1});

        #Find the selected report
        if ($okm_statisticsId && $okm_report->{id} == $okm_statisticsId) {
            $okm_report->{selected} = 1;
        }
    }
    return $okm_reports;
}
