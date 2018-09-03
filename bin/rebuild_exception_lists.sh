#!/bin/sh
# nbt, 2018-09-03

# recreate view lists from source

# stop on first error
set -e

cd /opt/stw-mappings/bin

# TODO make sure it cannot hang here
GIT_MERGE_AUTOEDIT=no
/usr/bin/git pull --quiet

for ds in dbpedia wikidata ; do
  for action in add remove ; do
    file="../var/$ds/exception.${action}.csv"
    ##echo $file
    /usr/bin/perl transform_execptions.pl $file
  done
done

# push even if commit failes (empty)
set +e
/usr/bin/git ci --quiet -m "Automatic build" ../var > /dev/null

/usr/bin/git push --quiet

