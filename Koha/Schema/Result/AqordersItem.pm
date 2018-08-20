use utf8;
package Koha::Schema::Result::AqordersItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AqordersItem

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<aqorders_items>

=cut

__PACKAGE__->table("aqorders_items");

=head1 ACCESSORS

=head2 ordernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 itemnumber

  data_type: 'integer'
  is_nullable: 0

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: 'current_timestamp()'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "ordernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "itemnumber",
  { data_type => "integer", is_nullable => 0 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => "current_timestamp()",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</itemnumber>

=back

=cut

__PACKAGE__->set_primary_key("itemnumber");

=head1 RELATIONS

=head2 ordernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqorder>

=cut

__PACKAGE__->belongs_to(
  "ordernumber",
  "Koha::Schema::Result::Aqorder",
  { ordernumber => "ordernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2BDyMs50/6v0qLK/6Ygk0g


# You can replace this text with custom content, and it will be preserved on regeneration
1;
