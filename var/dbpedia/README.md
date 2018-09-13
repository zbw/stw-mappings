# Legacy mapping to DBpedia

The mapping had been created in 2009/2010 in an automated approach. It will be replaced by a mapping derived from dbpedia, when the STW ./. Wikidata mapping will have been finished.

## Exception lists

On the one side, we know about wrong mappings which had been automatically created. For such cases, the "Deletions" list is maintained. On the other side, there is a list of "Additions" to add links manually.


Type      | Readable | Source  | Note
----------|----------|---------|------
Additions | [view](http://zbw.eu/beta/sparql-lab/result?resultRef=https://api.github.com/repos/zbw/stw-mappings/contents/var/dbpedia/view/exception.add.json) | [src](exception.add.csv) | Relations to add to the mapping automatically generated mapping
Deletions | [view](http://zbw.eu/beta/sparql-lab/result?resultRef=https://api.github.com/repos/zbw/stw-mappings/contents/var/dbpedia/view/exception.remove.json) | [src](exception.remove.csv) | Relations to remove from the automatically generated mapping


