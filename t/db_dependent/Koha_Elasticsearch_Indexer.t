# Copyright 2015 Catalyst IT
#
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

use Test::More tests => 3;
use Test::MockModule;
use t::lib::Mocks;

use MARC::Record;

use Koha::Database;

my $schema = Koha::Database->schema();

use_ok('Koha::SearchEngine::Elasticsearch::Indexer');

my $indexer;
ok(
    $indexer = Koha::SearchEngine::Elasticsearch::Indexer->new({ 'index' => 'biblio' }),
    'Creating new indexer object'
);

my $marc_record = MARC::Record->new();
$marc_record->append_fields(
	MARC::Field->new( '001', '1234567' ),
	MARC::Field->new( '020', '', '', 'a' => '1234567890123' ),
	MARC::Field->new( '245', '', '', 'a' => 'Title' )
);
my $records = [$marc_record];

SKIP: {

    eval { $indexer->get_elasticsearch_params; };

    skip 'Elasticsearch configuration not available', 1
        if $@;

    ok( $indexer->update_index(undef, $records), 'Update Index' );
}
