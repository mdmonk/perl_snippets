#
# convert_using_QTFairUse.pl
# Version: 1.0
# Date: 01-Sep-2006
#
# This program will help automate the process of exercising your Fair Use rights
# for songs you have purchased from the iTMS.
#
# Directions:
#   0.  Download this script 
#	1.  Download QTFairUse and unzip
#	2.  Download FAAD and unzip faad.exe into the QTFairUse directory
#	3.  Download mp4creator and place mp4creator60.exe in the
#		QTFairUse directory
#	4.  Copy this script into the QTFairUse directory
#   5.  Run this script (convert_using_QTFairUse.pl)
#   6.  Start playing your music in iTunes.  I recommended using a
#		playlist that contains only the songs you want to convert.
#   7.  Let the playlist finish.  The script will automatically convert
#		the files to a playable format, and tag them using the original
#		tags and artwork.
#
# Release changes:
# 	1.  Original release.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# 
# Please see the LICENSE.txt file for the full license.

use strict;
use Win32::OLE qw(EVENTS);
use IO::Select;
use Data::Dumper;
use Cwd;
use File::Spec;
use Time::Hires qw (sleep);

use sigtrap 'handler', \&quit, 'normal-signals';

remove_old_dumps();
sleep (0.2);

my @infohashes;
my @dumpnames;
my %songinfo;
my %seen;
my %gotsonginfo ;
my $current_dump;
my $songcounter = 0;
my $statecounter = -1;
my $threshold = 5;
my $converting = 0;

my $cwd = getcwd;

	
sub iTunesEvent
{
    my ($itunes, $Event, @Args) = @_;
    #my $current = $itunes->CurrentTrack;
	return if ($converting);
	
    #print "$Event\n";
    if ($Event eq "OnPlayerPlayEvent") {
	    print "Playing Song: ";
	    my $current = $itunes->CurrentTrack;
		$songinfo{Location} = $current->Location();
	    $songinfo{Name} = $current->Name;
	    $songinfo{Artist} = $current->Artist;
		$songinfo{Album} = $current->Album;
		$songinfo{Lyrics} = $current->Lyrics;
		#I guess this is an actual MP3 tag, not the detected bitrate
		# For some reason python dies when I try to get it
		#Bitrate = $current->Bitrate
		$songinfo{BPM} = $current->BPM;
		$songinfo{Comment} = $current->Comment;
		$songinfo{Compilation} = $current->Compilation;
		$songinfo{Composer} = $current->Composer;
		$songinfo{DiscCount} = $current->DiscCount;
		$songinfo{DiscNumber} = $current->DiscNumber;
		$songinfo{EQ} = $current->EQ;
		$songinfo{Finish} = $current->Finish;
		$songinfo{Genre} = $current->Genre;
		$songinfo{Grouping} = $current->Grouping;
		$songinfo{Rating} = $current->Rating;
		$songinfo{Start} = $current->Start;
		$songinfo{TrackCount} = $current->TrackCount;
		$songinfo{TrackNumber} = $current->TrackNumber;
		$songinfo{VolumeAdjustment} = $current->VolumeAdjustment;
		$songinfo{Year} = $current->Year;
		# Artwork has to be saved to a file
		$songinfo{ArtworkCount} = $current->Artwork->Count();
		for (my $n = 1 ; $n <= $songinfo{ArtworkCount} ; $n++) {
			#my $format = $current->Artwork->Item(1);
			my $artfile = File::Spec->catfile($cwd, "artwork_song${songcounter}_$n");
			# save artwork to file
			$current->Artwork->Item($n)->SaveArtworktoFile($artfile);
		}
			
	    print "$songinfo{Name} by $songinfo{Artist}\n";
#		print "Dumpfile: $dumpnames[$songcounter]\n";
	    $infohashes[$songcounter] = {%songinfo};
	    #print Dumper %songinfo;
	    #print Dumper $infohashes[$songcounter];
	    $songcounter++;
	    #\&find_new_dump();
    }
    
#     if ($Event eq "OnPlayerStopEvent") {
#    	    #convert_dump($songcounter - 1);
#     }
}

my $itunes = Win32::OLE->new("iTunes.Application") or die("iTunes ??????????????????\n");
my $Library = $itunes->LibraryPlaylist;

Win32::OLE->WithEvents($itunes, \&iTunesEvent);

print "Starting QTFairUse6.py\n";
system("start", "QTFairUse6.py");

print "OK, now start playing in iTunes\n";

while ( 1 ) {
	find_new_dump() unless ($converting);
	check_player_state();
	if ($statecounter > $threshold) {
		# Must be done playing, time to convert everything
		print "iTunes stopped, time to convert everything!\n";
		convert_all();
		quit();
	}
#    my $current = $itunes->CurrentTrack;
    #print "foo\n";
     sleep(1);

}

sub check_player_state {
	my $state = $itunes->PlayerState;
	if ($state == 0) {
		$statecounter++ unless ($statecounter == -1);
	} elsif ($state == 1) {
		$statecounter = 0;
	}
}

