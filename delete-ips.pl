#!/usr/bin/perl
# Written by Paul Ott
# 
# This custom tool is provided by Tenable Network Security to 
# customers upon specific request for the use of removing data
# from the Lightning Console under the pretense that said data
# is no longer valid to the customer's network.  Improper use that
# violates the licensing agreement is explicitly prohibited.
#
# Distribution of this script is explicitly prohibited.  This tool is
# controlled under the Tenable Network Security software license
# agreement.  Any questions regarding the use of this script should
# be directed to the Tenable Network Security Customer Support
# group at : support@tenablesecurity.com
#
# Copyright 2005 Tenable Network Security
# Not for use outside of the Lightning Console
#

use strict;

#
# Format of input file should be single ips each on its own line 
#
my $LCPATH = "/opt/sc3/customers/";
my $id;
if ($#ARGV != 3){
	print_usage();
	exit(1);
}

if (($ARGV[0] !~ /^-f$/) && ($ARGV[0] !~ /^-c$/)){
	print_usage();
	exit(1);
}

if (($ARGV[0] =~ /^-f$/) && (! -e $ARGV[1])){
	print "File $ARGV[1] does not exist!\n";
	exit(1);
}

if (($ARGV[2] =~ /^-f$/) && (! -e $ARGV[3])){
	print "File $ARGV[3] does not exist!\n";
	exit(1);
}

if ($ARGV[0] =~ /^-f$/){
	open(FH,$ARGV[1]) || die "Could not open file $ARGV[1]\n";
        $id = $ARGV[3];
} elsif ($ARGV[2] =~ /^-f$/){
	open(FH,$ARGV[3]) || die "Could not open file $ARGV[3]\n";
        $id = $ARGV[1];
}

my $execute = "egrep -v \"^(";
while(my $line = <FH>){
	chomp($line);
	if ($line =~ /^\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s*$/){
		$execute = $execute . $1. "|";
	}else{	
		print "Ignoring line $line ... Does not fit line format\n";	
	}
}

chop($execute);
$execute = $execute .")\\\|\" $LCPATH/$id/HDB/hdb.nsr > $LCPATH/$id/HDB/.lesshdb.nsr";
`$execute`;
`mv $LCPATH/$id/HDB/.lesshdb.nsr $LCPATH/$id/HDB/hdb.nsr`;
`/opt/sc3/bin/vimport $LCPATH/$id/HDB/hdb.nsr $LCPATH/$id/HDB/hdb.db $LCPATH/$id/HDB/hdb.raw $LCPATH/$id/HDB/namedb.db $LCPATH/$id/HDB/namedb.raw`;
`/opt/sc3/bin/asset_exec -r $LCPATH/$id/workflow.cfg -n $LCPATH/$id/HDB/namedb -c $LCPATH/$id/HDB/comments.db -h $LCPATH/$id/HDB/hdb.db`;
close(FH);

sub print_usage {
	print "Usage: delete-ips.pl -f filename -c id\n";
}
