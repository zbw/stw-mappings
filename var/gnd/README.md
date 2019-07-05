# Mapping to GND

The mapping is maintained in the GND database. 

## Exception lists

The conversion procedure from the GND database to the RDF dump of GND contains a long-existing bug, which results in highly missleading relations, e.g. GND "Goldmarkt" is set as an exact match to STW "Markt". These have to be filtered out in order to avoid wrong retrieval results.

Type      | Readable | Source  | Note
----------|----------|---------|------
Additions | [view](http://zbw.eu/beta/sparql-lab/result?resultRef=https://api.github.com/repos/zbw/stw-mappings/contents/var/gnd/view/exception.add.json) | [src](exception.add.csv) | Relations to add to the mapping extracted from GND
Deletions | [view](http://zbw.eu/beta/sparql-lab/result?resultRef=https://api.github.com/repos/zbw/stw-mappings/contents/var/gnd/view/exception.remove.json) | [src](exception.remove.csv) | Relations to remove from the mapping extracted from GND 


