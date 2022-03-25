use utf8;
package Koha::Schema::Result::Itemtype;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Itemtype

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<itemtypes>

=cut

__PACKAGE__->table("itemtypes");

=head1 ACCESSORS

=head2 itemtype

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 parent_type

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

=head2 description

  data_type: 'longtext'
  is_nullable: 1

=head2 rentalcharge

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 rentalcharge_daily

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 rentalcharge_daily_calendar

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 rentalcharge_hourly

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 rentalcharge_hourly_calendar

  data_type: 'tinyint'
  default_value: 1
  is_nullable: 0

=head2 defaultreplacecost

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 processfee

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 notforloan

  data_type: 'smallint'
  is_nullable: 1

=head2 imageurl

  data_type: 'varchar'
  is_nullable: 1
  size: 200

=head2 summary

  data_type: 'mediumtext'
  is_nullable: 1

=head2 checkinmsg

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 checkinmsgtype

  data_type: 'char'
  default_value: 'message'
  is_nullable: 0
  size: 16

=head2 sip_media_type

  data_type: 'varchar'
  is_nullable: 1
  size: 3

=head2 hideinopac

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 searchcategory

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 automatic_checkin

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

If automatic checkin is enabled for items of this type

=cut

__PACKAGE__->add_columns(
  "itemtype",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "parent_type",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
  "description",
  { data_type => "longtext", is_nullable => 1 },
  "rentalcharge",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "rentalcharge_daily",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "rentalcharge_daily_calendar",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "rentalcharge_hourly",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "rentalcharge_hourly_calendar",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "defaultreplacecost",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "processfee",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "notforloan",
  { data_type => "smallint", is_nullable => 1 },
  "imageurl",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "summary",
  { data_type => "mediumtext", is_nullable => 1 },
  "checkinmsg",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "checkinmsgtype",
  {
    data_type => "char",
    default_value => "message",
    is_nullable => 0,
    size => 16,
  },
  "sip_media_type",
  { data_type => "varchar", is_nullable => 1, size => 3 },
  "hideinopac",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "searchcategory",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "automatic_checkin",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</itemtype>

=back

=cut

__PACKAGE__->set_primary_key("itemtype");

=head1 RELATIONS

=head2 circulation_rules

Type: has_many

Related object: L<Koha::Schema::Result::CirculationRule>

=cut

__PACKAGE__->has_many(
  "circulation_rules",
  "Koha::Schema::Result::CirculationRule",
  { "foreign.itemtype" => "self.itemtype" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 itemtypes

Type: has_many

Related object: L<Koha::Schema::Result::Itemtype>

=cut

__PACKAGE__->has_many(
  "itemtypes",
  "Koha::Schema::Result::Itemtype",
  { "foreign.parent_type" => "self.itemtype" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 itemtypes_branches

Type: has_many

Related object: L<Koha::Schema::Result::ItemtypesBranch>

=cut

__PACKAGE__->has_many(
  "itemtypes_branches",
  "Koha::Schema::Result::ItemtypesBranch",
  { "foreign.itemtype" => "self.itemtype" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 old_reserves

Type: has_many

Related object: L<Koha::Schema::Result::OldReserve>

=cut

__PACKAGE__->has_many(
  "old_reserves",
  "Koha::Schema::Result::OldReserve",
  { "foreign.itemtype" => "self.itemtype" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 parent_type

Type: belongs_to

Related object: L<Koha::Schema::Result::Itemtype>

=cut

__PACKAGE__->belongs_to(
  "parent_type",
  "Koha::Schema::Result::Itemtype",
  { itemtype => "parent_type" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 reserves

Type: has_many

Related object: L<Koha::Schema::Result::Reserve>

=cut

__PACKAGE__->has_many(
  "reserves",
  "Koha::Schema::Result::Reserve",
  { "foreign.itemtype" => "self.itemtype" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GyeWSJTL6LyaPEv/8yW/xg

__PACKAGE__->add_columns(
    '+rentalcharge_hourly_calendar' => { is_boolean => 1 },
    '+rentalcharge_daily_calendar'  => { is_boolean => 1 },
    '+automatic_checkin'            => { is_boolean => 1 },
);

# Use the ItemtypeLocalization view to create the join on localization
our $LANGUAGE;
__PACKAGE__->has_many(
  "localization" => "Koha::Schema::Result::ItemtypeLocalization",
    sub {
        my $args = shift;

        die "no lang specified!" unless $LANGUAGE;

        return ({
            "$args->{self_alias}.itemtype" => { -ident => "$args->{foreign_alias}.code" },
            "$args->{foreign_alias}.lang" => $LANGUAGE,
        });

    }
);

sub koha_object_class {
    'Koha::ItemType';
}
sub koha_objects_class {
    'Koha::ItemTypes';
}

1;
