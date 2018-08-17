use utf8;
package Koha::Schema::Result::ReportingLocationDim;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ReportingLocationDim

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reporting_location_dim>

=cut

__PACKAGE__->table("reporting_location_dim");

=head1 ACCESSORS

=head2 location_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 branch

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=head2 location

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=head2 location_type

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=head2 location_age

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=cut

__PACKAGE__->add_columns(
  "location_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "branch",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "location",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "location_type",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "location_age",
  { data_type => "varchar", is_nullable => 0, size => 30 },
);

=head1 PRIMARY KEY

=over 4

=item * L</location_id>

=back

=cut

__PACKAGE__->set_primary_key("location_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<branch>

=over 4

=item * L</branch>

=item * L</location>

=item * L</location_type>

=item * L</location_age>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "branch",
  ["branch", "location", "location_type", "location_age"],
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lInLw0/qyjwi5Cz7mW184w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
