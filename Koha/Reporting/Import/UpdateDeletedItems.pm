#!/usr/bin/perl
package Koha::Reporting::Import::UpdateDeletedItems;

use Modern::Perl;
use Moose;
use Data::Dumper;
use POSIX qw(strftime floor);
use Time::Piece;
use utf8;

extends 'Koha::Reporting::Import::Abstract';

sub BUILD {
    my $self = shift;
    $self->initFactTable('reporting_deleteditems');
    $self->setInsertOnDuplicateFact(1);
    $self->setName('items_update');
    $self->{column_transform_method}->{fact}->{amount} = \&factAmount;
    $self->{column_filters}->{item}->{datelastborrowed} = 1;
}

sub loadDatas{
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $statistics;
    my @parameters;

    print Dumper "SELECTING";

    my $itemtypes = Koha::Reporting::Import::Abstract->getConditionValues('itemTypeToStatisticalCategory');

    my $query = "select update_items.itemnumber, deleteditems.location, deleteditems.barcode, deleteditems.homebranch as branch, deleteditems.dateaccessioned as acquired_year, deleteditems.itype as itemtype, COALESCE(deleteditems.timestamp) as datetime, deleteditems.biblioitemnumber, deleteditems.cn_sort, ";
    $query .= 'COALESCE(bibliometa.metadata, deletedbibliometa.metadata) as marcxml, COALESCE(biblioitems.publicationyear, deletedbiblioitems.publicationyear) as published_year ';
    $query .= 'from deleteditems ';
    $query .= 'inner join reporting_update_items as update_items on deleteditems.itemnumber=update_items.itemnumber ';
    $query .= 'left join biblioitems on deleteditems.biblioitemnumber = biblioitems.biblioitemnumber ';
    $query .= 'left join biblio_metadata as bibliometa on biblioitems.biblionumber = bibliometa.biblionumber ';
    $query .= 'left join deletedbiblioitems on deleteditems.biblioitemnumber = deletedbiblioitems.biblioitemnumber ';
    $query .= 'left join deletedbiblio_metadata as deletedbibliometa on deletedbiblioitems.biblionumber = deletedbibliometa.biblionumber ';

    my $whereDeleted = "where deleteditems.itype in ".$itemtypes;
    if($self->getLastSelectedId()){
        $whereDeleted .= $self->getWhereLogic($whereDeleted);
        $whereDeleted .= " update_items.itemnumber > ? ";
        push @parameters, $self->getLastSelectedId();
    }
    if($self->getLastAllowedId()){
        $whereDeleted .= $self->getWhereLogic($whereDeleted);
        $whereDeleted .= " update_items.itemnumber <= ? ";
        push @parameters, $self->getLastAllowedId();
    }

    $query .= $whereDeleted;
    $query .= 'order by itemnumber ';

    if($self->getLimit()){
        $query .= 'limit ?';
        push @parameters, $self->getLimit();
    }

    my $stmnt = $dbh->prepare($query);
    if(@parameters){
        $stmnt->execute(@parameters) or die($DBI::errstr);
    }
    else{
        $stmnt->execute() or die($DBI::errstr);
    }

    if ($stmnt->rows >= 1){
        print Dumper "ROWS: " . $stmnt->rows;
        $statistics = $stmnt->fetchall_arrayref({});
        if(defined @$statistics[-1]){
            my $lastRow =  @$statistics[-1];
            if(defined $lastRow->{itemnumber}){
                $self->updateLastSelected($lastRow->{itemnumber});
            }
        }
    }

    $self->updateIsDeleted($statistics);
    print Dumper 'returning';
    return $statistics;
}

sub loadLastAllowedId{
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $query = "select MAX(itemnumber) from reporting_update_items";
    my $stmnt = $dbh->prepare($query);
    $stmnt->execute() or die($DBI::errstr);

    my $lastId;
    if($stmnt->rows == 1){
        $lastId = $stmnt->fetch()->[0];
        $self->setLastAllowedId($lastId);
    }
}

sub factAmount{
    return 1;
}

sub updateIsDeleted {
    my $self = shift;
    my $statistics = shift;

    my @itemnumbers = ();
    foreach my $data (@$statistics) {
        if(defined $data->{itemnumber}){
	   push @itemnumbers, $data->{itemnumber};
        }
    }

    my $dbh = C4::Context->dbh;
    my $query = "update reporting_items_fact set is_deleted=1 where item_id in ( ";
    $query .= "select item_id from reporting_item_dim as items ";
    $query .= "where items.itemnumber in (?) ";
    $query .= ")";

    my $stmnt = $dbh->prepare($query);
    $stmnt->execute(@itemnumbers);
}

sub truncateUpdateTable{
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $query = "truncate table reporting_update_items";
    my $stmnt = $dbh->prepare($query);
    $stmnt->execute() or die($DBI::errstr);
}

sub prepareUpdateTable {
    my $self = shift;

    $self->truncateUpdateTable();
    $self->resetSettings();
    my $date = $self->getUpdateTimeStamp();
    my $dbh = C4::Context->dbh;
    my @parameters = ($date);

    my $query = "insert into reporting_update_items (itemnumber) select distinct deleteditems.itemnumber from deleteditems ";
       $query .= "where deleteditems.timestamp > ? ";

    my $stmnt = $dbh->prepare($query);
    $stmnt->execute(@parameters) or die($DBI::errstr);
}

sub resetSettings {
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $query = "update reporting_import_settings set last_inserted=null, last_selected=null, last_allowed_select=null, last_inserted_fact=null where name='items_update' ";

    my $stmnt = $dbh->prepare($query);
    $stmnt->execute() or die($DBI::errstr);
}

sub getUpdateTimeStamp {
    my $days = 2;
    my $self = shift;
    my $epoc = time();
    $epoc = $epoc - 24 * 60 * 60 * $days;
    return strftime("%Y-%m-%d %H:%I:%S", localtime($epoc));
}

1;
