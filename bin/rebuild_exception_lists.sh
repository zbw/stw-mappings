#!/bin/sh
# nbt, 2018-09-03

# recreate view lists from source

# stop on first error
set -e

cd /opt/stw-mappings/bin

# TODO make sure it cannot hang here
GIT_MERGE_AUTOEDIT=no
/usr/bin/git pull --quiet

for ds in dbpedia wikidata gnd agrovoc ; do
  for action in add remove ; do
    file="../var/$ds/exception.${action}.csv"
    ##echo $file
    /usr/bin/perl transform_execptions.pl stw_$ds $file
  done
done

# push even if commit failes (empty)
set +e
GIT_COMMITTER_NAME="stw-mappings-bot" GIT_COMMITTER_EMAIL="noreply@zbw.eu" \
  /usr/bin/git commit --quiet --author "stw-mappings-bot <noreply@zbw.eu>" -m "Update exception lists" ../var > /dev/null

/usr/bin/git push --quiet

