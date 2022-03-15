use utf8;
package Koha::Schema::Result::OkmStatistic;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OkmStatistic

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<okm_statistics>

=cut

__PACKAGE__->table("okm_statistics");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 startdate

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 enddate

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 individualbranches

  data_type: 'text'
  is_nullable: 1

=head2 okm_serialized

  data_type: 'longtext'
  is_nullable: 1

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "startdate",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "enddate",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "individualbranches",
  { data_type => "text", is_nullable => 1 },
  "okm_serialized",
  { data_type => "longtext", is_nullable => 1 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:UB44AIDNKCptJhpesayfgw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
