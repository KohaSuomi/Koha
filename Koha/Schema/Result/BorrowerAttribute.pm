use utf8;
package Koha::Schema::Result::BorrowerAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::BorrowerAttribute

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<borrower_attributes>

=cut

__PACKAGE__->table("borrower_attributes");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 code

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 10

=head2 attribute

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "code",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 10 },
  "attribute",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 code

Type: belongs_to

Related object: L<Koha::Schema::Result::BorrowerAttributeType>

=cut

__PACKAGE__->belongs_to(
  "code",
  "Koha::Schema::Result::BorrowerAttributeType",
  { code => "code" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FcCJ2d6J86OW7q+Rk/dQ2g

=head2 borrower_attribute_types

Type: belongs_to

Related object: L<Koha::Schema::Result::BorrowerAttributeType>

=cut

__PACKAGE__->belongs_to(
    "borrower_attribute_types",
    "Koha::Schema::Result::BorrowerAttributeType",
    { "foreign.code" => "self.code" },
    { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },);


sub koha_object_class {
    'Koha::Patron::Attribute';
}
sub koha_objects_class {
    'Koha::Patron::Attributes';
}

1;
