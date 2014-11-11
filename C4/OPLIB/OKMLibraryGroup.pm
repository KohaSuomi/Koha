package C4::OPLIB::OKMLibraryGroup;

# Copyright KohaSuomi
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
use Carp;

use C4::OPLIB::OKMGroupStatistics;

sub new {
    my ($class, $categoryGroupCode, $branches) = @_;

    croak '$branches parameter is not a HASH of {branchcode => 1, ...}!' unless (ref $branches eq 'HASH');

    my $self = {};
    bless($self, $class);

    $self->addStatistics( C4::OPLIB::OKMGroupStatistics->new() );
    my $stats = $self->getStatistics();
    $stats->{branchCategory} = $categoryGroupCode;
    $self->{branchCategory} = $categoryGroupCode;

    foreach my $branchcode (sort keys %$branches) {
        $self->addBranch($branchcode);
    }

    return $self;
}


=head getBranchcodesWhereClause

    my ($where, $bind) = $groupStatistics->getBranchcodesWhereClause('homebranch', 'items');
    $where eq "items.homebranch = ? OR items.homebranch = ? OR ...";

    my ($where, $bind) = $groupStatistics->getBranchcodesWhereClause('homebranch');
    $where eq "homebranch = ? OR homebranch = ? OR ...";

    $sth = $dbh->prepare("SELECT * FROM items WHERE $where");
    $sth->execute(@$bind);

Gets the SQL to limit the results to this groups material.

@PARAM1, DB column
@PARAM2, DB table
@RETURNS, String, meant to be appended after a WHERE-clause and the @bind-variables for the prepared statement
=cut

sub getBranchcodesWhereClause {
    my ($self, $column, $table) = @_;

    my $target;
    croak '$column must be defined!' unless $column;
    if ($table) {
        $target = $table.'.'.$column;
    }
    else {
        $target = $column;
    }

    my @sb;
    my @bind;
    foreach my $branchcode (sort keys %{$self->{branches}}) {
        push @sb, "$target = ?";
        push @bind, $branchcode;
    }
    return (join(' OR ', @sb), \@bind);
}

=head getBranchcodesWhereClause

    my $in_sql = $groupStatistics->getBranchcodesINClause();
    $in_sql eq "IN ('JOE_JOE', 'JOE_LIP', 'JOE_KON')";

    $sth = $dbh->prepare("SELECT * FROM items WHERE homebranch $in_sql");
    $sth->execute(@$bind);

Gets the SQL to limit the results to this groups material.

@RETURNS, String, meant to be appended after a WHERE-clause.
=cut

sub getBranchcodesINClause {
    my ($self) = @_;

    my @sb;
    foreach my $branchcode (sort keys %{$self->{branches}}) {
        push @sb, "'".$branchcode."'";
    }
    return ' IN ('.join(', ', @sb).')';
}

sub addBranch {
    my ($self, $branchcode) = @_;

    $self->{branches}->{$branchcode} = {};
}
sub getBranchesWithKeys {
    my $self = shift;
    my @keys = keys %{$self->{branches}};
    return ($self->{branches}, \@keys);
}

sub addStatistics {
    my ($self, $groupStatistics) = @_;
    $self->{statistics} = $groupStatistics;
}
sub getStatistics {
    my $self = shift;
    return $self->{statistics};
}

1;