#!/bin/bash
test -e /etc/environment && . /etc/environment
test -z "$KOHA_PATH" -o -z "$KOHA_CONF" && echo "No KOHA_PATH or KOHA_CONF." && exit 1
test -z "$1" -o -z "$2" && echo "Required parameters missing." && exit 1
$KOHA_PATH/misc/cronjobs/runBilling.pl "$@"
sftpconfig="$(dirname $KOHA_CONF)/$2_sftp.conf"
test ! -e "$sftpconfig" && echo "No billing sftp config for $2." && exit 1
. $sftpconfig
test -z "$SSHPORT" && export SSHPORT="22"
billingconfig="$(dirname $KOHA_CONF)/outibilling.xml"
test ! -e "$billingconfig" && echo "No billing config" && exit 1
stagingdir=$(xmllint --xpath "config/branchcategories/$2/targetdir/text()" $billingconfig)
for transferfile in $(ls -1 $stagingdir/*.dat); do
  filename="$FILEPREFIX$(basename $transferfile)"
  sshpass -e sftp -P $SSHPORT $SSHUSER@$SSHHOST <<< $"put $transferfile $SSHDIR/$filename" && mv $transferfile $stagingdir/siirretty/
done
