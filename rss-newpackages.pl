#!/usr/bin/perl

use File::Find;
use XML::RSS;
use Storable;

#use utf8;
use strict;

use vars qw(
	$CUTOFF
	$DAYS
	$DOCVS
	$NOW
	$PREFIX
	$SCP

	@FILES

	$STABLE_RSS
	$UNSTABLE_RSS
	%STABLE_PACKAGES
	%UNSTABLE_PACKAGES

	$CACHE
);

$DAYS   = 1.5; # number of days to look back
$NOW    = time;
$CUTOFF = ($NOW - (60 * 60 * 24 * $DAYS));
$PREFIX = '/tmp/fink-rss';
$SCP    = 1;
$DOCVS  = 0;

if (-f '/tmp/rss.cache') {
	$CACHE = retrieve('/tmp/rss.cache');
}

$ENV{CVS_RSH} = '/Users/ranger/bin/ssh.sh';

print "- updating cvs repository... ";
`mkdir -p '$PREFIX'`;
`cd $PREFIX; rsync -azvr rsync://master.us.finkmirrors.net/finkinfo/ dists >$PREFIX/rsync.log 2>&1`;
print "done\n";

print "- searching for new info files...\n";
find(\&find_infofiles, $PREFIX);

print "- generating RSS...\n";
make_rss(\%STABLE_PACKAGES, 'Stable');
make_rss(\%UNSTABLE_PACKAGES, 'Unstable');

store($CACHE, '/tmp/rss.cache');

if ($SCP) {
	print "- copying feeds to the Fink website... ";
	system('echo > /tmp/rss-rsync.log');
	my $newfiles;
	for my $file (@FILES) {
		$newfiles .= ' ' . $file . '.new';
	}
	`rsync -av -e /Users/ranger/bin/ssh.sh $newfiles rangerrick\@fink.sourceforge.net:/home/groups/f/fi/fink/htdocs/news/ >/tmp/rss-rsync.log 2>&1`;

	my $movecommands;
	for my $file (@FILES) {
		$movecommands .= "; mv news/${file}.new news/${file}; chgrp fink news/${file}";
	}
	`/Users/ranger/bin/ssh.sh rangerrick\@fink.sourceforge.net 'cd /home/groups/f/fi/fink/htdocs; ./fix_perm.sh $movecommands' >/dev/null 2>&1`;
	print "done\n";
}

sub w3c_date {
	my @time = localtime(int(shift));
	$time[5] += 1900;
	$time[4] += 1;

	return sprintf('%04d-%02d-%02dT%02d:%02d:%02d-05:00', $time[5], $time[4], $time[3], $time[2], $time[1], $time[0]);
}

sub iso_date {
	my @time = localtime(int(shift));
	$time[5] += 1900;
	#$time[4] += 1;

	my @days   = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
	my @months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

	return sprintf('%s, %02d %s %04d %02d:%02d:%02d EST', $days[$time[6]], $time[3], $months[$time[4]], $time[5], $time[2], $time[1], $time[0]);
}

sub get_cvs_log {
	my $path = shift;
	my $file = shift;

	$path =~ s/'/\\'/g;
	$file =~ s/'/\\'/g;

	# get the revision from status
	chomp(my $status = `cd '$path' && cvs status '$file' 2>/dev/null | grep 'Working revision'`);
	(undef, $status) = split(/\s*:\s*/, $status);

	my ($author, $logentry);
	my $indesc = 0;

	# now find the log for that revision
	open(CVSLOG, "cd '$path' && cvs log -r $status '$file' 2>/dev/null |") or die "can't get a log for $file: $!\n";
	while (my $line = <CVSLOG>) {
		if ($line =~ /date:.* author:\s*(\S+)\;/) {
			$author = $1;
			$indesc = 1;
		} elsif ($indesc) {
			$logentry .= $line;
		}
	}
	close(CVSLOG);
	$logentry =~ s/[\r\n=]+//gsi;

	return ($author, $logentry);
}

