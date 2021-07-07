package Koha::Template::Plugin::Checkouts;

# Copyright 2020 Hypernova Oy
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

=head1 NAME

Koha::Template::Plugin::Checkouts

=head1 DESCRIPTION

The Checkouts plugin is a helper for using Koha::Checkouts in templates.

=head1 SYNOPSYS

    [% USE Checkouts %]

=cut

use Modern::Perl;

use Template::Plugin;
use base qw( Template::Plugin );

use C4::Koha;
use C4::Context;
use Koha::Checkouts;

=head1 FUNCTIONS

=head2 checkout_type

Returns $Koha::Checkouts::type HASHref.

Usage:

    [% IF (checkout_type == Checkouts.checkout_type.onsite_checkout %]
        ...
    [% END %]

=cut

sub checkout_type {
    return $Koha::Checkouts::type;
}

1;
