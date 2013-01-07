#!/usr/bin/perl
#    
#    WorMeter (used to be bloodredmeter)
#
#    Copyright (C) 2001 Vadim "Kryptolus" Berezniker <vadim@berezniker.com>
#
#    http://www.kryptolus.com
#
#    This program is free software; you can redistribute it and/or
#    modify it under the terms of the GNU General Public License
#    as published by the Free Software Foundation; either version 2
#    of the License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#


#    Due to the recent tragic events here in New York, I am dedicating this script to Linda Tan.
#    My best wishes to her and her family and I hope for the best.


## -- NOTE: If you wish to run this, you must first have the Net::DNS modules --
## -- You also might have to edit the regexps on around line 141 that matches the log file lines --


## 0.9 - Added <html>,<head>,<title> and <body> to the generated reports
##         -- Thanks to Dagfinn I. Mannsaker (ilmari at ilm.nlc.no)
##     - Added spaces around the +/- for sorting and adding nowrap tags to header row
##         -- Thanks to Matthew H. Ray(mray at lordsofcomputing.com)
##     - Added Nimda support
##         -- <spoon at mac dot com>
##     - Renamed from "bloodredmeter" to WorMeter
##     - This is changing more into a generic worm report tool
##     - If different attacks come from the same IP, they are listed separately
##     - Sorting by reverse host works
## 0.8 - Added automatic detection and decompression of gzipped logs
## 0.7 - Added support for multiple log files and support for dns caching
##         -- Thanks to Drew Taylor(drew at drewtaylor.com) for the code
##       Here's a tip on how you could've done this w/o multiple file support in the program.
##       This might come in handy some day.
##       You could have put "(cat access_log; gzcat access_log.*)|"
##       This would allow the program to access the multiple outputs seamlessly 
## 0.6 - Added option to enable linking of IPs ($link_ips)
##         -- Thanks to Timothy L. Robertson(timothyr at timothyr.com) for the note
## 0.5a- Fixed reporting if not using default report name of 'red.html
##         -- Thanks to Patrick Burleson(pbur at patrickburleson.com) for the note
##     - Fixed sorting by IP address
##         -- Thanks to Ed Wilts(ewilts at ewilts.org) for the note
##     - For multiple attacks the latest attack time is displayed
##         -- Thanks to John S. Jacob(jsjacob at iamnota.com) for the note
##     - Pretty report(disable by changing $pretty = 1 to 0)
##         -- Thanks to Anonymous Coward for the note ;)
##     - Fixed the links in the HTML if not using default 'red.html'
## 0.4b- Added proper sorting by time
##     - NOTE: Sorting by time will only be available if the Date::Parse module is present on the system
##     - Read line by line instead of whole file
##     - use strict
##     - fixed code red worm counter
## 0.3 - Added sorting
##     - Added DNS timeout -- Thanks to Eric Johanson (ericj at cubesearch.com)
##     - This script now has a name -- "bloodredmeter"(BRM for short) thanks to Eric Johanson
##     - NOTE: THIS VERSION WILL GENERATE MULTIPLE FILES
##       In addition to red.html, you will have a file for each sorted version.
##       They will be named red_SORT_DIRECTION.html
##       Times are not sorted correctly. Is there an easy way to convert string time to unix time 
##	 w/o using Date::Parse?
## 0.2 - Added code red worm version
## 0.1 - Initial release


use strict;
use Socket;
use Net::DNS;
my $res = new Net::DNS::Resolver;

## -- timeout code thanks to Eric Johanson --
$res->tcp_timeout(5);
$res->retrans(1);
$res->retry(1);

my $query;

## -- log file: this can include wildcards
##    the pattern/file can match gzipped text files and they will be decompressed on the run
##    you can supply multiple files/patterns by separating them with a space --
my $logfile = "/var/log/httpd_access.log";

## -- text report for incident.pl to parse for email reporting
my $wormlog = "/tmp/wormeter.rpt";

## -- file to print report to (make sure this ends in .html)  --
my $outfile = "/pub/www/stats/wormeter.html";
## -- file to print number of attacks to --
my $stat    = "/pub/www/stats/wormeter_attacks";
## -- whether or not to be silent --
my $silent = 0;
## -- whether or not to use DNS cache --
my $use_dns_cache = 1;
## -- DNS cache file name to save data to--
my $dns_cache_file = "/tmp/.dnscache";
## -- enable detection of compressed data files --
my $detect_gzip = 0;
## -- gzip command --
my $gzip = "gzip -c -d";

## -- don't touch this, it will be automatically enabled
##    if Date::Parse is present --
my $use_date_parse = 0;

## -- pretty report or not --
my $pretty = 1;

