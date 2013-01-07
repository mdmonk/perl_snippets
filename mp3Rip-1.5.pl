#!/usr/bin/perl

########################################################################
# mp3Rip 1.5 (Sep 8, 2004)
# Perl script to convert CDs into MP3s
# Written by:
#    Kirk Bauer <kirk@kaybee.org>
# (see copyright notice and license at end of file)
########################################################################

# I feel this is necessary because of all the bad publicity MP3s get
# DISCLAIMER: This script is intended to allow an owner of one or more
#             audio CDs to copy said CDs to their computer.  These
#             MP3s can then be played in a much more convenient manner
#             than the original CDs.  The original CDs should be kept
#             in a safe place as a backup, as the MP3s will probably
#             become the copy that will be used.  The MP3s should not
#             be distributed and it is usually illegal to do so.  If
#             the original CDs are sold, the MP3s should be deleted,
#             and it is usually illegal to not do so.

# To use this script, run 'mp3Rip.pl' to just compress
# the entire CD, or you can run 'mp3Rip.pl <track> ...'
# where you specify which tracks to copy.

# The directory structure that will be created is this:
# <dest-dir>
#    <category>
#       <artist-name>
#          <disc-name>
#             XX-<artist-name>-<song-name>.mp3

# If no CDDB data is found, I use the gnome-cd player to store the track data.
# It will show you the DiscID on the edit screen, and the files are saved in
# your home directory in the .cddbslave directory.  You can then execute: 
#    mp3Rip.pl --cddbfile ~/.cddbslave/DISC_ID

# If the ripping process fails at any point after it starts reading from CD
# (i.e. if it doesn't finish reading the CD or if your computer reboots before
# the MP3 compression is done), you can resume by calling mp3Rip.pl with
# the incomplete directory as its argument:
#    mp3Rip.pl /data/new_mp3disks/category/artist/disc-name

# This script could be improved.. that's for sure.  That's why I'm releasing
# it... so, if you improve it, please send me improvements: 
#    Kirk Bauer <kirk@kaybee.org>

$| = 1;
use Getopt::Long;

# define this if you want a log
#$Log = '/home/kirk/.mp3control/song.log';

$ErrorOK = 0;
$CDDBfile = '';
GetOptions ('errorok' => \$ErrorOK, 'cddbfile=s' => \$CDDBfile) or die "Bad options";

# You need to download the CDDB_get perl module from
# http://search.cpan.org/search?dist=CDDB_get
# and specify the location of the included perl program here:
$CDDB = '/usr/bin/cddb.pl';

if ($ErrorOK) {
   $CDParanoia = '/usr/local/sbin/cdparanoia -w -d /dev/cdrom';
}
else {
   $CDParanoia = '/usr/local/sbin/cdparanoia -w -z -d /dev/cdrom';
}

# Where you want the up to 650MB of raw data to be stored
$DataDir = '/data/new_mp3disks';

# Where you want the MP3s to be placed when done
# (each MP3 will be placed here as it is generated)
$DestDir = '/data/new_mp3disks';

# Uncomment this if you want the entire directory for the
# given CD to be moved to a new base when the whole CD is finished
#$MoveDir = '/data/new_mp3disks/t';

# If you want the audio CD to be ejected when it is no
# longer needed, set this appropriately
$Eject = 'eject /dev/cdrom';

# Set this to your MP3 encoder.  It will be called like this:
#    <mp3encoder> file.wav file.mp3
# If that's not okay, you'll have to change the code below.
# Variable Bitrate - 128 to 256
$MP3Encoder = '/usr/bin/lame -V1 -mj -h -b128 -q1';

##########################################################

sub CheckCaps($) {
   my $name = $_[0];

   # Capitalize first letter
   $name =~ s/^(.)/uc($1)/e;

   # Capitalize other letters
   $name =~ s/([_-].)/uc($1)/ge;

   # Make sure the, of, a, an, from are not caps
   while ($name =~ s/_(As|On|In|By|The|Of|A|An|From|For|And|With|Or|To)_/'_' . lc($1) . '_'/e) {
      1;
   }

   return ($name);
}

