use utf8;
package Koha::Schema::Result::BorrowerSsBlock;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::BorrowerSsBlock

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<borrower_ss_blocks>

=cut

__PACKAGE__->table("borrower_ss_blocks");

=head1 ACCESSORS

=head2 borrower_ss_block_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 branchcode

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 expirationdate

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 notes

  data_type: 'mediumtext'
  is_nullable: 1

=head2 created_by

  data_type: 'integer'
  is_nullable: 0

=head2 created_on

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: 'current_timestamp()'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "borrower_ss_block_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "branchcode",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "expirationdate",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "notes",
  { data_type => "mediumtext", is_nullable => 1 },
  "created_by",
  { data_type => "integer", is_nullable => 0 },
  "created_on",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    default_value => "current_timestamp()",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</borrower_ss_block_id>

=back

=cut

__PACKAGE__->set_primary_key("borrower_ss_block_id");

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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kT1mXEQas/Pj5StbArxzkQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
