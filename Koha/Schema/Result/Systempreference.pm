use utf8;
package Koha::Schema::Result::Systempreference;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Systempreference

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<systempreferences>

=cut

__PACKAGE__->table("systempreferences");

=head1 ACCESSORS

=head2 variable

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 50

=head2 value

  data_type: 'mediumtext'
  is_nullable: 1

=head2 options

  data_type: 'longtext'
  is_nullable: 1

=head2 explanation

  data_type: 'mediumtext'
  is_nullable: 1

=head2 type

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=cut

__PACKAGE__->add_columns(
  "variable",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
  "value",
  { data_type => "mediumtext", is_nullable => 1 },
  "options",
  { data_type => "longtext", is_nullable => 1 },
  "explanation",
  { data_type => "mediumtext", is_nullable => 1 },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 20 },
);

=head1 PRIMARY KEY

=over 4

=item * L</variable>

=back

=cut

__PACKAGE__->set_primary_key("variable");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LrmfSR1uuRa431EL9hyaxQ

sub koha_object_class {
    'Koha::Config::SysPref';
}
sub koha_objects_class {
    'Koha::Config::SysPrefs';
}

1;
