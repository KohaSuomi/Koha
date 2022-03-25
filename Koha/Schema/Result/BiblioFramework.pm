use utf8;
package Koha::Schema::Result::BiblioFramework;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::BiblioFramework

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<biblio_framework>

=cut

__PACKAGE__->table("biblio_framework");

=head1 ACCESSORS

=head2 frameworkcode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 4

=head2 frameworktext

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "frameworkcode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 4 },
  "frameworktext",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</frameworkcode>

=back

=cut

__PACKAGE__->set_primary_key("frameworkcode");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:huL+HaOPSQbWHrs9T1gqEQ

# FIXME This should not be needed, we need to add the FK at DB level
# It cannot be done now because the default framework (frameworkcode=='')
# does not exist in DB
__PACKAGE__->has_many(
    "marc_tag_structure",
    "Koha::Schema::Result::MarcTagStructure",
    { "foreign.frameworkcode" => "self.frameworkcode"},
    { cascade_copy => 0, cascade_delete => 0 },
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
