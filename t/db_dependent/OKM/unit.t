# Copyright 2016 KohaSuomi
#
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
use Test::More;

use C4::OPLIB::OKM;



subtest "StandardizeTimeperiodParameter" => \&StandardizeTimeperiodParameter;
sub StandardizeTimeperiodParameter {
    eval {
    my ($startDt, $endDt, $thisYear, $lastMonthDt);
    $thisYear = DateTime->now(  time_zone => C4::Context->tz()  )->year();
    $lastMonthDt = DateTime->now(  time_zone => C4::Context->tz()  )->subtract( months => 1 );

    ($startDt, $endDt) = C4::OPLIB::OKM::StandardizeTimeperiodParameter('2015-03-12 - 2016-05-22');
    is($startDt->iso8601,
       "2015-03-12T00:00:00",
       "YYYY-MM-DD - YYYY-MM-DD start");
    is($endDt->iso8601,
       "2016-05-22T23:59:59",
       "YYYY-MM-DD - YYYY-MM-DD end");

    ($startDt, $endDt) = C4::OPLIB::OKM::StandardizeTimeperiodParameter('2016-11-12 - 2015-05-02');
    is($startDt->iso8601,
       "2015-05-02T00:00:00",
       "YYYY-MM-DD - YYYY-MM-DD start, reversed dates");
    is($endDt->iso8601,
       "2016-11-12T23:59:59",
       "YYYY-MM-DD - YYYY-MM-DD end, reversed dates");

    ($startDt, $endDt) = C4::OPLIB::OKM::StandardizeTimeperiodParameter('2015');
    is($startDt->iso8601,
       "2015-01-01T00:00:00",
       "YYYY start");
    is($endDt->iso8601,
       "2015-12-31T23:59:59",
       "YYYY end");

    ($startDt, $endDt) = C4::OPLIB::OKM::StandardizeTimeperiodParameter('12');
    is($startDt->iso8601,
       "$thisYear-12-01T00:00:00",
       "MM start");
    is($endDt->iso8601,
       "$thisYear-12-31T23:59:59",
       "MM end");

    ($startDt, $endDt) = C4::OPLIB::OKM::StandardizeTimeperiodParameter('lastyear');
    is($startDt->iso8601,
       ($thisYear-1)."-01-01T00:00:00",
       "lastyear start");
    is($endDt->iso8601,
       ($thisYear-1)."-12-31T23:59:59",
       "lastyear end");

    ($startDt, $endDt) = C4::OPLIB::OKM::StandardizeTimeperiodParameter('lastmonth');
    is($startDt->iso8601,
       $lastMonthDt->year().'-'.sprintf("%02d",$lastMonthDt->month())."-01T00:00:00",
       "lastmonth start");
    is($endDt->iso8601,
       $lastMonthDt->year().'-'.sprintf("%02d",$lastMonthDt->month())."-31T23:59:59",
       "lastmonth end");

    };
    if ($@) {
        ok(0, $@);
    }
}

done_testing();