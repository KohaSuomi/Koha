use utf8;
package Koha::Schema::Result::HouseboundProfile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::HouseboundProfile

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<housebound_profile>

=cut

__PACKAGE__->table("housebound_profile");

=head1 ACCESSORS

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 day

  data_type: 'mediumtext'
  is_nullable: 0

=head2 frequency

  data_type: 'mediumtext'
  is_nullable: 0

=head2 fav_itemtypes

  data_type: 'mediumtext'
  is_nullable: 1

=head2 fav_subjects

  data_type: 'mediumtext'
  is_nullable: 1

=head2 fav_authors

  data_type: 'mediumtext'
  is_nullable: 1

=head2 referral

  data_type: 'mediumtext'
  is_nullable: 1

=head2 notes

  data_type: 'mediumtext'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "day",
  { data_type => "mediumtext", is_nullable => 0 },
  "frequency",
  { data_type => "mediumtext", is_nullable => 0 },
  "fav_itemtypes",
  { data_type => "mediumtext", is_nullable => 1 },
  "fav_subjects",
  { data_type => "mediumtext", is_nullable => 1 },
  "fav_authors",
  { data_type => "mediumtext", is_nullable => 1 },
  "referral",
  { data_type => "mediumtext", is_nullable => 1 },
  "notes",
  { data_type => "mediumtext", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</borrowernumber>

=back

=cut

__PACKAGE__->set_primary_key("borrowernumber");

=head1 RELATIONS

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 housebound_visits

Type: has_many

Related object: L<Koha::Schema::Result::HouseboundVisit>

=cut

__PACKAGE__->has_many(
  "housebound_visits",
  "Koha::Schema::Result::HouseboundVisit",
  { "foreign.borrowernumber" => "self.borrowernumber" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2yBQQ6IVg1piyjSjcWKeKg

sub koha_object_class {
    'Koha::Patron::HouseboundProfile';
}
sub koha_objects_class {
    'Koha::Patron::HouseboundProfiles';
}

1;
