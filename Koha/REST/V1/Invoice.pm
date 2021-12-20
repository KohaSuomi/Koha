package Koha::REST::V1::Invoice;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Log;

use Koha::Notice::Messages;
use C4::Letters;
use POSIX qw(strftime);

use C4::Items;
use Koha::Account;
use Koha::Patron;
use Text::Unaccent;

use C4::Context;

use Try::Tiny;

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron_id = $c->validation->param('patron_id');
        my $body = $c->req->json;
        my $preview = $body->{preview} || 0;

        my %tables = ( 'borrowers' => $patron_id, 'branches' => $body->{branchcode} );

        my $repeatdata;

        my %params;
        $params{"module"} = $body->{module};
        $params{"letter_code"} = $body->{letter_code};
        $params{"branchcode"} = $body->{branchcode} || '';
        $params{"tables"} = \%tables;
        $params{"lang"} = $body->{lang} || 'default';
        my @items;
        my $count = 1;
        my $totalfines = 0;
        my @itemnumbers;
        foreach my $repeat (@{$body->{repeat}}) {
            my ($y, $m, $d) = $repeat->{date_due} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/;
            $repeat->{replacementprice} =~ tr/,/./;
            if ($body->{addreplacementprice} && !$preview) {
                my $accountline = Koha::Account::Lines->search({borrowernumber => $patron_id, itemnumber => $repeat->{itemnumber}, accounttype => 'B'});
                unless (@{$accountline->unblessed}) {
                    Koha::Account::Line->new({ 
                        borrowernumber => $patron_id, 
                        amountoutstanding => $repeat->{replacementprice}, 
                        amount => $repeat->{replacementprice},
                        note => 'Korvaushinta',
                        accounttype => 'B',
                        itemnumber => $repeat->{itemnumber},
                    })->store();
                }
            }
            $totalfines = $totalfines + $repeat->{replacementprice};
            $repeat->{replacementprice} =~ tr/./,/;
            my $item = {
                count => $count,
                itemnumber => $repeat->{itemnumber},
                replacementprice => $repeat->{replacementprice},
                finvoice_date => $y.$m.$d,
                date_due => $d.'.'.$m.'.'.$y,
                enumchron => $repeat->{enumchron},
                itype => $repeat->{itype},
                itemcallnumber => $repeat->{itemcallnumber},
                barcode => $repeat->{barcode}
            };
            if ($body->{overduefines}) {
                my $overdueline = Koha::Account::Lines->find({borrowernumber => $patron_id, itemnumber => $repeat->{itemnumber}, accounttype => 'FU'});
                $item->{overduefine} = $overdueline ? $overdueline->amountoutstanding : 0;
                $totalfines = $totalfines + $item->{overduefine};
            }
            my $biblio = {
                title => _escape_string($repeat->{title}),
                author => _escape_string($repeat->{author}),
            };
            
            push @items, {"items" => $item, "biblio" => $biblio, "biblioitems" => $repeat->{biblionumber}};
            push @itemnumbers, {itemnumber => $repeat->{itemnumber}, biblionumber => $repeat->{biblionumber}};
            $count++
        }
        $params{"repeat"} = {$body->{repeat_type} => \@items};
        $params{"message_transport_type"} = $body->{message_transport_type} || 'print';
        
        my $now = strftime "%d%m%Y", localtime;
        my $finvoice_now = strftime "%Y%m%d", localtime;
        my $timestamp = strftime "%d.%m.%Y %H:%M", localtime;
        my $date = time + (14 * 24 * 60 * 60);
        my $duedate = strftime "%d.%m.%Y", localtime($date);
        my $finvoice_duedate = strftime "%Y%m%d", localtime($date);
        my $invoicefine = $body->{invoicefine};
        $invoicefine =~ tr/,/./;
        $totalfines = $totalfines + $invoicefine if $invoicefine;
        $totalfines = sprintf("%.2f", $totalfines);
        $totalfines =~ tr/./,/;

        my $invoicenumber;
        if (!$preview) {
            $invoicenumber = _invoice_number();
        }
        my $reference;
        if ($body->{addreferencenumber} && !$preview) {
            $reference =_reference_number($body->{librarygroup}, $invoicenumber, $body->{increment});
        }

        $params{"substitute"} = {
            finvoice_today => $finvoice_now,
            finvoice_duedate => $finvoice_duedate,
            totalfines => $totalfines,
            referencenumber => $reference,
            invoicenumber => $invoicenumber,
            invoicefine => $body->{invoicefine}, 
            accountnumber => $body->{accountnumber},
            biccode => $body->{biccode},
            businessid => $body->{businessid},
        };

        my $guarantee;
        if ($body->{guarantee}) {
            $guarantee = Koha::Patrons->find($body->{guarantee});
            $params{"substitute"}{"issueborname"} = $guarantee->firstname.' '.$guarantee->surname;
            $params{"substitute"}{"issueborbarcode"} = $guarantee->cardnumber;
        }

        my $notice = C4::Letters::GetPreparedLetter(%params);

        $notice->{content} =~ s/\s+/ /gs;

        my $message_id;

        unless ($preview) {
        
            $message_id = C4::Letters::EnqueueLetter(
                            {   letter                 => $notice,
                                borrowernumber         => $patron_id,
                                message_transport_type => 'print',
                                from_address => $body->{branchcode},
                            }
                        );

            foreach my $item (@itemnumbers) {
                ModItem({new_status => $message_id, notforloan => $body->{notforloan_status} }, $item->{biblionumber}, $item->{itemnumber});
            }

            if ($body->{debarment}) {
                Koha::Patron::Debarments::AddUniqueDebarment({
                    borrowernumber => $patron_id,
                    type           => 'OVERDUES',
                    comment        => "Lainauskielto laskutetusta aineistosta",
                });
            }
        }
        
        return $c->render(status => 201, openapi => {message_id => $message_id, notice => $notice->{content}});
    }
    catch {
        Koha::Exceptions::rethrow_exception($_);
    };
}

