#!/usr/bin/env perl -w
use strict;
use warnings;

use lib "/usr/local/libexec/nagios";
use utils qw(%ERRORS);

my $usage = "Usage: check_mega_raid\nEvaluates whether volume is in optimal state\n";
my $output = ""; my $errs = 0; my $index = 0; my $count = 0;
my (@disk_status_fmt);
my (@part, $enclosure_id, $slot_number, $state, $progress_hosts);

my $status = `/usr/local/sbin/megacli -ldinfo -L0 -aall| /usr/bin/grep State`;
if ($status =~ m/^State: (.*)$/){
	$output .= "RAID Volume $1. ";
	if ($1 =~  m/Optimal/){
	} elsif ($1 =~ m/Degraded/) {
		## Pull data from all disks.  Grab current enclosure ID and slot number.
		my @disk_status = `/usr/local/sbin/megacli -ldpdinfo -aall`;
		while (my $line = shift @disk_status){
			if ($line =~ m/^\w/){
				push @disk_status_fmt, $line;
			}
		}
		splice @disk_status_fmt, 0, 16; 
		while (@disk_status_fmt){
			@part = splice @disk_status_fmt, 0, 16;
			while (my $line = shift @part){
				if ($line =~ m/Slot Number: (\d+)$/){
					$slot_number = $1;
				} elsif ($line =~ m/Enclosure Device ID: (\d+)$/){
					$enclosure_id = $1;
				} elsif ($line =~ m/Firmware\sstate:\s(\w+)$/){
					$state = $1;
				}
			}
			if ($state =~ m/Online/){
			} elsif ($state =~ m/Rebuild/){
				$errs++;
				my $rebuild_status = `/usr/local/sbin/megacli -pdrbld -showprog physdrv\[$enclosure_id:$slot_number\] -a0 | /usr/bin/grep Reb`;
				if ($rebuild_status =~ m/^.*Completed (\d+)%/){
					$output = $output . "$enclosure_id:$slot_number $state ($1%);";
				}
			} else {
				$errs++;
				$output = $output . "$enclosure_id:$slot_number $state; ";
			}
		}
		## We have a drive rebuilding, let's get it's progress.
		# megacli -pdrbld -showprog physdrv\[12:0\] -a0
		# Rebuild Progress on Device at Enclosure 12, Slot 0 Completed 1% in 2 Minutes.

	}
}
print "$output\n";
if ($errs gt 0){
	exit $ERRORS{'CRITICAL'};
} else {
	exit $ERRORS{'OK'};
}
