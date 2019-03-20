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

    my $js = qq|
<script type="text/javascript">
//<![CDATA[

 function Click$function_name(event) {
   var f = KOHA.MarcEdit.GetTitle();
   if (f === undefined) return false;
   var fv = f.value.trim();
   if (/,\$/.test(fv)) {
       fv = fv.replace(/,\$/, '');
   } else if (/[^\\s]\\S\.\$/.test(fv)) {
       fv = fv.replace(/\.\$/, '');
   }
   \$('#' + event.data.id).val(fv);
   return false;
 }

//]]>
</script>

|;
    return $js;
};

return { builder => $builder };
