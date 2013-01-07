#!/usr/bin/perl
## genHtmlCal#
# Generate a html version of cal for the current month.#
# $Id$
# (C) Copyright 1998 Jauder Ho <jauderho@carumba.com>#
#
# Modified 03/14/99 by Brett Schlank
#
# -- Added place holders for null days when the month does not begin on a monday.

my $month;
open(CAL,"cal |") or die "Cannot get output from cal\n";
$month = <CAL>;

($month) = ($month =~ /\s+(\w+)\s+/);
# Grab only the first part.
print "<table>\n";
print "<tr>\n<td colspan=7 align=center>$month</td>\n</tr>\n";

for (<CAL>) {
	my @row;
	s/   /## /g;
	s/\s*$//;
	s/^\s+//;

	print "<tr>\n";
	(@row) = split(/\s+/,$_);

	for (@row) {
		s/##/ /g;
		print "<td align=right>$_</td>\n";
	}
	print "</tr>\n";
}

