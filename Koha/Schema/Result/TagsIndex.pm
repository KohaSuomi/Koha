use utf8;
package Koha::Schema::Result::TagsIndex;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::TagsIndex

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tags_index>

=cut

__PACKAGE__->table("tags_index");

=head1 ACCESSORS

=head2 term

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 191

=head2 biblionumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 weight

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "term",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 191 },
  "biblionumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "weight",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</term>

=item * L</biblionumber>

=back

=cut

__PACKAGE__->set_primary_key("term", "biblionumber");

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

=head2 term

Type: belongs_to

Related object: L<Koha::Schema::Result::TagsApproval>

=cut

__PACKAGE__->belongs_to(
  "term",
  "Koha::Schema::Result::TagsApproval",
  { term => "term" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GuZD9EZ/zaJjn6zaj8LkCg

sub koha_object_class {
    'Koha::Tags::Index';
}
sub koha_objects_class {
    'Koha::Tags::Indexes';
}

1;
