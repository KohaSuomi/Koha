use utf8;
package Koha::Schema::Result::AqbudgetsSpendLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AqbudgetsSpendLog

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aqbudgets_spend_log>

=cut

__PACKAGE__->table("aqbudgets_spend_log");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 monetary_amount

  data_type: 'decimal'
  is_nullable: 0
  size: [18,2]

=head2 timestamp

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 origin

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 fund

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 account

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 itemtype

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 copy_quantity

  data_type: 'integer'
  is_nullable: 1

=head2 total_amount

  data_type: 'decimal'
  is_nullable: 1
  size: [18,2]

=head2 location

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 collection

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 biblionumber

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "monetary_amount",
  { data_type => "decimal", is_nullable => 0, size => [18, 2] },
  "timestamp",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "origin",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "fund",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "account",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "itemtype",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "copy_quantity",
  { data_type => "integer", is_nullable => 1 },
  "total_amount",
  { data_type => "decimal", is_nullable => 1, size => [18, 2] },
  "location",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "collection",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "biblionumber",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:63L9xVKZBFQ8Kh1wVjEiDQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
