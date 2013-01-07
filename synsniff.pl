#!/usr/bin/perl
#
# synsniff v1.1 - a TCP SYN connection logger & FIN scan detector 
# (c) 1996, 1998 James Abendschan <jwa@jammed.com>
# http://www.jammed.com/
#
# log incoming SYNs and write them to stdout.  This program requires
# tcpdump, available from ftp://ftp.ee.lbl.gov/tcpdump.tar.Z
#
# 29 Mar 1996 jwa - Initial code
# 02 Apr 1996 jwa - made output fit in 80 cols (should be an option, tho)
#                   added support for ignoring certain source ports
# 12 Apr 1996 jwa - potential portscans logged as [PORTSCAN]
# 02 Feb 1998 jwa - minor enhancements & code cleanup
# 05 Apr 1998 jwa - added syslog support.  Now at v1.0 (!@)
# 13 Apr 1998 jwa - added FIN anomaly detection 
#
# todo/good ideas:
#  flag data on "not-well known ports" (catches silly tcp backdoors)

require 5.002;
use Socket;
use Sys::Syslog;
select(STDOUT); $|=1; 

# debuggage

$SIG{USR1} = sub { print "> ** Open connection hash:\n"; @ish = keys %fin_logger; while ($h = shift @ish) { $t = $fin_logger{$h}; print "> $h  age $t  expires: ", time - ($t + $hashage) , "\n"; }; };


srand($$);

