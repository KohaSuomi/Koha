package Koha::REST::V1::Borrower;

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
use Mojo::JSON;

use C4::Members;

use Koha::Auth::Challenge::Password;

use Scalar::Util qw( blessed );
use Try::Tiny;
use C4::SelfService;

# NOTE
#
# This controller is for Koha-Suomi 3.16 ported operations. For new patron related
# endpoints, use /api/v1/patrons and Koha::REST::V1::Patron controller instead
sub status {
    my $c = shift->openapi->valid_input or return;

    my $username = $c->validation->param('uname');
    my $password = $c->validation->param('passwd');
    my ($borrower, $error);
    return try {

        $borrower = Koha::Auth::Challenge::Password::challenge(
                $username,
                $password
        );

        my $kp = GetMember(userid=>$borrower->userid);
        my $flags = C4::Members::patronflags( $kp );
        my $fines_amount = $flags->{CHARGES}->{amount};
        my $fines_amount = ($fines_amount and $fines_amount > 0) ? $fines_amount : 0;
        my $fee_limit = C4::Context->preference('noissuescharge') || 5;
        my $fine_blocked = $fines_amount > $fee_limit;
        my $card_lost = $kp->{lost} || $kp->{gonenoaddress} || $flags->{LOST};
        my $basic_privileges_ok = !$borrower->is_debarred && !$borrower->is_expired && !$fine_blocked;

        for (qw(EXPIRED CHARGES CREDITS GNA LOST DBARRED NOTES)) {
                ($flags->{$_}) or next;
                if ($flags->{$_}->{noissues}) {
                        my $basic_privileges_ok = 0;
                }
        }

        my $payload = {
            borrowernumber => 0+$borrower->borrowernumber,
            cardnumber     => $borrower->cardnumber || '',
            surname        => $borrower->surname || '',
            firstname      => $borrower->firstname || '',
            homebranch     => $borrower->branchcode || '',
            age            => $borrower->get_age || '',
            fines          => $fines_amount+0,
            language       => 'fin' || '',
            charge_privileges_denied    => _bool(!$basic_privileges_ok),
            renewal_privileges_denied   => _bool(!$basic_privileges_ok),
            recall_privileges_denied    => _bool(!$basic_privileges_ok),
            hold_privileges_denied      => _bool(!$basic_privileges_ok),
            card_reported_lost          => _bool($card_lost),
            too_many_items_charged      => _bool(0),
            too_many_items_overdue      => _bool(0),
            too_many_renewals           => _bool(0),
            too_many_claims_of_items_returned => _bool(0),
            too_many_items_lost         => _bool(0),
            excessive_outstanding_fines => _bool($fine_blocked),
            recall_overdue              => _bool(0),
            too_many_items_billed       => _bool(0),
        };
        return $c->render( status => 200, openapi => $payload );
    } catch {
        if (blessed($_)){
            if ($_->isa('Koha::Exception::LoginFailed')) {
                return $c->render( status => 400, openapi => { error => $_->error } );
            }
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

sub get_self_service_status {
    my $c = shift->openapi->valid_input or return;

    my $payload;
    try {
        my $patron = Koha::Patrons->cast($c->validation->param('cardnumber'));
        my $branchcode = $c->validation->param('branchcode');
        C4::SelfService::CheckSelfServicePermission($patron, $branchcode, 'accessMainDoor');
        #If we didn't get any exceptions, we succeeded
        $payload = {permission => Mojo::JSON->true};
        return $c->render(status => 200, openapi => $payload);

    } catch {
        if (not(blessed($_) && $_->can('rethrow'))) {
            return $c->render( status => 500, openapi => { error => "$_" } );
        }
        elsif ($_->isa('Koha::Exception::UnknownObject')) {
            return $c->render( status => 404, openapi => { error => "No such cardnumber" } );
        }
        elsif ($_->isa('Koha::Exception::SelfService::OpeningHours')) {
            $payload = {
                permission => Mojo::JSON->false,
                error => ref($_),
                startTime => $_->startTime,
                endTime => $_->endTime,
            };
            return $c->render( status => 200, openapi => $payload );
        }
        elsif ($_->isa('Koha::Exception::SelfService')) {
            $payload = {
                permission => Mojo::JSON->false,
                error => ref($_),
            };
            return $c->render( status => 200, openapi => $payload );
        }
        elsif ($_->isa('Koha::Exception::FeatureUnavailable')) {
            return $c->render( status => 501, openapi => { error => "$_" } );
        }
        else {
            return $c->render( status => 501, openapi => { error => $_->trace->as_string } );
        }
    };
}

sub _bool {
    return $_[0] ? Mojo::JSON->true : Mojo::JSON->false;
}

1;
