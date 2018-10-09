#!/bin/sh
# nbt, 29.8.2018

# create quickstatements which set all empty mapping relation qualifiers
# for a property to a default (as defined in the query file)

perl /opt/sparql-queries/bin/make_qs_input.pl /opt/sparql-queries/wikidata/mapping_relation_qualifier_qs2.rq qs2