sub _escape_string {
    my ($string) = @_;
    my $newstring;
    my @chars = split(//, $string);
    
    foreach my $char (@chars) {
        my $oldchar = $char;
        unless ( $char =~ /[A-Za-z0-9ÅåÄäÖöÉéÜüÁá]/ ) {
            $char = 'Z'  if $char eq 'Ʒ';
            $char = 'z'  if $char eq 'ʒ';
            $char = 'B'  if $char eq 'ß';
            $char = '\'' if $char eq 'ʻ';
            $char = 'e'  if $char eq '€';
            $char = unac_string( 'utf-8', $char ) if "$oldchar" eq "$char";
        }
        $newstring .= $char;
    }

    $newstring =~ s/&/&amp;/sg;
    $newstring =~ s/</&lt;/sg;
    $newstring =~ s/>/&gt;/sg;
    $newstring =~ s/"/&quot;/sg;
    
    return $newstring;
}

sub _reference_number {
    my ($librarygroup, $invoicenumber, $increment) = @_;
    my $dbh = C4::Context->dbh;

    my $sth_refnumber=$dbh->prepare('SELECT ' . $librarygroup . ' FROM sequences;');

    $sth_refnumber->execute() or return 0;
    my @refno=$sth_refnumber->fetchrow_array();
    
    $dbh->do('UPDATE sequences SET '. $librarygroup . ' = ' . $librarygroup . ' + ' . $increment);
    my $reference = $refno[0].'0'.$invoicenumber;
    return $reference . _ref_checksum($reference);
}

sub _ref_checksum {
    my $ref=reverse(shift);
    my $checkSum=0;
    my @weights=(7,3,1);
    my $i=0;

    for my $refNumber (split //, $ref) {
        $i=0 if $i==@weights;
        $checkSum=$checkSum+($refNumber*$weights[$i]);
        $i++;
    }

    my $nextTen=$checkSum+9;
    $nextTen=$nextTen-($nextTen%10);
    return $nextTen-$checkSum;
}

sub _invoice_number {
    my $dbh = C4::Context->dbh;
    my $sth_invoicenumber=$dbh->prepare('SELECT invoicenumber FROM sequences;');

    $sth_invoicenumber->execute() or return 0;
    my @invoiceno=$sth_invoicenumber->fetchrow_array();

    $dbh->do('UPDATE sequences SET invoicenumber = invoicenumber + 1');

    return $invoiceno[0];
}


1;
