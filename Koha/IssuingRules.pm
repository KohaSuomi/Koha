package Koha::IssuingRules;

# Copyright Vaara-kirjastot 2015
# Copyright Koha Development Team 2016
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

use Koha::Database;

use Koha::IssuingRule;

use base qw(Koha::Objects);

=head1 NAME

Koha::IssuingRules - Koha IssuingRule Object set class

=head1 API

=head2 Class Methods

=cut

sub get_effective_issuing_rule {
    my ( $self, $params ) = @_;

    my $default      = '*';
    my $categorycode = $params->{categorycode};
    my $itemtype     = $params->{itemtype};
    my $branchcode   = $params->{branchcode};
    my $ccode        = $params->{ccode};
    my $permanent_location = $params->{permanent_location};
    my $sub_location = $params->{sub_location};
    my $genre        = $params->{genre};
    my $checkout_type = $params->{checkout_type};
    my $reserve_level = $params->{reserve_level};

    my $search_categorycode = $default;
    my $search_itemtype     = $default;
    my $search_branchcode   = $default;
    my $search_ccode        = $default;
    my $search_permanent_location = $default;
    my $search_sub_location = $default;
    my $search_genre        = $default;
    my $search_checkout_type = $default;
    my $search_reserve_level = $default;

    if ($categorycode) {
        $search_categorycode = { 'in' => [ $categorycode, $default ] };
    }
    if ($itemtype) {
        $search_itemtype = { 'in' => [ $itemtype, $default ] };
    }
    if ($branchcode) {
        $search_branchcode = { 'in' => [ $branchcode, $default ] };
    }
    if ($ccode) {
        $search_ccode = { 'in' => [ $ccode, $default ] };
    }
    if ($permanent_location) {
        $search_permanent_location = { 'in' => [ $permanent_location, $default ] };
    }
    if ($sub_location) {
        $search_sub_location = { 'in' => [ $sub_location, $default ] };
    }
    if ($genre) {
        $search_genre = { 'in' => [ $genre, $default ] };
    }
    if ($checkout_type) {
        $search_checkout_type = { 'in' => [ $checkout_type, $default ] };
    }
    if ($reserve_level) {
        $search_reserve_level = { 'in' => [ $reserve_level, $default ] };
    }

    my $rule = $self->search({
        categorycode => $search_categorycode,
        itemtype     => $search_itemtype,
        branchcode   => $search_branchcode,
        ccode        => $search_ccode,
        permanent_location => $search_permanent_location,
        sub_location => $search_sub_location,
        genre        => $search_genre,
        checkout_type => $search_checkout_type,
        reserve_level => $search_reserve_level,
    }, {
        order_by => {
            -desc => [
                'branchcode', 'checkout_type', 'reserve_level',
                'categorycode', 'itemtype', 'ccode', 'permanent_location',
                'sub_location', 'genre',
            ]
        },
        rows => 1,
    })->single;
    return $rule;
}

=head3 type

=cut

sub _type {
    return 'Issuingrule';
}

sub object_class {
    return 'Koha::IssuingRule';
}

1;
