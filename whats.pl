#!/usr/bin/perl -w
####################################################################
##                                                                ##
##                            whats                               ##
##                                                                ##
####################################################################
##                                                                ##
##  Author:       Mark Zieg <mark@zieg.com>                       ##
##  Date:         Mar 29 2001                                     ##
##                                                                ##
##  Description:  Prints the "CREATOR" and "TYPE" codes for       ##
##                each pathname passed on the command line.       ##
##                                                                ##
##  Example:      bash$ whats /Volumes/MacHD/*                    ##
##                R*ch adrp       BBEdit Lite 4.6                 ##
##                CDrw dDrw       Glossary_schema.drw             ##
##                MSIE adrp       Internet Explorer               ##
##                MSWD adrp       Microsoft Word                  ##
##                NIFt adrp       NiftyTelnet 1.1 SSH r3          ##
##                CARO PDF        ziegnet.pdf                     ##
##                                                                ##
####################################################################

use strict;

my $GET_FILE_INFO = '/Developer/Tools/GetFileInfo';

MAIN: {
	while( @ARGV ) {
		my $Pathname = shift;
		my $Creator = GetInfo( 'c', $Pathname );
		my $Type = GetInfo( 't', $Pathname );
		printf( "%4s %4s\t%s\n", $Creator, $Type, $Pathname );
	}
}

sub GetInfo {
	my ($Option, $Pathname) = @_;
	my $Result = `$GET_FILE_INFO -$Option '$Pathname'`;
	my ($Code) = ( $Result =~ /^\s*"(.{4})"\s*$/ );
	$Code ||= " NA ";
	return $Code;
}