## -- links ips or not ? --
my $link_ips = 1;

eval("use Date::Parse;");
$use_date_parse = 1 unless $@;

if(!$use_date_parse) {
	print "Date::Parse cannot be loaded. Sorting by time disabled: $@" unless $silent;
}

my $host;
my @ip;
my $time;
my @attacks;
my @reverse;
my $numattacks = 0;
my %lookup_cache;
my %unique_hosts = 0;

my @SIGNATURES =
(
	{
		PATTERN		=>	'^(.*?)\s+(.*?)\[(.*?)\](.*?)\.ida\?N',
		IDENTIFY	=>	'V1',
		NAME		=>	'CodeRed Worm attack Version 1',
		COLOR		=>	'#00AA00'
	},
	{
		PATTERN		=>	'^(.*?)\s+(.*?)\[(.*?)\](.*?)\.ida\?X',
		IDENTIFY	=>	'V2',
		NAME		=>	'CodeRed Worm attack Version 2',
		COLOR		=>	'#FF0000'
	},
	{
		PATTERN		=>	'^(.*?)\s+(.*?)\[(.*?)\](.*?)\.ida\?(.*?)',
		IDENTIFY	=>	'V?',
		NAME		=>	'CodeRed Worm attack Version Unknown',
		COLOR		=>	'#AAAABB'
	},
	{
		PATTERN		=>	'^(.*?)\s+(.*?)\[(.*?)\](.*?)(cmd|root).exe\?/c\+dir(.*?)',
		IDENTIFY	=>	'Nimda',
		NAME		=>	'Nimda Worm attack',
		COLOR		=>	'#777700'
	},
	{
		PATTERN		=>	'^(.*?)\s+(.*?)\[(.*?)\](.*?)/formmail.(pl|cgi)(.*?)',
		IDENTIFY	=>	'formmail',
		NAME		=>	'formmail.cgi/pl probe',
		COLOR		=>	'#AA0000'
	}
);

sub print_attacks
{
	my($filename) = shift;
	print("generating $filename\n") unless $silent;
	
	$outfile =~ /([0-9a-zA-Z_-]*)\.html$/;
	my $file = $1;
	my $red = '<font color="#FF0000">';
	my $green = '<font color="#00AA00">';
	my $gray = '<font color="#DDDDDD">';

	$" = "<br>";
	## -- print out the table --
	open(OUT, ">$filename") || die "can not open outfile";

	print OUT "<html><head><title>Apache Server Attacks</title></head><body>";
	print OUT "<table align=center border=1>\n";
	#print OUT "<tr><td colspan=5 align=center><a href=\"http://www.kryptolus.com/WorMeter.txt\">Source Code(GPL)</a></td></tr>";
	#print OUT "<tr><td colspan=5 align=center>Automatically updated every 5 minutes</td></tr>\n";
	print OUT "<tr><td colspan=5 align=center>WorMeter</td></tr>\n";
	
	if($pretty) {
		print OUT "<tr><td colspan=5 align=center><b>$red$numattacks</b></font> total attacks, <b>$red" . keys(%unique_hosts) . "</b></font> unique hosts</td></tr>\n";
		#print OUT "<tr><td colspan=5 align=center><b>$green$num_v1</font></b> version 1 attacks, <b>$red$num_v2</font></b> version 2 attacks, $num_other other version attacks</td></tr>\n";
	} else {
		print OUT "<tr><td colspan=5 align=center>$numattacks total attacks, " . @attacks . " unique hosts</td></tr>\n";
		#print OUT "<tr><td colspan=5 align=center>$num_v1 version 1 attacks, $num_v2 version 2 attacks, $num_other other version attacks</td></tr>\n";
	}
	print OUT "<tr><td colspan=5 align=center>";
	for(my $v = 0; $v < @SIGNATURES; $v++)
	{
		if($v) {
			print OUT ", ";
		}
		
		if($pretty && $SIGNATURES[$v]->{COLOR})
		{
			print OUT "<b><font color=\"" . $SIGNATURES[$v]->{COLOR} . "\">";
		}
		print OUT int($SIGNATURES[$v]->{COUNT});
		if($pretty && $SIGNATURES[$v]->{COLOR})
		{
			print OUT "</font></b>";
		}
		
		print OUT " " . $SIGNATURES[$v]->{NAME};
	}
	print OUT "</td></tr>";
	
	print OUT "<tr><td colspan=5 align=center>Last updated: " . `date` . "</td></tr>\n";
	print OUT "<tr>";
	print OUT "<td nowrap><a href=\"" . $file . "_IP_desc.html\">-</a> IP <a href=\"" . $file . "_IP_asc.html\">+</a></td>";
	print OUT "<td nowrap><a href=\"" . $file . "_REVERSE_desc.html\">-</a> Hostname <a href=\"" . $file . "_REVERSE_asc.html\">+</a></td>";
	print OUT "<td nowrap><a href=\"" . $file . "_TYPE_desc.html\">-</a> Version <a href=\"" . $file . "_TYPE_asc.html\">+</a></td>";
	print OUT "<td nowrap><a href=\"" . $file . "_ATTACKS_desc.html\">-</a> # Attacks <a href=\"" . $file . "_ATTACKS_asc.html\">+</a></td>";
	if($use_date_parse) {
		print OUT "<td nowrap><a href=\"" . $file . "_TIME_desc.html\">-</a> Time <a href=\"" . $file . "_TIME_asc.html\">+</a></td>";
	} else  {
		print OUT "<td>Time</td>";
	}
	print OUT "</tr>\n";
	foreach my $attack(@attacks)
	{
		my $type = $attack -> {TYPE};
		if($pretty && $type -> {COLOR}) {
			$type = "<b><font color=\"" . $type -> {COLOR} . "\">" . $type -> {IDENTIFY} . "</font></b>";
		} else {
			$type = $type -> {IDENTIFY};
		}
		my @reverse = @{$attack -> {REVERSE}};
		if($pretty && @reverse == 1 && $reverse[0] =~ /^ERROR/) {
			$reverse[0] = "$gray$reverse[0]</font>";
		}

		my @ip = @{$attack -> {IP}};
		if($link_ips) {
			for(my $i = 0; $i < @ip; $i++) {
				$ip[$i] = "<a href=\"http://$ip[$i]\">$ip[$i]</a>" unless $ip[$i] eq 'ERROR';
			}
		}
			
		
		print OUT "<tr><td>@ip</td><td>@reverse</td><td align=right>$type</td><td align=right>" . $attack -> {ATTACKS} . "</td><td>" . $attack -> {TIME} . "</td></tr>\n";	
	}
	print OUT "</table></body></html>\n";
}

