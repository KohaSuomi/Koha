#!/usr/bin/perl

# Copyright 2019 Koha-Suomi Oy
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
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

my $builder = sub {
    my ( $params ) = @_;
    my $function_name = $params->{id};

    my $js = <<ENDJS;
<script type="text/javascript">
//<![CDATA[

 function Click$function_name(event) {
     var bn = \$('input[name="biblionumber"]').val();
     if (!bn) return false;
      \$('#' + event.data.id).prop('disabled', true);
     var url = '../cataloguing/plugin_launcher.pl?plugin_name=fi_JSON_942khm.pl&biblionumber=' + bn;
     var req = \$.get(url);
     req.fail(function(jqxhr, text, error){
	 alert(error);
         \$('#' + event.data.id).prop('disabled', false);
	 });
     req.done(function(resp){
	 var shelvingLoc = KOHA.MarcEdit.GetItemFieldValue('952c') || "";
	 var branch = KOHA.MarcEdit.GetItemFieldValue('952a') || "";
	 var genre = KOHA.MarcEdit.GetItemFieldValue('952G') || "";

	 var split = branch.split('_')[1];
	 if (split) {
	     branch = split;
	 }

	 var dat = resp.f942k + " " + resp.f942h + " " + resp.f942m + " " + branch + shelvingLoc + " " + genre;
	 dat = dat.replace(/ {1,}/g," ").trim();
	 \$('#' + event.data.id).val(dat);
         \$('#' + event.data.id).prop('disabled', false);
     });
     return false;
 }

//]]>
</script>

ENDJS

    return $js;
};

return { builder => $builder };