sub make_rss {
	my $packagehash = shift;
	my $tree        = shift;
	my $rss         = XML::RSS->new(version => '1.0');

	$rss->channel(
		title       => "Updated Fink Packages ($tree)",
		link        => 'http://fink.sourceforge.net/pdb/',
		description => "Updated Packages Released to the $tree Tree in the Last $DAYS Days.",
		dc          => {
			date      => w3c_date(time),
			subject   => 'Fink Software',
			creator   => 'fink-devel@lists.sourceforge.net',
			publisher => 'fink-devel@lists.sourceforge.net',
			language  => 'en-us',
		},
		syn         => {
			updatePeriod    => 'hourly',
			updateFrequency => '1',
			updateBase      => '2000-01-01T00:30:00-05:00',
		},
	);

	my $description;
	for my $package (sort { $packagehash->{$b}->{'date'} <=> $packagehash->{$a}->{'date'} } keys %{$packagehash}) {
		$package = $packagehash->{$package};

		#print "name = ", $package->{'package'}, ", version = ", $package->{'version'} . "-" . $package->{'revision'}, "\n";
		#print "cache = ", $CACHE->{$tree}->{$package->{'package'}}, "\n";

		next if ($CACHE->{$tree}->{$package->{'package'}} eq $package->{'version'} . '-' . $package->{'revision'});
		$CACHE->{$tree}->{$package->{'package'}} = $package->{'version'} . '-' . $package->{'revision'};

		print "  - ", $package->{'package'}, " ", $package->{'version'} . "-" . $package->{'revision'}, "\n";
		if (not exists $package->{'descdetail'} or $package->{'descdetail'} =~ /^\s*$/gs) {
			$description = $package->{'description'};
		} else {
			$description = $package->{'descdetail'};
		}

		$description =~ s/!\p{IsASCII}//gs;
		$description =~ s/^[\r\n]+//; $description =~ s/[\r\n\s]+$//;
		($description) = encode_entities($description);
		$package->{'cvslog'} =~ s/!\p{IsASCII}//gs;
		if ($DOCVS) {
			$description = '<![CDATA[<pre>' . $description . "\n\ncommit log from " .
				$package->{'cvsauthor'} . ":\n" .
				$package->{'cvslog'} . "</pre>]]>";
		}

		$rss->add_item(
			title       => encode_entities($package->{'package'} . ' ' . $package->{'version'} . '-' . $package->{'revision'} . ' (' . $package->{'description'} . ', ' . $package->{'tree'} . ' tree)'),
			description => $description,
			link        => encode_entities('http://fink.sourceforge.net/pdb/package.php/' . $package->{'package'}),
			dc          => {
				date => w3c_date($package->{'date'}),
			},
		);
	}

	my $lctree = lc($tree);
	$rss->save("fink-$lctree.rdf.new") or die "can't save rss: $!\n";
	push(@FILES, "fink-$lctree.rdf");
}

sub find_infofiles {
	return unless (/\.info$/);
	my $tree = '10.2';
	if ($File::Find::name =~ /dists\/([^\/]+)\//) {
		$tree = $1;
	}

	my @stat = stat($File::Find::name) or die "can't stat $_: $!\n";
	return unless ($stat[9] >= $CUTOFF);

	my $text;
	open(FILEIN, $File::Find::name) or die "can't open $File::Find::name: $!\n";
	{ local $/ = undef; $text = <FILEIN>; }
	my $hash = parse_keys($text);
	close(FILEIN);

	$hash->{'tree'} = $tree;
	next unless (exists $hash->{'package'});
	$hash->{'date'} = $stat[9];
	if ($DOCVS) {
		($hash->{'cvsauthor'}, $hash->{'cvslog'}) = get_cvs_log($File::Find::dir, $File::Find::name);
	}

	if ($File::Find::name =~ m#/stable/#) {
		$STABLE_PACKAGES{$tree . '/' . $hash->{'package'}} = $hash;
	} else {
		$UNSTABLE_PACKAGES{$tree . '/' . $hash->{'package'}} = $hash;
	}
}

sub parse_keys {
	my $text    = shift;
	my $hash    = {};
	my $lastkey = "";
	my $heredoc = 0;

	for (split(/\s*\r?\n/, $text)) {
		chomp;
		if ($heredoc > 0) {
			if (/^\s*<<$/) {
				$heredoc--;
				$hash->{lc($lastkey)} .= $_."\n" if ($heredoc > 0);
			} else {
				$hash->{lc($lastkey)} .= $_."\n";
				$heredoc++ if (/<<$/);
			}
		} else {
			$_ =~ s/!\p{IsASCII}//gs;
			next if /^\s*\#/;	# skip comments
			if (/^\s*([0-9A-Za-z_.\-]+)\:\s*(.+?)\s*$/) {
				$lastkey = lc($1);
				if ($2 eq "<<") {
					$hash->{lc($lastkey)} = "";
					$heredoc = 1;
				} else {
					$hash->{lc($lastkey)} = $2;
				}
			} elsif (/^\s+(.+?)\s*$/) {
				$hash->{lc($lastkey)} .= "\n".$1;
			}
		}
	}

	if ($heredoc > 0) {
		print "WARNING: End of file reached during here-document.\n";
	}

	return $hash;
}

sub encode_entities {
	for my $index (0..$#_) {
		$_[$index] =~ s/!\p{IsASCII}//gs;
		$_[$index] =~ s/>/&gt;/gs;
		$_[$index] =~ s/</&lt;/gs;
		$_[$index] =~ s/&/&amp;/gs;
#		$_[$index] =~ s/([\x{80}-\x{FFFF}])/'&#' . ord($1) . ';'/gse;
		$_[$index] =~ s/([^\x20-\x7F])/'&#' . ord($1) . ';'/gse;
#		$_[$index] =~ s/\xca//gs;
		$_[$index] =~ tr/\x91\x92\x93\x94\x96\x97/''""\-\-/;
		$_[$index] =~ tr/[\x80-\x9F]//d;
		$_[$index] = pack("C*", unpack('U*', $_[$index]));
#		$_[$index] =~ s/\xa8//gs;
	}
	return(@_);
}
