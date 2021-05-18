#!/usr/bin/perl

use Modern::Perl;

use Test::More tests => 3;
use Test::WWW::Mechanize;
use t::lib::Mocks qw(mock_preference);

use File::Basename;
use XML::LibXML;
use YAML;
use ZOOM;

BEGIN {
    use_ok('Koha::Z3950Responder');
    use_ok('Koha::Z3950Responder::GenericSession');
}

our $child;

subtest 'test_search' => sub {

    plan tests => 19;

    t::lib::Mocks::mock_preference('SearchEngine', 'Elasticsearch');

    my $marc_record_1 = MARC::Record->new();
    $marc_record_1->leader('     cam  22      a 4500');
    $marc_record_1->append_fields(
        MARC::Field->new('001', '123'),
        MARC::Field->new('020', '', '', a => '1-56619-909-3'),
        MARC::Field->new('100', '', '', a => 'Author 1'),
        MARC::Field->new('110', '', '', a => 'Corp Author'),
        MARC::Field->new('210', '', '', a => 'Title 1'),
        MARC::Field->new('245', '', '', a => 'Title:', b => 'first record'),
        MARC::Field->new('999', '', '', c => '1234567'),
    );

    my $marc_record_2 = MARC::Record->new();
    $marc_record_2->leader('     cam  22      a 4500');
    $marc_record_2->append_fields(
        MARC::Field->new('001', '234'),
        MARC::Field->new('020', '', '', a => '1-56619-909-3'),
        MARC::Field->new('100', '', '', a => 'Author 2'),
        MARC::Field->new('110', '', '', a => 'Corp Author'),
        MARC::Field->new('210', '', '', a => 'Title 2'),
        MARC::Field->new('245', '', '', a => 'Title:', b => 'second record'),
        MARC::Field->new('999', '', '', c => '1234567'),
    );

    my $yaml = new Test::MockModule('YAML');
    $yaml->mock('LoadFile', sub {
        return {
            biblios => {
                use => {
                    1 => 'author',
                    4 => 'title',
                    1003 => 'author'
                }
            }
        };
    });

    my $builder = new Test::MockModule('Koha::SearchEngine::Elasticsearch::QueryBuilder');
    $builder->mock('build_query_compat', sub {
        my ( $self, $operators, $operands ) = @_;

        return (undef, $operands->[0]);
    });

    my $search = new Test::MockModule('Koha::SearchEngine::Elasticsearch::Search');
    $search->mock('simple_search_compat', sub {
        my ( $self, $query ) = @_;

        return ('unexpected query', undef, 0) unless $query eq '((author:(author)) AND ((title:(title\(s\))) OR (title:(another))))';

        my @records = ($marc_record_1, $marc_record_2);
        return (undef, \@records, 2);
    });

    $child = fork();
    if ($child == 0) {
        my $config_dir = dirname(__FILE__) . '/';
        my $z = Koha::Z3950Responder->new( {
            config_dir => $config_dir
        });
        $z->start();
        exit;
    }
    sleep(1);

    # Z39.50 protocol tests
    my $o = new ZOOM::Options();
    $o->option(preferredRecordSyntax => 'xml');
    $o->option(elementSetName => 'marcxml');
    $o->option(databaseName => 'biblios');

    my $Zconn = ZOOM::Connection->create($o);
    ok($Zconn, 'ZOOM connection created');

    $Zconn->connect('localhost:42111', 0);
    is($Zconn->errcode(), 0, 'Connection is successful: ' . $Zconn->errmsg());

    my $rs = $Zconn->search_pqf('@and @attr 1=1 @attr 4=1 author @or @attr 1=4 title(s) @attr 1=4 another');
    is($Zconn->errcode(), 0, 'Search is successful: ' . $Zconn->errmsg());

    is($rs->size(), 2, 'Two results returned');

    my $returned1 = MARC::Record->new_from_xml($rs->record(0)->raw());
    ok($returned1, 'Record 1 returned as MARCXML');
    is($returned1->as_xml, $marc_record_1->as_xml, 'Record 1 returned properly');

    my $returned2= MARC::Record->new_from_xml($rs->record(1)->raw());
    ok($returned2, 'Record 2 returned as MARCXML');
    is($returned2->as_xml, $marc_record_2->as_xml, 'Record 2 returned properly');

    # SRU protocol tests
    my $base = 'http://localhost:42111';
    my $ns = 'http://docs.oasis-open.org/ns/search-ws/sruResponse';
    my $marc_ns = 'http://www.loc.gov/MARC21/slim';
    my $agent = Test::WWW::Mechanize->new( autocheck => 1 );

    $agent->get_ok("$base", 'Retrieve explain response');
    my $dom = XML::LibXML->load_xml(string => $agent->content());
    my @nodes = $dom->getElementsByTagNameNS($ns, 'explainResponse');
    is(scalar(@nodes), 1, 'explainResponse returned');

    $agent->get_ok("$base/biblios?operation=searchRetrieve&recordSchema=marcxml&maximumRecords=10&query=", 'Try bad search query');
    $dom = XML::LibXML->load_xml(string => $agent->content());
    @nodes = $dom->getElementsByTagNameNS($ns, 'diagnostics');
    is(scalar(@nodes), 1, 'diagnostics returned for bad query');

    $agent->get_ok("$base/biblios?operation=searchRetrieve&recordSchema=marcxml&maximumRecords=10&query=(dc.author%3dauthor AND (dc.title%3d\"title(s)\" OR dc.title%3danother))", 'Retrieve search results');
    $dom = XML::LibXML->load_xml(string => $agent->content());
    @nodes = $dom->getElementsByTagNameNS($ns, 'searchRetrieveResponse');
    is(scalar(@nodes), 1, 'searchRetrieveResponse returned');
    my @records = $nodes[0]->getElementsByTagNameNS($marc_ns, 'record');
    is(scalar(@records), 2, 'Two results returned');

    $returned1 = MARC::Record->new_from_xml($records[0]->toString());
    ok($returned1, 'Record 1 returned as MARCXML');
    is($returned1->as_xml, $marc_record_1->as_xml, 'Record 1 returned properly');

    $returned2= MARC::Record->new_from_xml($records[1]->toString());
    ok($returned2, 'Record 2 returned as MARCXML');
    is($returned2->as_xml, $marc_record_2->as_xml, 'Record 2 returned properly');

    cleanup();
};

sub cleanup {
    if ($child) {
        kill 9, $child;
        $child = undef;
    }
}

# Fall back to make sure that the server process gets cleaned up
END {
    cleanup();
}
