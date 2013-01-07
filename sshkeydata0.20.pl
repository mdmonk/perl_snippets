#!/usr/bin/perl
#
# sshkeydata - command line SSH content analysis. This program analyses 
#  keydata files created by "chaosreader", and can estimate the
#  original commands typed during SSH sessions.
#
# OVERVIEW: You have captured some SSH and some telnet sessions in tcpdump 
#  or snoop files, originating from the same user. sshkeydata compares
#  details from the known telnet session with details from the unknown SSH
#  session to estimate the commands typed.
#
#  First, chaosreader is executed on the dump files which generates keydata 
#  files - these contain keystroke delays and other details from the sessions.
#  Then sshkeydata is run on the keydata files and estimates of the original 
#  commands within the SSH session are given. 
# 
# 01-May-2004, ver 0.20  (check for new versions, http://www.brendangregg.com)
#			 (first release!)
#
# USAGE:	sshkeydata plaintext.keydata[...] ssh.keydata
# eg,
#    sshkeydata 1/session_0001.telnet.keydata 2/session_0001.textSSH.keydata 
#
# EXAMPLE:
#  For a full example see http://www.brendangregg.com/sshanalysis.html
#
# COPYRIGHT: Copyright (c) 2004 Brendan Gregg.
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version. 
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details. 
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software Foundation, 
#  Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#  (http://www.gnu.org/copyleft/gpl.html)
#
# Author: Brendan Gregg  [Sydney, Australia]
#
# NOTES: 
#  * The distance vector algorithm currently used compares the 
#    similaraties between the unknown events and the known events
#    taking the entire typed command as an event. This does compare
#    the individual keystroke delays between say a known "ls -l" and
#    a possible "ls -l", however does not currently make use of this
#    information to compare an "ls -l" with a possible "ls -la" - where
#    the compared events would be each key pair to any other command
#    that contained the same key pair.
#
# Todo:
#  * Improve distance algorithm. 
#  * Add more comments to code.
#  * More analysis algorithms; fuzzy, neural nets, Bayesian...
#
# 01-May-2004	Brendan Gregg	Created this.


##################
#  Coefficients
#
# These are the tunables for the distance analysis equation, they modify
# the influence that data has on the outcome. See Analyse_Distance.
#
# These values are critical to the analysis algorithm and have been "trained"
# by running this program in calibration mode (where a known session is
# analysed).
#
# The following are listed in desired impact order, as we would like
# keystroke delays to count the most and command frequency to count the least.
# (Their values may suggest otherwise as the values cannot be compared
# directly with each other without taking the analysis algorithm into account).
#
$KEY   = 0.14;	# The delay between keystrokes
$SUM   = 0.43;	# The time taken to type the command (keystroke delay sum).
$PAUSE = 0.69;	# The pause between the enter key and the command commencing
$SIZE  = 0.36;	# The size of the command output
$TIME  = 0.73;	# The time taken for the command to output
$FREQ  = 0.38;	# Frequency of command in training data


#######################
#  Default Variables
#
$TOP = 5;	# Print out top 5 matches
$PRINT = 1;	# Print normal output
$VERBOSE = 0;	# Print data sets
$DEBUG = 0;	# Print extra debug data
$| = 1;

# $RESPONSE enables use of the response data from the keydata files - this
# represents whether a command responded immediatly (builtins) or after
# an enter key was echoed (external commands). Setting this to 1 should
# help, however I have found the data is only reliable for some SSH sessions.
# To check which you have, grep "r" in your keydata files - if they are
# all the same value within a file then leave $RESPONSE = 0.
#
$RESPONSE = 0;


if ($ARGV[0] eq "--calibrate") {
	$CALIBRATE = 1;
	$answerfile = pop(@ARGV);
	shift(@ARGV);
}

$targetfile = pop(@ARGV);
@Basefiles = @ARGV;


####################
#  Read Base Data
#
# Here we read the keystroke data files. These are the base files that
# will be used for comparison with the unknown data. 
#
print "\nReading Input Data,\n\n" if $VERBOSE;

