package Koha::REST::V1::Auth;

# Copyright Koha-Suomi Oy 2017
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

use Mojo::Base 'Mojolicious::Controller';

use CGI;

use C4::Auth qw( check_cookie_auth get_session haspermission );

use Koha::Account::Lines;
use Koha::Checkouts;
use Koha::Holds;
use Koha::Old::Checkouts;
use Koha::Patrons;

use Koha::Exceptions;
use Koha::Exceptions::Authentication;
use Koha::Exceptions::Authorization;

use Scalar::Util qw( blessed );
use Try::Tiny;

=head1 NAME

Koha::REST::V1::Auth

=head2 Operations

=head3 under

This subroutine is called before every request to API.

=cut

sub under {
    my $c = shift->openapi->valid_input or return;;

    my $status = 0;
    try {

        $status = authenticate_api_request($c);

    } catch {
        unless (blessed($_)) {
            return $c->render(
                status => 500,
                json => { error => 'Something went wrong, check the logs.' }
            );
        }
        if ($_->isa('Koha::Exceptions::UnderMaintenance')) {
            return $c->render(status => 503, json => { error => $_->error });
        }
        elsif ($_->isa('Koha::Exceptions::Authentication::SessionExpired')) {
            return $c->render(status => 401, json => { error => $_->error });
        }
        elsif ($_->isa('Koha::Exceptions::Authentication::Required')) {
            return $c->render(status => 401, json => { error => $_->error });
        }
        elsif ($_->isa('Koha::Exceptions::Authentication')) {
            return $c->render(status => 500, json => { error => $_->error });
        }
        elsif ($_->isa('Koha::Exceptions::BadParameter')) {
            return $c->render(status => 400, json => $_->error );
        }
        elsif ($_->isa('Koha::Exceptions::Authorization::Unauthorized')) {
            return $c->render(status => 403, json => {
                error => $_->error,
                required_permissions => $_->required_permissions,
            });
        }
        elsif ($_->isa('Koha::Exceptions')) {
            return $c->render(status => 500, json => { error => $_->error });
        }
        else {
            return $c->render(
                status => 500,
                json => { error => 'Something went wrong, check the logs.' }
            );
        }
    };

    return $status;
}

sub login {
    my ($c, $args, $cb) = @_;

    my $userid = $args->{userid} || $args->{cardnumber};
    my $password = $args->{password};
    my $patron;

    return $c->$cb({ error => "Either userid or cardnumber is required "
                             ."- neither given." }, 403) unless ($userid);

    my $cgi = CGI->new;
    $cgi->param(userid => $userid);
    $cgi->param(password => $password);
    my ($status, $cookie, $sessionid) = C4::Auth::check_api_auth($cgi);

    return $c->$cb({ error => "Login failed." }, 401) if $status eq "failed";
    return $c->$cb({ error => "Session expired." }, 401) if $status eq "expired";
    return $c->$cb({ error => "Database is under maintenance." }, 401) if $status eq "maintenance";
    return $c->$cb({ error => "Login failed." }, 401) unless $status eq "ok";

    $patron = Koha::Patrons->find({ userid => $userid }) unless $patron;
    $patron = Koha::Patrons->find({ cardnumber => $userid }) unless $patron;

    my $session = _swaggerize_session($sessionid, $patron);

    $c->cookie(CGISESSID => $sessionid, { path => "/" });

    return $c->$cb($session, 201);
}

sub logout {
    my ($c, $args, $cb) = @_;

    my $sessionid = $args->{session}->{sessionid};
    $sessionid = $c->cookie('CGISESSID') unless $sessionid;

    my ($status, $sid) = C4::Auth::check_cookie_auth($sessionid);
    unless ($status eq "ok") {
        return $c->$cb({ error => "Invalid session id."}, 401);
    }

    $c->cookie(CGISESSID => $sessionid, { path => "/", expires => 1 });

    my $session = C4::Auth::get_session($sessionid);
    $session->delete;
    $session->flush;
    return $c->$cb({}, 200);
}

