#!/bin/sh

## SYNOPSIS ##
# This script takes another script and measures it's runtime, appending it to the same log that the script's stderr and stdout go.
# First argument is the script name, relative to this scripts location.
# All arguments are passed directly to the first argument script.
#
# This script also locks the given script to prevent cronjobs from going to a repeating loop.
#

logdirectory="$(grep -Po '(?<=<logdir>).*?(?=</logdir>)' $KOHA_CONF)/cronjobs"
logfile=$logdirectory/${1##*/}.log
croncommand="$KOHA_PATH/misc/$@"
lockdirectory="/var/lock/cronjobtimer"
lockfile="$lockdirectory/${1##*/}.lock"
disableCronjobsFlag="$lockdirectory/disableCronjobs.flag"

if [ -z "$1" ]; then
  printf "You need to provide a cronscript name and it's parameters as arguments."
  exit 1
fi

#Check if cronjobs are disabled by the preproduction to production migration process
if [ -e $disableCronjobsFlag ]; then
    printf "Disabled by disableCronjobsFlag\n" >> $logfile
    exit 0
fi

# Create required directories
mkdir -p "$logdirectory" "$lockdirectory"

#Lock the cronjob we are running!
if kill -0 $(cat $lockfile 2> /dev/null) 2> /dev/null; then
   printf "$1 already locked and running!\n" >> $logfile
   exit 1
fi
echo $$ > $lockfile

starttime=$(date +%s)
startMsg='Start: '$(date --date="@$starttime" "+%Y-%m-%d %H:%M:%S")
printf "$startMsg\n" >> $logfile

$croncommand 1>> $logfile 2>&1
wait # We need to wait here so that lockfile doesn't get released too early!

endtime=$(date +%s)
runtime=$((endtime - starttime))
timelog='End: '$(date --date="@$endtime" "+%Y-%m-%d %H:%M:%S")"\n"'Runtime: '$(($runtime/60/60))':'$(($runtime/60%60))':'$(($runtime%60))

printf "$timelog\n" >> $logfile

rm -f $lockfile
