use utf8;
package Koha::Schema::Result::MapProductform;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::MapProductform

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<map_productform>

=cut

__PACKAGE__->table("map_productform");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 onix_code

  data_type: 'varchar'
  is_nullable: 1
  size: 2

=head2 productform

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "onix_code",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "productform",
  { data_type => "varchar", is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EV/9+B9e95PMSTl2VqDCow


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
