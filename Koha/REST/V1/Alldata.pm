package Koha::REST::V1::Alldata;

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
use JSON;
use Mojo::Base 'Mojolicious::Controller';
use Koha::Account;
use Koha::AuthUtils qw(hash_password);
use Koha::Availability;
use C4::Auth qw( haspermission checkpw_internal );
use C4::Context;
use C4::PatronJson;
use Koha::Exceptions;
use Koha::Exceptions::Password;
use Koha::Patrons;
use Koha::Patron::Categories;
use Koha::Patron::Modifications;
use Koha::Libraries;
use Try::Tiny;


sub get {
    my $c = shift->openapi->valid_input or return;

    my $borrowernumber = $c->validation->param('borrowernumber');
    my $retval=C4::PatronJson->makejson($borrowernumber);    
    return $c->render(data => $retval,format => 'json');
   
}

1;
