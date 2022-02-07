package C4::KohaSuomi::Tweaks;

# Copyright 2022 Koha-Suomi Oy 
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Selects can be run on alt_host (database slave) if configured.

sub dbh {
   my $self=shift;
   
   if ( C4::Context->config('althostname') ) {

       my $alt_host=C4::Context->config('althostname');
       my $alt_port;
       if ( C4::Context->config('altport') ) {
           $slt_port=C4::Context->config('altport');
       } else {
           $alt_port=C4::Context->config('port');
       }

       my $db_name=C4::Context->config('database');
       my $db_user=C4::Context->config('user');
       my $db_pass=C4::Context->config('pass');

       warn "Using alt dbh to $alt_host. ONLY SELECTS ALLOWED, NEVER WRITE TO DB THROUGH THIS HANDLE!";
       my $dbh=DBI->connect("DBI:mysql:database=$db_name:host=$alt_host:port=$alt_port",
                            "$db_user", "$db_pass", { mysql_enable_utf8=>1 });  
       $dbh->do('set names utf8;');
       return $dbh;

    } else {

       warn "Alternative dbh was requested, but not configured. Using C4::Context->dbh";
       return C4::Context->dbh();

    }
}

1;
