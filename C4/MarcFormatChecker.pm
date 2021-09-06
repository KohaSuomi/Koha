package C4::MarcFormatChecker;

use strict;

use C4::Context;
use Koha::Caches;
use XML::LibXML;
use Storable;

use vars qw(@ISA @EXPORT);

BEGIN {

	require Exporter;
    @ISA = qw( Exporter );

    # function exports
    @EXPORT = qw(
        CheckMARC21FormatErrors
    );
}


# It's not currently possible to get this info out of the xml file
my %field_data = (
    'valid_fields' => {},
    'not_repeatable' => {},
    'allow_indicators' => {},
    'typed' => {},
    'fixed_length' => {
	'000' => 24,
	'005' => 16,
	'006' => 18,
	'008' => 40
    },
    'regex' => {},
    'allow_regex' => {
	'005' => {
	    'x' => '^[0-9]{14}\.[0-9]$',
	},
    },
    );

# convert 006/00 to material code
my %convert_006_material = (
    'a' => 'BK',
    't' => 'BK',
    'm' => 'CF',
    's' => 'CR',
    'e' => 'MP',
    'f' => 'MP',
    'c' => 'MU',
    'd' => 'MU',
    'i' => 'MU',
    'j' => 'MU',
    'p' => 'MX',
    'g' => 'VM',
    'k' => 'VM',
    'o' => 'VM',
    'r' => 'VM',
    );

sub get_field_tagntype {
    my ($f, $record) = @_;

    my $tag = $f->tag();

    if ($tag eq '006') {
        my $data = substr($f->data(), 0, 1) || '';
        return $tag.'-'.$convert_006_material{$data} if (defined($convert_006_material{$data}));
    } elsif ($tag eq '007') {
        my $data = substr($f->data(), 0, 1) || '';
        return $tag.'-'.$data if ($data ne '');
    } elsif ($tag eq '008') {
        my $ldr = $record->leader();
        my $l6 = substr($ldr, 6, 1);
        my $l7 = substr($ldr, 7, 1);
        my $data = '';
	# FIXME: Same as 006, but also checks ldr/07
        $data = 'BK' if (($l6 eq 'a' || $l6 eq 't') && !($l7 eq 'b' || $l7 eq 'i' || $l7 eq 's'));
        $data = 'CF' if ($l6 eq 'm');
        $data = 'CR' if (($l6 eq 'a' || $l6 eq 't') &&  ($l7 eq 'b' || $l7 eq 'i' || $l7 eq 's'));
        $data = 'MP' if ($l6 eq 'e' || $l6 eq 'f');
        $data = 'MU' if ($l6 eq 'c' || $l6 eq 'd' || $l6 eq 'i' || $l6 eq 'j');
        $data = 'MX' if ($l6 eq 'p');
        $data = 'VM' if ($l6 eq 'g' || $l6 eq 'k' || $l6 eq 'o' || $l6 eq 'r');
        return $tag.'-'.$data if ($data ne '');
    }
    return $tag;
}

sub generate_tag_sequence {
    my ($tag) = @_;

    my @fields;

    $tag =~ s/^\s+//;
    $tag =~ s/\s+$//;

    if ($tag =~ /,/) {
	foreach my $tmp (split(/,/, $tag)) {
	    push(@fields, generate_tag_sequence($tmp));
	}
	return @fields;
    }

    if (defined($tag) && $tag =~ /x/i && $tag =~ /^([0-9x])([0-9x])([0-9x])(.*)$/i) {
        my ($p1, $p2, $p3, $p4) = ($1, $2, $3, $4);
        my @c1 = (($p1 =~ /x/i) ? 0..9 : $p1);
        my @c2 = (($p2 =~ /x/i) ? 0..9 : $p2);
        my @c3 = (($p3 =~ /x/i) ? 0..9 : $p3);

        foreach my $a1 (@c1) {
            foreach my $a2 (@c2) {
                foreach my $a3 (@c3) {
                    my $fld = $a1.$a2.$a3.$p4;
                    push @fields, $fld;
                }
            }
        }
    } else {
        push @fields, $tag;
    }

    return @fields;
}

