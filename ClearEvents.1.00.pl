#!/usr/bin/perl
use Win32::EventLog;
use Time::CTime;
use strict;
my $VERSION = '1.00';

my ($Event, @timearray, $filename,
    $day, $month, $directory);

#  Where do you want to put the backup files?
$directory = 'c:/EventLogs/';

for ('System', 'Security', 'Application')	{
	$Event = new Win32::EventLog ("$_", "");
	@timearray=localtime(time);
	$month = sprintf ('%.2d', $timearray[4] +1);
	$day = sprintf ('%.2d', $timearray[3]);
	$filename = $directory . ($timearray[5]+1900) . '_' .
	             $month . '_' . $day . '_' . $_ . '.events';
	$Event->Clear($filename);
	`gzip -9 $filename`;
} # End for

=head1 NAME

ClearEvents - Clear out the events in the WinNT event log, and create
a backup copy, optionally gzip'ing it, if you happen to have 
gzip installed.

=head1 DESCRIPTION

Clear out the events in the WinNT event log, and create
a backup copy, optionally gzip'ing it, if you happen to have 
gzip installed.

There's nothing fancy going on here - the main part of this
is directly from the Win32::EventLog docs.

I run this via cron on some of my NT machines that have a nasty
habit of filling up the event logs every few days. Security 
policy requires that we keep 6 months worth of logs.

=head1 PREREQUISITE

uses Win32::EventLog and Time::CTime

=head1 COREQUISITE

None

=head1 README

Clears out events in the WinNT event log - System, Security, and
Application logs - and creates a backup copy, optionally gzip'ing
it, if you have gzip installed.

=head1 To Do

Instead of using gzip, I'm planning to use Amine's PerlZip package.

=head1 Author

Rich Bowen - <rbowen@rcbowen.com>

=pod OSNAMES

MSWin32

=pod SCRIPT CATEGORIES

Win32

=cut