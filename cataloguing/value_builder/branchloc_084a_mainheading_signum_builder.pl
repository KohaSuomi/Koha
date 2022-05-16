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
         
                // Do shelving location
        var shelvingLoc = \$("select[id^='tag_952_subfield_c']").val() ? \$("select[id^='tag_952_subfield_c']").val() : \$("div[id^='subfieldc']").find("select").val();
        if (!shelvingLoc) {
            shelvingLoc = "";
        }

        var branch = \$("select[id^='tag_952_subfield_a']").val() ? \$("select[id^='tag_952_subfield_a']").val() : \$("div[id^='subfielda']").find("select").val();
        if (!branch) {
            branch = "";
        }

        // Do classification
        
        var marc084a = resp.f084a;
        
        // Do main heading
        // Actually we should also follow the bypass indicators here

        var marc100a = resp.f100a;

        var marc110a = resp.f110a;
        marc110a =marc110a.substring(1);

        var marc111a = resp.f111a;

        // First indicator is 'bypass'
        var marc130a = resp.f130a;

        // Second indicator is 'bypass'
        var marc245a = resp.f245a;

        if (marc100a) {
            var mainHeading = marc100a;
        } else if (marc110a) {
            var mainHeading = marc110a;
        } else if (marc111a) {
            var mainHeading = marc111a;
        } else if (marc130a) {
            var mainHeading = marc130a;
        } else if (marc245a) {
            var mainHeading = marc245a;
        }

        mainHeading = mainHeading.substring(0, 3).toUpperCase();
        var splitted = branch.split('_')[1];
        if (splitted) {
            branch = splitted;
        }
            
        var dat = branch + shelvingLoc + " " + marc084a + " " + mainHeading;
	    
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
