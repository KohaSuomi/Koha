#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 1;
use Test::MockModule;
use Test::MockTime qw( set_fixed_time );
use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Circulation qw( AddIssue AddReturn );
use C4::Members qw( FineSlip );
use C4::Overdues qw( UpdateFine );

use Koha::CirculationRules;
use Koha::DateUtils qw( dt_from_string output_pref );

my $schema = Koha::Database->schema;
$schema->storage->txn_begin;
my $dbh = C4::Context->dbh;

$dbh->do(q|DELETE FROM letter|);
$dbh->do(q|DELETE FROM circulation_rules|);

my $builder = t::lib::TestBuilder->new;
set_fixed_time(CORE::time());

my $branchcode   = $builder->build({ source => 'Branch' })->{ branchcode };
my $itemtype     = $builder->build({ source => 'Itemtype' })->{ itemtype };

my $item  = $builder->build_sample_item({
    homebranch => $branchcode,
    itype      => $itemtype
});

my $issuingrule = Koha::CirculationRules->set_rules(
    {
        categorycode => undef,
        itemtype     => undef,
        branchcode   => undef,
        rules        => {
            fine                   => 1,
            finedays               => 0,
            chargeperiod           => 7,
            chargeperiod_charge_at => 0,
            lengthunit             => 'days',
            issuelength            => 1,
        }
    }
);

my $module = Test::MockModule->new('C4::Context');
$module->mock( 'userenv', sub { { branch => $branchcode } } );

my $slip_content = <<EOS;
<<borrowers.firstname>> <<borrowers.surname>>
<<borrowers.cardnumber>>
Fines and fees: <<total.fines>>
<fines>
<<fines.date_due>>, <<fines.amount>>
Barcode: <<items.barcode>>
<<fines.description>>
</fines>
Total: <<total.amount>>
EOS

$dbh->do(q|
    INSERT INTO  letter (module, code, branchcode, name, is_html, title, content, message_transport_type) VALUES ( 'circulation', 'FINESLIP', '', 'Patron fines -slip', '1', 'Fines and fees slip', ?, 'print')
|, {}, $slip_content);

my $patron = $builder->build(
    {
        source => 'Borrower',
        value  => {
            surname    => 'Patron',
            firstname  => 'New',
            cardnumber => '0011223344',
            branchcode => $branchcode
        },
    }
);

my $today = dt_from_string();
my $date_due = dt_from_string->subtract_duration( DateTime::Duration->new( days => 13 ) );
my $issue_date = dt_from_string->subtract_duration( DateTime::Duration->new( days => 14 ) );
my $barcode = $item->barcode;

my $issue = AddIssue($patron, $barcode, $date_due, undef, $issue_date);
t::lib::Mocks::mock_preference('CalculateFinesOnReturn', 1);
AddReturn( $barcode, $branchcode);

my $lines = Koha::Account::Lines->search({ borrowernumber => $patron->{borrowernumber} });
my $total_fines = $lines->count;
my $fine_amount = 0;
my $description = '';
while (my $line = $lines->next){
    $fine_amount = sprintf('%.2f', $line->amount);
    $description = $line->description;
}

my $total = sprintf('%.2f', $lines->total_outstanding);

$date_due = output_pref({ dt => $date_due, dateonly => 1 });

my $fineslip = FineSlip( $patron->{borrowernumber}, $branchcode );
my $expected_slip = <<EOS;
New Patron
0011223344
Fines and fees: $total_fines

$date_due, $fine_amount
Barcode: $barcode
$description

Total: $total
EOS

is( $fineslip->{content}, $expected_slip, 'Fineslip returns slip with 1 item' );

$schema->storage->txn_rollback;