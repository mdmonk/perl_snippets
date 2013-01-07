#!/usr/bin/perl
#############################################################
# Prog Namen: mp3checks.pl
# Kodur:      MdMonk
# Tell me about it: Read the help, dork. (mp3checks.pl -h)
# Mad Props:  Thanks to Ranger Rick for sending me his
#             mp3-time script (which is included in this
#             script), and getting me started on this
#             one. Yeah, I know. This script is pretty
#             weak. But I needed *something* to clean up
#             my mp3 archive. CWL
# Date:       10/21/2001 (Initial Revision)
#############################################################

use MP3::Info;
use File::Find;
use Getopt::Std;

use vars qw(
	$seconds
	$counter
	$number
	$runinfo
	$test
	$badcounter
	$file
	$origfile
	$info
	$originfo
	$VERSION
	$VDATE
);
#
# p=path, a=automagic, f=findDups, t=mp3time, d=debug, k=killIt, h=help, b=bitrate
# -p and one of the following options are always required:
#	-f (findDups), -t (mp3time), or -c (cleanUp)
# -h (help) is always good for a (somewhat) useful msg.
#
getopts('p:b:aAftdkhcs');

$VERSION = '0.0.5';
$VDATE   = '11.06.2001';

if ($opt_h) {
	printHelp();
}
if ($opt_f || $opt_t ||$opt_c) {
	unless ($opt_p) {
		die "The path must always be specified, unless you are accessing help, Foo!!!\n";
	}
} else {
	printHelp();
}
if ($opt_c) {
	unless ($opt_b) {
		die "You must specify the bitrate if you are doing cleanUp (-c). Read the help chedderhead...\n";
	}
}

$seconds = 0;
$counter = 0;
$number  = 0;
$runinfo = 0;
$test    = 0;
$badcounter = 0;

print "$0, v$VERSION, $VDATE\n";

if ($opt_t) {
	print "Calculating MP3 Play Time...\n";
} elsif ($opt_f) {
	print "Finding Duplicate Files...\n";
} elsif ($opt_c) {
	print "Finding substandard MP3s...\n";
} else {
	# should never reach this point.... CWL
	print "You must specify *something* foolio!\n";
}

find (\&wanted, $opt_p);

$number = int(keys %files);

for my $file (sort keys %files) {
	if ($opt_t) {
		bens_get_info($file);
	} else {
		chucks_get_info($file);
	}
}

if ($opt_t) {
	print "\r100%       \n";
	print "\nTotal MP3 Playtime:\n";
	print "In Seconds:";
	#printf("\t\%7.2f              \n", $seconds);
	printf("\t\%7.2f\n", $seconds);
	print "In Minutes:";
	#printf("\t\%7.2f              \n", $seconds / 60);
	printf("\t\%7.2f\n", $seconds / 60);
	print "In Hours:  ";
	#printf("\t\%7.2f              \n", $seconds / 60 / 60);
	printf("\t\%7.2f\n", $seconds / 60 / 60);
	print "In Days:   ";
	#printf("\t\%7.2f              \n", $seconds / 60 / 60 / 24);
	printf("\t\%7.2f\n", $seconds / 60 / 60 / 24);
}

print "\n\nRun Complete.....\n";

endRunSummary();

##################################
# Subroutines
##################################
sub wanted {
	if ($opt_f) {
		if ($opt_k) {
			# just deleting all the other dup files. Not checking them
			# until I develop better (more intelligent) checks than are
			# currently in place. CWL
			if (/\-2\.mp3$/i) {killFile($_);}
			if (/\-3\.mp3$/i) {killFile($_);}
			if (/\-4\.mp3$/i) {killFile($_);}
			if (/\-5\.mp3$/i) {killFile($_);}
			if (/\-6\.mp3$/i) {killFile($_);}
			if (/\-7\.mp3$/i) {killFile($_);}
			if (/\-8\.mp3$/i) {killFile($_);}
			if (/\-9\.mp3$/i) {killFile($_);}
		}
	}
	if ($opt_f) {	
		return unless (/\-1\.mp3$/i);
	} else {
		return unless /\.mp3$/i;
	}
	$files{$File::Find::dir . '/' . $_} = 1;
}

sub bens_get_info {
        my $file = shift;

        my $info = get_mp3info($file);

        $counter++;

        if ($counter % 10 == 0) {
                printf("\r\%3.2f\%\%              \n", $counter / $number * 100);
        }

        $seconds += ($info->{MM} * 60);
        $seconds += $info->{SS};
}