sub parse_positions {
    my ($field, $data, $tag, $type, $subfield) = @_;

    my @posdom = $field->findnodes('positions/position');
    if (scalar(@posdom) > 0) {
        foreach my $p (@posdom) {
            my $pos = $p->getAttribute('pos');
            my @equals = $p->findnodes('equals');
            my @pvalues = $p->findnodes('alternatives/alternative/values/value|values/value');
            my @vals;

	    $pos =~ s/^\///;

            if (scalar(@pvalues) > 0) {
		my $fcode = $tag . $subfield . $type;
                foreach my $pv (@pvalues) {
                    my $pv_code = $pv->getAttribute('code');
                    $pv_code =~ s/#/ /g;
                    $data->{'regex'}{$fcode}{$pos} = [] if (!defined($data->{'regex'}{$fcode}{$pos}));
                    push @{$data->{'regex'}{$fcode}{$pos}}, $pv_code;

                    $data->{'allow_regex'}{$fcode}{$pos} = [] if (!defined($data->{'allow_regex'}{$fcode}{$pos}));
		    if (ref($data->{'allow_regex'}{$fcode}{$pos}) eq 'ARRAY') {
			push @{$data->{'allow_regex'}{$fcode}{$pos}}, $pv_code;
		    } else {
			print STDERR "allow_regex is not array for '$fcode/$pos' '$pv_code'";
		    }
                }

                if (scalar(@equals) > 0) {
                    foreach my $eq (@equals) {
                        my $eq_tag = $eq->getAttribute('tag');
                        my $eq_pos = $eq->getAttribute('positions');
			my $efcode =  $eq_tag . $type;
                        $data->{'regex'}{$efcode}{$eq_pos} = [] if (!defined($data->{'regex'}{$efcode}{$eq_pos}));
                        @{$data->{'regex'}{$efcode}{$eq_pos}} = @{$data->{'regex'}{$fcode}{$pos}};

                        $data->{'allow_regex'}{$efcode}{$eq_pos} = [] if (!defined($data->{'allow_regex'}{$efcode}{$eq_pos}));
                        if (ref($data->{'allow_regex'}{$efcode}{$eq_pos}) eq 'ARRAY') {
                            @{$data->{'allow_regex'}{$efcode}{$eq_pos}} = @{$data->{'allow_regex'}{$fcode}{$pos}};
                        } else {
                            print STDERR "allow_regex equals is not array for '$eq_tag' '$type' '$eq_pos'"
                        }
                    }
                }
            }
        }
    }
}

sub parse_single_field {
    my ($field, $data) = @_;

    #my $name = $field->{'name'};
    my $tag = $field->getAttribute('tag');
    my $type = $field->getAttribute('type') || '';
    my $repeatable = $field->getAttribute('repeatable') || '';

    if ($tag =~ /x/i) {
        my @tags = generate_tag_sequence($tag);
        foreach my $tmptag (@tags) {
            $field->setAttribute('tag', $tmptag);
            parse_single_field($field, $data);
        }
        return;
    }

    $type = '' if ($type eq 'yleista');
    $type = "-".$type if ($type ne '');
    $data->{'typed'}{$tag} = 1 if ($type ne '');

    $data->{'valid_fields'}{$tag} = 1;
    $data->{'not_repeatable'}{$tag . $type} = 1 if ($repeatable eq 'N');

    my @inddom = $field->findnodes('indicators/indicator');
    if (scalar(@inddom) > 0) {
        foreach my $ind (@inddom) {
            my $ind_num = $ind->getAttribute('num');
            my @ind_values = $ind->findnodes('values/value');
            my $allowed_ind_values = '';

            foreach my $indval (@ind_values) {
                my $ivcode = $indval->getAttribute('code');
                $ivcode =~ s/#/ /g;
                $allowed_ind_values .= $ivcode;
            }
            $data->{'allow_indicators'}{$tag . $ind_num} = $allowed_ind_values if ($allowed_ind_values ne '');
        }
    }

    my @sfdom = $field->findnodes('subfields/subfield');
    if (scalar(@sfdom) > 0) {
        foreach my $sf (@sfdom) {
            my $sf_code = $sf->getAttribute('code');
            my $sf_repeatable = $sf->getAttribute('repeatable');
            my $sf_name = $sf->findvalue('name');

            my $sf_a;
            my $sf_b;
            if ($sf_code =~ /^(.)-(.)$/) {
                $sf_a = $1;
                $sf_b = $2;
            } else {
                $sf_a = $sf_b = $sf_code;
            }

            for my $sfc ($sf_a .. $sf_b) {
                $data->{'valid_fields'}{$tag . $sfc} = 1;
                $data->{'not_repeatable'}{$tag . $sfc . $type} = 1 if ($sf_repeatable eq 'N');
                parse_positions($sf, $data, $tag, $type, $sfc);
            }
        }
    }

    parse_positions($field, $data, $tag, $type, '');
}

