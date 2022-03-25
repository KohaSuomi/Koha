use utf8;
package Koha::Schema::Result::AuthorisedValueCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AuthorisedValueCategory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<authorised_value_categories>

=cut

__PACKAGE__->table("authorised_value_categories");

=head1 ACCESSORS

=head2 category_name

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 is_system

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "category_name",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "is_system",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</category_name>

=back

=cut

__PACKAGE__->set_primary_key("category_name");

=head1 RELATIONS

=head2 authorised_values

Type: has_many

Related object: L<Koha::Schema::Result::AuthorisedValue>

=cut

__PACKAGE__->has_many(
  "authorised_values",
  "Koha::Schema::Result::AuthorisedValue",
  { "foreign.category" => "self.category_name" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 items_search_fields

Type: has_many

Related object: L<Koha::Schema::Result::ItemsSearchField>

=cut

__PACKAGE__->has_many(
  "items_search_fields",
  "Koha::Schema::Result::ItemsSearchField",
  { "foreign.authorised_values_category" => "self.category_name" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 marc_subfield_structures

Type: has_many

Related object: L<Koha::Schema::Result::MarcSubfieldStructure>

=cut

__PACKAGE__->has_many(
  "marc_subfield_structures",
  "Koha::Schema::Result::MarcSubfieldStructure",
  { "foreign.authorised_value" => "self.category_name" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Mq6bwLGZAZVV8hHTitHLXg

__PACKAGE__->add_columns(
    '+is_system' => { is_boolean => 1 },
);

sub koha_objects_class {
    'Koha::AuthorisedValueCategories';
}

1;
