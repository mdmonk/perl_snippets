#!/usr/bin/perl

use strict;
use warnings;

use Spreadsheet::ParseExcel;


my $file = "SAMReport.xls";

my $workbook = Spreadsheet::ParseExcel::Workbook->Parse($file)or die "Unable to open $file\n";

#locate columns in the spreadsheet from which we want to extract data
foreach my $sheet (@{$workbook->{Worksheet}}) {
print "Sheet number $sheet\n";

	foreach my $col ($sheet->{MinCol} .. $sheet->{MaxCol}) {
		if ($sheet->{Cells}[0][$col]->{Val} eq "Site Number") {
			my $siteid = $col;
		}

		if ($sheet->{Cells}[0][$col]->{Val} eq "Site Name") {
			my $name = $col;
		}

		if ($sheet->{Cells}[0][$col]->{Val} eq "Address") {
			my $address = $col;
		}

		if ($sheet->{Cells}[0][$col]->{Val} eq "City") {
			my $city = $col;
		}

		if ($sheet->{Cells}[0][$col]->{Val} eq "State") {
			my $state = $col;
		}

		if ($sheet->{Cells}[0][$col]->{Val} eq "Zip Code") {
			my $zip = $col;
		}
	}

#iterate through spreadsheet rows and extract site.siteid, site.name, site.address, site.city, site.state, site.zip
foreach my $row ($sheet->{MinRow}+1 .. $sheet->{MaxRow}) {

	my $site_number = $sheet->{Cells}[$row][$siteid];
	my $site_name = $sheet->{Cells}[$row][$name];
	my $site_address = $sheet->{Cells}[$row][$address];
	my $site_city = $sheet->{Cells}[$row][$city];
	my $site_state = $sheet->{Cells}[$row][$state];
	my $site_zip = $sheet->{Cells}[$row][$zip];

#print captured output
	print "$site_number\n";
	print "$site_name\n";
	print "$site_address\n";
	print "$site_city\n";
	print "$site_state\n";
	print "$site_zip\n";

	}
}
exit;
