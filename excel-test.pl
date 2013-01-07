#!/usr/bin/env perl

use Spreadsheet::ParseExcel;

@columns = (0,1,2,3,4,5,7);
@headers = ("Site", "HTTP/HTTPS", "External IP", "Internal Teros IP", "Internal IP", "Location", "Owner");
@sheets = ("External", "Internal", "FBMS");
# join using the pipe ("|") as a delimiter
my $strng = join "|", @sheets;
my $parser   = Spreadsheet::ParseExcel->new();
my $workbook = $parser->parse('Website.Scanning.2.6.2009.xls');

if ( !defined $workbook ) {
    die $parser->error(), ".\n";
}

WS: foreach $ws (@sheets) {
	my $worksheet = $workbook->worksheet($ws);
	my $sheetname = $worksheet->get_name();
	my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
	print "Processing sheet: $ws, Rows: $row_max, Columns: $col_max\n";
CWL: for my $row ( $row_min .. $row_max ) {
		next CWL if ($row == "0");
		foreach my $col ( @columns ) {
            my $cell = $worksheet->get_cell( $row, $col );
            next unless $cell;
			next WS if ("*" . $cell->value() . "*" eq "**" && $col == 0);
			print "Row, Col    = ($row, $col)\n";
			if ("*" . $cell->value() . "*" eq "**") {
				print "BLANK\n";
			} else {
				print "Value       = *", $cell->value(),       "*\n";
				print "Unformatted = *", $cell->unformatted(), "*\n";
			}
        }
    }
}