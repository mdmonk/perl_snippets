#!/usr/bin/perl -w

use strict;
use Spreadsheet::ParseExcel;
use Spreadsheet::WriteExcel;
use Data::Dumper;

# cobbled together from examples for the Spreadsheet::ParseExcel and
# Spreadsheet::WriteExcel modules

my $sourcename = shift @ARGV;
my $destname = shift @ARGV or die "invocation: $0 <source file> <destination file>";

my $source_excel = new Spreadsheet::ParseExcel;

my $source_book = $source_excel->Parse($sourcename)
 or die "Could not open source Excel file $sourcename: $!";

my $storage_book;

foreach my $source_sheet_number (0 .. $source_book->{SheetCount}-1)
{
 my $source_sheet = $source_book->{Worksheet}[$source_sheet_number];

 print "--------- SHEET:", $source_sheet->{Name}, "\n";

 # sanity checking on the source file: rows and columns should be sensible
 next unless defined $source_sheet->{MaxRow};
 next unless $source_sheet->{MinRow} <= $source_sheet->{MaxRow};
 next unless defined $source_sheet->{MaxCol};
 next unless $source_sheet->{MinCol} <= $source_sheet->{MaxCol};

 foreach my $row_index ($source_sheet->{MinRow} .. $source_sheet->{MaxRow})
 {
  foreach my $col_index ($source_sheet->{MinCol} .. $source_sheet->{MaxCol})
  {
   my $source_cell = $source_sheet->{Cells}[$row_index][$col_index];
   if ($source_cell)
   {
    print "( $row_index , $col_index ) =>", $source_cell->Value, "\n";

    if ($source_cell->{Type} eq 'Numeric')
    {
     $storage_book->{$source_sheet->{Name}}->{$row_index}->{$col_index} = $source_cell->Value*2;
    }
    else
    {
     $storage_book->{$source_sheet->{Name}}->{$row_index}->{$col_index} = $source_cell->Value;
    } # end of if/else
   } # end of source_cell check
  } # foreach col_index
 } # foreach row_index
} # foreach source_sheet_number

print "Perl recognized the following data (sheet/row/column order):\n";
print Dumper $storage_book;

my $dest_book  = Spreadsheet::WriteExcel->new("$destname")
 or die "Could not create a new Excel file in $destname: $!";

print "\n\nSaving recognized data in $destname...";

foreach my $sheet (keys %$storage_book)
{
 my $dest_sheet = $dest_book->addworksheet($sheet);
 foreach my $row (keys %{$storage_book->{$sheet}})
 {
  foreach my $col (keys %{$storage_book->{$sheet}->{$row}})
  {
   $dest_sheet->write($row, $col, $storage_book->{$sheet}->{$row}->{$col});
  } # foreach column
 } # foreach row
} # foreach sheet

$dest_book->close();

print "done!\n";
