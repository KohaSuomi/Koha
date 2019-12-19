package Koha::REST::V1::Patron::Attribute;

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

use Mojo::Base 'Mojolicious::Controller';
use C4::Context;
use Koha::Exceptions;
use Koha::Exceptions::Password;
use Koha::Exceptions::Patron::Attribute;
use Koha::Patrons;
use Koha::Patron::Attributes;
use Scalar::Util qw(blessed looks_like_number);
use Try::Tiny;

sub list {
    my $c = shift->openapi->valid_input or return;

    my $params = $c->req->query_params->to_hash;

    if ($params->{code} && $params->{attribute}) {
        my $attribute_search = { code => $params->{code}, attribute => $params->{attribute} };
        my $found_attributes = Koha::Patron::Attributes->search($attribute_search);
        my @borrowernumbers = $found_attributes->get_column("borrowernumber");

        if (@borrowernumbers != 0) {
            my $patron_search->{"borrowernumber"} = [ @borrowernumbers ];
            my $matching_patrons = Koha::Patrons->search($patron_search);
            return $c->render(status => 200, openapi => $matching_patrons);
        }
        else {
            return $c->render(status => 200, openapi => []);
        }
    }
    else {
        return $c->render(status => 400, openapi => { error => "Missing 'code' or 'attribute' parameter" });
    }
}

sub add {
    my $c = shift->openapi->valid_input or return;

    my $body = $c->req->json;
    my $attribute_data = { borrowernumber => $body->{borrowernumber}, code => $body->{code}, attribute => $body->{attribute} };

    return try {
        my $attribute = Koha::Patron::Attribute->new($attribute_data)
            ->store;
        return $c->render(status => 201, openapi => $attribute);
    }
    catch {
        if ($_->isa('Koha::Exceptions::Patron::Attribute::NonRepeatable')) {
            return $c->render(status => 409, openapi => { error => $_->description });
        }

        if ($_->isa('Koha::Exceptions::Patron::Attribute::UniqueIDConstraint')) {
            return $c->render(status => 409, openapi => { error => $_->description });
        }
        #Koha::Exceptions::rethrow_exception($_);
        return $c->render(status => 500, openapi => { error => "Attribute not added: $@ $_" });
    };
}

1;