sub sort_func
{
	my ($a, $b, $type, $dir) = @_;

	my $rv;

	if($type eq 'ATTACKS') {
		$rv = $a->{$type} <=> $b->{$type};
	} elsif($type eq 'TIME') {
		$rv = str2time($a->{$type}) <=> str2time($b -> {$type});
	} elsif($type eq 'IP') {
		my $ip_a = inet_aton($a -> {$type}->[0]);
		my $ip_b = inet_aton($b -> {$type}->[0]);
		$rv = $ip_a cmp $ip_b;
	} elsif($type eq 'TYPE') {
		$rv = $a->{TYPE}->{IDENTIFY} cmp $b -> {TYPE} -> {IDENTIFY};
	} elsif($type eq 'REVERSE') {
		$rv = $a->{REVERSE}->[0] cmp $b->{REVERSE}->[0];
	} else {
		$rv = $a->{$type} cmp $b->{$type};
	}

	if($dir eq 'DESC') {
		$rv = -$rv;
	}

	return $rv;
}

sub print_report
{
	my($SORTKEY) = shift;

	my @attacks_copy = @attacks;
	print_attacks($outfile);

	my @att;
	my $newfile;
	foreach my $sort('IP', 'REVERSE', 'TYPE', 'ATTACKS', 'TIME')
	{
		next if $sort eq 'TIME' && !$use_date_parse;
		$newfile = $outfile;
		$newfile =~ s/([0-9a-zA-Z_-]*)\.html$/$1 . '_' . $sort . '_asc.html'/e;
		@attacks = sort {sort_func($a,$b,$sort, 'ASC')} @attacks_copy;
		print_attacks($newfile);

		$newfile = $outfile;
		$newfile =~ s/([0-9a-zA-Z_-]*)\.html$/$1 . '_' . $sort . '_desc.html'/e;
		@attacks = sort {sort_func($a,$b,$sort, 'DESC')} @attacks_copy;
		print_attacks($newfile);
	}
	
}


sub add_attack
{
	my($IP, $REV, $TIME, $TYPE) = @_;

	for(my $i = 0; $i < @{$IP}; $i++)
	{
		$unique_hosts{$IP->[$i]} = 1;
	}

	for(my $i = 0; $i < @attacks; $i++)
	{
		for(my $j = 0; $j < @{$IP}; $j++)
		{
			for(my $k = 0; $k < @{$attacks[$i]->{IP}}; $k++)
			{
				if($IP->[$j] eq $attacks[$i]->{IP}->[$k] && $attacks[$i]->{TYPE} eq $TYPE) 
				{
					if($use_date_parse && str2time($TIME) > str2time($attacks[$i]->{TIME})) {
						$attacks[$i] -> {TIME} = $TIME;
					}
					$attacks[$i]->{ATTACKS}++;
					return;
				}	
			}
		}
	}

	push @attacks, {IP => $IP, REVERSE => $REV, TIME => $TIME, ATTACKS => 1, TYPE => $TYPE};
}

