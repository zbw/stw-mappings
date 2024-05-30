#!/usr/bin/env perl
# nbt, 2018-08-15

# Create from CSV
#   1) a SPARQL query and result set with labels and links
#   2) a turtle file with exception triples (without the notes)

# Creating view file from turtle file DOES NOT WORK, because the notes cannot
# be attached to the exception triple without reification.

use strict;
use warnings;
use utf8;

use Data::Dumper;
use Encode;
use Path::Tiny;
use REST::Client;
use Text::CSV_XS qw( csv );

# In order to extend the csv to a viewable HTML table (via json with YASR),
# an endpoint and a query to retrieve accordings labels has to be provided
# in the configuration
my %config = (
  stw_wikidata => {
    target     => 'wikidata',
    source_col => 'stw',
    target_col => 'wd',
    endpoint   => 'http://zbw.eu/beta/sparql/stw/query',
    query      => '
select distinct (str(?line) as ?ln)  ?stw ?stwLabel ?relation ?wd ?wdLabel ?issue ?issueLabel ?note ?wdExists ?wdExistsLabel
where {
  service <https://query.wikidata.org/sparql> {
    values ( ?line ?stw ?relation ?wd ?issueLabel ?note ) {
      ( 2 stw:30083-1 ">" wd:Q4127 "#1" "alle WP-Seiten hängen hier"  )
    }
    optional {
      ?wd rdfs:label ?wdLabelDe .
      filter(lang(?wdLabelDe) = "de")
    }
    optional {
      ?wd rdfs:label ?wdLabelEn .
      filter(lang(?wdLabelEn) = "en")
    }
    bind(concat(if(bound(?wdLabelDe), str(?wdLabelDe), ""), " | ", if(bound(?wdLabelEn), str(?wdLabelEn), "")) as ?wdLabel)
    #
    bind(strafter(str(?stw), str(stw:)) as ?stwId)
    #
    optional {
      ?wdExists wdt:P3911 ?stwId .
      optional {
        ?wdExists rdfs:label ?wdExistsLabelDe .
        filter(lang(?wdExistsLabelDe) = "de")
      }
      optional {
        ?wdExists rdfs:label ?wdExistsLabelEn .
        filter(lang(?wdExistsLabelEn) = "en")
      }
    }
    bind(concat(if(bound(?wdExistsLabelDe), str(?wdExistsLabelDe), ""), " | ", if(bound(?wdExistsLabelEn), str(?wdExistsLabelEn), "")) as ?wdExistsLabel)
  }
  ?stw skos:prefLabel ?stwLabelDe .
  filter(lang(?stwLabelDe) = "de")
  ?stw skos:prefLabel ?stwLabelEn .
  filter(lang(?stwLabelEn) = "en")
  bind(concat(if(bound(?stwLabelDe), str(?stwLabelDe), ""), " | ", if(bound(?stwLabelEn), str(?stwLabelEn), "")) as ?stwLabel)
  bind(uri(concat("https://github.com/zbw/stw-mappings/issues/", strafter(?issueLabel, "#"))) as ?issue)
}
order by ?line
',
  },
  stw_dbpedia => {
    target     => 'dbpedia',
    source_col => 'stw',
    target_col => 'dbr',
    endpoint   => 'http://zbw.eu/beta/sparql/stw/query',
    query      => '
select distinct (str(?line) as ?ln)  ?stw ?stwLabel ?relation ?dbr ?dbrLabel ?issue ?issueLabel ?note
where {
  service <http://dbpedia.org/sparql> {
    values ( ?line ?stw ?relation ?dbr ?issueLabel ?note ) {
      ( 2 stw:16977-5 "=" dbr:Canton_of_Uri "#2" " "  )
    }

    optional {
      ?dbr rdfs:label ?dbrLabelDe .
      filter(lang(?dbrLabelDe) = "de")
    }
    optional {
      ?dbr rdfs:label ?dbrLabelEn .
      filter(lang(?dbrLabelEn) = "en")
    }
    bind(concat(if(bound(?dbrLabelDe), str(?dbrLabelDe), ""), " | ", if(bound(?dbrLabelEn), str(?dbrLabelEn), "")) as ?dbrLabel)
  }
  ?stw skos:prefLabel ?stwLabelDe .
  filter(lang(?stwLabelDe) = "de")
  ?stw skos:prefLabel ?stwLabelEn .
  filter(lang(?stwLabelEn) = "en")
  bind(concat(if(bound(?stwLabelDe), str(?stwLabelDe), ""), " | ", if(bound(?stwLabelEn), str(?stwLabelEn), "")) as ?stwLabel)
  bind(uri(concat("https://github.com/zbw/stw-mappings/issues/", strafter(?issueLabel, "#"))) as ?issue)
}
order by ?line
',
  },
  stw_gnd => {
    target     => 'gnd',
    source_col => 'stw',
    target_col => 'gnd',
    endpoint   => 'http://zbw.eu/beta/sparql/stw/query',
    query      => '
select distinct (str(?line) as ?ln)  ?stw ?stwLabel ?relation ?gnd ?gndLabel ?issue ?issueLabel ?note
where {
  service <http://zbw.eu/beta/sparql/gnd/query> {
    values ( ?line ?stw ?relation ?gnd ?issueLabel ?note ) {
      ( 2 stw:10928-6 "=" gnd:4334934-1 " " "GND CK Bug"  )
    }

    optional {
      ?gnd gndo:preferredNameForTheSubjectHeading ?gndLabel .
    }
    #
    bind(strafter(str(?stw), str(stw:)) as ?stwId)
    #
  }
  ?stw skos:prefLabel ?stwLabelDe .
  filter(lang(?stwLabelDe) = "de")
  ?stw skos:prefLabel ?stwLabelEn .
  filter(lang(?stwLabelEn) = "en")
  bind(concat(if(bound(?stwLabelDe), str(?stwLabelDe), ""), " | ", if(bound(?stwLabelEn), str(?stwLabelEn), "")) as ?stwLabel)
  bind(uri(concat("https://github.com/zbw/stw-mappings/issues/", strafter(?issueLabel, "#"))) as ?issue)
}
order by ?line
',
  },

  stw_agrovoc => {
    target     => 'agrovoc',
    source_col => 'stw',
    target_col => 'agrovoc',
    endpoint   => 'http://zbw.eu/beta/sparql/stw/query',
    query      => '
select distinct (str(?line) as ?ln)  ?stw ?stwLabel ?relation ?agrovoc ?agrovocLabel ?issue ?issueLabel ?note
where {
  service <http://zbw.eu/beta/sparql/agrovoc/query> {
    values ( ?line ?stw ?relation ?agrovoc ?issueLabel ?note ) {
      ( 2 stw:19316-6 "=" agrovoc:c_34241 " " "missing"  )
    }

    optional {
      ?agrovoc skos:prefLabel ?agrovocLabelEn .
      filter(lang(?agrovocLabelEn) = "en")
    }
    optional {
      ?agrovoc skos:prefLabel ?agrovocLabelDe .
      filter(lang(?agrovocLabelDe) = "de")
    }
    bind(concat(if(bound(?agrovocLabelDe), str(?agrovocLabelDe), ""), " | ", if(bound(?agrovocLabelEn), str(?agrovocLabelEn), "")) as ?agrovocLabel)
    #
    bind(strafter(str(?stw), str(stw:)) as ?stwId)
    #
  }
  ?stw skos:prefLabel ?stwLabelDe .
  filter(lang(?stwLabelDe) = "de")
  ?stw skos:prefLabel ?stwLabelEn .
  filter(lang(?stwLabelEn) = "en")
  bind(concat(if(bound(?stwLabelDe), str(?stwLabelDe), ""), " | ", if(bound(?stwLabelEn), str(?stwLabelEn), "")) as ?stwLabel)
  bind(uri(concat("https://github.com/zbw/stw-mappings/issues/", strafter(?issueLabel, "#"))) as ?issue)
}
order by ?line
',
  },

  # Non-STW mappings

  pm20ag_wd => {
    source_col => 'pm20ag',
    target_col => 'wd',
    endpoint   => 'http://zbw.eu/beta/sparql/pm20/query',
    query      => '
select distinct (str(?line) as ?ln)  ?pm20ag ?pm20agLabel ?relation ?wd ?wdLabel ?issue ?note
where {
  service <https://query.wikidata.org/sparql> {
    values ( ?line ?pm20ag ?relation ?wd ?issueLabel ?note ) {
      ( 2 pm20ag:141729 "=" wd:Q42530 " " " "  )
    }
    optional {
      ?wd rdfs:label ?wdLabelDe
      filter(lang(?wdLabelDe) = "de")
    }
    optional {
      ?wd rdfs:label ?wdLabelEn .
      filter(lang(?wdLabelEn) = "en")
    }
    bind(concat(if(bound(?wdLabelDe), str(?wdLabelDe), ""), " | ", if(bound(?wdLabelEn), str(?wdLabelEn), "")) as ?wdLabel)
  }
  graph <http://zbw.eu/beta/ag/ng> {
    ?pm20ag skos:prefLabel ?pm20agLabelDe .
    filter(lang(?pm20agLabelDe) = "de")
    ?pm20ag skos:prefLabel ?pm20agLabelEn .
    filter(lang(?pm20agLabelEn) = "en")
    bind(concat(if(bound(?pm20agLabelDe), str(?pm20agLabelDe), ""), " | ", if(bound(?pm20agLabelEn), str(?pm20agLabelEn), "")) as ?pm20agLabel)
  }
}
order by ?line
',
  },
);