sub parse_xml_data {
    my ($filename, $data) = @_;

    my $dom = XML::LibXML->load_xml(location => $filename);

    my @ldr = $dom->findnodes('//fields/leader-directory/leader');
    if (scalar(@ldr) > 0) {
        foreach my $tag (@ldr) {
            $tag->setAttribute('tag', '000');
            parse_single_field($tag, $data);
        }
    }

    my @ctrls = $dom->findnodes('//fields/controlfields/controlfield');
    if (scalar(@ctrls) > 0) {
        foreach my $tag (@ctrls) {
            parse_single_field($tag, $data);
        }
    }

    my @datas = $dom->findnodes('//fields/datafields/datafield');
    if (scalar(@datas) > 0) {
        foreach my $tag (@datas) {
            parse_single_field($tag, $data);
        }
    }
}

sub fix_regex_data {
    my ($data) = @_;

    my %re = %{$data};

    foreach my $rekey (sort keys(%re)) {
        my %sr = %{$re{$rekey}};
        foreach my $srkey (sort keys(%sr)) {
            my $dat = $sr{$srkey};
            my $rdat = ref($sr{$srkey});
            next if ($rdat eq 'Regexp');

            my $srkeylen = 1;
            if ($srkey =~ /(\d+)-(\d+)/) {
                my ($startpos, $endpos) = ($1, $2);
                $srkeylen = ($endpos - $startpos) + 1;
            }

            if ($rdat eq 'ARRAY') {
                my @vals;
                for (my $idx = 0; $idx < scalar(@{$dat}); $idx++) {
                    my $val = @{$dat}[$idx];
                    if ($val =~ /^(\d+)-(\d+)$/) {
                        push(@vals, ($1 .. $2));
                        next;
                    }
                    push(@vals, $val);
                }

                my %reparts;
                foreach my $val (@vals) {
                    my $lval = length($val);
                    $val =~ s/\|/\\|/g;
                    $reparts{$lval} = () if (!defined($reparts{$lval}));
                    push(@{$reparts{$lval}}, $val);
                }

                my @restr;
                for my $key (sort keys(%reparts)) {
                    if (int($key) == $srkeylen) {
                        push(@restr, @{$reparts{$key}});
                    } else {
                        my $reps = ($srkeylen / int($key));
                        if ($reps == int($reps)) {
                            my $s = '(' . join('|', @{$reparts{$key}}) . '){'.int($reps).'}';
                            push(@restr, $s);
                        } else {
                            warn "Regexp repeat not an int: (".join('|', @{$reparts{$key}})."){".$reps."}";
                        }
                    }
                }

                my $s = join('|', @restr);
                $re{$rekey}{$srkey} = qr/^($s)$/;

            } else {
                warn "marc21 format regex is not array";
            }
        }
    }
    return $data;
}

sub quoted_str_list {
    my ($lst) = @_;
    my $ret = '';
    if (defined($lst)) {
	my @arr = @{$lst};
	my $haspipes = 0;
	my $len = 0;
	my %lens;
	foreach my $tmp (@arr) {
	    $haspipes = 1 if ($tmp =~ /\|/);
	    $len = length($tmp) if ($len == 0);
	    $len = -1 if ($len != length($tmp));
	}
	if (!$haspipes && $len != -1) {
	    $ret = join('', @arr) if ($len == 1);
	    $ret = join('|', @arr) if ($len > 1);
	} elsif ($len != -1) {
	    $ret = join('', @arr) if ($len == 1);
	    $ret = join(',', @arr) if ($len > 1);
	} else {
	    $ret = join('","', @arr);
	    $ret = '"'.$ret.'"' if ($ret ne '');
	}
    }
    return '['.$ret.']';
}

sub fix_allow_regex_data {
    my ($data) = @_;

    my %re = %{$data};

    foreach my $rekey (sort keys(%re)) {
        my %sr = %{$re{$rekey}};
        foreach my $srkey (sort keys(%sr)) {
            my $dat = $sr{$srkey};
	    if (ref($dat) eq 'ARRAY') {
		$re{$rekey}{$srkey} = quoted_str_list($dat);
	    }
        }
    }

    return $data;
}

