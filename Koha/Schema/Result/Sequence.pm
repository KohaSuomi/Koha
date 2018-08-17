use utf8;
package Koha::Schema::Result::Sequence;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Sequence

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sequences>

=cut

__PACKAGE__->table("sequences");

=head1 ACCESSORS

=head2 invoicenumber

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 item_barcode_nextval

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "invoicenumber",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "item_barcode_nextval",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:l20nUcdrMgYV3GUwRPGLNw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
