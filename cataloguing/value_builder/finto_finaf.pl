#!/usr/bin/perl

# Copyright 2021 KohaSuomi Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use utf8;

use CGI qw ( -utf8 );

use C4::Context;
use C4::Output qw( output_html_with_http_headers output_with_http_headers);
use C4::Auth qw( get_template_and_user);
use Encode qw( decode encode is_utf8 );
use JSON;

use Mojo::UserAgent;
use XML::LibXML;

use C4::AuthoritiesMarc;
use Koha::SearchEngine::Search;
use Koha::SearchEngine::QueryBuilder;

my $builder = sub {
    my ( $params ) = @_;
    my $function_name = $params->{id};
    my %args;

    my $vocab = "finaf";

    my $js  = <<END_OF_JS;
<script type="text/javascript">
//<![CDATA[
	\$( document ).ready(function() {
		\$($function_name).css("margin-bottom", "5px");
	 	\$($function_name).after('<select class="$function_name"></select>');
	 	selectBox$function_name(\$($function_name).attr('id'));
	});

	function selectBox$function_name(selecttag) {
		\$('.' + selecttag).select2({
			ajax: {
				url: 'https://api.finto.fi/rest/v1/search',
				dataType: 'json',
				data: function(params) {
					var query = {
					vocab: '$vocab',
					query: '*' + params.term + '*',
					type: 'skos:Concept',
					unique: 1,
					}
					return query;
				},
				processResults: function(data) {
					var tmp = \$.map(data.results, function(obj){
									var sl = obj.prefLabel;
									if (obj.altLabel) { sl += " <i>("+obj.altLabel+")</i>" };
						if (obj.vocab && / /.test("$vocab")) { sl += " <i>("+obj.vocab+")</i>" }
									return { id: obj.prefLabel,
											text: sl,
											uri: obj.uri,
											vocab: obj.vocab,
											localname: obj.localname,
											field: selecttag }
							});
					return { results: tmp };
				},
				cache: true
			},
			minimumInputLength: 2,
			templateSelection: formatSelection$function_name,
			escapeMarkup: function(m) { return m; },
		});

	}

	function formatSelection$function_name (data) {
		if (data.id === '') {
			return 'Etsi Fintosta';
		}
		var id = \$("#"+data.field).attr('id');
		
		if(data.localname) {
			newin=window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=finto_finaf.pl&index=\"+ id +\"&localname=\"+data.localname,\"tag_editor\",'width=1000,height=600,toolbar=false,scrollbars=yes');
		}

		\$('.'+data.field).empty();
	}

	function MouseOver$function_name(event) {
		var tag = event.data.id;
		\$("#"+tag).next().attr('class', tag);
		selectBox$function_name(tag);
	}

	function Click$function_name(event) {

		var re = /^(tag_...)/;
	    var found = event.data.id.match(re);
		var authcode;
		if (found[0] == 'tag_100') {
			authcode = 'PERSO_NAME';
		}
		if (found[0] == 'tag_110') {
			authcode = 'CORPO_NAME';
		}

		newin=window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=finto_finaf.pl&index=\"+event.data.id,\"_blank\",'width=1000,height=600,toolbar=false,scrollbars=yes');

	}

//]]>
</script>
END_OF_JS
    return $js;
};