sub copy_allow_to_regex {
    my ($allow, $regex) = @_;

    my %al = %{$allow};
    my %re = %{$regex};

    foreach my $alkey (keys (%al)) {
	foreach my $xlkey (sort keys (%{$al{$alkey}})) {
	    $re{$alkey} = {} if (!defined($re{$alkey}));
	    $re{$alkey}{$xlkey} = qr/$al{$alkey}{$xlkey}/ if (!defined($re{$alkey}{$xlkey}));
	}
    }
    return \%re;
}

sub parse_MARC21_format_definition {

    my $cache_key = 'MARC21-formatchecker-bib';
    my $cache = Koha::Caches->get_instance();
    my $cached = $cache->get_from_cache($cache_key);
    return $cached if $cached;

    my $xml_dir = C4::Context->config('intranetdir') . '/cataloguing/MARC21formatXML';
    my $xml_glob = $xml_dir . '/bib-*.xml';

    return undef if (! -d $xml_dir);

    my @xmlfiles = glob($xml_glob);

    return undef if (scalar(@xmlfiles) < 1);

    my $fd = Storable::dclone(\%field_data);

    $fd->{'regex'} = copy_allow_to_regex($fd->{'allow_regex'}, $fd->{'regex'});

    foreach my $file (@xmlfiles) {
	parse_xml_data($file, $fd);
    }

    $fd->{'regex'} = fix_regex_data($fd->{'regex'});
    $fd->{'allow_regex'} = fix_allow_regex_data($fd->{'allow_regex'});

    # indicators are listed as sets of allowed chars. eg. ' ab' or '1-9'
    foreach my $tmp (keys(%{$fd->{'allow_indicators'}})) {
	$fd->{'allow_indicators'}{$tmp} = '[' . $fd->{'allow_indicators'}{$tmp} . ']';
    }

    my %tmpignores = map {($_, 1)} generate_tag_sequence(C4::Context->preference('MARC21FormatWarningsIgnoreFields'));
    $fd->{'ignore_fields'} = \%tmpignores;

    $cache->set_in_cache($cache_key, $fd);

    return $fd;
}

sub sort_by_number {
    my ( $anum ) = $a =~ /(\d+)/;
    my ( $bnum ) = $b =~ /(\d+)/;
    ( $anum || 0 ) <=> ( $bnum || 0 );
}