$cmdnum = 0;
foreach $basefile (@Basefiles) {
	open (TRAIN,"$basefile") || die "ERROR1: Can't open $basefile: $!\n";

	$keynum = 0; $response = 0; $pause = 0;
	$size = 0; $time = 0; $argv = ""; $delay = "";

	while ($line = <TRAIN>) {
		($code,$value) = $line =~ /^(.).(.*)/;
		if ($code eq "k") { 
			$keynum++; 
			$argv .= $value;
		}
		if ($code eq "d") { 	$delay .= "$value:"; }
		if ($code eq "r") { 	$response = $value; }
		if ($code eq "p") { 	$pause = $value; }
		if ($code eq "s") {	$size = $value; }
		if ($code eq "t") {	$time = $value; }
		if ($code eq " ") {
			$delay =~ s/:$//;
			$response = 1 if $RESPONSE == 0;
			$Known{$keynum}{$response}{$cmdnum}{argv} = $argv;
			$Known{$keynum}{$response}{$cmdnum}{delay} = $delay;
			$Known{$keynum}{$response}{$cmdnum}{pause} = $pause;
			$Known{$keynum}{$response}{$cmdnum}{size} = $size;
			$Known{$keynum}{$response}{$cmdnum}{time} = $time;
			$Command{$cmdnum} = $argv;
			$Freq{$argv}++;

			print "$keynum:$response:$delay:$pause:$size:" .
			 "$time:$argv\n" if $VERBOSE;

			$keynum = 0; $response = 0; $pause = 0;
			$size = 0; $time = 0; $argv = ""; $delay = "";
			$cmdnum++;
		}
	}
	close TRAIN;
}


######################
#  Read Target Data
#
# Here the target data file is read, this contains all the details
# except for the plain text which is unknown.
#
print "\nReading Target Data,\n\n" if $VERBOSE;

open (TARGET,"$targetfile") || die "ERROR2: Can't open $targetfile: $!\n";

$cmdnum = 0; $keynum = 0; $response = 0; $pause = 0;
$size = 0; $time = 0; $argv = ""; $delay = "";

while ($line = <TARGET>) {
	($code,$value) = $line =~ /^(.).(.*)/;
	if ($code eq "k") { 
		$keynum++; 
		# the following is for test runs on known data
		$argv .= $value;	
	}
	if ($code eq "d") { 	$delay .= "$value:"; }
	if ($code eq "r") { 	$response = $value; }
	if ($code eq "p") { 	$pause = $value; }
	if ($code eq "s") {	$size = $value; }
	if ($code eq "t") {	$time = $value; }
	if ($code eq " ") {
		$delay =~ s/:$//;
		$response = 1 if $RESPONSE == 0;
		$Target[$cmdnum]{keynum} = $keynum;
		$Target[$cmdnum]{response} = $response;
		$Target[$cmdnum]{argv} = $argv;
		$Target[$cmdnum]{delay} = $delay;
		$Target[$cmdnum]{pause} = $pause;
		$Target[$cmdnum]{size} = $size;
		$Target[$cmdnum]{time} = $time;

		print "$keynum:$response:$delay:$pause:$size:$time:$argv\n"
		 if $VERBOSE;

		$keynum = 0; $response = 0; $pause = 0;
		$size = 0; $time = 0; $argv = ""; $delay = "";
		$cmdnum++;
	}
}
close TARGET;
$commands = $cmdnum;


##########
#  MAIN
#
if ($CALIBRATE) {
	&Calibrate(\&Analyse_Distance);
} else {
	&Analyse_Distance();
}