# broad/narrow had been reversed in jel_mapping.pl!!!
my %relation = (
  '=' => 'skos:exactMatch',
  '*' => 'skos:closeMatch',
  '<' => 'skos:broadMatch',
  '>' => 'skos:narrowMatch',
  '^' => 'skos:relatedMatch',
);

my ( $infile, $config_name );
if ( not $ARGV[1] ) {
  die "usage: $0 configuration infile\n";
}
if ( -f path( $ARGV[1] ) ) {
  $infile = path( $ARGV[1] );
} else {
  die "input file $ARGV[1] is missing\n";
}
$config_name = $ARGV[0];
if ( not defined $config{$config_name} ) {
  die "configuration $config_name not in [ "
    . join( ' ', keys %config ) . " ]\n";
}

# initialize selected configuration
my $conf = $config{$config_name};

# prefixes and columns
my %prefix = %{ read_prefixes($infile) };
my $prefixes;
# NOTE: Prefixes should be sorted consistently to ensure idempotent behavior. 
# I.e. the output files should only change if there are actual content-wise 
# changes...
foreach my $prefix ( sort keys %prefix ) {
  $prefixes .= "PREFIX $prefix $prefix{$prefix}\n";
}
$prefixes .= "#\n";
my @prefixed_columns = keys %prefix;
my @skip_columns     = qw/ issue note /;
my @legal_columns    = ( @prefixed_columns, @skip_columns );

