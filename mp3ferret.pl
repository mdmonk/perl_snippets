#!/usr/bin/perl
use File::Find;
use MPEG::MP3Info;
use Getopt::Std;
# looks for mp3's with certain tests for rate, freq, and stereo/mono
# the script is intended for use with DJIAB but could work for other things.

# Copyright (C) 2001 George Motter (george@motter.com)
# Portions Copyright (C) 2001 Ben Reed (ranger@befunk.com)
# Portions from mp3check.pl at http://muse.linuxmafia.org/

# this script is released under the GPL
# version .04

# USAGE
# mp3ferret.pl [option] mp3 dir
# options are:
#  -r bitrate     check for files less than bitrate
#  -m             check for mono files
#  -s frequency   check for samplerate less than frequency
#  -l             return both the filename and directory
#    Then specify the directory where you store your mp3's
#  example:  mp3ferret -r 128 -f /home/djiab/music

######### options ########
my %options;
getopts("r:mvkhs:f:l", \%options);

  if ($options{r}){
  	$bitrate = $options{r};
  #  print "Checking for files with a bitrate less than $bitrate\n";
#	  print "----------------------------\n";
  }

  elsif ($options{m}){
    $stereo = 0;
#    print "Checking for files that are mono\n";
#	  print "----------------------------\n";
  }

  elsif ($options{s}){
  	$freq = $options{s};
#    print "Checking for files with a sample freq. less than $freq\n";
	#  print "----------------------------\n";
  }
  
  elsif ($options{l}){
  	$uselong = 1;
   # print "Returning full path and filename\n";
   # print "----------------------------\n";
  }

  elsif ($options{k}){
  	$killIt = 1;
   # print "Returning full path and filename\n";
   # print "----------------------------\n";
  }


  else {
  	print "\nYou must specify an action and optionally a filepath:\n";
	  print "-r bitrate     check for files less than bitrate\n";
    print "-m             check for mono files\n";
    print "-s frequency   check for samplerate less than frequency\n";
    print "-l             return both the filename and directory\n";
    print "Then specify the directory where you store your mp3's\n";
    print "example:  mp3ferret -r 128 /home/djiab/music\n\n";
    exit;
  }

  my $path=$ARGV[0];

  if (!($path)){
   $path=".";
	# print "Using current directory\n";
	}else{
	# print "Using $path as directory\n";
  }
	#print "----------------------------\n";

 #  print "Scanning $path...\n";

  find(\&find_path, $path);
  find({ wanted => \&find_path, follow => 0}, $path);


sub find_path {
  my $name = $File::Find::name;

  if ($name =~ /\.mp3$/) {

     my @path             = split(/[\\\/]+/, $name);
     my $filename  = pop(@path);
     
     my $rPath = @path;

     my $file = $filename;
     print "Reading file: $filename\n";

     my $info = get_mp3info($name);


  if (!($uselong)){
  	$file =~ s/\/.*\///;
  }

  # $fileQ = "\"$file\"";
  $fileQ = $file;

	if ($bitrate){
	my $ratetest= ($info->{BITRATE});
		if ($ratetest < $bitrate){
	#		printf "$file\'s bitrate is %d", $info->{BITRATE};
	#		print "\n";
            print STDOUT "$rPath/$fileQ\n";
            if ($killIt) { unlink("$rPath/$fileQ"); }
		}
	}

	if ($stereo){
	  my $modetest= ($info->{STEREO});
		if ($modetest == $stereo){
	#		printf "$file\'s mode is mono\n";
            print STDOUT "$rPath/$fileQ\n";
            if ($killIt) { unlink("$rPath/$fileQ"); }
		}
	}

	if ($freq){
	my $freqtest= ($info->{FREQUENCY});
		if ($freqtest < $freq){
	#		printf "$file\'s Frequency is %d", $freqtest;
	#		print "\n";
            print STDOUT "$rPath/$fileQ\n";
            if ($killIt) { unlink("$rPath/$fileQ"); }
		}
	}
 }
}

#close (LOG);
