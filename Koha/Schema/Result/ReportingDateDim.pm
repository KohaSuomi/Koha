use utf8;
package Koha::Schema::Result::ReportingDateDim;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ReportingDateDim

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reporting_date_dim>

=cut

__PACKAGE__->table("reporting_date_dim");

=head1 ACCESSORS

=head2 date_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 year

  data_type: 'integer'
  is_nullable: 0

=head2 month

  data_type: 'integer'
  is_nullable: 0

=head2 day

  data_type: 'integer'
  is_nullable: 0

=head2 hour

  data_type: 'integer'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "date_id",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "year",
  { data_type => "integer", is_nullable => 0 },
  "month",
  { data_type => "integer", is_nullable => 0 },
  "day",
  { data_type => "integer", is_nullable => 0 },
  "hour",
  { data_type => "integer", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</date_id>

=back

=cut

__PACKAGE__->set_primary_key("date_id");


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BJN9GKDkJAqYKQFaIqChTA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
