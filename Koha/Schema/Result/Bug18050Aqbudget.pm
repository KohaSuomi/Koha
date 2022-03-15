use utf8;
package Koha::Schema::Result::Bug18050Aqbudget;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Bug18050Aqbudget

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<_bug_18050_aqbudgets>

=cut

__PACKAGE__->table("_bug_18050_aqbudgets");

=head1 ACCESSORS

=head2 budget_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 budget_parent_id

  data_type: 'integer'
  is_nullable: 1

=head2 budget_code

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 budget_name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 budget_branchcode

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 budget_amount

  data_type: 'decimal'
  default_value: 0.000000
  is_nullable: 1
  size: [28,6]

=head2 budget_encumb

  data_type: 'decimal'
  default_value: 0.000000
  is_nullable: 1
  size: [28,6]

=head2 budget_expend

  data_type: 'decimal'
  default_value: 0.000000
  is_nullable: 1
  size: [28,6]

=head2 budget_notes

  data_type: 'longtext'
  is_nullable: 1

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=head2 budget_period_id

  data_type: 'integer'
  is_nullable: 1

=head2 sort1_authcat

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 sort2_authcat

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 budget_owner_id

  data_type: 'integer'
  is_nullable: 1

=head2 budget_permission

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "budget_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "budget_parent_id",
  { data_type => "integer", is_nullable => 1 },
  "budget_code",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "budget_name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "budget_branchcode",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "budget_amount",
  {
    data_type => "decimal",
    default_value => "0.000000",
    is_nullable => 1,
    size => [28, 6],
  },
  "budget_encumb",
  {
    data_type => "decimal",
    default_value => "0.000000",
    is_nullable => 1,
    size => [28, 6],
  },
  "budget_expend",
  {
    data_type => "decimal",
    default_value => "0.000000",
    is_nullable => 1,
    size => [28, 6],
  },
  "budget_notes",
  { data_type => "longtext", is_nullable => 1 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
  "budget_period_id",
  { data_type => "integer", is_nullable => 1 },
  "sort1_authcat",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "sort2_authcat",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "budget_owner_id",
  { data_type => "integer", is_nullable => 1 },
  "budget_permission",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wENIVkQ25oVYpn/ZcZzAmQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
