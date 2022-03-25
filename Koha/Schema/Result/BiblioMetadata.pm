use utf8;
package Koha::Schema::Result::BiblioMetadata;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::BiblioMetadata

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<biblio_metadata>

=cut

__PACKAGE__->table("biblio_metadata");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 biblionumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 format

  data_type: 'varchar'
  is_nullable: 0
  size: 16

=head2 schema

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 metadata

  data_type: 'longtext'
  is_nullable: 0

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "biblionumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "format",
  { data_type => "varchar", is_nullable => 0, size => 16 },
  "schema",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "metadata",
  { data_type => "longtext", is_nullable => 0 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<biblio_metadata_uniq_key>

=over 4

=item * L</biblionumber>

=item * L</format>

=item * L</schema>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "biblio_metadata_uniq_key",
  ["biblionumber", "format", "schema"],
);

=head1 RELATIONS

=head2 biblionumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Biblio>

=cut

__PACKAGE__->belongs_to(
  "biblionumber",
  "Koha::Schema::Result::Biblio",
  { biblionumber => "biblionumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K4QzfBLfWYlgIWBrK+z3BQ

sub koha_object_class {
    'Koha::Biblio::Metadata';
}
sub koha_objects_class {
    'Koha::Biblio::Metadatas';
}

1;
