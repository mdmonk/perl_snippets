#!/usr/bin/perl
# dnsscan.pl - Queries a nameserver for information
# ** Public Release Version 1.3 **
# By JJ <JJ@atstake.com>
#
# Copyright 2001 @stake, Inc. All rights reserved.
# http://www.atstake.com/
#
#
# Usage : dnsscan.pl [ -d target domain | -n target nameserver ]
#
# Requires the Net::DNS package 
# by Mike Fuhr http://www.fuhr.org/~mfuhr/perldns/
# Tested under Win32 and Linux (RH7) with Perl 5.6.0
#
# To Do :
# Walk an IP range greater than a Class C.
# Allow IP range to be specified in different formats.
# Send output to a target file.
# Anything else that is suggested - requests/comments welcome.

use Net::DNS;
use IO::Socket;
use Getopt::Long;

# Vulnerability Database
#
# Key : Version,zxfr,sigdiv0,srv,nxt,sig,naptr,maxdname,solinger,fdmax,
#	complain, infoleak, tsig.
# Values : V = Vulnerable, N = Not Vulnerable, - = Function not present
# Data taken from http://www.isc.org/products/BIND/bind-security.html

@vulns = ("ZXFR - Remote DoS","SIGDIV0 - Remote DoS","SRV - Remote DoS",
	"NXT - Remote Exploit","SIG - Remote DoS","NAPTR - Local DoS",
	"MAXDNAME - Remote DoS","SOLINGER - Remote DoS","FDMAX - Remote DoS",
	"COMPLAIN - Remote Exploit","INFOLEAK - Remote Enumeration","TSIG - Remote Exploit" );

@database = (	
		[ "4.8",	"-","-","-","-","-","-","-","-","-","-","V","-" ],
	 	[ "4.8.1",	"-","-","-","-","-","-","N","-","-","-","V","-" ],
		[ "4.8.2.1",	"-","-","-","-","-","-","N","-","-","-","V","-" ],
		[ "4.8.3",	"-","-","-","-","-","-","N","-","-","-","V","-" ],
		[ "4.9.3",	"-","-","-","-","-","-","N","-","-","V","V","-" ],
		[ "4.9.4",	"-","-","-","-","-","-","N","-","-","V","V","-" ],
		[ "4.9.4-P1",	"-","-","-","-","-","-","N","-","-","V","V","-" ],
		[ "4.9.5",	"-","-","N","-","V","V","V","-","-","V","V","-" ],
		[ "4.9.5-P1",	"-","-","N","-","V","V","V","-","-","V","V","-" ],
		[ "4.9.6",	"-","-","N","-","V","V","V","-","-","V","V","-" ],
		[ "4.9.7",	"-","-","N","-","N","V","V","-","-","V","V","-" ],
		[ "4.9.8",	"-","-","N","-","N","V","V","-","-","N","N","-" ],
		[ "8.1",	"-","-","N","-","V","V","V","V","V","N","V","-" ],
		[ "8.1.1",	"-","-","N","-","V","V","V","V","V","N","V","-" ],
		[ "8.1.2",	"-","-","N","-","N","V","V","V","V","N","V","-" ],
		[ "8.2",	"N","V","V","V","V","V","V","V","V","N","V","V" ],
		[ "8.2.2-P1",	"N","V","V","V","V","V","V","V","V","N","V","V" ],
		[ "8.2.1",	"N","V","V","V","V","V","V","V","V","N","V","V" ],
		[ "8.2.2",	"V","V","V","N","N","V","V","N","N","N","V","V" ],
		[ "8.2.2-P1",	"V","V","V","N","N","V","V","N","N","N","V","V" ],
		[ "8.2.2-P2",	"V","V","V","N","N","N","N","N","N","N","V","V" ],
		[ "8.2.2-P3",	"V","V","V","N","N","N","N","N","N","N","V","V" ],
		[ "8.2.2-P4",	"V","V","V","N","N","N","N","N","N","N","V","V" ],
		[ "8.2.2-P5",	"V","V","V","N","N","N","N","N","N","N","V","V" ],
		[ "8.2.2-P6",	"V","N","V","N","N","N","N","N","N","N","V","V" ],
		[ "8.2.2-P7",	"N","N","N","N","N","N","N","N","N","N","V","V" ],
		[ "8.2.3",	"N","N","N","N","N","N","N","N","N","N","N","N" ],
		[ "9.0.0",	"-","N","N","N","N","N","N","N","N","N","N","N" ],
		[ "9.1.0",	"-","N","N","N","N","N","N","N","N","N","N","N" ],
		
		);
		
