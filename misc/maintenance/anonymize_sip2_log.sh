#!/bin/sh

# This script is only meant to execute under logrotate's prerotate phase
# See etc/logrotate.d/koha for logrotate configuration

if [ ! "$1" ]; then
    echo "Usage: anonymize_sip2_log.sh /path/to/sip2.log"
    exit 1
fi;

LOG_FILE=$1
ANONYMIZE_PATRON_DATA="${LOG_FILE}.1"       # sip2.log.1        (absolute path)
ANONYMIZE_CARDNUMBER="${LOG_FILE}.183.gz"   # sip2.log.183.gz   (absolute path)

if test -e $ANONYMIZE_PATRON_DATA; then
    cat $ANONYMIZE_PATRON_DATA | perl -pe "s/(ILS::Patron\().*(\): found patron ').*('.*$)/\1***\2***\3/;s/(ILS::Checkout: patron ').*(' has checked out)/\1***\2/;s/(AE|BD|BE|BF|PB|CY|DA).*?\\|/\1***|/g;" > "${ANONYMIZE_PATRON_DATA}.anon";
    cp -a "${ANONYMIZE_PATRON_DATA}.anon" $ANONYMIZE_PATRON_DATA;
    rm "${ANONYMIZE_PATRON_DATA}.anon"
fi;
if test -e $ANONYMIZE_CARDNUMBER; then
    cat $ANONYMIZE_CARDNUMBER | gunzip | perl -pe "s/(ILS::Checkout: patron ').*(' has checked out)/\1***\2/;s/(AA).*?\\|/\1***|/g;" | gzip > "${ANONYMIZE_CARDNUMBER}.anon";
    cp -a "${ANONYMIZE_CARDNUMBER}.anon" $ANONYMIZE_CARDNUMBER;
    rm "${ANONYMIZE_CARDNUMBER}.anon"
fi;

exit 0
