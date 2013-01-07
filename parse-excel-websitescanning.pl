#!/usr/bin/perl -w
#----------------------------------------------------------
#
#----------------------------------------------------------
use Spreadsheet::ParseExcel;

$DEBUG = 0;
$count = 0;
@columns = (0,1,2,3,4,5,7);
@headers = ("Site", "HTTP/HTTPS", "External IP", "Internal Teros IP", "Internal IP", "Location", "Owner");
@sheets = ("External", "Internal", "FBMS");
# join using the pipe ("|") as a delimiter
my $strng = join "|", @sheets;
my $parser   = Spreadsheet::ParseExcel->new();
my $workbook = $parser->parse('Website.Scanning.2.6.2009.xls');
my $outfile = "websites.csv";

open(my $FH, '>', "$outfile") or die $!;

if ( !defined $workbook ) {
    die $parser->error(), ".\n";
}

if ($DEBUG) {
	print "Number of worksheets: " . $workbook->worksheet_count() . "\n";
	foreach (my @cl = $workbook->worksheets()) {
		print "Worksheet: " . $_->get_name() . "\n";
	}
}

print $FH join ", ", @headers;
print $FH "\n";

##WS: for my $worksheet ( $workbook->worksheets() ) {
WS: foreach $ws (@sheets) {
	my $worksheet = $workbook->worksheet($ws);
	my $sheetname = $worksheet->get_name();
	my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
	print "Processing sheet: $ws, Rows: $row_max, Columns: $col_max\n";
CWL: for my $row ( $row_min .. $row_max ) {
		#if ($row == "0") { $row++; }
		next CWL if ($row == "0");
		foreach my $col ( @columns ) {
            my $cell = $worksheet->get_cell( $row, $col );
            next unless $cell;
			next WS if ("*" . $cell->value() . "*" eq "**" && $col == 0);
			next CWL if ($cell->value() =~ m/doi.gov/);
			if ("*" . $cell->value() . "*" eq "**") {
				print $FH "BLANK, ";
			} else {
				print $FH $cell->value() . ", ";
			}
			if (utf8::is_utf8($cell->value())) {
				print "UTF8 detected at $count site, row: $row, column: $col\n";
			}
        }
		print $FH "\n";
		$count++;
    }
}
close($FH);
print "COMPLETE!\n";
print "Number of websites exported: $count\n\n";