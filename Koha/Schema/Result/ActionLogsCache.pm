use utf8;
package Koha::Schema::Result::ActionLogsCache;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ActionLogsCache

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<action_logs_cache>

=cut

__PACKAGE__->table("action_logs_cache");

=head1 ACCESSORS

=head2 action_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: 'current_timestamp()'
  is_nullable: 0

=head2 user

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 module

  data_type: 'text'
  is_nullable: 1

=head2 action

  data_type: 'text'
  is_nullable: 1

=head2 object

  data_type: 'integer'
  is_nullable: 1

=head2 info

  data_type: 'text'
  is_nullable: 1

=head2 interface

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=cut

__PACKAGE__->add_columns(
  "action_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => "current_timestamp()",
    is_nullable => 0,
  },
  "user",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "module",
  { data_type => "text", is_nullable => 1 },
  "action",
  { data_type => "text", is_nullable => 1 },
  "object",
  { data_type => "integer", is_nullable => 1 },
  "info",
  { data_type => "text", is_nullable => 1 },
  "interface",
  { data_type => "varchar", is_nullable => 1, size => 30 },
);

=head1 PRIMARY KEY

=over 4

=item * L</action_id>

=back

=cut

__PACKAGE__->set_primary_key("action_id");


# Created by DBIx::Class::Schema::Loader v0.07048 @ 2018-08-17 15:31:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8SKrPIvPg49zqvrYRcYAQQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
