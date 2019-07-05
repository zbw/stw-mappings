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

my %config = (
  stw_wikidata => {
    endpoint   => 'http://zbw.eu/beta/sparql/stw/query',
    target     => 'wikidata',
    source_col => 'stw',
    target_col => 'wd',
  },
  stw_dbpedia => {
    endpoint   => 'http://zbw.eu/beta/sparql/stw/query',
    target     => 'dbpedia',
    source_col => 'stw',
    target_col => 'dbr',
  },
  stw_gnd => {
    endpoint   => 'http://zbw.eu/beta/sparql/stw/query',
    target     => 'gnd',
    source_col => 'stw',
    target_col => 'gnd',
  },
);

my %target = (
  wikidata => {
    datasource => 'service <https://query.wikidata.org/sparql>',
    statements => "
      optional {
        ?wd rdfs:label ?wdLabelDe .
        filter(lang(?wdLabelDe) = 'de')
      }
      optional {
        ?wd rdfs:label ?wdLabelEn .
        filter(lang(?wdLabelEn) = 'en')
      }
      bind(concat(if(bound(?wdLabelDe), str(?wdLabelDe), ''), ' | ', if(bound(?wdLabelEn), str(?wdLabelEn), '')) as ?wdLabel)
      #
      bind(strafter(str(?stw), str(stw:)) as ?stwId)
      #
      optional {
        ?wdExists wdt:P3911 ?stwId .
        optional {
          ?wdExists rdfs:label ?wdExistsLabelDe .
          filter(lang(?wdExistsLabelDe) = 'de')
        }
        optional {
          ?wdExists rdfs:label ?wdExistsLabelEn .
          filter(lang(?wdExistsLabelEn) = 'en')
        }
      }
      bind(concat(if(bound(?wdExistsLabelDe), str(?wdExistsLabelDe), ''), ' | ', if(bound(?wdExistsLabelEn), str(?wdExistsLabelEn), '')) as ?wdExistsLabel)",
  },
  dbpedia => {
    datasource => 'service <http://dbpedia.org/sparql>',
    statements => "
      optional {
        ?dbr rdfs:label ?dbrLabelDe .
        filter(lang(?dbrLabelDe) = 'de')
      }
      optional {
        ?dbr rdfs:label ?dbrLabelEn .
        filter(lang(?dbrLabelEn) = 'en')
      }
      bind(concat(if(bound(?dbrLabelDe), str(?dbrLabelDe), ''), ' | ', if(bound(?dbrLabelEn), str(?dbrLabelEn), '')) as ?dbrLabel)",
  },
  gnd => {
    datasource => 'service <http://zbw.eu/beta/sparql/gnd/query>',
    statements => "
      optional {
        ?gnd gndo:preferredNameForTheSubjectHeading ?gndLabel .
      }
      #
      bind(strafter(str(?stw), str(stw:)) as ?stwId)
      #
      ",
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
if ( $ARGV[1] and -f path( $ARGV[1] ) ) {
  $infile = path( $ARGV[1] );
} else {
  die "usage: $0 configuration infile\n";
}
$config_name = $ARGV[0];
if ( not defined $config{$config_name} ) {
  die "configuration $config_name not in [ "
    . join( ' ', keys %config ) . " ]\n";
}

# initialize selected configuration
my $conf   = $config{$config_name};
my $target = $target{ $conf->{target} };

# prefixes and columns
my %prefix = %{ read_prefixes($infile) };
my $prefixes;
foreach my $prefix ( keys %prefix ) {
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
        die "Wrong rel value '$column_value'\n";
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

my $query = build_query( $prefixes, $values );

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

  my $src = $conf->{source_col};
  my $tgt = $conf->{target_col};

  my $stub1 = "
select distinct (str(?line) as ?ln)  ?$src ?${src}Label ?relation ?$tgt ?${tgt}Label ?issue ?issueLabel ?note ?${tgt}Exists ?${tgt}ExistsLabel
where {
  $target->{datasource} {
    values ( ?line ?$src ?relation ?$tgt ?issueLabel ?note ) {
";
  my $stub2 = "
    }
    $target->{statements}
  }
  ?stw skos:prefLabel ?stwLabelDe .
  filter(lang(?stwLabelDe) = 'de')
  ?stw skos:prefLabel ?stwLabelEn .
  filter(lang(?stwLabelEn) = 'en')
  bind(concat(if(bound(?stwLabelDe), str(?stwLabelDe), ''), ' | ', if(bound(?stwLabelEn), str(?stwLabelEn), '')) as ?stwLabel)
  bind(uri(concat('https://github.com/zbw/stw-mappings/issues/', strafter(?issueLabel, '#'))) as ?issue)
}
order by ?line
";

  my $query = encode_utf8( $prefixes . $stub1 . $values . $stub2 );
  print "\n$query\n";
  return $query;
}