sub find_new_dump() {
	opendir (DIR, ".");
	my @dumps = grep { /^dump_\d\d.aac$/ && -f "./$_" } readdir(DIR);
	foreach my $file (@dumps) {
		if (not defined $seen{$file}) {
			$seen{$file} = 1;
			$dumpnames[$songcounter] = $file;
			print "Found dumpfile: $dumpnames[$songcounter]\n";
		}
	}
}

sub remove_old_dumps () {
	opendir (DIR, ".");
	my @dumps = grep { /^dump_\d\d.aac$/ && -f "./$_" } readdir(DIR);
	map { unlink } @dumps;
}

sub convert_all {
	
	# I want to Kill QTFairUse6, because it will create more dump files if 
	# iTunes is set to use Sound Check
	# Commented out because killing it this way seems to crash iTunes
	#system("taskkill", "/FI", "imagename eq python.exe");
	
	print "I am about to convert all the dumped tracks\n";
	print "NOW WOULD BE A GOOD TIME TO EXIT QTFAIRUSE\n";
	print "(but it isn't necessary)\n";
	sleep (5);
	for (my $n = 0 ; $n < $songcounter ; $n++) {
		convert_dump($n);
	}
	
	print "Conversions complete!\n";
	print "NOTE:  you have to exit QTFairUse manually by hitting\n";
	print "Ctrl-C in its window\n";
	print "Hit enter to exit THIS script.\n";
	chomp (my $foo = <STDIN>);
}

sub convert_dump {
	my $counter = $_[0];
	#print "counter is $counter\n";
	if ($counter >= 0) {
		my $file = $dumpnames[$counter];
		print "converting file $file\n";
		my $output = "faad_".$file;
		print "running FAAD -a $output $file...\n";
		if ( -f $output ) {
			print "WARNING - FAAD output file ($output) exists, removing\n";
			unlink $output;
		}
		system("faad.exe", "-a", "$output", "$file");
		my $itunes_out = "itunes_".$file;
		$itunes_out =~ s/\.aac$/.m4a/;
		if ( -f $itunes_out ) {
			print "WARNING - M4a output file ($itunes_out) exists, removing\n";
			unlink $itunes_out;
		}
		print "running mp4creator60 -create=$output $itunes_out\n";
		system("mp4creator60.exe", "-create=$output", "$itunes_out");
		add2library($itunes_out, $counter);
	}
	
}

sub add2library () {
	my $file = $_[0];
	my $counter = $_[1];
	
	print "Adding $file to Library...\n";
	# I *could* move it to the same directory as the original file...
	# by using the $songinfo{Location}, but I'm not going to
	# Maybe in a later version :-D
	my $fullpath = File::Spec->catfile($cwd , $file);
	#print "fullpath is $fullpath\n";
	
	# Add to Library
	my $operation = $Library->AddFile($fullpath);

	while ($operation->InProgress) {
		sleep (100);
	}
	my $addedTracks = $operation->Tracks;
	# Should only be one!
	my $addedTrack = $addedTracks->Item(1);

	# Now set the Track Info per earlier stored info
	my %info = %{$infohashes[$counter]};
#	print Dumper %info;
	
	print "Tagging $file...\n";
	$addedTrack->{Name} = $info{Name};
	$addedTrack->{Artist} = $info{Artist};
	$addedTrack->{Album} = $info{Album};
	$addedTrack->{Lyrics} = $info{Lyrics};
	$addedTrack->{BPM} = $info{BPM};
	$addedTrack->{Comment} = $info{Comment};
	$addedTrack->{Compilation} = $info{Compilation};
	$addedTrack->{Composer} = $info{Composer};
	$addedTrack->{DiscCount} = $info{DiscCount};
	$addedTrack->{DiscNumber} = $info{DiscNumber};
	$addedTrack->{EQ} = $info{EQ};
	$addedTrack->{Finish} = $info{Finish};
	$addedTrack->{Genre} = $info{Genre};
	$addedTrack->{Grouping} = $info{Grouping};
	$addedTrack->{Rating} = $info{Rating};
	$addedTrack->{Start} = $info{Start};
	$addedTrack->{TrackCount} = $info{TrackCount};
	$addedTrack->{TrackNumber} = $info{TrackNumber};
	$addedTrack->{VolumeAdjustment} = $info{VolumeAdjustment};
	$addedTrack->{Year} = $info{Year};
	
	if ($info{ArtworkCount}) {
		for (my $n = 1 ; $n <= $info{ArtworkCount} ; $n++) {
			#my $format = $current->Artwork->Item(1);
			my $artfile = File::Spec->catfile($cwd, "artwork_song${counter}_$n");
			# save artwork to file
			$addedTrack->AddArtworkFromFile($artfile);
		}
	}
}


# Destroy the object.  Otherwise zombie object will come back
# to haunt you
quit();

sub quit 
{
        # This destroys the object
        #close (QT);
        undef $itunes;
        Win32::OLE->FreeUnusedLibraries();
        exit;
}
