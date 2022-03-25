use utf8;
package Koha::Schema::Result::Category;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::Category

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<categories>

=cut

__PACKAGE__->table("categories");

=head1 ACCESSORS

=head2 categorycode

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 10

=head2 description

  data_type: 'longtext'
  is_nullable: 1

=head2 enrolmentperiod

  data_type: 'smallint'
  is_nullable: 1

=head2 enrolmentperioddate

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 upperagelimit

  data_type: 'smallint'
  is_nullable: 1

=head2 dateofbirthrequired

  data_type: 'tinyint'
  is_nullable: 1

=head2 finetype

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 bulk

  data_type: 'tinyint'
  is_nullable: 1

=head2 enrolmentfee

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 overduenoticerequired

  data_type: 'tinyint'
  is_nullable: 1

=head2 issuelimit

  data_type: 'smallint'
  is_nullable: 1

=head2 reservefee

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 hidelostitems

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 category_type

  data_type: 'varchar'
  default_value: 'A'
  is_nullable: 0
  size: 1

=head2 default_privacy

  data_type: 'enum'
  default_value: 'default'
  extra: {list => ["default","never","forever"]}
  is_nullable: 0

=head2 checkprevcheckout

  data_type: 'varchar'
  default_value: 'inherit'
  is_nullable: 0
  size: 7

=head2 reset_password

  data_type: 'tinyint'
  is_nullable: 1

=head2 change_password

  data_type: 'tinyint'
  is_nullable: 1

=head2 min_password_length

  data_type: 'smallint'
  is_nullable: 1

=head2 require_strong_password

  data_type: 'tinyint'
  is_nullable: 1

=head2 exclude_from_local_holds_priority

  data_type: 'tinyint'
  is_nullable: 1

=head2 passwordpolicy

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 BlockExpiredPatronOpacActions

  accessor: 'block_expired_patron_opac_actions'
  data_type: 'tinyint'
  default_value: -1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "categorycode",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 10 },
  "description",
  { data_type => "longtext", is_nullable => 1 },
  "enrolmentperiod",
  { data_type => "smallint", is_nullable => 1 },
  "enrolmentperioddate",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "upperagelimit",
  { data_type => "smallint", is_nullable => 1 },
  "dateofbirthrequired",
  { data_type => "tinyint", is_nullable => 1 },
  "finetype",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "bulk",
  { data_type => "tinyint", is_nullable => 1 },
  "enrolmentfee",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "overduenoticerequired",
  { data_type => "tinyint", is_nullable => 1 },
  "issuelimit",
  { data_type => "smallint", is_nullable => 1 },
  "reservefee",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "hidelostitems",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "category_type",
  { data_type => "varchar", default_value => "A", is_nullable => 0, size => 1 },
  "default_privacy",
  {
    data_type => "enum",
    default_value => "default",
    extra => { list => ["default", "never", "forever"] },
    is_nullable => 0,
  },
  "checkprevcheckout",
  {
    data_type => "varchar",
    default_value => "inherit",
    is_nullable => 0,
    size => 7,
  },
  "reset_password",
  { data_type => "tinyint", is_nullable => 1 },
  "change_password",
  { data_type => "tinyint", is_nullable => 1 },
  "min_password_length",
  { data_type => "smallint", is_nullable => 1 },
  "require_strong_password",
  { data_type => "tinyint", is_nullable => 1 },
  "exclude_from_local_holds_priority",
  { data_type => "tinyint", is_nullable => 1 },
  "passwordpolicy",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "BlockExpiredPatronOpacActions",
  {
    accessor      => "block_expired_patron_opac_actions",
    data_type     => "tinyint",
    default_value => -1,
    is_nullable   => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</categorycode>

=back

=cut

__PACKAGE__->set_primary_key("categorycode");

=head1 RELATIONS

=head2 borrower_message_preferences

Type: has_many

Related object: L<Koha::Schema::Result::BorrowerMessagePreference>

=cut

__PACKAGE__->has_many(
  "borrower_message_preferences",
  "Koha::Schema::Result::BorrowerMessagePreference",
  { "foreign.categorycode" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 borrowers

Type: has_many

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->has_many(
  "borrowers",
  "Koha::Schema::Result::Borrower",
  { "foreign.categorycode" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 categories_branches

Type: has_many

Related object: L<Koha::Schema::Result::CategoriesBranch>

=cut

__PACKAGE__->has_many(
  "categories_branches",
  "Koha::Schema::Result::CategoriesBranch",
  { "foreign.categorycode" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 circulation_rules

Type: has_many

Related object: L<Koha::Schema::Result::CirculationRule>

=cut

__PACKAGE__->has_many(
  "circulation_rules",
  "Koha::Schema::Result::CirculationRule",
  { "foreign.categorycode" => "self.categorycode" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-03-15 19:43:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0SKb1CZwMYQJFI6uo04PqQ

__PACKAGE__->add_columns(
    '+exclude_from_local_holds_priority' => { is_boolean => 1 },
);

sub koha_object_class {
    'Koha::Patron::Category';
}
sub koha_objects_class {
    'Koha::Patron::Categories';
}

__PACKAGE__->add_columns(
    '+require_strong_password' => { is_boolean => 1 }
);

1;
