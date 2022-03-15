use utf8;
package Koha::Schema::Result::OkmStatisticsLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::OkmStatisticsLog

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<okm_statistics_logs>

=cut

__PACKAGE__->table("okm_statistics_logs");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 entry

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "entry",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3M8+o469hwXmZ+yX4+FnVg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
