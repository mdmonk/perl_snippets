#!/usr/bin/perl -w
# $Id$
# Give the ATIME, MTIME and CTIME of all readable files listed in @ARGV.

use strict;

sub showtimes {
	# Local initialisation
	my ($atime,$mtime,$ctime);
	my $file;
	my @files = @_;

	for $file (@files) {
		next unless -r $file;
		($atime,$mtime,$ctime) = (stat $file)[8,9,10];
#		print "$file: ATIME $atime, MTIME $mtime, CTIME $ctime\n";
		print "$file $atime $mtime\n";
	}
}

&showtimes(@ARGV);