$database_count = 28;
		
use constant DEFAULT_NAMESERVER => "192.168.1.1"; # Change for your net

$res = new Net::DNS::Resolver;

@auth_ns_list = "";

$res->nameservers(DEFAULT_NAMESERVER);

$target_domain = "";
$target_ns = "";
$bind_version = "";

GetOptions ('d=s' => \$target_domain, 'n=s' => \$target_ns);

if (($target_domain eq "") && ($target_ns eq "")) { &usage; }

print "DNSScan by JJ <JJ\@atstake.com>  Public Release 1.3\n\n";

&check_targets;

if ($target_domain ne "") { &go_domain } else { &go_nameserver };

die "\n\nSo mote it be.\n\n";

#-----------------------------------------------------------------------------#

sub usage
{
	my ($program_name) = $0 =~ m|[\\\/]([^\\\/]*)$|g;
	print "Usage : $program_name [ -d target domain | -n target nameserver ]\n\n";
	die "\n";
} # usage

#-----------------------------------------------------------------------------#

sub check_targets
{
	if ($target_domain ne "")
	{
		my $query = $res->search($target_domain);
		if (!$query) { die "\n**Error : Cannot resolve target !\n\n"; }
	}
	
	if ($target_ns ne "")
	{
		my $query = inet_aton($target_ns);
		if (!$query) { die "\n**Error : Cannot resolve target !\n\n"; }
		}
} # check_targets

#-----------------------------------------------------------------------------#

sub go_domain
{

	my $target = "";
	my $temp=0;
	
	print "Target Domain : $target_domain\n\n";
	$temp = &get_auth_ns;
	$target = $auth_ns_list[$temp];
	print "Target is $target...\n";
	&bind_version($target);
	&zone_transfer($target_domain);
	&walk_class_c;
	
} # go_domain

#-----------------------------------------------------------------------------#

sub go_nameserver
{
	my $target = inet_ntoa(inet_aton($target_ns));
	my $choice = "";
	my $done_flag = 0;
	my $domain = "";
	
	print "Target nameserver : ",$target_ns," [",$target,"]\n\n";
	&bind_version($target);
	print "Do you want to try a Zone Transfer ? (y/n) :";
	chomp($choice = <STDIN>);
	if ($choice eq "y")
	{
		while ($done_flag eq 0)
			{	
			print "\nGive me a domain :";
			chomp($domain = <STDIN>);
			&zone_transfer($domain);
			print "\n\nAnother ? (y/n) :";
			chomp($choice = <STDIN>);
			if ($choice eq "n") { $done_flag = 1; }
			}
	}
	
	&walk_class_c;
	
} # go_nameserver

#-----------------------------------------------------------------------------#

sub get_auth_ns
{
	print "Checking for nameservers...\n\n";
	my $input_flag=0;
	my $choice=0;
	
	my $query = $res->query($target_domain,"NS");
	if (!$query) { die "Query Failed !! - $res->errorstring\n\n"; }
	my $loop=1;
	foreach $rr ($query->answer)	{
					next unless $rr->type eq "NS";
					print "[",$loop++,"] : ",$rr->nsdname,"\n";
					push (@auth_ns_list, $rr->nsdname);
					}
	until ($input_flag eq 1)
		{
		print "\n\nChoose nameserver to target : [1-",$loop-1,"] : ";
		chomp($choice = <STDIN>);
		if (($choice >0) && ($choice < $loop)) { $input_flag=1; }
		}
		
	return $choice;
		
} # get_auth_ns

#-----------------------------------------------------------------------------#

