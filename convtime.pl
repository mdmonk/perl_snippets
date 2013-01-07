#!/usr/bin/perl  --

# Name: amtime.pl
# Purpose: generate output in unix-time-in-seconds format
#          and convert UTiS to a date and time string.
# Author: Andrew Barber

# History: 01-29-2003 - initial creation - Andrew Barber
#
# Notes:
#      Utilizes the POSIX perl module to interface
#use strict;
use Getopt::Std; 
use POSIX 'strftime';
use POSIX 'mktime';

# Define some variables
#$GMT_FLAG=0;
#$GMT_FLAG=0;
$FMT_STR="%c";

# Define some functions
# Display the usage.
sub usage_exit {
     print "@_\n";
     print "Usage: amtime.pl {-t \"\" | -d \"\" [+]}\n";
     print "     -t     Calculate Unix time in seconds from a date.\n";
     print "          Format is \"wday mon day hh:mm:ss yyyy\"\n";
     print "          ex: amtime.pl -t \"Wed Jan 29 11:16:32 2003\"\n";
     print "     -d     Formats a date-time string from a give unix time in seconds\n";
     print "          ex: amtime.pl -d 1043857131\n";
     print "     +     Format of the date-time string of option -d\n";
     print "          Default is %c.\n";
     print "          Optionally can be any supported format string of the 'date' command.\n";
     print "          ex: amtime.pl -d 1043857131 +%Y%m%d\n";
     exit;
}

# print_dttm() function - argument is a Unix-time-in-seconds integer value.
# If no argument is given, we will use the current time.
sub print_dttm {
     if ($_[0] ne '') {
          $TIME_ARG=$_[0];
     } else {
          # Because of how getopt works, this will probably
          # never be reached.
          $TIME_ARG=time;
     }
     # strftime() formats the data in the list returned by 
     # localtime() based on the format string given.
     print strftime("$FMT_STR\n",localtime($TIME_ARG));
     return 0;
}

# print_utis() function - argument passed is a date/time string.
# Currently supported format is "WDAY MONTH DAY TIME YEAR"
# i.e. Sun Mar  2 19:52:46 2003
sub print_utis {
     my($time_str)=@_;
     if (! defined($time_str)) {
          # Return utis for current time.
          $UTIS_STR=time;
     } else {
          my($weekday,$month,$mday,$time,$year) = split(/ /,$time_str);
          # We need to parse time time string sent in.
          
          # Here are some arrays of conversion stuff.
          # week day conversion:
          my(%WDAY)=(     "Sun",0,
                    "Mon",1,
                    "Tue",2,
                    "Wed",3,
                    "Thu",4,
                    "Fri",5,
                    "Sat",6);
          my(%MON)=(     "Jan",0,
                    "Feb",1,
                    "Mar",2,
                    "Apr",3,
                    "May",4,
                    "Jun",5,
                    "Jul",6,
                    "Aug",7,
                    "Sep",8,
                    "Oct",9,
                    "Nov",10,
                    "Dec",11);
          
          # Set the week day and month numbers based on the above hash.
          my($wday)=$WDAY{$weekday};
          my($mon)=$MON{$month};

          # split up the time into hour, min, and sec.
          my($hour,$min,$sec)=split(/:/,$time);

          # Make the real year:)
          $year-=1900;

          # See what happens:P
          $UTIS_STR=mktime($sec,$min,$hour,$mday,$mon,$year);

     }
     print "$UTIS_STR\n";
}

####### MAIN #######

# Process command-line args.
# perl 5.001 doesn't understand hashes yet:P
#getopts('?hd:t:g', \%opts);
getopts('hd:t:g');

# check if we want help.
if ($opt_h) {
     usage_exit "";
}

# Parse the rest of ARGV in case a format is specified.
$arg="@ARGV";
if ($arg =~ /^\+(.*)/) {
     $FMT_STR="$1";
}

# only one of -d or -t are allowed, and -f isn't allowed for -t...
if ($opt_d && $opt_t) {
     usage_exit "-d and -t options cannot be used together.";
}

if (! $opt_d && ! $opt_t) {
     print_utis;
} elsif ( $opt_d ) {
     print_dttm $opt_d;
} elsif ( $opt_t ) {
     print_utis $opt_t;
}
