use utf8;
package Koha::Schema::Result::ReportingBorrowerDim;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ReportingBorrowerDim

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reporting_borrower_dim>

=cut

__PACKAGE__->table("reporting_borrower_dim");

=head1 ACCESSORS

=head2 borrower_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 borrowernumber

  data_type: 'integer'
  is_nullable: 0

=head2 categorycode

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 cardnumber

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 age_group

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 postcode

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=cut

__PACKAGE__->add_columns(
  "borrower_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "borrowernumber",
  { data_type => "integer", is_nullable => 0 },
  "categorycode",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "cardnumber",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "age_group",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "postcode",
  { data_type => "varchar", is_nullable => 1, size => 30 },
);

=head1 PRIMARY KEY

=over 4

=item * L</borrower_id>

=back

=cut

__PACKAGE__->set_primary_key("borrower_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<borrowernumber>

=over 4

=item * L</borrowernumber>

=back

=cut

__PACKAGE__->add_unique_constraint("borrowernumber", ["borrowernumber"]);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pNbQRi2Nlx4CWh1k3pUJQw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