my $launcher = sub {
    my ( $params ) = @_;
    my $input = $params->{cgi};
    my $index= $input->param('index');
	my $tag = substr( $index, 0, index( $index, '_subfield' ) );
	$tag =~ s/\D//g;
	my $authtypecode = authtypecodehelper($tag);
    my $localname= $input->param('localname')||'';
	my $search = $input->param('search');
	my $record;
	my $authid;
	my $error;
	my $subfields;
	my $ind1;
	my $ind2;
	my ( $authresults, $total );

	my ($template, $loggedinuser, $cookie)
    = get_template_and_user({template_name => "cataloguing/value_builder/finto_finaf.tt",
                 query => $input,
                 type => "intranet",
                 authnotrequired => 0,
                 flagsrequired => {editcatalogue => '*'},
                 debug => 1,
                 });

	if ($search) {
		my @value      = $input->multi_param('term');
		my $searchtype = $input->param('querytype');
		my @marclist  = ($searchtype);
		my $authtypecode = $input->param('authtypecode');
		my @and_or    = $input->multi_param('and_or');
		my @excluding = $input->multi_param('excluding');
		my @operator  = $input->multi_param('operator');
		my $orderby   = $input->param('orderby');
		my $offset = $input->param('offset');
		my $limit = $input->param('limit');

		my $builder = Koha::SearchEngine::QueryBuilder->new(
        { index => $Koha::SearchEngine::AUTHORITIES_INDEX } );
		my $searcher = Koha::SearchEngine::Search->new(
			{ index => $Koha::SearchEngine::AUTHORITIES_INDEX } );
		my $search_query = $builder->build_authorities_query_compat(
			\@marclist, \@and_or, \@excluding, \@operator,
			\@value, $authtypecode, $orderby
		);
		( $authresults, $total ) = $searcher->search_auth_compat( $search_query, $offset, $limit );
		output_with_http_headers $input, $cookie, to_json($authresults, { utf8 => 1 }), 'json';
	} else {
		if ($localname) {
			my $config = C4::Context->config("finto")->{"finaf"};
			my $base_url = $config->{"base_url"}."?operation=searchRetrieve&version=2.0&maximumRecords=1&query=rec.id=".$localname;
			my $ua = Mojo::UserAgent->new;
			if ($config->{"proxy_url"}) {
				$ua->proxy->https($config->{"proxy_url"});
			}
			my $tx = $ua->build_tx(GET => $base_url);
			$tx = $ua->start($tx);
			$error = $tx->error if $tx->error;
			if (!$error) {
				my $dom = eval { XML::LibXML->load_xml(string => $tx->res->body)};
				my @records = $dom->getElementsByTagName('record');
				if (@records) {
					my $authrecord = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
					$authrecord .= $records[0]->toString();
					$record = MARC::Record::new_from_xml($authrecord, 'UTF-8');
					my $authresult = searchauthority($record);
					my ($authtypecode, $newtag) = authtypecodehelper($tag);
					if ($record->field($newtag)) {
						foreach my $subfield( $record->field($newtag)->subfields ) {
							my $subfieldcode  = shift @$subfield;
							my $subfieldvalue = shift @$subfield;
							push @{$subfields}, {code => $subfieldcode, value => $subfieldvalue};
						}
						$ind1 = $record->field($newtag)->indicator("1");
						$ind2 = $record->field($newtag)->indicator("2");
						$authid= C4::AuthoritiesMarc::AddAuthority($record, $authresult, $authtypecode);
					} else {
						$error->{message} = Encode::decode('UTF-8',"$newtag-kenttää ei löydy valitusta auktoriteetista");
					}
				}
			}
		}

		$template->param( MARC_FORMATTED => $record->as_formatted ) if $record;
		$template->param( SUBFIELDS => $subfields ) if $subfields;
		$template->param( authid => $authid );
		$template->param( index => $index);
		$template->param( ind1 => $ind1);
		$template->param( ind2 => $ind2);
		$template->param( ERROR => $error->{message} ) if $error;
    	output_html_with_http_headers $input, $cookie, $template->output;
	}
};

sub authtypecodehelper {
	my ( $tag ) = @_;
	my $authtypecode;
	my $newtag = $tag;
	if ($tag eq "100" || $tag eq "600" || $tag eq "696" || $tag eq "700" || $tag eq "796" || $tag eq "800" || $tag eq "896") {
		$authtypecode = 'PERSO_NAME';
		$newtag = '100';
	}
	if ($tag eq "110" || $tag eq "610" || $tag eq "697" || $tag eq "710" || $tag eq "797" || $tag eq "810" || $tag eq "897") {
		$authtypecode = 'CORPO_NAME';
		$newtag = '110';
	}
	if ($tag eq "111" || $tag eq "611" || $tag eq "698" || $tag eq "711" || $tag eq "798" || $tag eq "811" || $tag eq "898") {
		$authtypecode = 'MEETI_NAME';
		$newtag = '111';
	}

	return ($authtypecode, $newtag);
};

sub searchauthority {
	my ($record) = @_;

	my $marclist  = 'mainmainentry';
	my $and_or    = '';
	my $excluding = '';
	my $operator  = 'is';
	my $orderby   = '';
	my $value     = $record->subfield('035','a');
	my $authid;
	state $builder  = Koha::SearchEngine::QueryBuilder->new({index => $Koha::SearchEngine::AUTHORITIES_INDEX});
	state $searcher = Koha::SearchEngine::Search->new({index => $Koha::SearchEngine::AUTHORITIES_INDEX});
	my $search_query = $builder->build_authorities_query_compat(
		[$marclist], [$and_or], [$excluding], [$operator],
		[$value], '', $orderby
	);
	my ( $authresults, $total ) = $searcher->search_auth_compat( $search_query, 0, 1 );
	$authid = @{$authresults}[0]->{authid} if (@{$authresults});
	
	return $authid;
}

return { builder => $builder, launcher => $launcher };