sub _swaggerize_session {
    my ($sessionid, $patron) = @_;

    return unless ref($patron) eq 'Koha::Patron';

    my $rawPermissions = C4::Auth::haspermission($patron->userid); # defaults to all permissions
    my @permissions;

    # delete all empty permissions
    while ( my ($key, $val) = each %{$rawPermissions} ) {
        push @permissions, $key if $val;
    }

    return {
        borrowernumber => $patron->borrowernumber,
        firstname => $patron->firstname,
        surname  => $patron->surname,
        email     => $patron->email,
        sessionid => $sessionid,
	permissions => \@permissions,
    };
}

=head3 authenticate_api_request

Validates authentication and allows access if authorization is not required or
if authorization is required and user has required permissions to access.

=cut

sub authenticate_api_request {
    my ( $c ) = @_;

    my $spec = $c->match->endpoint->pattern->defaults->{'openapi.op_spec'};
    my $authorization = $spec->{'x-koha-authorization'};
    my $cookie = $c->cookie('CGISESSID');
    my ($session, $user);
    # Mojo doesn't use %ENV the way CGI apps do
    # Manually pass the remote_address to check_auth_cookie
    my $remote_addr = $c->tx->remote_address;
    my ($status, $sessionID) = check_cookie_auth(
                                            $cookie, undef,
                                            { remote_addr => $remote_addr });
    if ($status eq "ok") {
        $session = get_session($sessionID);
        $user = Koha::Patrons->find($session->param('number'));
        $c->stash('koha.user' => $user);
    }
    elsif ($status eq "maintenance") {
        Koha::Exceptions::UnderMaintenance->throw(
            error => 'System is under maintenance.'
        );
    }
    elsif ($status eq "expired" and $authorization) {
        Koha::Exceptions::Authentication::SessionExpired->throw(
            error => 'Session has been expired.'
        );
    }
    elsif ($status eq "failed" and $authorization) {
        Koha::Exceptions::Authentication::Required->throw(
            error => 'Authentication failure.'
        );
    }
    elsif ($authorization) {
        Koha::Exceptions::Authentication->throw(
            error => 'Unexpected authentication status.'
        );
    }

    # We do not need any authorization
    unless ($authorization) {
        # Check the parameters
        validate_query_parameters( $c, $spec );
        return 1;
    }

    my $permissions = $authorization->{'permissions'};
    # Check if the user is authorized
    my ($owner_access, $guarantor_access);
    if ( haspermission($user->userid, $permissions)
        or $owner_access = allow_owner($c, $authorization, $user)
        or $guarantor_access = allow_guarantor($c, $authorization, $user) ) {

        validate_query_parameters( $c, $spec );

        # Store information on owner/guarantor access
        $c->stash('is_owner_access', 1) if $owner_access;
        $c->stash('is_guarantor_access', 1) if $guarantor_access;

        # Everything is ok
        return 1;
    }

    Koha::Exceptions::Authorization::Unauthorized->throw(
        error => "Authorization failure. Missing required permission(s).",
        required_permissions => $permissions,
    );
}
sub validate_query_parameters {
    my ( $c, $action_spec ) = @_;

    # Check for malformed query parameters
    my @errors;
    my %valid_parameters = map { ( $_->{in} eq 'query' ) ? ( $_->{name} => 1 ) : () } @{ $action_spec->{parameters} };
    my $existing_params = $c->req->query_params->to_hash;
    for my $param ( keys %{$existing_params} ) {
        push @errors, { path => "/query/" . $param, message => 'Malformed query string' } unless exists $valid_parameters{$param};
    }

    Koha::Exceptions::BadParameter->throw(
        error => \@errors
    ) if @errors;
}


=head3 allow_owner

Allows access to object for its owner.

There are endpoints that should allow access for the object owner even if they
do not have the required permission, e.g. access an own reserve. This can be
achieved by defining the operation as follows:

