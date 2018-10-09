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
use Path::Tiny;
use REST::Client;
use Text::CSV_XS qw( csv );

my $endpoint = 'http://zbw.eu/beta/sparql/stw/query';

my $infile;
if ( $ARGV[0] and -f path( $ARGV[0] ) ) {
  $infile = path( $ARGV[0] );
} else {
  die "usage: $0 infile\n";
}

# broad/narrow had been reversed in jel_mapping.pl!!!
my %relation = (
  '=' => 'skos:exactMatch',
  '*' => 'skos:closeMatch',
  '<' => 'skos:broadMatch',
  '>' => 'skos:narrowMatch',
  '^' => 'skos:relatedMatch',
);

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
my $in_fh   = $infile->openr;
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
while ( my $row = $csv->getline_hr($in_fh) ) {

  # skip if first column is comment or empty
  my $first_value = $row->{ $column_names[0] };
  next if ( not $first_value or $first_value =~ /^#/ );

  my $values_line = '  ( ';
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
  $endpoint,
  $query,
  {
    'Content-type' => 'application/sparql-query',
    Accept         => 'application/sparql-results+json'
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
  my $infile = shift or die "param missing\n";
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

  my $stub1 = "
select distinct ?stw ?stwLabel ?relation ?wd ?wdLabel ?issue ?issueLabel ?note ?wdExists ?wdExistsLabel
where {
  service <https://query.wikidata.org/sparql> {
    values ( ?stw ?relation ?wd ?issueLabel ?note ) {
";
  my $stub2 = "
    }
    bind(strafter(str(?stw), str(stw:)) as ?stwId)
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
    optional {
      ?wdExists wdt:P3911 ?stwId .
    }
    optional {
      ?wdExists rdfs:label ?wdExistsLabelDe .
      filter(lang(?wdExistsLabelDe) = 'de')
    }
    optional {
      ?wdExists rdfs:label ?wdExistsLabelEn .
      filter(lang(?wdExistsLabelEn) = 'en')
    }
    bind(concat(if(bound(?wdExistsLabelDe), str(?wdExistsLabelDe), ''), ' | ', if(bound(?wdExistsLabelEn), str(?wdExistsLabelEn), '')) as ?wdExistsLabel)
  }
  ?stw skos:prefLabel ?stwLabelDe .
  filter(lang(?stwLabelDe) = 'de')
  ?stw skos:prefLabel ?stwLabelEn .
  filter(lang(?stwLabelEn) = 'en')
  bind(concat(if(bound(?stwLabelDe), str(?stwLabelDe), ''), ' | ', if(bound(?stwLabelEn), str(?stwLabelEn), '')) as ?stwLabel)
  bind(uri(concat('https://github.com/zbw/stw-mappings/issues/', strafter(?issueLabel, '#'))) as ?issue)
}
";

  my $query = $prefixes . $stub1 . $values . $stub2;
  return $query;
}

