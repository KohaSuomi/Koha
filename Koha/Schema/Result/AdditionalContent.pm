use utf8;
package Koha::Schema::Result::AdditionalContent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AdditionalContent

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<additional_contents>

=cut

__PACKAGE__->table("additional_contents");

=head1 ACCESSORS

=head2 idnew

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 category

  data_type: 'varchar'
  is_nullable: 0
  size: 20

category for the additional content

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 location

  data_type: 'varchar'
  is_nullable: 0
  size: 255

location of the additional content

=head2 branchcode

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

=head2 title

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 250

=head2 content

  data_type: 'mediumtext'
  is_nullable: 0

=head2 lang

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 50

=head2 published_on

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 updated_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 expirationdate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 number

  data_type: 'integer'
  is_nullable: 1

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "idnew",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "category",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "location",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "branchcode",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "title",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 250 },
  "content",
  { data_type => "mediumtext", is_nullable => 0 },
  "lang",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
  "published_on",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "updated_on",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "expirationdate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "number",
  { data_type => "integer", is_nullable => 1 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</idnew>

=back

=cut

__PACKAGE__->set_primary_key("idnew");

=head1 UNIQUE CONSTRAINTS

=head2 C<additional_contents_uniq>

=over 4

=item * L</category>

=item * L</code>

=item * L</branchcode>

=item * L</lang>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "additional_contents_uniq",
  ["category", "code", "branchcode", "lang"],
);

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "CASCADE",
  },
);

=head2 branchcode

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "branchcode",
  "Koha::Schema::Result::Branch",
  { branchcode => "branchcode" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BGAjEm1bufuBsVTzwmeXuQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
