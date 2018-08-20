use utf8;
package Koha::Schema::Result::Accountoffset;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Accountoffset

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<accountoffsets>

=cut

__PACKAGE__->table("accountoffsets");

=head1 ACCESSORS

=head2 borrowernumber

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 accountno

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 offsetaccount

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 offsetamount

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: 'current_timestamp()'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "borrowernumber",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "accountno",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "offsetaccount",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "offsetamount",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => "current_timestamp()",
    is_nullable => 0,
  },
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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LdCmlyBilhmPjalB7NPuyQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