###################################
# Analyse Target Data - Distance
#
# This analyses the target data (unknown content) with the training data
# (known content), to estimate the original text.
#
# This is a distance vector algorithm with trained coefficients.
#
sub Analyse_Distance {
   @Output = ();
   print "\nAnalysis of Target Data,\n" if $PRINT;

   for ($i=0; $i < $commands; $i++) {
	$keynum = $Target[$i]{keynum};
	$response = $Target[$i]{response};
	$argv = $Target[$i]{argv};
	$delay = $Target[$i]{delay};
	$pause = $Target[$i]{pause};
	$size = $Target[$i]{size};
	$time = $Target[$i]{time};
	$time = 1 if $time > 1;			# cap long running commands
	$size = 10_000 if $size > 10_000;	#  "   "
	$keys = @Delay = split(/:/,$delay);
	
	next if $keynum < 2;
	$output++;

	print "\nExamining $i, keys $keynum, response $response, argv $argv\n"
	 if $PRINT;

	foreach $cmdnum (keys(%{$Known{$keynum}{$response}})) {
		$score = 0;

		$targv = $Known{$keynum}{$response}{$cmdnum}{argv};
		$tdelay = $Known{$keynum}{$response}{$cmdnum}{delay};
		$tpause = $Known{$keynum}{$response}{$cmdnum}{pause};
		$tsize = $Known{$keynum}{$response}{$cmdnum}{size};
		$ttime = $Known{$keynum}{$response}{$cmdnum}{time};
		$ttime = 1 if $ttime > 1;
		$tsize = 10_000 if $tsize > 10_000;
		@TDelay = split(/:/,$tdelay);

		$sdelay = 0; $sum1 = 0; $sum2 = 0;

		for ($j=0; $j < $keynum; $j++) {
			$d1 = $Delay[$j];
			$d2 = $TDelay[$j];
			$sum1 += $d1;
			$sum2 += $d2;
			$diff = abs($d1 - $d2);
			$sdelay += $KEY * $diff;
		}
		$spause = $PAUSE * abs($pause - $tpause);
		$ssum = $SUM * abs($sum1 - $sum2);
		$tmp = abs($size - 80 - $tsize) / 32;
		if ($tmp > 1) {
			$ssize = $SIZE * log($tmp);
		} else {
			$ssize = 0;
		}
		$stime = $TIME * abs($time - $ttime);
		$sfreq = $FREQ * (1 / $Freq{$targv});

		$score = $sdelay + $ssum + $spause + $ssize + $stime + $sfreq;

		printf(" Delay %.3f, Sum %.3f, Pause %.3f, Size %.3f, " .
		 "Time %.3f, Freq %.3f = %.6f, $targv\n",$sdelay,$ssum,
		 $spause,$ssize,$stime,$sfreq,$score) if $DEBUG;

		$Result{$i}{$cmdnum}{score} = $score;
	}
	
	$top = 1;
	foreach $cmdnum (sort { 
	 $Result{$i}{$a}{score} <=> $Result{$i}{$b}{score}
	  } (keys(%{$Result{$i}}))) {
		$command = $Command{$cmdnum};
		$command =~ s/\\n$//;
		if ($PRINT) {
			$score = $Result{$i}{$cmdnum}{score};
			# the following formula converts the score into
			# a percent confidence (it's just a rough guide).
			if ($score < 0.5) {
				$percent = 100 - 100 * $score**2;
			} elsif ($score > 0) {
				$percent = 18.75 * 1 / $score**2;
			} else {
				$percent = 100;
			}
			printf("%3d %11.6f %8.2f  %s\n",$top,$score,
			 $percent,$command);
			push(@Final,sprintf("%3d %11.6f %8.2f  %s\n",
			 $i,$score,$percent,$command)) if $top == 1;
		}
		push(@Output,$command) if $top == 1;
		last if $top++ == $TOP;
	}

   }
}

#
#  Print Summary
#
if ($PRINT) {
	print "\n\nFinal Report,\n\n";
	printf("%3s %11s %8s  %s\n","Num","Score","Percent","Command");
	print @Final;
}


###########################
#  Calibrate Coefficients
#
# Here we run through a range of coefficients to see how they perform.
# This is designed to be used during development of the analysis algorithms.
#
sub Calibrate {
	$Analyse = shift;

	shift(@ARGV);
	$PRINT = 0;
	$VERBOSE = 0;
	$DEBUG = 0;
	$total = 0;
	$i = 0;

	@Coeffs1 = qw(0.02 0.1 0.2 0.5 1.0 2.0);
	@Coeffs2 = qw(0.02 0.1 0.2 0.5);

	#
	#  Read Answer File
	#
	open (ANSWER,"$answerfile") || 
	 die "ERROR3: Can't open $answerfile: $!\n";
	while (chomp($line = <ANSWER>)) {
		$i++;
		$total++;
		$Answer{$i} = $line;
	}
	close ANSWER;

	
	foreach $a (@Coeffs1) {	$KEY = $a;
	foreach $b (@Coeffs1) {	$SUM = $b;
	foreach $c (@Coeffs1) {	$PAUSE = $c;
	foreach $d (@Coeffs1) {	$SIZE = $d;
	foreach $e (@Coeffs1) {	$TIME = $e;
	foreach $f (@Coeffs2) {	$FREQ = $f;

		&{$Analyse};
		$i = 0;
		$correct = 0;
		foreach $command (@Output) {
			$i++;
			$command =~ s/\\n$//;
			$correct++ if $command eq $Answer{$i};
		}
		$percent = sprintf("%.8f",100 * $correct / $total);
		print "$a $b $c $d $e $f = $percent\n";
	}
	}
	}
	}
	}
	}
}

