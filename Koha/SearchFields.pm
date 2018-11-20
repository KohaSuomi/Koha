package Koha::SearchFields;

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

use Carp;

use Koha::Database;

use Koha::SearchField;

use base qw(Koha::Objects);

=head1 NAME

Koha::SearchFields - Koha SearchField Object set class

=head1 API

=head2 Class Methods

=cut

=head3 weighted_fields

my (@w_fields, @weight) = Koha::SearchFields->weighted_fields();

=cut

sub weighted_fields {
    my ($self) = @_;

    return $self->search(
        { weight => { '>' => 0, '!=' => undef } },
        { order_by => { -desc => 'weight' } }
    );
}

=head3 type

=cut

sub _type {
    return 'SearchField';
}

sub object_class {
    return 'Koha::SearchField';
}

1;
