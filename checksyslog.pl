#!/usr/bin/perl
#
# checksyslog - a program to extract abnormal entries from a system log
#
# author: James W. Abendschan  <jwa@jammed.com>
# license: GPL - http://www.gnu.org/copyleft/gpl.html
# url: http://www.jammed.com/~jwa/hacks/security/checksyslog/
# date: 4 Dec 1996 (v1.0)
#
# $Id: checksyslog,v 1.3 2001/05/04 10:07:42 jwa Exp $
#

select (STDOUT); $|=1;

# parse arguments

while ($arg = shift @ARGV) {
	$log = shift @ARGV if ($arg =~ /^-l$|^--log$/);
	if ($arg =~ /^-t$|^--today$/) {
		$filter=`date +"%b %e"`;
		chop $filter;
	}
	$filter = shift @ARGV if ($arg =~ /^-f$|^--filter$/);
	$rules = shift @ARGV if ($arg =~ /^-r$|^--rules$/);
	$constant = 1 if ($arg =~ /^-c$|^--constant$/);
	$verbose = 1 if ($arg =~ /^-v$|^--verbose$/);
}

usage() if ($rules eq "");

# suck in the rulefile

open (RULES, $rules) || die "Can't locate rule file: $!\n";
@lines = <RULES>;
close (RULES);

# preprocess to remove comments & expand % definitions

$defS = 1;

while (@lines) {
	$line = shift @lines;
	$line =~ s/\r|\n//g;
	next if (($line =~ /^$/) || ($line =~ /^#/));
	$defS = 0 if ($line !~ /^\%/);	# end definition state 
	$rules .= $line . "\n";
	if ($defS) {
		# $VAR=something
		($k, @v) = split(/=/, $line);
		$v = join("=", @v);
		$defH{$k} = $v;
		print "$k = $defH{$k}\n" if ($verbose);
	} else {
		@k = keys %defH;
		while ($k = shift @k) {
			if ($line =~ /${k}/) {
				$line =~ s/$k/$defH{$k}/g;
			}
		}
		push(@rules, $line);
	}
}	

# now build the moby regexp

while ($line = shift @rules) {
	if (($line !~ /^$/) && ($line !~ /^#/) && ($line ne " ")) {
		# validate RE.  perl will barf here if it's bad.
		if (/$line/ =~ /cheesypoofs/) { };
		$rulecount++;
		$line = $defH{"%PREPEND"} . $line;
		$rulez = "$rulez|$line" if ($rulez ne "");
		$rulez = "$line" if ($rulez eq "");
		print "Added rule: [$line]\n" if ($verbose == 1);
	}
}
close (RULES);

print "Read $rulecount rules\n" if ($verbose == 1);

# Do it.

if ($constant == 1) {		# tail -f
	open (LOG, $log) || die "can't open $log: $!";
	while (1) {
		for ($curpos = tell(LOG); $line = <LOG>; $curpos = tell(LOG)) {
			print $line if ((($filter eq "") || ($line =~ /$filter/)) && ($line !~ /$rulez/));
		}
		sleep 3;
		seek (LOG, $curpos, 0);
	}
}

if (defined($log)) {
	close(STDIN);
	open(STDIN, $log) || die "can't open $log: $!";
} else {
	print STDERR "Reading from stdin\n";
}	

while ($line = <STDIN>) {
	print $line if ((($filter eq "") || ($line =~ /$filter/o)) && ($line !~ /$rulez/o));
}

close (LOG);
exit (0);


sub usage {
	print <<_EOF_;
usage: $0 -rules rulefile 
          [--log path to syslog] 
 	  [--today] 
 	  [--filter filter]
IE:
	$0 --rules /usr/local/lib/checksyslog.rules \\
	   --log /var/log/syslog --today

A rulefile must be specified.  With no --log option, input is taken from stdin.
_EOF_
	exit(1);
}

