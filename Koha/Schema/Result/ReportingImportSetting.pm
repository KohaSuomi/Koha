use utf8;
package Koha::Schema::Result::ReportingImportSetting;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ReportingImportSetting

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reporting_import_settings>

=cut

__PACKAGE__->table("reporting_import_settings");

=head1 ACCESSORS

=head2 primary_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 primary_column

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 last_inserted

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 last_selected

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 last_allowed_select

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 last_inserted_fact

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 batch_limit

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "primary_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "primary_column",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "last_inserted",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "last_selected",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "last_allowed_select",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "last_inserted_fact",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "batch_limit",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</primary_id>

=back

=cut

__PACKAGE__->set_primary_key("primary_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MVc+ARXR8AReg6HmVTrRFg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