sub CheckMARC21FormatErrors {
    my ($origrecord) = @_;

    my $record = $origrecord->clone();

    if (substr($record->leader(), 1, 1) eq ' ') {
	$record->set_leader_lengths();
    }

    my $skip_enclevels = "8"; # Record encoding levels (ldr/17) to skip
    my $formatdata = parse_MARC21_format_definition();

    my %mainf;
    my %undeffs;

    my @errors;

    if (!defined($formatdata)) {
	warn "No MARC21 format data available";
	return \@errors;
    }

    if (index($skip_enclevels, substr($record->leader(),17,1)) != -1) {
	return \@errors;
    }

    my %ignore_fields = %{$formatdata->{'ignore_fields'}};
    my %valid_fields = %{$formatdata->{'valid_fields'}};
    my %not_repeatable = %{$formatdata->{'not_repeatable'}};
    my %allow_indicators = %{$formatdata->{'allow_indicators'}};
    my %typed_field = %{$formatdata->{'typed'}};
    my %format_regex = %{$formatdata->{'regex'}};

    my $test_field_data = 1;
    $record->append_fields(MARC::Field->new('000', $record->leader()));

    foreach my $f ($record->field('...')) {
	my $fi = $f->tag();
	my $fityp = get_field_tagntype($f, $record);

	next if (defined($ignore_fields{$fi}) || defined($ignore_fields{$fityp}));

	if (!defined($valid_fields{$fi})) {
	    $undeffs{$fi} = 1;
	    #push(@errors, "field $fi not defined by format");
	    next;
	}

	if ($test_field_data) {
	    my $key = $fi.'.length';
	    if (!defined($ignore_fields{$key}) && defined($formatdata->{'fixed_length'}{$fi})) {
		my $tmp = $formatdata->{'fixed_length'}{$fi};
		if ($tmp != length($f->data())) {
		    my %tmphash = (
			'field' => $key,
			'length' => length($f->data()),
			'wanted' => $tmp,
			'error' => 'FIELD_LENGTH'
			);
		    push(@errors, \%tmphash);
		    next;
		}
	    }

	    my @regexkeys;
	    push(@regexkeys, $fi) if ($format_regex{$fi});
	    push(@regexkeys, $fityp) if ($fi ne $fityp && $format_regex{$fityp});
	    push(@regexkeys, $fi.'-kaikki') if ($format_regex{$fi.'-kaikki'});

	    if (scalar(@regexkeys)) {
		my $data = $f->data();
		foreach my $rk (sort @regexkeys ) {
		    my $s;
		    my $zf = $format_regex{$rk};
		    my %ff = %{$zf};

		    foreach my $ffk (sort(sort_by_number keys(%ff))) {
                        my $allow_vals = $formatdata->{'allow_regex'}{$rk}{$ffk};

			if ($ffk =~ /^\d+$/) {
			    $s = length($data) < int($ffk) ? '' : substr($data, int($ffk), 1);
			    if ($s !~ /$ff{$ffk}/) {
				my %tmphash = (
				    'field' => $fi,
				    'pos' => $ffk,
				    'value' => $s,
				    'required' => $allow_vals,
				    'error' => 'FIELD_VALUE_POS'
				    );
				push(@errors, \%tmphash);
				next;
			    }
			} elsif ($ffk =~ /^(\d+)-(\d+)$/) {
			    my ($kstart, $kend) = (int($1), int($2));
			    $s = length($data) < $kend ? '' : substr($data, $kstart, $kend - $kstart + 1);
			    if ($s !~ /$ff{$ffk}/) {
				my %tmphash = (
				    'field' => $fi,
				    'pos' => $ffk,
				    'value' => $s,
				    'required' => $allow_vals,
				    'error' => 'FIELD_VALUE_POS'
				    );
				push(@errors, \%tmphash);
				next;
			    }
			} else {
			    $s = $data || "";
			    if ($s !~ /$ff{$ffk}/) {
				my %tmphash = (
				    'field' => $fi,
				    'value' => $s,
				    'required' => $allow_vals,
				    'error' => 'FIELD_VALUE'
				    );
				push(@errors, \%tmphash);
				next;
			    }
			}
		    }
		}
	    }
	}

	if ($typed_field{$fi}) {

	    next if (defined($ignore_fields{$fityp}));

	    if ($fityp ne $fi) {
		$mainf{$fityp} = 0 if (!defined($mainf{$fityp}));
		$mainf{$fityp}++;
	    }
	}

	next if (scalar($fi) < 10);

	$mainf{$fi} = 0 if (!defined($mainf{$fi}));
	$mainf{$fi}++;

	my @subf = $f->subfields();
	my %subff;

	foreach my $sf (@subf) {
	    my $key = $sf->[0];
	    my $val = $sf->[1];
	    my $fikey = $fi.$key;

	    next if (defined($ignore_fields{$fikey}));

	    if (!defined($valid_fields{$fikey})) {
		$undeffs{$fi . '$' . $key} = 1;
		#push(@errors, "field $fikey not defined by format");
		next;
	    }

	    $subff{$fikey} = 0 if (!defined($subff{$fikey}));
	    $subff{$fikey}++;
	}

	foreach my $k (keys(%subff)) {
	    if (($subff{$k} > 1) && defined($not_repeatable{$k})) {
		my %tmphash = (
		    'field' => $k,
		    'count' => $subff{$k},
		    'error' => 'NOT_REPEATABLE_SUBFIELD'
		    );
		push(@errors, \%tmphash);
	    }
	}

	foreach my $ind ((1, 2)) {
	    my $indv = $f->indicator($ind);
	    my $tmp = $allow_indicators{$fi.$ind};
	    my $key = $fi.'.ind'.$ind;

	    next if (defined($ignore_fields{$key}));

	    if (defined($tmp) && ($indv !~ /$tmp/)) {
		my %tmphash = (
		    'field' => $fi,
		    'indicator' => $ind,
		    'current' => $indv,
		    'valid' => $tmp,
		    'error' => 'INDICATOR'
		    );
		push(@errors, \%tmphash);
	    }
	}
    }

    if (scalar(keys(%undeffs)) > 0) {
	foreach my $undkey (keys(%undeffs)) {
	    my %tmphash = (
		'field' => $undkey,
		'error' => 'NOT_IN_FORMAT'
		);
	    push(@errors, \%tmphash);
	}
    }

    foreach my $k (keys(%mainf)) {
	if (($mainf{$k} > 1) && defined($not_repeatable{$k})) {
	    my %tmphash = (
		'field' => $k,
		'count' => $mainf{$k},
		'error' => 'NOT_REPEATABLE_FIELD'
		);
	    push(@errors, \%tmphash);
	}
    }

    my @tmperr = sort { $a->{'field'} cmp $b->{'field'} } @errors;
    return \@tmperr;
}

1;
