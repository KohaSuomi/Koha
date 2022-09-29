use utf8;
package Koha::Schema::Result::Statistic;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Statistic

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<statistics>

=cut

__PACKAGE__->table("statistics");

=head1 ACCESSORS

=head2 datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 branch

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 value

  data_type: 'double precision'
  is_nullable: 1
  size: [16,4]

=head2 type

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 other

  data_type: 'longtext'
  is_nullable: 1

=head2 usercode

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 itemnumber

  data_type: 'integer'
  is_nullable: 1

=head2 itemtype

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 location

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 borrowernumber

  data_type: 'integer'
  is_nullable: 1

=head2 ccode

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 categorycode

  data_type: 'varchar'
  is_nullable: 1
  size: 10

foreign key from the borrowers table, links transaction to a specific borrower category

=cut

__PACKAGE__->add_columns(
  "datetime",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "branch",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "value",
  { data_type => "double precision", is_nullable => 1, size => [16, 4] },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "other",
  { data_type => "longtext", is_nullable => 1 },
  "usercode",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "itemnumber",
  { data_type => "integer", is_nullable => 1 },
  "itemtype",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "location",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "borrowernumber",
  { data_type => "integer", is_nullable => 1 },
  "ccode",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "categorycode",
  { data_type => "varchar", is_nullable => 1, size => 10 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-09-29 12:40:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/oKD0mbtb4nU4Ay//Xplxg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
