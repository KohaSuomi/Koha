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

use CGI qw ( -utf8 );

use C4::Context;
use C4::Output;
use C4::Auth;
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
	 if (!window.FintoCache) window.FintoCache = [];

	 function gatherdata$function_name(id, sels) {
		\$("#" + id).val(sels.oldval);
		if (sels.userdef) {
			\$("#" + id).val(sels.id);
			var fid = \$('#'+id).parent().parent().attr('id');
			var re = /^(tag_..._)/;
			var found = fid.match(re);
			var sfid0 = found[1] + 'subfield_0_';
			var sfid2 = found[1] + 'subfield_2_';
			var sf2val;
			var sf0val;
			sf2val = "local";
			sf0val = "";
			if (typeof sf2val !== "undefined") \$('#'+id).parent().parent().find("input[id^='"+sfid2+"']").val(sf2val);
        	if (typeof sf0val !== "undefined") \$('#'+id).parent().parent().find("input[id^='"+sfid0+"']").val(sf0val);
		} else {
			if(sels.localname) {
				newin=window.open(\"../cataloguing/plugin_launcher.pl?plugin_name=finto_finaf.pl&index=\"+ id +\"&localname=\"+sels.localname,\"tag_editor\",'width=1000,height=600,toolbar=false,scrollbars=yes');
			}
		}
	 }
	 
	 function Focus$function_name(elementid, force) {
		var oldval = \$("#" + elementid).val();
	if (\$("#" + elementid).data("select2-enabled") == 1) { return; };
	\$("#" + elementid).data("select2-enabled", 1).select2({
	  width: 'resolve',
	  data: { id:"", text: "" },
	  initSelection: function(element, callback) {
	      var v = element.val();
              var duri = element.data('uri');
              var dvocab = element.data('vocab');
	      callback({ id:v, text:v, uri: duri, vocab: dvocab });
	  },
	  escapeMarkup: function(m) { return m; },
	  createSearchChoice: function(term, data) { return { id: term, text: term + " <i>(local)</i>", userdef: true }; },
	  minimumInputLength: 2,
	  ajax: {
	      url:'https://api.finto.fi/rest/v1/search',
	      dataType: 'json',
	      delay: 250,
	      quietMillis: 250,
	      cache: true,
	      data: function(params) {
		    var query = {
		      vocab: '$vocab',
		      query: '*' + params + '*',
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
									 localname: obj.localname }
                    });
		    return { results: tmp };
	      },
	      transport: function(params) {
		  if (params.dataType == "json") {
		      var cachekey = params.data.vocab+","+params.data.query+","+params.data.lang;
		      if (window.FintoCache && window.FintoCache[cachekey]) {
			  var res = window.FintoCache[cachekey];
			  params.success(res);
			  return {
			    abort: function() { console.log("FINTO: AJAX call aborted"); }
			  }
		      } else {
			  var \$request = \$.ajax(params);
			  \$request.then(function (data) {
			      window.FintoCache[cachekey] = data;
			      return data;
					 })
			      .then(params.success)
			      \$request.fail(params.failure);
			  return \$request;
		      }
		  } else {
		      var \$request = \$.ajax(params);
		      \$request.then(params.success);
		      \$request.fail(params.failure);
		      return \$request;
		  }
	      },
            }
           })
	   .focus()
           .on('select2-blur', function() { 
			   var sels=\$(this).select2('data'); 
			   sels.oldval = oldval;
			   gatherdata$function_name(\$(this).attr('id'), sels); 
			   \$(this).data("select2-enabled", 0); 
			   \$(this).off('select2-blur');  
			   \$(this).off('select2-close');  
			   \$(this).off('select2-select'); 
			   \$(this).off('change'); 
			   \$(this).select2('destroy'); })
           .on('select2-select', function(e) { \$(this).trigger({ type: 'select2-blur' }); })
           .on('select2-close', function() { \$(this).trigger({ type: 'select2-select' }); })
		   .on('select2-open', function() {  \$(this).select2('search', oldval); })
           .data('select2').open()

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
						$authid= AddAuthority($record, $authresult, $authtypecode);
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
