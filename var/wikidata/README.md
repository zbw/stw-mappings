# Creation of a mapping to Wikidata

The mapping "lives" in Wikidata. It is materialized via the WD property [STW Thesaurus for Economics ID](https://www.wikidata.org/wiki/Property:P3911). The property values are the descriptor ID numbers (TIN), which form the last part of each STW descriptor URI.

In the course of this mapping it proved necessary to introduce a [mapping relation type](https://www.wikidata.org/wiki/Property:P4390) qualifier to specify relations different from identity (e.g., skos:closeMatch, skos:narrowMatch). According to the discussion about the newly introduced property, an external identifier should only be added to the best matching Wikidata item.

## Exception lists

From the STW side, beyond this links more Wikidata items may be useful - e.g. if these items in turn link to Wikipedia pages or other autorities. The "Additions" list below will be instrumental for adding such links to our published STW - Wikidata mapping.

On the other side, we might disagree with links to STW created by the Wikidata community. For such cases, the (currently empty) "Deletions" list is maintained.


Type      | Readable | Source  | Note
----------|----------|---------|------
Additions | [view](http://zbw.eu/beta/sparql-lab/result?resultRef=https://api.github.com/repos/zbw/stw-mappings/contents/var/wikidata/view/exception.add.json) | [src](exception.add.csv) | Relations to add to the mapping extracted from Wikidata
Deletions | [view]() | [src]() | Relations to remove from the mapping extracted from Wikidata 


## Mapping and maintenance lists

- the [mapping in its current state](http://zbw.eu/beta/sparql-lab/?endpoint=http://zbw.eu/beta/sparql/stw/query&queryRef=https://api.github.com/repos/zbw/sparql-queries/contents/stw/wikidata_mapping.rq)
- [further reports for maintenance and quality assurance](https://www.wikidata.org/wiki/Property_talk:P3911#Reports_for_the_maintenance_of_the_STW_ID_.2F_Wikidata_mapping)



## Process (TODO)

### 1) Sub-thesaurus G (geografic names)

### 2) Sub-thesaurus W (economic sectors)
