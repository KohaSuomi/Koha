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

my $builder= sub {
    my ( $params ) = @_;
    my $function_name = $params->{id};

    my $js = <<ENDJS;
<script type="text/javascript">
//<![CDATA[

 function Click$function_name(event) {
   var f = KOHA.MarcEdit.GetTitle();
   if (f === undefined) return false;
   var v = f.value;
   var skip = 0;
   if (f.tag == '130') skip = f.ind(1);
   if (f.tag == '245') skip = f.ind(2);

   if (skip > 0) v = v.slice(skip);
   else {
       // find first non-alphanumeric character
       var re = /[^a-zA-Z0-9]/;
       var vn = v.normalize('NFD');
       var i = 0;
       while (vn.substr(i,1).match(re) && i < v.length) i++;
       v = v.slice(i);
   }

   v = v.substring(0, 3).trim().toUpperCase();

   \$('#' + event.data.id).val(v);
   return false;
 }

//]]>
</script>

ENDJS
    return $js;
};

return { builder => $builder };
