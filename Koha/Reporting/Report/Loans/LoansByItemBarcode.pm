#!/usr/bin/perl
package Koha::Reporting::Report::Loans::LoansByItemBarcode;

use Modern::Perl;
use Moose;
use Data::Dumper;
use Koha::Reporting::Report::Filter::LoanType;

extends "Koha::Reporting::Report::Loans";

sub BUILD {
    my $self = shift;
    $self->setDescription('Loans by Item (barcodes and titles)');
    $self->setGroup('oma');
    $self->setRendererClass('Koha::Reporting::Report::Renderer::OneRow');

    $self->addGrouping('Koha::Reporting::Report::Grouping::Barcode');

    $self->addGrouping('Koha::Reporting::Report::Grouping::CnClass');
    $self->addGrouping('Koha::Reporting::Report::Grouping::Signum');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LanguageAll');
    $self->addGrouping('Koha::Reporting::Report::Grouping::Branch');
    $self->addGrouping('Koha::Reporting::Report::Grouping::ItemType');
    $self->addGrouping('Koha::Reporting::Report::Grouping::Location');
    $self->addGrouping('Koha::Reporting::Report::Grouping::CollectionCodeLoan');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LocationType');
    $self->addGrouping('Koha::Reporting::Report::Grouping::LocationAge');
    $self->addGrouping('Koha::Reporting::Report::Grouping::PublishedYear');
    $self->addGrouping('Koha::Reporting::Report::Grouping::AcquiredYear');
    $self->addGrouping('Koha::Reporting::Report::Grouping::DateLastLoaned');

    $self->addFilter('branch_category', 'Koha::Reporting::Report::Filter::BranchGroup');
    $self->addFilter('branch', 'Koha::Reporting::Report::Filter::Branch');
    $self->addFilter('location', 'Koha::Reporting::Report::Filter::Location');
    $self->addFilter('cn_class', 'Koha::Reporting::Report::Filter::CnClass::Primary');
    $self->addFilter('signum', 'Koha::Reporting::Report::Filter::Signum');
    $self->addFilter('cn_class_fict', 'Koha::Reporting::Report::Filter::CnClass::Fictive');
    $self->addFilter('itemtype', 'Koha::Reporting::Report::Filter::Itemtype');
#    $self->addFilter('itemtype_okm', 'Koha::Reporting::Report::Filter::ItemtypeOkm');
    $self->addFilter('language', 'Koha::Reporting::Report::Filter::LanguageAll');
    $self->addFilter('is_yle', 'Koha::Reporting::Report::Filter::IsYle');
    $self->addFilter('published_start', 'Koha::Reporting::Report::Filter::PublishedStart');
    $self->addFilter('published_end', 'Koha::Reporting::Report::Filter::PublishedEnd');
    $self->addFilter('collection_code', 'Koha::Reporting::Report::Filter::CollectionCodeLoan');
    $self->addFilter('acquired_start', 'Koha::Reporting::Report::Filter::AcquiredStart');
    $self->addFilter('acquirder_end', 'Koha::Reporting::Report::Filter::AcquiredEnd');
    $self->addFilter('location_type', 'Koha::Reporting::Report::Filter::Location::Type');
    $self->addFilter('location_age', 'Koha::Reporting::Report::Filter::Location::Age');
#    $self->addFilter('loan_type', 'Koha::Reporting::Report::Filter::LoanType');
    $self->addFilter('loaned_amount_start', 'Koha::Reporting::Report::Filter::LoanedAmountStart');
    $self->addFilter('loaned_amount_end', 'Koha::Reporting::Report::Filter::LoanedAmountEnd');

#    $self->addOrdering('branch', {name => 'branch', 'dimension' => 'location', 'field' => 'branch', 'alias'=> 'Branch' });
#    $self->addOrdering('location', {name => 'location', 'dimension' => 'location', 'field' => 'location', 'alias'=> 'Location' });

    $self->addOrdering('amount', {name => 'loaned_amount', 'dimension' => 'fact', 'field' => 'loaned_amount', 'alias'=> 'loaned_amount', default_ordering => 'desc'});
    $self->setDefaultOrdering('amount');
    $self->setHasTopLimit(1);
    $self->setDefaultLimit(500);
}

sub initSelectFieldsBefore{
    my $self = shift;
    $self->addFieldToSelect('item', 'title', 'Title');
}

sub addHardcodedFilters{
    my $self = shift;
    my $loanTypeFilter = new Koha::Reporting::Report::Filter::LoanType;
    $self->filter('fact', $loanTypeFilter , 'Issue');
}

1;