sub forward_resolve
{	
	my($IP) = shift;

	if($IP =~ /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$/) {
		return $IP;
	}


	my $query = $res -> search($host);
	if(!$query) {
		return "ERROR";
	}

	my @ips;
	foreach my $rr ($query -> answer) {
		next unless $rr -> type eq "A";
		push @ips, $rr -> address;	
	}

	return @ips;
}

sub reverse_resolve
{
	my @IP = @_;
	my $rev;
	my @revs;

	foreach my $ip (@IP)
	{
		## -- Check for the IP in the cache --
		if(defined $lookup_cache{$ip}) {
			print "Found cached DNS lookup\n" unless $silent;
			return @{$lookup_cache{$ip}};
		}
		$ip =~ /^(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})$/;
		$rev = "$4.$3.$2.$1.in-addr.arpa";
		
		my $query = $res -> search($rev, "PTR");
		if(!$query) {
			#warn $res -> errorstring;
			push @revs, "ERROR(" . $res -> errorstring . ")";
		} else {
			foreach my $rr ($query -> answer) {
				if($rr -> type eq 'PTR') {
					push @revs, $rr -> ptrdname;
				}
			}
		}
	}

	if(@revs == 0) {
		push @revs, "NO";
	}

	return @revs;
}

sub load_cache
{
	print "Loading DNS cache\n" unless $silent;
	return if !-e $dns_cache_file;

	open(CACHE, "$dns_cache_file") ||
		die "Couldn't open DNS cache file $dns_cache_file to read";
	my $count;
	my $ip;
	my $line;
	while($line = <CACHE>) {
		chomp $line;
		next unless $line;

		if($line =~ /^\|(.*)$/) {
			$count ++;
			$ip = $1;
			$lookup_cache{$ip} = [];
		} else {
			push @{$lookup_cache{$ip}}, $line;
		}
	}
	close CACHE;
	print "Found $count cached entries\n" unless $silent;
}

sub save_cache
{
	open(CACHE, ">$dns_cache_file") ||
		die "Couldn't open DNS cache file $dns_cache_file for writing";
	foreach my $key (keys %lookup_cache) {
		print CACHE "|$key\n";
		my @r = @{$lookup_cache{$key}};
		foreach my $reverse(@r) {
			print CACHE "$reverse\n";
		}
	}
	close CACHE;
}


## -- Load DNS cache --
load_cache if $use_dns_cache;

## -- Process the logs --
my $log;

sub process_line
{
	my $line = shift;
	
	foreach my $sig(@SIGNATURES)
	{
		my $pattern = $sig -> {PATTERN};
		my $attack = $sig -> {NAME};
		my $id = $sig -> {IDENTIFY};
		if($line =~/$pattern/) 
		{
			$numattacks++;
			$sig -> {COUNT} ++;
			print "processing $1\n" unless $silent;
			$host = $1;
			$time = $3;
			my @ip = forward_resolve($host);
			my @reverse = reverse_resolve(@ip);
	
			## -- Save lookups --
			if(!defined($lookup_cache{$ip[0]})) {
				$lookup_cache{$ip[0]} = \@reverse;
			}	
			add_attack(\@ip, \@reverse, $time, $sig);
			print WORMREPORT "$time @ip Variation[$id]: $attack: @ip -> associate.com:80\n";
			print "done\n\n" unless $silent;
			return;
		}
	}
}

open(WORMREPORT, ">$wormlog") || die "Unable to open report: $wormlog";
foreach $log (glob($logfile)) 
{
	my $bytes;
	print "Processing log file $log\n" unless $silent;
	open(LOGFILE, "$log") || die "Unable to open logfile: $log";
	if($detect_gzip) 
	{
		read(LOGFILE, $bytes, 2);
		seek(LOGFILE, 0, 0);
		if($bytes eq chr(31) . chr(139)) {
			print "Will uncompress $log\n" unless $silent;
			close(LOGFILE);
			open(LOGFILE, "$gzip $log |");
		}
	}
	## -- filter the log --
	while(my $line = <LOGFILE>)
	{
		process_line($line);
	}
	close(LOGFILE);
	print "Finished with log file $log\n" unless $silent;
}
close(LOGFILE);
close(WORMREPORT);

print_report;

open(STAT, ">$stat");
print STAT $numattacks;
close(STAT);

close(OUT);

## -- save the DNS cache --
save_cache() if $use_dns_cache;