# This fixes up names like I like them
sub FixName ($) {
   my $name = $_[0];

   # Forward slashes -> hyphen
   $name =~ s=/=-=g;

   # Turn ' (blah)' into '-blah'
   $name =~ s/\((.*)\)/-$1/g;

   # Turn spaces into underscores
   $name =~ s/ /_/g;
   $name =~ s/^_+//;
   $name =~ s/_+$//;

   # Get rid of: ! ? ` ' * , [ ] { } ( ) ; " # \n \r .
   $name =~ s/[\!\[\]{}()'?*,`;"#\n\r\.]//g;

   # Turn '-_' or '_-' or '_-_' or : into '-'
   $name =~ s/(_-_)|(-_)|(_-)|\:/-/g;

   # Get rid of multiple __ or -- in a row
   $name =~ s/--+/-/g;
   $name =~ s/__+/_/g;

   # Turn '&' into '+'
   $name =~ s/&/+/g;

   # Turn '_+_' into '+'
   $name =~ s/_\+_/+/g;

   # Turn '_=_' into '='
   $name =~ s/_\=_/=/g;

   # Rename any form of disk or disc to Disc
   $name =~ s/disk|disc/Disc/ig;

   # Turn '-_' or '_-' or '_-_' or : into '-' (one more time)
   $name =~ s/(_-_)|(-_)|(_-)|\:/-/g;

   # Get rid of multiple __ or -- in a row (one more time)
   $name =~ s/--+/-/g;
   $name =~ s/__+/_/g;

   return (&CheckCaps($name));
}

sub ToID3 ($) {
   my $str = $_[0];
   $str =~ s/_/ /g;
   $str =~ s/^(.{,30}).*$/$1/;
   return ($str);
}

sub GenerateID3 ($) {
   my $num = $_[0];
   my $tags = "";
   my $temp = ToID3($Tracks{$num});
   $tags .= "--tt \"$temp\" ";
   my $temp = ToID3($Artist);
   $tags .= "--ta \"$temp\" ";
   my $temp = ToID3($CD);
   $tags .= "--tl \"$temp\" ";
   $tags .= "--tn \"$num\" ";
   return ($tags);
}

sub Action ($$) {
   my ($str, $logit) = @_;
   print "\033]2;$str\007";
   print "\n ** $str **\n\n";
   if ($Log and $logit) {
      open(LOG, ">>$Log");
      print LOG "$str\n";
      close(LOG);
   }
}

sub FormatTime ($) {
   my $time = $_[0];
   my ($min, $hours) = (0, 0);
   if ($min = int($time/60)) {
      $time = ($time - (60 * $min));
   }
   if ($hours = int($min/60)) {
      $min = ($min - (60 * $hours));
   }
   $time =~ s/^(\d)$/0$1/;
   $min =~ s/^(\d)$/0$1/;
   return ("$hours:$min:$time");
}

my $StartTime = time;
print "\nDetermining CD Data...\n\n";
my $TempIndex = "";

if (-d $ARGV[0]) {
   # We are finishing a directory
   open (INDEX, ">/dev/null");
   open (CDDB, "$ARGV[0]/.cddbinfo");
   shift @ARGV;
}
else {
   # Lookup CD in CDDB
   $TempIndex = "/tmp/.cddbinfo.$$";
   if ($CDDBfile) {
      # Specifies a file created by cddbslave and gnome-cd
      open (CDDB, "$CDDBfile");
   } else {
      open (CDDB, "echo 1 | $CDDB |");
   }
   open (INDEX, ">$TempIndex");
}

my $wrote_num_tracks = 0;
while (defined($line = <CDDB>)) {
   # Convert data from cddbslave/gnome-cd file format if necessary
   $line =~ s/DISCID=/cddbid: /;
   $line =~ s/DGENRE=/category: /;
   if ($line =~ /TTITLE(\d+)=/) {
      my $tnum = $1 + 1;
      $line =~ s/TTITLE(\d+)=/track $tnum: /;
      if ($tnum > $NumTracks) {
         $NumTracks = $tnum;
      }
   }
   if ($line =~ /DTITLE=(.+) \/ (.+)/) {
      print INDEX "artist: $1\n";
      $Artist = FixName($1);
      $Artist =~ s/-/_/g;
      $line = "title: $2\n";
   }

   print INDEX $line;
   chomp ($line);
   if ($line =~ s/^.*artist: //) {
      $Artist = FixName($line);
      $Artist =~ s/-/_/g;
   }
   if ($line =~ s/^title: //) {
      $CD = FixName($line);
      $CD =~ s/-/_/g;
   }
   if ($line =~ s/^category: //) {
      $Category = lc(FixName($line));
   }
   if ($line =~ s/^cddbid: //) {
      $cddbid = $line;
   }
   if ($line =~ s/^trackno: //) {
      $NumTracks = $line;
      $wrote_num_tracks = 1;
   }
   if (($num, $name) = ($line =~ /^track (\d+): (.+)$/)) {
      $name = FixName($name);
      $num =~ s/^(\d)$/0$1/;
      $Tracks{$num} = $name;
   }
}
close (CDDB);
unless ($wrote_num_tracks) {
   print INDEX "trackno: $NumTracks\n";
}
close (INDEX);

if ($Artist) {
   # CDDB Info was found...

   print "Category: $Category\n";
   print "Artist: $Artist\n";
   print "CD: $CD\n";
   print "Total Tracks: $NumTracks\n\n";

   # Make up a list of tracks to read
   if ($#ARGV > -1) {
      # Tracks were specified on the command line
      foreach $this (@ARGV) {
         $this =~ s/^(\d)$/0$1/;
         push @ToRead, $this;
      }
      @ToRead = @ARGV;
   } 
   else {
      # Read all tracks
      @ToRead = keys %Tracks;
   }

   # Create data directory...
   system ("mkdir -p $DataDir/$Category/$Artist/$CD");

   # Create destination directory... and save index file
   system ("mkdir -p $DestDir/$Category/$Artist/$CD");
   if ($TempIndex) {
      system ("mv $TempIndex $DestDir/$Category/$Artist/$CD/.cddbinfo");
   }

   $TracksRead = 0;

   my $ReadStartTime = time;

   # Read tracks...
   foreach $ThisTrack (sort @ToRead) {
      my $outbase = "$DataDir/$Category/$Artist/$CD/$ThisTrack-$Artist-$Tracks{$ThisTrack}";
      unless ((-s "$outbase.wav") or (-s "$outbase.mp3")) {
         Action("[$ThisTrack/$NumTracks] Reading $Tracks{$ThisTrack} ($Artist/$CD)", 0);
         system ("$CDParanoia $ThisTrack $outbase.wav.tmp");
         if ( $? != 0) {
            unlink ("$outbase.wav.tmp");
            Action("!! There was an error reading tracks from $Artist/$CD !!", 1);
            die "Read of track with cdparanoia failed...\n";
         }
         system ("mv $outbase.wav.tmp $outbase.wav");
         $TracksRead++;
      }
      $RawSize{$ThisTrack} = int((-s "$outbase.wav") / 1000);
   }

   print "\n$TracksRead tracks read.\n";
   Action("Finished Reading $CD", 1);
   if ($Eject and $TracksRead) {
      system ("$Eject");
   }

   my $CompressStartTime = time;

   foreach $ThisTrack (sort @ToRead) {
      my $inbase = "$DataDir/$Category/$Artist/$CD/$ThisTrack-$Artist-$Tracks{$ThisTrack}";
      my $outbase = "$DestDir/$Category/$Artist/$CD/$ThisTrack-$Artist-$Tracks{$ThisTrack}";
      Action("[$ThisTrack/$NumTracks] Compressing $Tracks{$ThisTrack} ($Artist/$CD)", 0);
      if (-s "$inbase.wav") {
         my $tags = GenerateID3($ThisTrack);
         system ("$MP3Encoder $tags $inbase.wav $outbase.mp3");
         if ( $? != 0) {
            unlink ("$outbase.mp3");
            Action("!! There was an error compressing tracks from $Artist/$CD !!", 1);
            die "MP3 compression failed...\n";
         }
      }
      $MP3Size{$ThisTrack} = int((-s "$outbase.mp3") / 1000);
      unlink ("$inbase.wav");
   }

   my $EndTime = time;

   if ($DataDir ne $DestDir) {
      # Delete data directories if not equal to the destination directory
      unless (rmdir ("$DataDir/$Category/$Artist/$CD")) {
         print "WARNING: Data directory not empty\n";
      }
      rmdir ("$DataDir/$Category/$Artist");
      rmdir ("$DataDir/$Category");
   }
   system ("chmod -R a+rX $DestDir");

   print "\nDone. Summary:\n\n";
   print "Artist Name: $Artist\nCD Name: $CD\nNumber of Tracks: $NumTracks\nTracks Read: $TracksRead\n";
   $TotalSize = 0;
   foreach $ThisTrack (sort @ToRead) {
      print "  [$ThisTrack] $Tracks{$ThisTrack} $RawSize{$ThisTrack}kb -> $MP3Size{$ThisTrack}kb\n";
      $TotalMP3Size += $MP3Size{$ThisTrack};
      $TotalRawSize += $RawSize{$ThisTrack};
   }
   my $percent = int(100 - (($TotalMP3Size / $TotalRawSize) * 100));
   print "\nTotal Size: $TotalRawSize kb (Before), $TotalMP3Size kb (After) = $percent\% compression\n\n";
   my $CDDB_Time = FormatTime($ReadStartTime - $StartTime);
   my $Rip_Time = FormatTime($CompressStartTime - $ReadStartTime);
   my $MP3_Time = FormatTime($EndTime - $CompressStartTime);
   my $TotalTime = FormatTime($EndTime - $StartTime);
   print "CDDB Lookup Time: $CDDB_Time\n";
   print "CD Rip Time: $Rip_Time\n";
   print "MP3 Compression Time: $MP3_Time\n";
   print "   Total Time Elapsed: $TotalTime\n\n";
   Action("Finished Ripping CD: $Artist/$CD", 1);
   if ($MoveDir) {
      system ("mkdir -p $MoveDir/$Category/$Artist");
      system ("mv $DataDir/$Category/$Artist/$CD $MoveDir/$Category/$Artist");
      system ("cd $DataDir; rmdir -p $Category/$Artist 2>/dev/null");
   }
}
else {
   # No CDDB data found
   Action("!! No CDDB Data Found !!", 1);
}

# Copyright (c) 2002 Kirk Bauer
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

