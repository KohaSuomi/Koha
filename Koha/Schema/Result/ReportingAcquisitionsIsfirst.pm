use utf8;
package Koha::Schema::Result::ReportingAcquisitionsIsfirst;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ReportingAcquisitionsIsfirst

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reporting_acquisitions_isfirst>

=cut

__PACKAGE__->table("reporting_acquisitions_isfirst");

=head1 ACCESSORS

=head2 item_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 branch_group

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=cut

__PACKAGE__->add_columns(
  "item_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 0 },
  "branch_group",
  { data_type => "varchar", is_nullable => 0, size => 30 },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DnvO/D9mdALER7Vc35a+Tw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
