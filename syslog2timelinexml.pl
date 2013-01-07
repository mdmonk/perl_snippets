#!/usr/bin/perl
use XML::Writer;
my $writer = XML::Writer->new();
$writer->xmlDecl();
$writer->startTag('data');

$thisyear=((localtime)[5]+1900);

while( <> ) {
  # The if() is all one line.
  if( /([a-zA-Z ]+[0-9]+) ([0-9]+
:[0-9]+:[0-9]+) ([^:]+):(.*)/)
  {
    $date=$1; $time=$2;
    $src=$3;
    $msg=$4;
    $writer->startTag(
      'event',
      'start' => "$date $thisyear $time",
      'title' => $src
    );
    $writer->characters( $msg );
    $writer->endTag('event');
  }
}

$writer->endTag('data');
$writer->end();
