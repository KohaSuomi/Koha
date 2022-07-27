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

function Blur$function_name(index) {
    // No action
}

function Focus$function_name(subfield_managed, id, force) {
    // Uncomment the below line to have the signum updated when the field gets focus
    // return Clic$function_name(id);
}

function Click$function_name(event) {
    
    var bn = \$('input[name="biblionumber"]').val();
     
    \$('#' + event.data.id).prop('disabled', true);
     
    if (!bn) return false;
    \$('#' + event.data.id).prop('disabled', true);
    var url = '../cataloguing/plugin_launcher.pl?plugin_name=fi_JSON_084a_signum_builder_subfields.pl&biblionumber=' + bn;
    var req = \$.get(url);
    req.fail(function(jqxhr, text, error){
	alert(error);
    \$('#' + event.data.id).prop('disabled', false);
	});
    req.done(function(resp){ 
    
        // Do classification
        var marc084a = resp.f084a;

 	    \$('#' + event.data.id).val(marc084a);
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
