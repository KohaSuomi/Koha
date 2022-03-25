use utf8;
package Koha::Schema::Result::ImportRecordMatch;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::ImportRecordMatch

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<import_record_matches>

=cut

__PACKAGE__->table("import_record_matches");

=head1 ACCESSORS

=head2 import_record_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 candidate_match_id

  data_type: 'integer'
  is_nullable: 0

=head2 score

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "import_record_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "candidate_match_id",
  { data_type => "integer", is_nullable => 0 },
  "score",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</import_record_id>

=item * L</candidate_match_id>

=back

=cut

__PACKAGE__->set_primary_key("import_record_id", "candidate_match_id");

=head1 RELATIONS

=head2 import_record

Type: belongs_to

Related object: L<Koha::Schema::Result::ImportRecord>

=cut

__PACKAGE__->belongs_to(
  "import_record",
  "Koha::Schema::Result::ImportRecord",
  { import_record_id => "import_record_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FsqrGMZPboFCyYh+gxcJZg

sub koha_object_class {
    'Koha::Import::Record::Match';
}
sub koha_objects_class {
    'Koha::Import::Record::Matches';
}

1;