sub chucks_get_info {
	$file = $origfile = shift;
	$counter++;
	$info = get_mp3info($file);

	if ($opt_f) {	
		$origfile =~ (s/\-1\./\./);
		$originfo = get_mp3info($origfile);
		cmpFiles();
	} else {
		# Since we aren't looking for dup files, we must be checking for good mp3s. CWL
		if ($info->{VBR}) {
			# skipping VBR files for now. CWL
		} elsif ($info->{BITRATE} < $opt_b) {
			# Add more checks here....for now, only checking bitrate. CWL
			$badcounter++;
			print "$badcounter of $counter: $file\n";
			print "\tReason: Minimum bitrate is: $opt_b, file bitrate is: $info->{BITRATE}\n";
			if ($opt_k) {killFile($file);}
		}
	}
}

sub cmpFiles {
	# MP3 information about the *-1.mp3 file
	print "[0] Original File: $origfile\n";
	print "\tVBR?\t\t\t$originfo->{VBR}\n";
	if ($originfo->{VBR}) {print "\tVBR_Scale:\t\t\t$originfo->{VBR_SCALE}\n";}
	print "\tBitrate:\t\t$originfo->{BITRATE}\n";
	print "\tTime:\t\t\t$originfo->{TIME}\n";
	print "\tSeconds:\t\t$originfo->{SECS}\n";
	print "\tSize:\t\t\t$originfo->{SIZE}\n\n";
	# MP3 information about the *-1.mp3 file
	print "[1] *-1 File: $file\n";
	print "\tVBR?\t\t\t$info->{VBR}\n";
	if ($info->{VBR}) {print "\tVBR_Scale:\t\t\t$info->{VBR_SCALE}\n";}
	print "\tBitrate:\t\t$info->{BITRATE}\n";
	print "\tTime:\t\t\t$info->{TIME}\n";
	print "\tSeconds:\t\t$info->{SECS}\n";
	print "\tSize:\t\t\t$info->{SIZE}\n\n";
	if ($opt_a) {
		if ($originfo->{BITRATE} == $info->{BITRATE}) {
			if ($originfo->{SECS} < $info->{SECS}) {
				if ($opt_k) {killFile($origfile);}
				print "Moving $file, to $origfile\n";
				unless ($test) {rename ($file, $origfile);}
			} else { if ($opt_k) {killFile($file);} }
		} else { getInput(); }
	} elsif ($opt_A) {
		if ($originfo->{SECS} < $info->{SECS}) {
			if ($opt_k) {killFile($origfile);}
			print "Moving $file, to $origfile\n";
			unless ($test) {rename ($file, $origfile);}
		} else { if ($opt_k) {killFile($file);} }
	} else { getInput(); }
}

sub getInput {
	# initialize $input with a nonvalid value. CWL
	my $input = '3.14';
	while ($input !~ /^[0-1]$/) {
		print "(0=Original File and 1=Duplicate Filename'd File)\n";
		print "Please Enter File Number to Remove [0 or 1]: " ;    
		$input = <STDIN>;
		chomp $input;
	}
	if ($input == '0') {
		killFile($origfile);
		print "Moving $file, to $origfile\n";
		unless ($test) {rename ($file, $origfile);}
	} elsif ($input == '1') { if ($opt_k) {killFile($file);} }
}

sub killFile {
	my $rmFile = shift;
	print "Removing $rmFile .....\n";
	unless ($test) {unlink ($rmFile);}
}

sub removeSpaces {
	# this sub not yet implemented...
	$fileName = shift;
	$fileName =~ s/\s+/\_/g;
}

sub endRunSummary {
	unless ($opt_t) {	
		print "Total MP3s checked:\t$counter\n";
		print "          Bad MP3s:\t$badcounter\n\n";
	}
}
sub printHelp {
	print "$0, v$VERSION, $VDATE\n\n";
	print "$0 is a script to do a couple of different things with mp3s.\n";
	print "   It calculates the total playing time for a directory of mp3s;\n";
	print "   It can go through a directory to locate and purge mp3s that are\n";
	print "   substandard (e.g. low bitrate).\n";
	print "   It can compare duplicate mp3s (dup name, one with a -1.mp3 at the\n";
	print "   end of the filename), and you can select which mp3 to remove.\n\n";
	print "*Required* '-p': path to search\n";
	print "You must specify one of the following options:\n";
	print "   '-f': search for duplicate files\n";
	print "   '-t': calculate playing time\n";
	print "   '-c': clean up crappy mp3s\n";
	print "Other options (some required by the options listed above:\n";
	print "   '-k': kill (delete) offending files\n";
	print "   '-a': automagic (in one spot, you can have it remove the most likely crappy mp3)\n";
	print "   '-b': bitrate (required for '-c' option)\n";
	print "   '-s': change spaces, in filename, to '_' (feature creep from Ralph =) )\n";
	print "         (coming soon...any suggestions on how to implement this function?)\n";
	print "   '-d': debug\n";
	print "   '-h': you're readin' it....\n\n";
	print "example: $0 -k -c -b 128 -p /path/to/mp3s\n";
	print "         $0 -k -f -p /path/to/mp3s\n";
	die   "         $0 -t -p /path/to/mp3s\n";
}
