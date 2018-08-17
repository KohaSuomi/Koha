use utf8;
package Koha::Schema::Result::ReportingItemDim;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ReportingItemDim

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reporting_item_dim>

=cut

__PACKAGE__->table("reporting_item_dim");

=head1 ACCESSORS

=head2 item_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 itemnumber

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 biblioitemnumber

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 title

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 acquired_year

  data_type: 'integer'
  is_nullable: 1

=head2 published_year

  data_type: 'integer'
  is_nullable: 1

=head2 cn_class

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 cn_class_fict

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 cn_class_primary

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 cn_class_1_dec

  data_type: 'integer'
  is_nullable: 1

=head2 cn_class_2_dec

  data_type: 'integer'
  is_nullable: 1

=head2 cn_class_3_dec

  data_type: 'integer'
  is_nullable: 1

=head2 cn_class_signum

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 itemtype

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 itemtype_okm

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 is_yle

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 language

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 language_all

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 collection_code

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 barcode

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 datelastborrowed

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "item_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "itemnumber",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "biblioitemnumber",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "acquired_year",
  { data_type => "integer", is_nullable => 1 },
  "published_year",
  { data_type => "integer", is_nullable => 1 },
  "cn_class",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "cn_class_fict",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "cn_class_primary",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "cn_class_1_dec",
  { data_type => "integer", is_nullable => 1 },
  "cn_class_2_dec",
  { data_type => "integer", is_nullable => 1 },
  "cn_class_3_dec",
  { data_type => "integer", is_nullable => 1 },
  "cn_class_signum",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "itemtype",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "itemtype_okm",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "is_yle",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "language",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "language_all",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "collection_code",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "barcode",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "datelastborrowed",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</item_id>

=back

=cut

__PACKAGE__->set_primary_key("item_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<itemnumber>

=over 4

=item * L</itemnumber>

=back

=cut

__PACKAGE__->add_unique_constraint("itemnumber", ["itemnumber"]);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Jcj5UCufL81PV9sFedYRvw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