sub bind_version
{
	my @answer = "";
	
	$res->nameservers(inet_ntoa(inet_aton($_[0])));
	$res->recurse(0);
	$res->tcp_timeout(1);
	
	print "\n\nQuerying BIND version... : ";
	my $packet = $res->query("version.bind","TXT","CH");
	if (!$packet)
	{
		if ($res->errorstring eq "NOTIMP")
			{ $bind_version = "Probably a Microsoft DNS Server"; }
		
		else	{ $bind_version = "Secured - timeout !"; }
	}
	
	else	{
		@answer = $packet->answer;
		$_ = @answer[0]->rdatastr;
		s/"//g;
		$bind_version = $_;
		}
		
	print $bind_version,"\n\n";
		
	$result = &check_vuln;
	if ($result eq 0)
		{
			print "Non-standard version string, can you see a version ";
			print "number ? ie BIND 4.9.7-REL\n";
			print "If so, enter it, or 'n' for skip :";		
			chomp($bind_version = <STDIN>);
			if ($temp ne "n") { $result = &check_vuln; }
		}

	
} # bind_version

#-----------------------------------------------------------------------------#

sub zone_transfer
{
	my @zone = $res->axfr($_[0]);
	
	print "Trying a Zone Transfer...\n\n";
	
	if (@zone)
	{
		foreach $rr (@zone)
		{
			print $rr->name,"\t\t",$rr->type,"\t\t",$rr->rdatastr,"\n";
		}
	}
	
	else
	{
		print "Zone Transfer failed !\n\n";
	}
	
} # zone_transfer
	
#-----------------------------------------------------------------------------#

sub walk_class_c
{
	my $choice = "";
	my $ip_range = "";
	print "Walk a registered Class C IP block ? (y/n) :";
	chomp($choice = <STDIN>);
	
	if ($choice eq "y")
	{
		print "\nEnter Class C range, eg 172.16.1.1-254 :";
		chomp($ip_range = <STDIN>);
		($ip1,$ip2,$ip3,$ip4) = split (/\./ ,$ip_range);
		
		($lower, $higher) = split ("-", $ip4);
			print "\nWorking...\n\n";
		
			for ($loop = $lower; $loop <= $higher; $loop++)
				{
				$full_ip = "$ip1.$ip2.$ip3.$loop";
				$query = $res->query($full_ip);
				if ($query)
					{
					$temp = ($query->answer)[0]; $temp = $temp->string;
					(@textline) = split (/\t/, $temp);
					$found_name = @textline[4];
					print "Found : $full_ip\t$found_name\t";
					$query = $res->query($found_name);
					if ($query)
						{
						foreach $rr ($query->answer )	{
										next unless $rr->type eq "A";
										print "[",$rr->address,"]\n";
										}
						}
					else { print "[No Resolution]\n"; }
					}
				}
			
		# Now check reverse records
		
		print "\nChecking reverse records...\n\n";
		
		for ($loop = $lower; $loop <= $higher; $loop++)
			{
			$full_rev_ip = "$loop.$ip3.$ip2.$ip1.in-addr.arpa";
			$query = $res->query($full_rev_ip,"PTR");
			if ($query)	{
					$temp = ($query->answer)[0]; $temp = $temp->string;
					(@textline) = split (/\t/, $temp);
					$found_name = @textline[4];
					print "$full_rev_ip\t$found_name\t";
					$query = $res->query($found_name);
					if ($query)
						{
						foreach $rr ($query->answer )	{
										next unless $rr->type eq "A";
										print "[",$rr->address,"]\n";
										}
						}
					else { print "[No Resolution]\n"; }
					}
			}
	}
	
} # walk_class_c

#-----------------------------------------------------------------------------#

sub check_vuln
{

	my $vuln_found = 0;
	for ($loop = 0; $loop < $database_count; $loop ++)
	{
		if ($database[$loop][0] eq $bind_version)
		{
			$vuln_found = 1;
			print "BIND Version $bind_version is vulnerable to ";
			print "the following Bug(s) :\n\n";
			for ($loop2 = 1; $loop2 < 13; $loop2++ )
				{
				if ($database[$loop][$loop2] eq "V")
					{ print "* $vulns[$loop2-1] Bug.\n"; }
				}
			print "\n\nFuther information on these problems can be found\n";
			print "at http://www.isc.org/products/BIND/bind-security.html\n\n";
		}
	}
			
	return $vuln_found;
} # check_vuln

#-----------------------------------------------------------------------------#


	







