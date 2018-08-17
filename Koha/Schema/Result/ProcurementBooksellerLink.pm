use utf8;
package Koha::Schema::Result::ProcurementBooksellerLink;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ProcurementBooksellerLink

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<procurement_bookseller_link>

=cut

__PACKAGE__->table("procurement_bookseller_link");

=head1 ACCESSORS

=head2 aqbooksellers_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 vendor_assigned_id

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=cut

__PACKAGE__->add_columns(
  "aqbooksellers_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "vendor_assigned_id",
  { data_type => "varchar", is_nullable => 0, size => 20 },
);

=head1 PRIMARY KEY

=over 4

=item * L</aqbooksellers_id>

=item * L</vendor_assigned_id>

=back

=cut

__PACKAGE__->set_primary_key("aqbooksellers_id", "vendor_assigned_id");

=head1 RELATIONS

=head2 aqbookseller

Type: belongs_to

Related object: L<Koha::Schema::Result::Aqbookseller>

=cut

__PACKAGE__->belongs_to(
  "aqbookseller",
  "Koha::Schema::Result::Aqbookseller",
  { id => "aqbooksellers_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CfW2Y/DJZ56pM7N88BNylQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
