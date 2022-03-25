use utf8;
package Koha::Schema::Result::ImportBatchProfile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ImportBatchProfile

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<import_batch_profiles>

=cut

__PACKAGE__->table("import_batch_profiles");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 matcher_id

  data_type: 'integer'
  is_nullable: 1

=head2 template_id

  data_type: 'integer'
  is_nullable: 1

=head2 overlay_action

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 nomatch_action

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 item_action

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 parse_items

  data_type: 'tinyint'
  is_nullable: 1

=head2 record_type

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 encoding

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 format

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 comments

  data_type: 'longtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "matcher_id",
  { data_type => "integer", is_nullable => 1 },
  "template_id",
  { data_type => "integer", is_nullable => 1 },
  "overlay_action",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "nomatch_action",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "item_action",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "parse_items",
  { data_type => "tinyint", is_nullable => 1 },
  "record_type",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "encoding",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "format",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "comments",
  { data_type => "longtext", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<u_import_batch_profiles__name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("u_import_batch_profiles__name", ["name"]);

=head1 RELATIONS

=head2 import_batches

Type: has_many

Related object: L<Koha::Schema::Result::ImportBatch>

=cut

__PACKAGE__->has_many(
  "import_batches",
  "Koha::Schema::Result::ImportBatch",
  { "foreign.profile_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K7QBaxwe5w0HB/WtH8VS9w


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->add_columns(
  '+parse_items' => { is_boolean => 1 },
);

=head2 koha_object_class

  Koha Object class

=cut

sub koha_object_class {
    'Koha::ImportBatchProfile';
}

=head2 koha_objects_class

  Koha Objects class

=cut

sub koha_objects_class {
    'Koha::ImportBatchProfiles';
}

1;
