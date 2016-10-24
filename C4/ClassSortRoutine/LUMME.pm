package C4::ClassSortRoutine::LUMME;

# Copyright (C) 2007 LibLime
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

use strict;
use warnings;

=head1 NAME

C4::ClassSortRoutine::LUMME - LUMME call number sorting key routine

=head1 SYNOPSIS

use C4::ClassSortRoutine qw( GetClassSortKey );

my $cn_sort = GetClassSortKey('LUMME', $cn_class, $cn_item);

=head1 FUNCTIONS

=head2 get_class_sort_key

  my $cn_sort = C4::ClassSortRoutine::LUMME::LUMME($cn_class, $cn_item);

Generates sorting key using the following rules:

* Removes leading and trailing whitespace.

=cut

sub get_class_sort_key {
    my ($cn_class, $cn_item) = @_;

    $cn_class = '' unless defined $cn_class;
    $cn_item  = '' unless defined $cn_item;
    my $key = uc "$cn_class $cn_item";
    $key =~ s/^\s+//;
    $key =~ s/\s+$//;
    return $key;
}

1;

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>
Broken by Koha-Suomi Oy/OUTI-Libraries <http://koha-suomi.fi/>

=cut
