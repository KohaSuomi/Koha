package Koha::Patron::AllData;

# Copyright 2018 Koha-Suomi Oy
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

use Modern::Perl;

use Carp;

use C4::Context;

use Koha::Database;
use Koha::Patrons;
use Koha::Checkouts;
use Koha::Old::Checkouts;
use Koha::Holds;
use Koha::Old::Holds;
use Koha::Account::Lines;
use Koha::Patron::Messages;
use Koha::Suggestions;
use Koha::MessageQueues;


=head1 NAME

Koha::Patron::AllData - Module for managing patron AllData

=head1 METHODS

=over

=cut

sub getall {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{personal} = Koha::Patrons->find($borrowernumber)->unblessed;
    $jsonObject->{checkouts} = Koha::Checkouts->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{oldcheckouts} = Koha::Old::Checkouts->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{holds} = Koha::Holds->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{oldholds} = Koha::Old::Holds->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{accountlines} = Koha::Account::Lines->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{notices} = Koha::MessageQueues->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{messages} = Koha::Patron::Messages->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{debarments} = Koha::Patron::Debarments::GetDebarments({ borrowernumber => $borrowernumber});
    $jsonObject->{suggestions} = Koha::Suggestions->search({suggestedby => $borrowernumber})->unblessed;

    return $jsonObject;
}

sub getpersonal {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{personal} = Koha::Patrons->find($borrowernumber)->unblessed;

    return $jsonObject;
}

sub getcheckouts {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{checkouts} = Koha::Checkouts->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{oldcheckouts} = Koha::Old::Checkouts->search({borrowernumber => $borrowernumber})->unblessed;

    return $jsonObject;
}

sub getholds {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{holds} = Koha::Holds->search({borrowernumber => $borrowernumber})->unblessed;
    $jsonObject->{oldholds} = Koha::Old::Holds->search({borrowernumber => $borrowernumber})->unblessed;
    
    return $jsonObject;
}

sub getaccountlines {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{accountlines} = Koha::Account::Lines->search({borrowernumber => $borrowernumber})->unblessed;
    
    return $jsonObject;
}

sub getnotices {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{notices} = Koha::MessageQueues->search({borrowernumber => $borrowernumber})->unblessed;
    
    return $jsonObject;
}

sub getmessages {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{messages} = Koha::Patron::Messages->search({borrowernumber => $borrowernumber})->unblessed;
    
    return $jsonObject;
}

sub getdebarments {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{debarments} = Koha::Patron::Debarments::GetDebarments({ borrowernumber => $borrowernumber});
    
    return $jsonObject;
}

sub getsuggestions {
    my ($class, $params) = @_;
    my $self = bless( {}, $class );

    return unless $params->{'borrowernumber'};

    my $borrowernumber = $params->{'borrowernumber'};
    my $jsonObject;

    $jsonObject->{suggestions} = Koha::Suggestions->search({suggestedby => $borrowernumber})->unblessed;
    
    return $jsonObject;
}

1;