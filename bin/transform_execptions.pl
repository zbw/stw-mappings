#!/usr/bin/env perl
# nbt, 2018-08-15

# Create from CSV
#   1) a SPARQL query and result set with labels and links
#   2) a turtle file with exception triples (without the notes)

# Creating view file from turtle file DOES NOT WORK, because the notes cannot
# be attached to the exception triple without reification.

use strict;
use warnings;

use Data::Dumper;
use Path::Tiny;
use REST::Client;
use Text::CSV_XS qw( csv );

my $endpoint = 'http://zbw.eu/beta/sparql/stw/query';

my $infile;
if ( -f path( $ARGV[0] ) ) {
  $infile = path( $ARGV[0] );
} else {
  die "usage: $0 infile\n";
}

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
while ( my $row = $csv->getline_hr($in_fh) ) {

  # skip if first column is comment or empty
  my $first_value = $row->{ $column_names[0] };
  next if ( not $first_value or $first_value =~ /^#/ );

  my $values_line = '  ( ';
  foreach my $column_name (@column_names) {
    my $column_value;
    if ( grep( /^$column_name$/, @prefixed_columns ) ) {
      $column_value = "$column_name$row->{$column_name}";
    } elsif ( $column_name eq "rel" ) {

      # TODO
    } else {
      $column_value = "\"$row->{$column_name}\"";
    }

    # output for query values clause
    $values_line .= "$column_value ";

    # output for turtle file
    next if grep( /^$column_name$/, @skip_columns );
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
select ?stw ?stwLabel ?relation ?wd ?wdLabel ?issue ?issueLabel ?note
where {
  values ( ?stw ?relation ?wd ?issueLabel ?note ) {
";
  my $stub2 = "
  }
  service <https://query.wikidata.org/sparql> {
    ?wd rdfs:label ?wdLabelLang .
    filter(lang(?wdLabelLang) = 'de')
    bind(str(?wdLabelLang) as ?wdLabel)
  }
  ?stw skos:prefLabel ?stwLabelLang .
  filter(lang(?stwLabelLang) = 'de')
  bind(str(?stwLabelLang) as ?stwLabel)
  bind(uri(concat('https://github.com/zbw/stw-mappings/issues/', strafter(?issueLabel, '#'))) as ?issue)
}
";

  my $query = $prefixes . $stub1 . $values . $stub2;
  return $query;
}

