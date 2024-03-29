#!/bin/bash
# nbt, 23.12.2022

# create directories and files für a new stw mapping

if [[ $# < 1 ]]; then
  echo "Usage: $0 {dataset}"
  exit 1
fi

# enforce dataset name in lowercase
DATASET=$1
DATASET=${DATASET,,}
UC_DATASET=${DATASET^^}

mkdir -p ../var/$DATASET

for action in add remove ; do
  file=../var/$DATASET/exception.${action}.csv
  if [ -f $file ] ; then
    echo ERROR: $file already exists
    exit 1
  else
    echo "stw:,rel,$DATASET:,issue,note" > ../var/$DATASET/exception.${action}.csv
  fi
done

echo 

for d in view rdf ; do
  mkdir -p ../var/$DATASET/$d
  touch ../var/$DATASET/$d/.gitkeep
done

cat << EOF > ../var/$DATASET/README.md
# Mapping to $UC_DATASET

## Exception lists

Type      | Readable | Source  | Note
----------|----------|---------|------
Additions | [view](http://zbw.eu/beta/sparql-lab/result?resultRef=https://api.github.com/repos/zbw/stw-mappings/contents/var/$DATASET/view/exception.add.json) | [src](exception.add.csv) | Relations to add to the mapping extracted from $UC_DATASET
Deletions | [view](http://zbw.eu/beta/sparql-lab/result?resultRef=https://api.github.com/repos/zbw/stw-mappings/contents/var/$DATASET/view/exception.remove.json) | [src](exception.remove.csv) | Relations to remove from the mapping extracted from $UC_DATASET 
EOF


if [ -f ../var/$DATASET/prefix.ttl ] ; then
  echo ERROR: ../var/$DATASET/prefix.ttl already exists
  exit 1
else
  cp ../var/gnd/prefix.ttl ../var/$DATASET
fi

echo "INFO: manual tasks"
echo "INFO: - define '$DATASET:' in ../var/$DATASET/prefix.ttl"
echo "INFO: - add 'stw_$DATASET' section to transform_execptions.pl"
echo "INFO: - add $DATASET to rebuild_exception_lists.sh"
echo "INFO: - extend ../var/$DATASET/README.md"
echo "INFO: - add link to ../README.md"


