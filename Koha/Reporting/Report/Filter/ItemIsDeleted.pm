#!/usr/bin/perl
package Koha::Reporting::Report::Filter::ItemIsDeleted;

use Modern::Perl;
use Moose;
use Data::Dumper;

extends 'Koha::Reporting::Report::Filter::Abstract';

sub BUILD {
    my $self = shift;
    $self->setName('is_deleted');
    $self->setDescription('Item is deleted');
    $self->setType('multiselect');
    $self->setDimension('fact');
    $self->setField('is_deleted');
    $self->setRule('neq');
    $self->setAddNotSetOption(0);
}

sub loadOptions{
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $options = [
        {'name' => '0', 'description' => 'Is Not Deleted'}
#        {'name' => '1', 'description' => 'Is Deleted'}
    ];

    return $options;
}






1;
