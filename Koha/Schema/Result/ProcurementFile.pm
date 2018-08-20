use utf8;
package Koha::Schema::Result::ProcurementFile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ProcurementFile

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<procurement_file>

=cut

__PACKAGE__->table("procurement_file");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 file_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 file_hash

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "file_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "file_hash",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</file_id>

=back

=cut

__PACKAGE__->set_primary_key("file_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<ix_procurement_file_file_name_file_hash>

=over 4

=item * L</file_name>

=item * L</file_hash>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "ix_procurement_file_file_name_file_hash",
  ["file_name", "file_hash"],
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LGsxrwPeA6NITo2VbbS2sw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
