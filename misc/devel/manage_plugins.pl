#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2019 Koha Development Team
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
use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );

use C4::Context;
use Koha::Plugins;
use Koha::Plugins::Handler;

my $method = "list";
my $class;
my ($help);
GetOptions( 'help|?' => \$help,
            'enable=s' => sub { $method = "enable"; $class = $_[1]; },
            'disable=s' => sub { $method = "disable"; $class = $_[1]; },
    );

pod2usage(1) if $help;

unless ( C4::Context->config("enable_plugins") ) {
    print
"The plugin system must be enabled for one to be able to manage plugins\n";
    exit 1;
}

if ($method eq "enable" || $method eq "disable") {
    Koha::Plugins::Handler->run({
        class => $class,
        method => $method
    });
}

my @plugins = Koha::Plugins->new()->GetPlugins(
    {
        method => undef,
        all    => 1,
        errors => 1
    }
    );

foreach my $plugin (@plugins) {
    print ($plugin->is_enabled ? "Enabled " : "Disabled");
    print "  ".$plugin->{class};
    print "\n";
}

=head1 NAME

manage_plugins.pl - list, disable or enable plugins

=head1 SYNOPSIS

 manage_plugins.pl

Options:
  -?|--help        brief help message
  --enable         enable a plugin
  --disable        disable a plugin

=head1 OPTIONS

=over 8

=item B<--help|-?>

Print a brief help message and exits

=item B<--enable>

Enables the plugin given as a parameter

=item B<--disable>

Disables the plugin given as a parameter

=back

=head1 DESCRIPTION

A simple script to manage plugins from the command line

=cut
