use utf8;
package Koha::Schema::Result::ReportingItemsFact;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ReportingItemsFact

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reporting_items_fact>

=cut

__PACKAGE__->table("reporting_items_fact");

=head1 ACCESSORS

=head2 primary_key

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 date_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 item_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 location_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 is_deleted

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 amount

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "primary_key",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "date_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "item_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "location_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "is_deleted",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "amount",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</primary_key>

=back

=cut

__PACKAGE__->set_primary_key("primary_key");


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EP/00EIc3jplgVLG6zSUpQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
