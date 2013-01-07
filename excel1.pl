#!/usr/bin/env perl -w
use strict;
use Spreadsheet::ParseExcel;
 
my $FILE = "<filename>";
my $SHEETNAME = "<worksheetname>";
 
# the column that contains searchable key
my $KEY_COLUMN = 1;
 
my $searchstring = $ARGV[0];

if (! "$searchstring") {
	die "You must provide a search string! $!\n";
}
 
my $excel = Spreadsheet::ParseExcel::Workbook->Parse($FILE);
my $sheet = $excel->Worksheet($SHEETNAME);
 
foreach my $row ($sheet->{MinRow} .. $sheet->{MaxRow})
{
  my $key	= $sheet->Cell($row,$KEY_COLUMN);
 
  if($key)
  {
    my $f1	= $sheet->Cell($row,0);
    my $f2	= $sheet->Cell($row,2);
    my $f3	= $sheet->Cell($row,3);
	my $f4	= $sheet->Cell($row,6);
	
    if($key->Value() =~ m/$searchstring/)
    {
      print "\n\n";
      print "Key: " . $key->Value() . "\n";
      print "Field 1: " . $f1->Value() . "\n" if($f1);
      print "Field 2: " . $f2->Value() . "\n" if($f2);
      print "Field 3: " . $f3->Value() . "\n" if($f3);
      print "Field 4: " . $f4->Value() . "\n" if($f4);
      print "\n\n";
    }
  }
}