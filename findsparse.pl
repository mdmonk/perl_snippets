#!/usr/bin/env perl

use strict;
use warnings;
use File::Find;

sub process_file {
	my $f=$File::Find::name;
	(my $dev,my $ino,my $mode,my $nlink,my $uid,my $gid,my  $rdev,my $size,my $atime,my $mtime,my $ctime,my $blksize,my $blocks) = stat($f);

	if ($blocks * 512 < $size) {
		print "\t$f => SZ: $size BLSZ: $blksize BLKS: $blocks\n";
		print "\t" . -s $f;
		print "\n";
	}
}

##find(\&process_file,("/home/sparse-files"));
find(\&process_file,("/home/clittle"));