# file handling
my $ttlfile =
  $infile->parent->child('rdf')->child( $infile->basename('.csv') . '.ttl' );
my $jsonfile =
  $infile->parent->child('view')->child( $infile->basename('.csv') . '.json' );
my $in_fh   = $infile->openr_utf8;
my $ttl_fh  = $ttlfile->openw;
my $json_fh = $jsonfile->openw;

# print turtle header
print $ttl_fh $prefixes;

# initialize CSV object
my $csv = Text::CSV_XS->new(
  {
    binary    => 1,
    auto_diag => 1,
  }
);

# get field names from the first row
$csv->header($in_fh);
my @column_names = $csv->column_names();

# iterate over csv lines
my @values;
my $line_no = 1;
while ( my $row = $csv->getline_hr($in_fh) ) {

  $line_no++;

  # skip if first column is comment or empty
  my $first_value = $row->{ $column_names[0] };
  next if ( not $first_value or $first_value =~ /^#/ );

  my $values_line = "  ( $line_no ";
  foreach my $column_name (@column_names) {

    my $column_value = $row->{$column_name};

    # validate rel value and provide translation
    my $skos_relation;
    if ( $column_name eq 'rel' ) {
      if ( defined $relation{$column_value} ) {
        $skos_relation = $relation{$column_value};
      } else {
        die "Wrong rel value '$column_value' in line $line_no of file $infile\n";
      }
    }

    if ( grep( /^$column_name$/, @prefixed_columns ) ) {
      $column_value = "$column_name$column_value";
    } else {
      if ( length($column_value) gt 0 ) {
        $column_value = "\"$column_value\"";
      } else {
        $column_value = "\" \"";
      }
    }

    # output for query values clause
    $values_line .= "$column_value ";

    # output for turtle file
    next if grep( /^$column_name$/, @skip_columns );

    # replace rel symbol with property
    if ( $column_name eq 'rel' ) {
      $column_value = $skos_relation;
    }
    print $ttl_fh "$column_value ";
  }
  print $ttl_fh ".\n";
  push( @values, " $values_line )" );
}
my $values = join( "\n", @values ) . "\n";

my $query = build_query( $prefixes, $values, $conf->{query} );

my $client = REST::Client->new();

$client->POST(
  $conf->{endpoint},
  $query,
  {
    'Content-type' => 'application/sparql-query; charset=utf8',
    Accept         => 'application/sparql-results+json',
  }
);
if ( $client->responseCode() ne '200' ) {
  die "Query terminated with "
    . $client->responseCode() . "\n"
    . $client->responseContent() . "\n";
}
print $json_fh $client->responseContent();

##################################

sub read_prefixes {
  my $infile     = shift or die "param missing\n";
  my $prefixfile = $infile->parent->child('prefix.ttl');

  my %prefix;

  my @lines = split( /\n/, $prefixfile->slurp );
  foreach my $line (@lines) {
    next if length($line) lt 10 or $line =~ m/^#/;

    ( $line =~ m/^PREFIX\s+(.*?:)\s+(<.*?>)\s*$/ )
      or die "Could not parse $prefixfile\n";
    $prefix{$1} = $2;
  }
  return \%prefix;
}

sub build_query {
  my $prefixes = shift or die "param missing\n";
  my $values   = shift or die "param missing\n";
  my $query    = shift or die "param missing\n";

  # insert values
  $query =~ s/ ( \s+ values \s+ .*? \s+ { ) .*? \s+ } /$1\n$values\n}/ixms;

  $query = encode_utf8( $prefixes . $query );
  ##print "\n$query\n";

  return $query;
}

