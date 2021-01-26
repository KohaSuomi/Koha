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

use C4::KohaSuomi::SSN::Access;
use C4::Items;
use Koha::Account;
use Koha::Patron;

use Try::Tiny;

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron_id = $c->validation->param('patron_id');
        my $body = $c->req->json;

        my $ssn = GetSSNByBorrowerNumber ( $patron_id );

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
            if (defined $body->{addreplacementprice} && $body->{addreplacementprice} eq "yes") {
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
                itemcallnumber => $repeat->{itemcallnumber}
            };
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
        $totalfines =~ tr/./,/;
        $params{"substitute"} = {
            ssn => $ssn,
            finvoice_today => $finvoice_now,
            finvoice_duedate => $finvoice_duedate,
            totalfines => $totalfines,
        };

        my $guarantee;
        if ($body->{guarantee}) {
            $guarantee = Koha::Patrons->find($body->{guarantee});
            $params{"substitute"}{"issueborname"} = $guarantee->firstname.' '.$guarantee->surname;
            $params{"substitute"}{"issueborbarcode"} = $guarantee->cardnumber;
        }

        my $notice = C4::Letters::GetPreparedLetter(%params);

        $notice->{content} =~ s/\s+/ /gs;
        
        my $message_id = C4::Letters::EnqueueLetter(
                        {   letter                 => $notice,
                            borrowernumber         => $patron_id,
                            message_transport_type => 'print',
                            from_address => $body->{branchcode},
                        }
                    );

        foreach my $item (@itemnumbers) {
            ModItem({new_status => $message_id, notforloan => $body->{notforloan_status} }, $item->{biblionumber}, $item->{itemnumber});
        }

        if (defined $body->{debarment} && $body->{debarment} eq "yes") {
            Koha::Patron::Debarments::AddUniqueDebarment({
                borrowernumber => $patron_id,
                type           => 'OVERDUES',
                comment        => "Lainauskielto laskutetusta aineistosta",
            });
        }
        
        return $c->render(status => 201, openapi => {message_id => $message_id});
    }
    catch {
        Koha::Exceptions::rethrow_exception($_);
    };
}

sub _escape_string {
    my ($string) = @_;

    $string =~ s/&/&amp;/sg;
    $string =~ s/</&lt;/sg;
    $string =~ s/>/&gt;/sg;
    $string =~ s/"/&quot;/sg;

    return $string;
}

1;
