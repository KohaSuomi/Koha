package Koha::REST::V1::Logpatron;

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

#This is Mojolicious controller. Get returns json, which includes log data from MongoDB

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Koha::MongoDB::LogJson;

sub get {
    my $c = shift->openapi->valid_input or return;
    my $borrowernumber = $c->validation->param('borrowernumber');
    my $retval=Koha::MongoDB::LogJson->logs_borrower($borrowernumber);    
    return $c->render(data => $retval,format => 'json');
  
   
}

1;
