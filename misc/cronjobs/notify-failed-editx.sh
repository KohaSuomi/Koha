#!/bin/sh
# Send e-mail notifications of failed EDItX processing to people defined in procurement-config
# Written by Kodo Korkalo / Koha-Suomi Oy, GNU GPL3 or later applies.

# You will need to add <notifications> part to the end of your procurement-config.xml:

# <notifications>
#   <mailto>someone@somewere.com,someone@else.com</mailto>
#   <mailfrom>someone@somewere.com</mailfrom> <!-- this is optional, [user]@[host] will be used if left unset -->
# </notifications>

die() { printf "$@\n" ; exit 1 ; }

# Get, set and check variables

export xmllint="$(which xmllint)"
test -n "$xmllint" || die "No xmllint, apt install libxml2-utils."

mailer="$(which mail)"
test -n "$mailer" || die "No mail, apt install heirloom-mailx."

test -e "$KOHA_CONF" || die "No KOHA_CONF."

config_file="$(dirname $KOHA_CONF)/procurement-config.xml"
test -e "$config_file" || die "No procurement config $config_file."

mailto=$($xmllint --xpath '*/notifications/mailto/text()' $config_file 2> /dev/null)
mailfrom=$($xmllint --xpath '*/notifications/mailfrom/text()' $config_file 2> /dev/null)

export tmp_path=$($xmllint --xpath '*/settings/import_tmp_path/text()' $config_file 2> /dev/null)
export failed_path=$($xmllint --xpath '*/settings/import_failed_path/text()' $config_file 2> /dev/null)
export failed_archived_path=$($xmllint --xpath '*/settings/import_failed_archived_path/text()' $config_file 2> /dev/null)
export log_path=$($xmllint --xpath 'yazgfs/config/logdir/text()' $KOHA_CONF 2> /dev/null)

test -n "$mailfrom" && mailfrom="-r $mailfrom"
test -n "$mailto" || die "No one to send notifications to in $config_file."

test -n "$tmp_path" || die "No path to incoming EDItX messages in $config_file."
test -n "$failed_path" || die "No path to failed EDItX messages in $config_file."
test -n "$failed_archived_path" || die "No path to failed_archived EDItX messages in $config_file."
test -n "$log_path" || die "No path to logs in $KOHA_CONF."

# Get postponed and failed EDItX notices and send emails

export pending_files="$(ls -1 $tmp_path/*.xml 2> /dev/null)"
export failed_files="$(ls -1 $failed_path/*.xml 2> /dev/null)"

test -z "$pending_files" && test -z "$failed_files" && exit 0 # Exit if nothing to report

(

  if test -n "$pending_files"; then

  printf "Seuraavat EDItX sanomat odottavat edelleen käsittelyä:\n\n"

    printf "Sanomien muodostamisessa aineistontoimittajan järjestelmässä tai niiden siirrossa Koha-palvelimelle\n"
    printf "on tapahtunut virhe, tai siirto palvelimelle on edelleen kesken.\n\n"

    for file in $pending_filed; do

      if test $(stat -c %Y "$file") -lt $(($(date +%s) - 604800)); then
        printf "Sanoma $file vanhentunut ja se hylätään. Arkistoitu hakemistoon $failed_archived_path.\n"
        mv "$file" "$failed_archived_path/"
      else
        printf "Sanoma $file on jätetty käsittelyjonoon ($tmp_path) odottamaan täydennystä.\n"
      fi

      printf "\n"

    done

  fi

  if test -n "$failed_files"; then

    printf "Seuraavien EDItX sanomien käsittelyssä oli ongelmia:\n"

    for file in $failed_files; do

      printf "\n=== Sanoma: $(basename $file) ===\n\n"
      
      printf "Ote rajapinnan virhelokista ($log_path/editx/error.log):\n"
      grep "$(basename $file)" $log_path/editx/error.log -B 1 -A 1 | grep -v 'Order processing failed for file' | grep -v '^$'

      unset affected_locations
      for location in $($xmllint --xpath "*/ItemDetail/CopyDetail/DeliverToLocation" $file | sed 's/<\/*DeliverToLocation\/*>/\n/ig' | sort -u); do
        affected_locations="$affected_locations $location"
      done

      if test -n "$affected_locations"; then
        printf "\nSanoma koskee sijainteja/tilejä:$affected_locations\n"
      else
        printf "\nSijoitus- ja tilitietoja ei löytynyt sanomasta.\n"
      fi

      if ! xmllint --noout "$file" 2> /dev/null ; then
        printf "\nSanoma on formaatiltaan virheellinen ja se hylätään. Arkistoitu hakemistoon $failed_archived_path.\n"
        mv "$file" "$failed_archived_path/"
        continue
      fi

      if test $(stat -c %Y "$file") -lt $(($(date +%s) - 604800)); then
        printf "\nSanoma on vanhentunut ja se hylätään. Arkistoitu hakemistoon $failed_archived_path.\n"
        mv "$file" "$failed_archived_path/"
        continue
      fi

      printf "\nSanoma on palautettu käsittelyjonoon ($tmp_path). Käsittelyä yritetään uudelleen ajastuksen mukaisesti.\n"
      mv "$file" "$tmp_path/"

    done

  fi 

  printf "Katso lisätietoja EDItX rajapinnan parametroinnista ja tyypillisten virhetilanteiden korjaamisesta:\n"
  printf "https://tiketti.koha-suomi.fi/projects/koha-suomen-dokumentaatio/wiki/EditX-hankinta#43-Erilaisia-virhetilanteita\n"

) | $mailer $mailfrom -s "EDItX tilaussanomien käsittelyssä oli ongelmia" $mailto

# All done, exit gracefully
exit 0