$myname = reverse((split(/\//, reverse($0)))[0]);	# basename..

# where is your tcpdump?
$ENV{PATH}="/bin:/usr/bin:/etc:/usr/etc:/sbin:/usr/sbin";

# number of repeated connects from a host during a timestamp period (1 second)
# to be considered a portscan/port flood

$srcmax = 7;
$dstmax = 7;

$prunemax = 1000;	# prune the FIN hash every x packets

$hashage = 60 * 60 * 24;# maximum age of FIN scan detection hash (seconds)
			# If you're running low on memory on a busy net, 
			# make this smaller..

# process command line arguments

while ($arg = shift @ARGV) {
	$use_syslog = 1 if ($arg eq "-s");
	$debug = 1 if ($arg eq "-d");
	$srcmax = shift @ARGV if ($arg eq "-srcmax");
	$dstmax = shift @ARGV if ($arg eq "-dstmax");
	push(@exclude_ports, shift @ARGV) if ($arg eq "-i");
	$net = shift @ARGV if ($arg eq "-net");
	$norev = 1 if ($arg eq "-n");
	$srchost = shift @ARGV if ($arg eq "-srchost");
	$dsthost = shift @ARGV if ($arg eq "-dsthost");
	$flag_fin = 1 if ($arg eq "-f");
	usage() if ($arg =~ /^-\?|^-h/);
}

if (!defined($net)) {
	print "Need a network to monitor!\n";
	usage();
}

# build tcpdump command line

@ex = @exclude_ports;

while ($port = shift @ex) {
	$excludes .= " and not tcp port $port";
}

# build tcpdump command line
								# UAPRSF
$tcpdump = "tcpdump -n -l 'tcp[13] & 2 != 0' "; 		# 000010
$tcpdump = "tcpdump -n -l 'tcp[13] & 3 != 0' " if ($flag_fin);	# 000011
$tcpdump .= "and src net not $net " if (defined($net));
$tcpdump .= $excludes . " " if (defined($excludes));
$tcpdump .= "and not broadcast ";
$tcpdump .= "and src host $srchost " if (defined($srchost));
$tcpdump .= "and dst host $dsthost " if (defined($dsthost));
$tcpdump .= "2> /dev/null" if (!$debug);

$stamp = timestamp();

if ($use_syslog) {
	openlog($myname, 'pid', 'user');
	syslog('auth|info', "monitoring network $net");
	syslog('auth|info', "ignoring ports @exclude_ports") if (defined(@exclude_ports));
} else {	
	print "$stamp -- $tcpdump" if ($debug);
	print "$stamp -- $0 monitoring network $net\n";
	print "$stamp -- ignoring ports @exclude_ports\n" if (defined(@exclude_ports));
}

open (TCPDUMP, "$tcpdump |");
TCPDUMP:
while ($line = <TCPDUMP>) {
	$timestamp = &timestamp();

	($gmtime, $src, $whoot, $dst, $type, $blah) = split (/ /, $line);

	($one, $two, $three, $four, $port) = split (/\./, $src);
	$srcip = "$one.$two.$three.$four";
	$srcport = $port;
	if (defined($norev)) {
		$srcname = $srcip;
	} else {
		$srcname = get_host_name($srcip);
	}
	$dst =~ s/://g;
	($one, $two, $three, $four, $port) = split (/\./, $dst);
	$dstip = "$one.$two.$three.$four";
	$dstport = $port;
	if (defined($norev)) {
		$dstname = $dstip;
	} else {
		$dstname = get_host_name($dstip);
	}

# - compare $network_filter to dstip  -- useful if we're on a gateway net
# (this will ignore all packets with a destination net other than our own --
# you can prolly do this in tcpdump, but I couldn't figure it out :-)
# - ignore all broadcast packets (dst ip x.x.x.255 or x.x.x.0) (?)

	if ($dstip !~ /$net/) {
		undef $flags;

		$srchits++ if ($srcname eq $osrcname);
		$dsthits++ if ($dstname eq $odstname);

# reset counters if time threshold exceeded

		if ($timestamp ne $otime) { $srchits=0; $dsthits=0; }
   
		if ($srchits >= $srcmax) {
			$flags .= "portscan-s ";
			$srchits = 0;
		} 

		if ($dsthits >= $dstmax) {
			$flags .="portscan-d ";
			$dsthits = 0;
   		}

		if ($flag_fin) {
			$hash = "$srcname/$srcport/$dstname/$dstport";
			if ($type eq "S") {
				print "SYN Saw [$hash]\n" if ($debug);
				$fin_logger{$hash} = time;
				#print "pushed $fin_logger{$hash} into fin_logger\{$hash\}\n";
			}
			if ($type eq "F") {
				print "FIN saw [$hash] .." if ($debug);
				if (defined($fin_logger{$hash})) {
					undef $fin_logger{$hash};
					print "Matched\n" if ($debug);
				} else {
					print "** Unmatched!\n" if ($debug);
					$flags .= "!FIN ";
				}
			}

# periodically prune the hash 

			if (($prune_c++ > $prunemax) && ($flag_fin)) {	
				print "** Pruning..\n" if ($debug);
				$prune_c = 0;
				@ish = keys %fin_logger;
				while ($h = shift @ish) {
					$t = $fin_logger{$h};
					if ($t + $hashage < time) {
						print "-- $h ($t secs, ", $t % $hashage, " age)\n" if ($debug);
						undef $fin_logger{$h};
					} else {
						print "OK $h ($t secs, ", $t % $hashage, " age)\n" if ($debug);
					}
				}
			}
		}

		next TCPDUMP if (($type eq "F") && ($flags !~ /FIN/));

# log it!
		$line = "$type $srcname:$srcport -> $dstname:$dstport $flags";

		if ($use_syslog) {
			syslog('auth|info', $line);
		} else {	
			print $timestamp . " ". $line . "\n";
		}

		$osrcname = $srcname;
		$odstname = $dstname;
		$otime = $timestamp;
	}
}
fatal("unexepected termination of tcpdump: $!\ncheck PATH and permissions.");



# simple routine to pad numbers w/ zeros

sub pad
{
	my ($what, $countn) = @_;
	my ($pad, $size, $padded, $i);

	$size = length ($what);
	$count = $countn - length ($what);
	for ($i=0; $i<$count; $i++) {
		$padded="0" . $padded;
	}
	$padded = "$padded$what";
	return $padded;
}

#
# this code snagged from satan-1.0 (zen & wzv)
#
#  Lookup the FQDN for a host name or address with cacheing.

sub get_host_name {
	local($host) = @_;
	local($aliases, $type, $len, @ip, $a,$b,$c,$d);

	$orig = $host;

	# do cache lookup first
	if (exists($host_name_cache{$host})) {
		return($host_name_cache{$host});
		}

	# if host is ip address
	if ($host =~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
		($a,$b,$c,$d) = split(/\./, $host);
		@ip = ($a,$b,$c,$d);
		($host) = gethostbyaddr(pack("C4", @ip), &AF_INET);
		}
	# if host is name, not ip address
	else {
		($host, $aliases, $type, $len, @ip) = gethostbyname($host);
		($a,$b,$c,$d) = unpack('C4',$ip[0]);
		}

	# success:
 	if ($host eq "") {
		$host = $orig;
	}
	if ($host && @ip) {
		$host =~ tr /A-Z/a-z/;
		return $host_name_cache{$host} = $host;
	} else {
		return $host_name_cache{$host} = "";
	}
}

# terse timestamp :-)

sub timestamp {
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	my ($stamp);

	$mday = pad($mday, 2);
	$mon = pad($mon + 1 , 2);
	$hour = pad($hour, 2);
	$min = pad($min, 2);
	$sec = pad($sec, 2);
	$stamp = "$mon/$mday $hour:$min:$sec";

	return $stamp;
}

sub fatal {
	my ($oops) = shift @_;

	print "Fatal: $oops\n";
	exit 1;
}

sub usage {
	print "usage: $0 -net network to watch\n";
        print "\t[-i # ignore destination TCP port]\n";
        print "\t[-n don't resolve hostnames]\n";
        print "\t[-srcmax # threshold for scans]\n";
        print "\t[-dstmax # threshold for scans]\n";
        print "\t[-s log to syslog instead of stdout]\n";
        print "\t[-srchost watch for SYNs from this host]\n";
        print "\t[-dsthost watch for SYNs to this host]\n";
	print "\t[-f flag FINs with no SYNs]\n";
        print "\t[-d extra debugging]\n";
        exit 1;
}