"/holds/{reserve_id}": {
    "get": {
        ...,
        "x-koha-authorization": {
            "allow-owner": true,
            "permissions": {
                "borrowers": "1"
            }
        }
    }
}

=cut

sub allow_owner {
    my ($c, $authorization, $user) = @_;

    return unless $authorization->{'allow-owner'};

    return check_object_ownership($c, $user) if $user and $c;
}

=head3 allow_guarantor

Same as "allow_owner", but checks if the object is owned by one of C<$user>'s
guarantees.

=cut

sub allow_guarantor {
    my ($c, $authorization, $user) = @_;

    if (!$c || !$user || !$authorization || !$authorization->{'allow-guarantor'}){
        return;
    }

    my $guarantees = $user->guarantees->as_list;
    foreach my $guarantee (@{$guarantees}) {
        return 1 if check_object_ownership($c, $guarantee);
    }
}

=head3 check_object_ownership

Determines ownership of an object from request parameters.

As introducing an endpoint that allows access for object's owner; if the
parameter that will be used to determine ownership is not already inside
$parameters, add a new subroutine that checks the ownership and extend
$parameters to contain a key with parameter_name and a value of a subref to
the subroutine that you created.

=cut

sub check_object_ownership {
    my ($c, $user) = @_;

    return if not $c or not $user;

    my $parameters = {
        accountlines_id => \&_object_ownership_by_accountlines_id,
        borrowernumber  => \&_object_ownership_by_borrowernumber,
        checkout_id     => \&_object_ownership_by_checkout_id,
        reserve_id      => \&_object_ownership_by_reserve_id,
    };

    foreach my $param ( keys %{ $parameters } ) {
        my $check_ownership = $parameters->{$param};
        if ($c->stash($param)) {
            return &$check_ownership($c, $user, $c->stash($param));
        }
        elsif ($c->param($param)) {
            return &$check_ownership($c, $user, $c->param($param));
        }
        elsif ($c->match->stack->[-1]->{$param}) {
            return &$check_ownership($c, $user, $c->match->stack->[-1]->{$param});
        }
        elsif ($c->req->json && $c->req->json->{$param}) {
            return 1 if &$check_ownership($c, $user, $c->req->json->{$param});
        }
    }
}

=head3 _object_ownership_by_accountlines_id

Finds a Koha::Account::Line-object by C<$accountlines_id> and checks if it
belongs to C<$user>.

=cut

sub _object_ownership_by_accountlines_id {
    my ($c, $user, $accountlines_id) = @_;

    my $accountline = Koha::Account::Lines->find($accountlines_id);
    return $accountline && $user->borrowernumber == $accountline->borrowernumber;
}

=head3 _object_ownership_by_borrowernumber

Compares C<$borrowernumber> to currently logged in C<$user>.

=cut

sub _object_ownership_by_borrowernumber {
    my ($c, $user, $borrowernumber) = @_;

    return $user->borrowernumber == $borrowernumber;
}

=head3 _object_ownership_by_checkout_id

First, attempts to find a Koha::Checkout-object by C<$issue_id>. If we find one,
compare its borrowernumber to currently logged in C<$user>. However, if an issue
is not found, attempt to find a Koha::Old::Checkout-object instead and compare its
borrowernumber to currently logged in C<$user>.

=cut

sub _object_ownership_by_checkout_id {
    my ($c, $user, $issue_id) = @_;

    my $issue = Koha::Checkouts->find($issue_id);
    $issue = Koha::Old::Checkouts->find($issue_id) unless $issue;
    return $issue && $issue->borrowernumber
            && $user->borrowernumber == $issue->borrowernumber;
}

=head3 _object_ownership_by_reserve_id

Finds a Koha::Hold-object by C<$reserve_id> and checks if it
belongs to C<$user>.

TODO: Also compare against old_reserves

=cut

sub _object_ownership_by_reserve_id {
    my ($c, $user, $reserve_id) = @_;

    my $reserve = Koha::Holds->find($reserve_id);
    return $reserve && $user->borrowernumber == $reserve->borrowernumber;
}

1;
