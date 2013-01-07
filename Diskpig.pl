# DISKPIG.PL - Reports the total bytes of each subdirectory of a directory
#
# This script was written by Paul Popour (ppopour@infoave.net) in 2000.
# It is released into the public domain.  You may use it freely, however,
# if you make any modifications and redistribute, please list your name
# and describe the changes. This script is distributed without any warranty,
# express or implied.
#
#  SYNTAX - perl diskpig.pl {dirname}
#
# Example
#   perl diskpig.pl C:\TEMP
#  or
#   perl diskpig.pl \\SERVER1\PROFILES
#
# Primary use for this script is to calculate and record the amount of
# space used by each user under their user and profile directory.  You
# can also use it on the groups directory, however, it doesn't calculate
# by user only by parent directory.  Will accept either a local directory
# name or a UNC share/directory.  AND PLEASE - Windows 95 adds about as
# well as a two year old.  If you think the script's totals are wrong feel
# free to break out the calculator.

use strict;
my (@trash, %badext, $dir, $output1, $output2, $chopped, @filenames, $fcount,
$tsize, $file, $myfile, %H1, $fsize, $root, @keys, $key, $value1, $endtime,
$runtime, $entry, $size, $fname, @fnext, $starttime, %H2);

$starttime = (time); # Used to measure performance

# Files with the extensions in the trash array are not deleted, just recorded.

@trash = ("AVI", "MP3", "MOV", "MPEG");

# Any file that has an extension that matches the ones in the trash array
# will be recorded in the diskpig_trash.txt file.  Add entries in the
# same syntax ("EXT",) in uppercase.  Uses badext hash to speed searches.

undef %badext;
for (@trash) {$badext{$_} = 1 };
if ($ARGV[0] eq ""){&syntax; exit 1;}
$dir = $ARGV[0];

# The two output file names are stored in output1 and output2.  These are
# deleted each time the program runs so remember to rename if you want to
# save them.

$output1 = "C:\\temp\\diskpig_size.txt";
$output2 = "C:\\temp\\diskpig_trash.txt";

# The directory path needs to end with a backslash so the last character
# is chopped off, compared, and added back with the backslash if needed.

$chopped = chop ($dir);
if ($chopped eq "\\"){$dir = "$dir$chopped";}
else {$dir = "$dir$chopped\\";}

# Read in the files and directory names in the directory excluding . and ..

unless (opendir (PDIR, $dir))
 {
 print "\n\n\tERROR: Path not found - $dir\n\n";
 &syntax;
 exit 1;
 }
@filenames = grep (!/^\.\.?$/ , readdir (PDIR));
closedir PDIR;
print "\n\nWalking $dir\n\n";

$fcount = 0; # Initialize a counter to count the total number of files
$tsize = 0; # Initialize a counter for total bytes in a subdirectory

foreach (@filenames)
 {
 $myfile = ("$dir$_");
 if (-d $myfile) # If a directory sends to subdir subroutine
  {
  print "\t$myfile\n";
  &subdir("$myfile");
  $H1{"$myfile"} = $tsize;
  $tsize = 0;
  }
 else
  {
  # Records the size of the files in the parent directory
  $fsize = 0;
  $fsize = -s ("$myfile");
  &anytrash($myfile, $fsize);
  $root = ($root + $fsize);
  $fsize = 0;
  $fcount++;
  }
 }
$H1{"$dir"} = $root;
open(OUTPUT1, ">$output1") || die "Can't open $output1";
@keys = sort {$H1{$b} <=> $H1{$a} || length($b) <=> length($a) || $a cmp $b}
keys %H1;
foreach $key (@keys)
 {
 $value1 = $H1{$key};
 1 while $value1 =~ s/(.*\d)(\d\d\d)/$1,$2/;
format OUTPUT1 =
@<<<<<<<<<<<<<<<<<<<<<<<<<@>>>>>>>>>>>>>>>>
$key,$value1
.
$~ = "OUTPUT1";
 write (OUTPUT1);
 }
close OUTPUT1;
open(OUTPUT2, ">$output2") || die "Can't open $output2";
@keys = sort {$H2{$b} <=> $H2{$a} || length($b) <=> length($a) || $a cmp $b}
keys %H2;
foreach $key (@keys)
 {
 $value1 = $H2{$key};
 1 while $value1 =~ s/(.*\d)(\d\d\d)/$1,$2/;
format OUTPUT2 =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<@>>>>>>>>>>>>>>
$key,$value1
.
$~ = "OUTPUT2";
 write (OUTPUT2);
 }
close OUTPUT2;
$endtime = (time);
$runtime = $endtime - $starttime;
if ($runtime <= 60){print "\n\nProcessed $fcount files in $runtime
seconds\n\n";}
else {print "\n\nProcessed $fcount files in ". $runtime/60 . " minutes\n\n";}

sub subdir
 {
 my $DIR = shift;
 if (opendir DIR, $DIR)
  {
  foreach (readdir(DIR))
   {
   next if $_ =~ m/^(\.|\.\.)$/;
   $entry = "$DIR\\$_";
   if (-d $entry){&subdir($entry);}
   else
    {
    $size = 0;
    $size = -s ("$entry");
    $tsize = ($tsize + $size);
    $fcount++;
    &anytrash($entry, $size); # look for extensions in the trash array
    }
   }
  closedir DIR;
  }
  else {
  print "Can't open directory $DIR\n";
  }
 }

sub syntax
 {
 print "
 SYNTAX\t\tperl diskpig.pl {dirname}\n\n
 Examples\tperl diskpig.pl D:\MYFILES\n\n\t\t\tperl diskpig.pl
\\\\SERVER1\\PROFILES\n\n";
 }

sub anytrash
{
 my ($fname, $size) = @_;
 @fnext = split ('\.', "$fname");
 # If the extension is in the trash array but the file isn't a shortcut link
 if (($badext{"\U$fnext[1]\E"} eq "1") && ("\U$fnext[2]\E" ne "LNK"))
 {
  $H2{"$fname"} = $size;
 }
}
