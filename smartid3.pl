#!/usr/bin/perl -w
# smartid3 (Smart Might not Always Read True ID3)
# by Leif Josson (lejon@ju-jutsu.com)
#
# Please send feedback, feature requests, ideas and...
# bug reports to lejon@ju-jutsu.com
#
# License: Artistic.
#
# http://www.ju-jutsu.com/smartid3/
# http://www.ju-jutsu.com/smartid3/smartid3.pl

# Inspired by: (with some code residues left =)
#
# mp3frip (MP3 File Renamer in Perl) 
# by Ryan Lathouwers (ryanlath@pacbell.net)
# License: Artistic, baby.
# http://www.pancake.org/mp3frip.html
#

# BEWARE 
# If the ID3 tag is set to strange things, running this program
# may have strange effects, since it has quite a lot of influence
# over the final vote for the new filename

# ALSO BEWARE
# I'm sorry if I offend anyone with this code, obviously I'm not
# a Perl hacker, but I'm working on it. Mr. Lathouwers shall not be
# held responsible for any of the ugly code herein, since there
# is not much left of his code. What's left is the parts which
# does some fiddeling with the casing of the filenames and adding
# leading zeros and so on. You will recognize it often by looong
# 's///' expressions. =) Also the code left from Mr. Lathouwers is
# the code for finding the id3 tag from the file. The writing of
# the id3 tag I have done myself.

# IDEAS: 
#          guess_format2: add more separators to split.
#          increase the weight of id3 
#          decrease the weight of id3 if it is 30 chars long
#          examine if id3 is a shorter vesion than some of the other methods
#          make it possible to create directorys for the the artist and album
#          make it less case sensitive
#          add interactivity
#          add preferences file
#          remove empty directories when reverting
#          add the possibility to prompt if the score is below a limit
#          fix logging so it handles [] in the filename

# ChangeLog:
#    * 01/10/01 v0.0.3
#         Added sharp execution of my routines
#         Moved the actual work done to a subroutine do_processing
#         Fixed vote_track so it doesn't complain on non numeric argument
#    * 01/10/27 v0.0.4
#         Added the possibility to write the id3 tag to file
#    * 01/10/27 v0.0.5
#         Added the create subdirectory functionallity
#         Added separator functionallity and removed the %N option
#               which added a '-' after the track since you can now
#               use the separator option instead (-p).
#    * 01/10/27 v0.0.6
#         Splitted guess_format1 into several heuristics with lower score
#         Removed most_possible_artist from the above
#         Added using id3 tag in the preprossessing of guessing artist
#               and album
#         Added the possibility to take the filenames from the commanline (-i)
#    * 01/11/4 v0.0.7
#         Added the possibility to give album, artist, track and title as arguments
#         Added the possibility to give the verbosity level as argument
#         You can ignore the ID3 tag
#    * 01/11/09 v0.0.8
#         Added POD
#         Added prompt methods.
#    * 01/11/10 v0.0.8
#         Did the website
#    * 01/11/12 v0.0.8
#         Added the possibility to remove ID3 tags (-R)
#    * 01/11/16 v0.0.9
#         Added the log (-L) and revert (-B) facility
#    * 01/11/16 v0.1.0
#         Initial [fm] setup
#    * 01/11/17 v0.1.0
#         Initial [fm] release 
#    * 01/11/17 v0.1.0
#         Fixed bug wich made prompt delay the result if you had done ? first.
#         Added mkdir in the log
#    * 01/11/18 v0.1.1
#         Added user preferences file $HOME/.smartid3.rc
#         Removed a test printout which ended up in the logfile
#         Fixed misc bugs, often related to undefined values, which caused
#               perl to spurt out ugly error messages when perl -w is used
#         Revert now removes dirs when they are empty
#    * 01/11/20 v0.1.1
#         Second [fm] release 
#    * 01/11/20 v0.1.2
#         Added template feature (-M)
#         Changed the get_mp3s method since the order of the files is
#               significant, but I have introduced a bug which most likely
#		makes it not work on mac, since I don't know how 'ls' is
#               done on mac. =P
#    * 01/11/29 v0.1.2
#         Fixed recusion bug (Thanks Mark!)
#         Fixed it again (Thanks, again, Mark!)
#         Removed -M for now...


# logfile semantics:
#   syntax:
#     id:command:<args>
#   semantics:
#     id <number>: unique id for a log entry, might span several lines
#     command <string>: one of:
#                                rename [file1]<string> [file2]<string>
#                                info [info]<string>
#                                map <<command name> ":" <number of args>>
#                                mark [date + time]<string>
#                                mkdir [directory] <string>
#     args: the arguments to the command

use strict;
use vars qw($opt_U $opt_m $opt_M $opt_g $opt_i $opt_r $opt_R $opt__ $opt_u $opt_l $opt_h $opt_t $opt_s $opt_S $opt_f $opt_D $opt_w $opt_c $opt_p $opt_A $opt_T $opt_I $opt_F $opt_O $opt_o $opt_N $opt_v $opt_V $opt_w $opt_W $opt_L $opt_B $opt_z $opt_Z);
use Getopt::Std;
use File::Basename;

my $version = "0.1.2";

my %hash_tracks = ();
my %hash_albums = ();
my %hash_artists = ();
my %hash_titles = ();
my @prompt_conds;
my %prompts = ();
my $prompt_lvl = 6;

my %possible_a;

my @mp3s;
my @user_artists;
my @user_titles;
my @user_tracks;
my @user_albums;

#
# joern
my @undo_files;
my @undo_dirs;
my $msdos_chars="[\\\:,\\\\,\\\/,\\\*,\\\",\\\<,\\\>,\\\|]";
#

my $verbosity = 0;
my $verbosity_filter = 3;
my $debuglevel = 5;
my $mindebuglevel = 5;
my $maxdebuglevel = 10;

my $have_logfile = 0;
my $logid = 0;
my %log_map = ();

my $id3_vote = 1;
my $dir = '.';
my $new_file = "%f";
my %Hack;

my $sharp = "UnSharp";                     # Starting value

# Append the users preferences file to ARGV
if( -e (%ENV->{HOME} . "/.smartid3.rc") )
{
    open (RCFILE, "< " .  %ENV->{HOME} . "/.smartid3.rc");

    my $rcfile = %ENV->{HOME} . "/.smartid3.rc";

    print "\nUsing preferences file ($rcfile)\n";    

    my @rccontent;
    
    @rccontent = <RCFILE>;

    @rccontent = grep !/^#/, @rccontent;
    @rccontent = map split, @rccontent;

    push (@ARGV, @rccontent);
}
else
{
    print "\nNo user preferences file (\$HOME/.smartid3.rc)\n";
}

getopts('irIWFs_ultSRDdohwcmUf:p:g:A:T:O:N:v:V:L:B:z:Z:M:');

if(defined($opt_v))
{
    $debuglevel = $opt_v;
    $verbosity_filter = 1;
}

if(defined($opt_V))
{
    $debuglevel = $opt_V;
    $verbosity_filter = 0;
}

if ((defined($opt_u) + defined($opt_l) + defined($opt_t) > 1) || 
     (defined($opt__) && defined($opt_s)) ) 
{ 
    usage();
}

if (defined($opt_h) && $opt_h) 
{ 
    usage();
}


if(not defined $opt_i)
{
    if (@ARGV == 1) 
    { 
	$dir = $ARGV[0]; 
    }
}

if(defined($opt_p) && not defined($opt_f))
{
    print(STDERR "Warning, You have given a separator but You have not specified ");
    print(STDERR "a format (-f <format string>) to use. \nThe -p option will have ");
    print(STDERR "no effect!\n");
}

$opt_D = 0 unless ($opt_D);
$opt_S = 0 unless ($opt_S);

# Joern

$opt_m = 0 unless ($opt_m);
if ($opt_m)
{
  print "MS-DOS Filerestriction selected\n";
}

$opt_U = 0 unless ($opt_U);
if ($opt_U)
{
  print "Undo-Script is written \n";
}

#

if ($opt_f) 
{
    if ( $opt_f !~ /%[astnf]/) 
    { 
	usage(); 
    }
} 
else 
{
	$opt_f = "%f";
}

if ($opt_p) 
{
    debug( "Using separator $opt_p\n",5);
} 

if ($opt_g) 
{
    $opt_g = "/^" . $opt_g . "\$/";
    $opt_g =~ s/\(/\\(/;
    $opt_g =~ s/\)/\\)/;
} 

if($opt_i)
{
    @mp3s = @ARGV;
}
else
{
    @mp3s = get_mp3s($dir, $opt_r);
}
my @suffix = ('\.mp3','\.MP3');

#enable below to make it default NOT to work on the 
#$opt_D = 1;

print "\nWarning: Running this program might make you end\n";
print "up with strange filenames on your mp3's. A good idea\n";
print "would be to copy some of your files and play with the\n";
print "program to familiarize yourself a bit with it.\n\n";
print "THIS SOFTWARE IS IN BETA STATE AND HAS NOT BEEN\n";
print "THOROUGHLY TESTED YET.\n\n";

if( !prompt_yn("Are you sure you want to continue?") )
{
    print "That might have been a good choice. =)\n";
    exit;
}

if( $opt_L )
{
    init_log($opt_L);
}

if( $opt_B )
{
    init_log($opt_B);
}

#This option takes a file of filenames, and renames the files fed to
#this script to each flename in the templatefile. The order is highly
#significant
if( $opt_M )
{

    print "\n\n---------------------------------------------------------\n";
    print "\nSorry I have disabled this feature since I can not get it\n";
    print "to work satisfactory\n\n";
    print "If you really want this feature NOW please contact me at\n";
    print "lejon\@ju-jutsu.com\n\n";
    print "---------------------------------------------------------\n";

    exit;

    if(!($^O =~ /mac/i))
    {
	debug("Template file is: $opt_M\n",7);
	if( -e $opt_M )
	{
	    open(TEMPLATEFILE, "< $opt_M") or die "Couldn't open $opt_M for reading: $!\n";
	    
	    foreach my $orig_file (@mp3s) {
		
		my $template = <TEMPLATEFILE>;
		chomp $template;
		if( !$opt_D )
		{
		    rename ($orig_file, $template) or warn "COULDN'T RENAME: $!\n";
		    if($opt_L)
		    {
			mlog("rename",$orig_file, $template);
		    }
		}
		else
		{
		    debug("Would rename $orig_file to \n             $template.\n");
		}
	    }
	}
	else
	{
	    debug("Couldn't find: $opt_M\n");
	}
    }
    else
    {
	print "\nSorry this feature is not supported under MAC since\n";
	print "I don't know how to do dir on a MAC so that the filenames\n";
	print "gets sorted the way you see it when you list the files\n";
	print "in a directory.\n\n";
	print "If you know how to solve this please contact me at\n";
	print "lejon\@ju-jutsu.com\n\n";
    }

    exit;
}


if( $opt_B )
{
    if($opt_z && $opt_Z)
    {
	#between opt_z and opt_Z
	reverter($opt_B,$opt_z,$opt_Z);
    }
    elsif($opt_Z)
    {
	#Zero to opt_Z
	reverter($opt_B,0,$opt_Z);
    }
    elsif($opt_z)
    {
	#all above opt_z
	reverter($opt_B,$opt_z,-1);
    }
    else
    {
	reverter($opt_B);
    }

    exit;
}

guess_a(@mp3s);

if( lprompt_yn(2, "Print possible artists and albums?", 0) > 0 )
{
    print_possible_a();
}

doit();

sub doit {

if(!$opt_D)
{
    my $final_path;

    foreach my $orig_file (@mp3s) {
	
	my $id3 = get_id3_info($orig_file);
	
	my ($file, $path, $suffix) = fileparse($orig_file, @suffix);

	if($opt_R)
	{
	    remove_tag_id3v1($orig_file);
	}

	do_processing($orig_file);

	if ( ((!$id3->got_tag()) && $opt_w) || defined($opt_W)) {

	    if(!defined($opt_W))
	    {
		debug( "\nFile had no tag, writing id3 tag!\n\n",5);
	    }
	    else
	    {
		debug( "\nFile had tag, but forced rewriting of id3 tag!\n\n",5);
	    }
	    my $new_tag = ();
	    $new_tag->{artist} = find_highest(%hash_artists);
	    $new_tag->{album} = find_highest(%hash_albums);
	    $new_tag->{title} = find_highest(%hash_titles);
	    $new_tag->{track} = find_highest(%hash_tracks);
	    write_tag_id3v1($orig_file,$new_tag);
	}

	(my $new_file = $opt_f) =~ s/%f/$file/g;

	if ($new_file =~ /%[astnN]/) { 
	    if(1){

		if(%hash_artists)
		{
		    if($opt_p)
		    {
			$new_file =~ s/%a/find_highest(%hash_artists) . $opt_p/ge;
		    }
		    else
		    {
			$new_file =~ s/%a/find_highest(%hash_artists)/ge;
		    }
		}
		else
		{
		    if( $new_file =~ /%a/ )
		    {
			$new_file =~ s/%a/ /ge;
		    }
		}
		if(%hash_albums)
		{
		    if($opt_p)
		    {
			$new_file =~ s/%t/find_highest(%hash_albums) . $opt_p/ge;
		    }
		    else
		    {
			$new_file =~ s/%t/find_highest(%hash_albums)/ge;
		    }
		}
		else
		{
		    if( $new_file =~ /%t/ )
		    {
			$new_file =~ s/%t/ /ge;
		    }
		}
		if(%hash_titles)
		{
		    if($opt_p)
		    {
			$new_file =~ s/%s/find_highest(%hash_titles) . $opt_p/ge;
		    }
		    else
		    {
			$new_file =~ s/%s/find_highest(%hash_titles)/ge;
		    }
		}
		else
		{
		    if( $new_file =~ /%s/ )
		    {
			$new_file =~ s/%s/ /ge;
		    }
		}

		my $track  = find_highest(%hash_tracks);
		
		if (defined $track && $new_file =~ /%[nN]/ && $track ne "") {
		    
		    #have this be an option?
		    $track = leading_zero($track);
		    
		    if($opt_p)
		    {
			$track = $track . $opt_p;
		    }

		    $new_file =~ s/%[nN]/$track/g;
		}
		#Remove %nN if we couldn't deduce any trackname
		elsif ($new_file =~ /%[nN]/)
		{
		    $new_file =~ s/%[n]//g;
		}
		
		if (!$opt_S && defined $track) {
		    if (substr($new_file,length($track),4) =~ /-/) {
			if (substr($new_file,length($track),1) =~ /\d/) {
			    $new_file =~ s/^$track//;		
			}
		    }
		}
		
	    } else {
		warn "No ID3 info found for: $orig_file.\n";
		$new_file = $file;
	    }
	}

	if(!$opt_c)
	{
#	    $new_file = "$path$new_file";
	    $final_path = "$path";
	}
	else
	{
	    my $subdir = "";
	    if(%hash_artists && defined find_highest(%hash_artists))
	    {
		$subdir = find_highest(%hash_artists);
		
		if($opt_t)
		{
#		    $path =~ s/(\w+)/\u\L$1/g; 
		    $subdir =~ s/(\w+)/\u\L$1/g; 
		}
print "path: $path\nsubdir: $subdir\n";
		if (-e $path . $subdir) 
		{
		    debug("$path$subdir exists.\n",9);
		}
		else
		{
		    mkdir($path . $subdir,0777) || die "cannot mkdir " . $path . $subdir . ": $!";
		    if($opt_L)
		    {
			mlog("mkdir",$path . $subdir);
		    }

# joern 

		    if($opt_U)
		    {
		       push @undo_dirs, "rmdir \"$path$subdir\"\n";
		    }

#

		}

		my $sep = ((($^O =~ /MSWin32/i) || ($^O =~ /dos/i)) ? 
		      "\\" : (($^O =~ /mac/i) ? "/" : "/"));


		$subdir = $subdir . $sep;
		if(%hash_albums && defined find_highest(%hash_albums))
		{
		    my $new_sub = find_highest(%hash_albums);

# joern
		    if ($opt_m)
			{
			 $new_sub=~ s/$msdos_chars+/-/g;
			 $new_sub=~ s/^$msdos_chars+//g;
			 $new_sub=~ s/\.$+//g;
			}
			 
# to avoid error due to Albumnames containing "/"
# in addition: "." at the end of directories is also not allowed

		    if($opt_t)
		    {
			$new_sub =~ s/(\w+)/\u\L$1/g; 
		    }
		    $subdir .= $new_sub;

		    if (-e $path . $subdir) 
		    {
			debug( "$path$subdir exists.\n",5);
		    }
		    else
		    {
			debug( "$path$subdir does not exist, creating it!\n",9);
			mkdir($path . $subdir,0777) || die "cannot mkdir " . $path . $subdir . ": $!";
			if($opt_L)
			{
			    mlog("mkdir",$path . $subdir);
			}  

# joern 

 		    if($opt_U)
		    {
		       push @undo_dirs, "rmdir \"$path$subdir\"\n";
		    }

#

		    }
		    $subdir = $subdir . $sep;
		}
	    }
	    else
	    {
		debug( "Warning, option for subdirs (-c) was on but could'nt find ",5);
		debug( "artist name to create subdir from.\n",5);
	    }

	    $final_path = "$path$subdir";
	}

	#get rid of underscores
	if ($opt_s) { 
		$new_file =~ s/_/ /g;
		if (!$opt_S) {
			$new_file =~ s/^([0-9]{1,2})((?:[ ]-|-[ ])|(?:-))(?=[^ -])/$1 - /;
			$new_file =~ s/[ ]{2,}/ /g;
		}
	}
	#Case options
	if ($opt_l) { $new_file = lc($new_file); }
	if ($opt_u) { $new_file = uc($new_file); }
	if ($opt_t) { 
		if ($opt__) { $new_file =~ s/_/ /g; } 
		
		$new_file =~ s/(\w+)/\u\L$1/g; 
		#change Ii and Iii to II and III
		#'S 'T to 's 't
		if (!$opt_S) { 
			$new_file =~ s/(i{2,3})/uc($1)/ie; 
			#Fix the quote below
			#$new_file =~ s/([ST])/"'".lc($1)/eg;
			#$new_file =~ s/([^-] On )/lc($1)/ge;
			#$new_file =~ s/([^-] Of )/lc($1)/ge;
			#$new_file =~ s/([^-] The )/lc($1)/ge;
			#$new_file =~ s/([^-] A )/lc($1)/ge;
		}
	}

	#Get rid of spaces - yuck.
	if ($opt__) { 
		$new_file =~ s/ /_/g; 
		if (!$opt_S) {
			$new_file =~ s/^([0-9]{1,2})((?:[_]-|-[_])|(?:-))(?=[^_-])/$1_-_/;
			$new_file =~ s/[_]{2,}/_/g;
		}
	} 

	#make sure 1 = 01 etc.
	if (!$opt_S) {
		if (substr($new_file,0,1) =~ /\d/ && substr($new_file,1,1) !~ /\d/) {
			$new_file = "0$new_file";
		}
	}

	$new_file = $new_file . ".mp3";

	#We don't want the separator at the very end of the filename
	if($opt_p)
	{
	    $new_file =~ s/$opt_p\.mp3/\.mp3/;
	}
	#rename friggin would'nt work here =(
	#scope issue?  too lazy to track down, therefor...
	#hash hack

# joern

	if ($opt_m)
	{
	 $new_file=~ s/$msdos_chars+/-/g;
	 $new_file=~ s/^$msdos_chars+//g;
	}
	
	if ($opt_U) 
	{
	  push @undo_files, " mv \"$final_path$new_file\" \"$orig_file\" \n";
	}

#
#

	$new_file = $final_path . $new_file;

	$Hack{$orig_file} = $new_file;
    }

# joern

	 if ($opt_U)
	 {
	   print "Writing Undo-File\n";
	   my $undo_filename=%ENV->{HOME}."/smartundo.sh";
	   open (FH,">$undo_filename");
	   print FH "@undo_files";
	   while (@undo_dirs)
	   {
	    $dir = pop (@undo_dirs);
	    print FH "$dir";
	   }
	  close(FH);
	  chmod (0744, $undo_filename);
	 }

#

}
else
{
    foreach my $orig_file (@mp3s) 
    {
	my $id3 = do_processing($orig_file);
	
	my ($file, $path, $suffix) = fileparse($orig_file, @suffix);

	$path = $path;

	debug( "\n\n**************** NEW ROUND *****************\n",7);
	debug( "File: $orig_file\n\n",7);

  	if ($id3->got_tag()) 
  	{
  	    debug(("ID3 Artist: " . $id3->get_artist() . "\n"),7) unless not defined $id3->get_artist();
  	    debug(("ID3 Album: " . $id3->get_album() . "\n"),7) unless not defined $id3->get_album(); 
  	    debug(("ID3 Title: " . $id3->get_title() . "\n"),7) unless not defined $id3->get_title();	    
  	    debug(("ID3 Track: " . $id3->get_track() . "\n\n"),7) unless not defined $id3->get_track();
  	}
	elsif ($opt_w) 
	{
	    debug( "\nFile had no tag, would have written id3 tag!\n\n",7);
	}

	(my $new_file = $opt_f) =~ s/%f/$file/g;

	if ($new_file =~ /%[astnN]/) { 
	    if(1){
		if(%hash_artists)
		{
		    
		    if($opt_p)
		    {
			debug( "New artist: " . find_highest(%hash_artists) . $opt_p . "\n",1) unless not defined find_highest(%hash_artists);
			$new_file =~ s/%a/find_highest(%hash_artists) . $opt_p/ge;
		    }
		    else
		    {
			$new_file =~ s/%a/find_highest(%hash_artists)/ge;
		    }
		}
		else
		{
		    $new_file =~ s/%a/ /ge;
		}
		if(%hash_albums)
		{
		    if($opt_p)
		    {
			debug( "New album: " . find_highest(%hash_albums) . $opt_p . "\n",1) unless not defined find_highest(%hash_albums);
			$new_file =~ s/%t/find_highest(%hash_albums) . $opt_p/ge;
		    }
		    else
		    {
			$new_file =~ s/%t/find_highest(%hash_albums)/ge;
		    }
		}
		else
		{
		    $new_file =~ s/%t/ /ge;
		}
		if(%hash_titles)
		{
		    if($opt_p)
		    {
			debug( "New title: " . find_highest(%hash_titles) . $opt_p . "\n",1) unless not defined find_highest(%hash_titles);
			$new_file =~ s/%s/find_highest(%hash_titles) . $opt_p/ge;
		    }
		    else
		    {
			$new_file =~ s/%s/find_highest(%hash_titles)/ge;
		    }
		}
		else
		{
		    $new_file =~ s/%s/ /ge;
		}

		my $track  = find_highest(%hash_tracks);
		
		if ($new_file =~ /%[nN]/ && $track ne "") {
		    
		    #have this be an option?
		    $track = leading_zero($track);
		    
		    if($opt_p)
		    {
			$track = $track . $opt_p;
		    }

		    $new_file =~ s/%[nN]/$track/g;
		}
				
		if (!$opt_S) {
		    if (substr($new_file,length($track),4) =~ /-/) {
			if (substr($new_file,length($track),1) =~ /\d/) {
			    $new_file =~ s/^$track//;		
			}
		    }
		}
		
	    } else {
		warn "No ID3 info found for: $orig_file.\n";
		$new_file = $file;
	    }
	}


	if(!$opt_c)
	{
	    $new_file = "$path$new_file";
	}
	else
	{
	    my $subdir = "";
	    if(%hash_artists && defined find_highest(%hash_artists))
	    {
		$subdir = find_highest(%hash_artists);

		if($opt_t)
		{
		    $path =~ s/(\w+)/\u\L$1/g; 
		    $subdir =~ s/(\w+)/\u\L$1/g; 
		}

		if (-e $path . $subdir) 
		{
		    debug( "$path$subdir exists.\n",5);
		}
		else
		{
		    debug( "$path$subdir does not exist, would have created it!\n",5);
		}
		$subdir = $subdir . "/";
		if(%hash_albums && defined find_highest(%hash_albums))
		{
		    if($opt_t)
		    {
			my $new_sub = find_highest(%hash_albums);
			$new_sub =~ s/(\w+)/\u\L$1/g; 
			$subdir .= $new_sub;
		    }
		    else
		    {
			$subdir .= find_highest(%hash_albums);
		    }

		    if (-e $path . $subdir) 
		    {
			debug( "$path$subdir exists.\n",5);
		    }
		    else
		    {
			debug( "$path$subdir does not exist, would have created it!\n",5);
		    }
		    $subdir = $subdir . "/";
		}
	    }
	    else
	    {
		debug( "Warning, option for subdirs (-c) was on but could'nt find",9);
		debug( "artist name to create subdir from.\n",9);
	    }

	    $new_file = "$path$subdir$new_file";
	}

	#get rid of underscores
	if ($opt_s) { 
		$new_file =~ s/_/ /g;
		if (!$opt_S) {
			$new_file =~ s/^([0-9]{1,2})((?:[ ]-|-[ ])|(?:-))(?=[^ -])/$1 - /;
			$new_file =~ s/[ ]{2,}/ /g;
		}
	}
	#Case options
	if ($opt_l) { $new_file = lc($new_file); }
	if ($opt_u) { $new_file = uc($new_file); }
	if ($opt_t) { 
		if ($opt__) { $new_file =~ s/_/ /g; } 
		
		$new_file =~ s/(\w+)/\u\L$1/g; 
		#change Ii and Iii to II and III
		#'S 'T to 's 't
		if (!$opt_S) { 
			$new_file =~ s/(i{2,3})/uc($1)/ie; 
			#Fix the quote below
			#$new_file =~ s/([ST])/"'".lc($1)/eg;
			#$new_file =~ s/([^-] On )/lc($1)/ge;
			#$new_file =~ s/([^-] Of )/lc($1)/ge;
			#$new_file =~ s/([^-] The )/lc($1)/ge;
			#$new_file =~ s/([^-] A )/lc($1)/ge;
		}
	}

	#Get rid of spaces - yuck.
	if ($opt__) { 
		$new_file =~ s/ /_/g; 
		if (!$opt_S) {
			$new_file =~ s/^([0-9]{1,2})((?:[_]-|-[_])|(?:-))(?=[^_-])/$1_-_/;
			$new_file =~ s/[_]{2,}/_/g;
		}
	} 

	#make sure 1 = 01 etc.
	if (!$opt_S) {
		if (substr($new_file,0,1) =~ /\d/ && substr($new_file,1,1) !~ /\d/) {
			$new_file = "0$new_file";
		}
	}

	$new_file = $new_file . ".mp3";

	# no separator at the end
	if($opt_p)
	{
	    $new_file =~ s/$opt_p\.mp3/\.mp3/;
	}

	print_votes();

	debug( "------------ The Winners are...  ------------\n",7);

	debug( "Track winner is: " . find_highest(%hash_tracks) . "\n",7) unless not defined find_highest(%hash_tracks);
	debug( "Title winner is: " . find_highest(%hash_titles) . "\n",7) unless not defined find_highest(%hash_titles);
	debug( "Artist winner is: " . find_highest(%hash_artists) . "\n",7) unless not defined find_highest(%hash_artists);
	debug( "Album winner is: " . find_highest(%hash_albums) . "\n",7) unless not defined find_highest(%hash_albums);
	debug( "Path is: " . $new_file . "\n",7) unless not defined $new_file;

	debug( "**************** ENDOF ROUND ****************\n\n",7);

	debug(("\n"),7);

    }
}
}

sub do_processing{
    my ($orig_file) = @_;
    my ($file, $path, $suffix) = fileparse($orig_file, @suffix);

    my $id3;

    reset_round();

    if ($opt_A) 
    {
	vote_artist($opt_A,200);
    } 

    if ($opt_T) 
    {
	vote_album($opt_T,200);
    } 

    if ($opt_O) 
    {
	vote_title($opt_O,200);
    } 

    if ($opt_N) 
    {
	vote_track($opt_N,200);
    } 

    if(not $opt_g)
    {		
	$id3 = get_id3_info($orig_file);
	
	$file = lc($file);
	
	if(not $opt_o)
	{
	    my $guess1 = guess_format1($file);
	    my $guess2 = guess_format2($file);
	    my $guess3 = guess_format3($file);
	    my $guess4 = guess_format4($file);
	    my $guess5 = guess_format5($file);
	    my $guess6 = guess_format6($file);
	    my $guess7 = guess_format7($file);
	    my $guess8 = guess_format8($file);
	    do_post_processing();
	}
	
	if( !$opt_D && lprompt_yn(5,"Do you want to check the results?",0) > 0 ) 
	{
	    print "\n--------------------------------------------\n";
	    print "Filename was: $file\n";

	    if(%hash_artists && defined find_highest(%hash_artists))
	    {
		my $artist = find_highest(%hash_artists);
		my @artists = keys(%hash_artists);
		@artists = grep { !($_ eq $artist) } @artists;
		push(@artists,@user_artists);
		my $res_artist = lprompt_def(5,"Artist?",0,$artist,@artists);
		if(!member($res_artist,@artists,$artist))
		{
		    debug("Adding $res_artist to the list of possible artists.\n",5);
		    push(@user_artists,$res_artist);
		}
		vote_artist($res_artist,300);
	    }

	    if(%hash_albums && defined find_highest(%hash_albums))
	    {
		my $album = find_highest(%hash_albums);
		my @albums = keys(%hash_albums);
		@albums = grep { !($_ eq $album) } @albums;
		push(@albums,@user_albums);
		my $res_album = lprompt_def(5,"Album?",0,$album,@albums);
		if(!member($res_album,@albums,$album))
		{
		    debug("Adding $res_album to the list of possible albums.\n",5);
		    push(@user_albums,$res_album);
		}
		vote_album($res_album,300);
	    }
	    if(%hash_titles && defined find_highest(%hash_titles))
	    {
		my $title = find_highest(%hash_titles);
		my @titles = keys(%hash_titles);
		@titles = grep { !($_ eq $title) } @titles;
		push(@titles,@user_titles);
		my $res_title = lprompt_def(5,"Title?",0,$title,@titles);
		if(!member($res_title,@titles,$title))
		{
		    debug("Adding $res_title to the list of possible titles.\n",5);
		    push(@user_titles,$res_title);
		}
		vote_title($res_title,300);
	    }
	    if(%hash_tracks && defined find_highest(%hash_tracks))
	    {
		my $track = find_highest(%hash_tracks);
		my @tracks = keys(%hash_tracks);
		@tracks = grep { !($_ eq $track) } @tracks;
		push(@tracks,@user_tracks);
		my $res_track = lprompt_def(5,"Track?",0,$track,@tracks);
		if(!member($res_track,@tracks,$track))
		{
		    debug("Adding $res_track to the list of possible tracks.\n",5);
		    push(@user_tracks,$res_track);
		}

		vote_track($res_track,300);
	    }
	}
    }
    else
    {
	# Ok, we have the format of the files
	$id3 = fixed_format($file);
    }
    
    return $id3;
}

sub reset_round {
    %hash_tracks = ();
    %hash_albums = ();
    %hash_artists = ();
    %hash_titles = ();
}

sub print_votes {
      debug("Current tracks:\n",7);
      foreach my $key (keys %hash_tracks) {
  	    debug( "Value: " . %hash_tracks->{$key},7);
   	    debug( " Track: " . $key,7);
 	    debug( "\n",7);
      }
      debug( "\n",7);

      debug( "Current titles:\n",7);
      foreach my $key (keys %hash_titles) {
  	    debug( "Value: " . %hash_titles->{$key},7);
   	    debug( " Title: " . $key,7);
 	    debug( "\n",7);
      }
      debug( "\n",7);

      debug( "Current artists:\n",7);
      foreach my $key (keys %hash_artists) {
  	    debug( "Value: " . %hash_artists->{$key},7);
   	    debug( " Artist: " . $key,7);
 	    debug( "\n",7);
      }
      debug( "\n",7);

      debug( "Current albums:\n",7);
      foreach my $key (keys %hash_albums) {
  	    debug( "Value: " . %hash_albums->{$key},7);
   	    debug( " Album: " . $key,7);
 	    debug( "\n",7);
      }
      debug( "\n",7);
}

sub do_post_processing {
    inspect_tracks();
    inspect_titles();
    inspect_artists();
    inspect_albums();
}

sub inspect_tracks {
    debug( "################### INSPECT TRACKS ##########################\n",2);
    foreach my $key (keys %hash_tracks) {
	if( $key > 99 )
	{
	    # debug( "Tracknum tooo high, decreasing score....\n",5);
	    %hash_tracks->{$key} -= 4;
	}
    }
}

sub inspect_titles {
    my $probable_track = find_highest(%hash_tracks);
    my $probable_artist = find_highest(%hash_artists);
    my $probable_album = find_highest(%hash_albums);
    
    $probable_artist =~ tr/_-"("")"/    / unless not defined $probable_artist;
    $probable_album =~ tr/_-"("")"/    / unless not defined $probable_album;
    
    debug( "################### INSPECT TITLES ##########################\n",2);

    if( defined $probable_track || defined $probable_artist || defined $probable_album)
    {
	my $padded_track = "0" . $probable_track unless not defined $probable_track;
	
	foreach my $key (keys %hash_titles) {

	    if(stoopid_entry($key))
	    { 
		%hash_titles->{$key} -= 7;
		debug( "Key $key contains stoopid entry decreasing score with 7\n",7);
	    }

	    if( my @times = ($key =~ /-/g) )
	    {
		my $times = @times;
		debug( "Key $key contains $times '-' decreasing score with $times",2);
		%hash_titles->{$key} -= $times;
	    }

	    if( my @times = ($key =~ /,/) )
	    {
		my $times = @times;
		debug( "Key $key contains $times ',' decreasing score with $times",2);
		%hash_titles->{$key} -= $times;
	    }

	    
	    if( defined $probable_track )
	    {
		debug( "Looking at $probable_track and $key\n",2);

		if( $key =~ / $probable_track /i )
		{
		    debug( "#################################################################\n",2);
		    debug( "Title contains probable Tracknum, decreasing score...\n",2);
		    %hash_titles->{$key} -= 4;
		}
		elsif ( $key =~ /^$probable_track /i )
		{
		    debug( "#################################################################\n",2);
		    debug( "Title contains probable Tracknum, decreasing score...\n",2);
		    %hash_titles->{$key} -= 4;
		}
		elsif ( $key =~ / $probable_track$/i )
		{
		    debug( "#################################################################\n",2);
		    debug( "Title contains probable Tracknum, decreasing score...\n",2);
		    %hash_titles->{$key} -= 4;
		}
		elsif ( $key =~ / $padded_track /i )
		{
		    debug( "#################################################################\n",2);
		    debug( "Title contains probable Tracknum, decreasing score...\n",2);
		    %hash_titles->{$key} -= 4;
		}
		elsif ( $key =~ /^$padded_track /i )
		{
		    debug( "#################################################################\n",2);
		    debug( "Title contains probable Tracknum, decreasing score...\n",2);
		    %hash_titles->{$key} -= 4;
		}
		elsif ( $key =~ / $padded_track$/i )
		{
		    debug( "#################################################################\n",2);
		    debug( "Title contains probable Tracknum, decreasing score...\n",2);
		    %hash_titles->{$key} -= 4;
		}
	    }

	    if( defined $probable_artist )
	    {
		debug( "Looking at $probable_artist and $key\n",2);
		if( $key =~ /$probable_artist/i )
		{
		    debug( "#################################################################\n",2);
		    debug( "Title contains probable artist, decreasing score...\n",2);
		    %hash_titles->{$key} -= 4;
		}
	    }

	    if( defined $probable_album )
	    {
		debug( "Looking at $probable_album and $key\n",2);
		if( $key =~ /$probable_album/i )
		{
		    debug( "#################################################################\n",2);
		    debug( "Title contains probable album, decreasing score...\n",2);
		    %hash_titles->{$key} -= 4;
		}
	    }

	}
    }

}

sub inspect_albums {
    my $probable_artist = find_highest(%hash_artists);

    debug( "################### INSPECT ALBUMS ##########################\n",2);
    if( defined $probable_artist ) 
    {
	$probable_artist =~ tr/_-"("")"/    /;

	foreach my $key (keys %hash_albums) {

	    if(stoopid_entry($key))
	    { 
		%hash_albums->{$key} -= 7;
	    }

	    debug( "Looking at $probable_artist and $key\n",2);
	    
	    if( $key =~ /$probable_artist/i )
	    {
		debug( "#################################################################\n",2);
		debug( "Album title contains probable artist, decreasing score...\n",2);
		%hash_albums->{$key} -= 4;
	    }
	}
    }

}

sub inspect_artists {
    my $probable_album = find_highest(%hash_albums);

# Ok, the artist score gets less punishment than album, because
# if they are the same, it is more probable that it is the artist
# that is correct

    debug( "################### INSPECT ARTISTS ##########################\n",2);
    if( defined $probable_album ) 
    {
	$probable_album =~ tr/_-"("")"/    /;

	foreach my $key (keys %hash_artists) {

	    if(stoopid_entry($key))
	    { 
		%hash_artists->{$key} -= 7;
	    }

	    debug( "Looking at $probable_album and $key\n",2);
	    
	    if( $key =~ /$probable_album/i )
	    {
		debug( "#################################################################\n",2);
		debug( "Artist title contains probable album, decreasing score...\n",2);
		%hash_artists->{$key} -= 3;
	    }
	}
    }
}

sub stoopid_entry {
    my $key = shift;
    return $key =~ /^http|^www|^track|^title|^artist/i;
}
    
sub find_highest {
    my %votes = @_; 
    my $top_val = 0;
    my $best_vote = ();

    foreach my $key (keys %votes) {
	if( %votes->{$key} > $top_val )
	{
	    $top_val = %votes->{$key};
	    $best_vote = $key;
	 } 
    }

    return $best_vote;
}

sub find_highest_score {
    my %votes = @_; 
    my $top_val = 0;
    my $best_vote = ();

    foreach my $key (keys %votes) {
	if( %votes->{$key} > $top_val )
	{
	    $top_val = %votes->{$key};
	} 
    }

    return $top_val;
}

sub vote_track {
    my ($track, $value) = @_;
    my $vote;

    if( (defined $track) && (not ($track eq "")) && (not ($track eq "0")))
    {
	# Remove all junk...
	($track) = ($track =~ /[^0-9]*([0-9]*).*/);

  	debug( "Voting...\n",3);
  	debug( "Track = $track\n",3);
  	debug( "Value = $value\n\n",3);

	$track = $track + 0;

	%hash_tracks->{$track} += $value unless $track == 0;
    }
	
}

sub vote_album {
    my ($album, $value) = @_;
    my $vote;
    
    if( (defined $album) && (not ($album eq "")))
    {
  	debug( "Voting...\n",3);
  	debug( "Album = $album : ",3);
  	debug( "Value = $value\n\n",3);
	%hash_albums->{$album} += $value;
    }
}

sub vote_artist {
    my ($artist, $value) = @_;
    my $vote;
    
    if( (defined $artist) && (not ($artist eq "")))
    {
  	debug( "Voting...\n",3);
  	debug( "Artist = $artist : ",3);
  	debug( "Value = $value\n\n",3);
	

	%hash_artists->{$artist} += $value;
    }
}

sub vote_title {
    my ($title, $value) = @_;
    my $vote;

    if( (defined $title) && (not ($title eq "")))
    {
  	debug( "Voting...\n",3);
  	debug( "Title = $title : ",3);
  	debug( "Value = $value\n\n",3);

	%hash_titles->{$title} += $value;

    }    
}

sub most_possible_artist {
    my ($possible_x, $possible_y) = @_;

    $possible_x = lc($possible_x);
    $possible_y = lc($possible_y);
    debug( "The contestants are: $possible_x ### $possible_y\n",2);

    if(exists $possible_a{$possible_x} && exists $possible_a{$possible_y})
    {
	my $aval = $possible_a{$possible_x};
	my $bval = $possible_a{$possible_y};
	my $result = $possible_a{$possible_x} - $possible_a{$possible_y};
	debug( "Both are in... and the score....: $possible_x, $possible_y\n",2);
	debug( "Possible X ($possible_x): $aval\n",2);
	debug( "Possible Y ($possible_y): $bval\n",2);
	debug( "Result is $result.\n",2);
	return $possible_a{$possible_x} - $possible_a{$possible_y};
    }
    elsif (exists $possible_a{$possible_x})
    {
	debug( "Only Possible X is in...\n",2);
	return 1;
    }
    elsif (exists $possible_a{$possible_y})
    {
	debug( "Only Possible Y is in...\n",2);
	return -1;
    }

    debug( "Noone where in...\n",2);
    return 0;

}

sub possible_artist {
    my ($possible) = @_;
    $possible = lc($possible);
    return exists $possible_a{$possible};
}

sub possible_album {
    my ($possible) = @_;
    $possible = lc($possible);
    return exists $possible_a{$possible};
}

sub print_possible_a {
    my @keys = keys %possible_a;
    foreach my $key (@keys) 
    {
	my $value = $possible_a{$key};
	print "Artist: $key \nProbability: $value\n\n";
    }
    #debug( %possible_a,5);
}

sub guess_a {
    my %tmphash;

    foreach my $fn (@_)
    { 
	my ($file, $path, $suffix) = fileparse($fn, @suffix);


	# Is it smart to use the ID3 info here, it feels a bit like
	# it gets alot of influnece.... lets try it for a while

	# Turn off voting
	$id3_vote = 0;
	my $id3 = get_id3_info($fn);
	# Turn it on agan
	$id3_vote = 1;
	if( $id3->got_tag())
	{
	    if( defined $id3->get_artist() )
	    {
		my $possible = trim($id3->get_artist());

		$possible = lc($possible);
		
		%tmphash->{$possible} += 3 unless $possible =~ /^(\d)+$/;
	    }

	    if( defined $id3->get_album() )
	    {
		my $possible = trim($id3->get_album());

		$possible = lc($possible);
		
		%tmphash->{$possible} += 2 unless $possible =~ /^(\d)+$/;
	    }
	}

        my @info = split(/-/,$file);
	foreach my $possible (@info)
	{
	    $possible = trim($possible);
	    
	    #Let's make them lowercase
	    $possible = lc($possible);
	    
	    %tmphash->{$possible} += 1 unless $possible =~ /^(\d)+$/;

	    ## let's skip numbers...
	    my $points = %tmphash->{$possible} unless $possible =~ /^(\d)+$/;
	}
    }

    my @keys = keys %tmphash;
    foreach my $key (@keys) 
    {
	my $value = $tmphash{$key};
	%possible_a->{$key} = $value unless $value == 1;
    }

}

sub guess_format1 {
    my $fn = shift;

# File: ./Gladiator - 01 - Progeny.mp3

    my ($artist, $track, $title) = ($fn =~ /([^0-9]*)([0-9]*)[ -]*(.*)/);
    my $dataobj;
    my $vote_value = 4;
    
    $artist = wash($artist);
    $title = wash($title);
    $track = wash($track);

    my $artist_bonus = 0;
    $dataobj->{tag} = ();

    #Guess it's more usual to have the song rather than the artist
    #if either is missing
    if (($title eq "" || not defined($title)) && (not possible_artist($artist)) ) 
    {    
	$title = $artist;
	$artist="";
    }

    if( possible_artist($title) )
    { 
	# Ok, so we fond the title among the possible artists
	# or album, let's guess it's the artist....
	# We thusly switch places on title and artist...
	my $tmp;
	
	$tmp = $title;
	$title = $artist;
	$artist = $tmp;

	$artist_bonus += 1;
    }

    $dataobj->{tag}{'track'}=$track;
    vote_track($track,$vote_value);

    # Let's raise the probability a bit for this artist vote
    $dataobj->{tag}{'artist'}=$artist;
    vote_artist($artist,$vote_value + $artist_bonus);

    $dataobj->{tag}{'title'}=$title;
    vote_title($title,$vote_value);

    debug("1 - Guessing track: " . $track . "\n",4);
    debug("1 - Guessing artist: " . $artist . "\n",4);
    debug("1 - Guessing title: " . $title . "\n\n",4);

    bless($dataobj, "main");
    return $dataobj;
} 

sub guess_format7 {
    my $fn = shift;

# File: ./01 - Gladiator - Progeny.mp3

    my ($track, $album, $title) = ($fn =~ /([0-9]*)[ -]*([^-]*)[ -]*(.*)/);
    my $dataobj;
    my $vote_value = 4;
    my $artist;

    $album = wash($album);
    $title = wash($title);
    $track = wash($track);

    $dataobj->{tag} = ();

    #Guess it's more usual to have the song rather than the artist
    #if either is missing
    if (($title eq "" || not defined($title)) && (not possible_album($album)) ) 
    {    
	$title = $album;
	$album="";
    }
    
    if( possible_album($title))
    { 
	# Ok, so we fond the title among the possible artists
	# or album, let's guess it's the artist....
	# We thusly switch places on title and album...
	my $tmp;
	
	$tmp = $title;
	$title = $album;
	$album = $tmp;
    }

    $dataobj->{tag}{'track'}=$track;
    vote_track($track,$vote_value);

    $dataobj->{tag}{'album'}=$album;    
    vote_album($album,$vote_value);

    $dataobj->{tag}{'title'}=$title;
    vote_title($title,$vote_value);

    debug("7 - Guessing track: " . $track . "\n",4);
    debug("7 - Guessing album: " . $album . "\n",4);
    debug("7 - Guessing title: " . $title . "\n\n",4);

    bless($dataobj, "main");
    return $dataobj;
} 

sub guess_format8 {
    my $fn = shift;

# File: ./01 - Gladiator - Progeny.mp3

    my ($track, $artist, $title) = ($fn =~ /([0-9]*)[ -]*([^-]*)[ -]*(.*)/);
    my $dataobj;
    my $vote_value = 4;

    $artist = wash($artist);
    $title = wash($title);
    $track = wash($track);

    debug( "8 - First guess track: $track \n",4) if not $track eq "";
    debug( "8 - First guess artist: $artist \n",4) if not $artist eq "";
    debug( "8 - First guess title: $title \n\n",4) if not $title eq "";

    my $artist_bonus = 0;
    $dataobj->{tag} = ();

    #Guess it's more usual to have the song rather than the artist
    #if either is missing
    if (($title eq "" || not defined($title)) && (not possible_artist($artist)) ) 
    {    
	$title = $artist;
	$artist="";
    }
    
    if( possible_artist($title))
    { 

	# Ok, so we fond the title among the possible artists
	# or album, let's guess it's the artist....
	# We thusly switch places on title and artist...
	my $tmp;
	
	$tmp = $title;
	$title = $artist;
	$artist = $tmp;

	$artist_bonus += 1;
    }

#    if( most_possible_artist($artist,$album) < 0 )
#    {
	# This tells us that it is MORE probible that 
	# the album is the artist rather than the current artist
#	$tmp = $album;
#	$album = $artist;
#	$artist = $tmp;

#	$artist_bonus += 2;
#    }

    $dataobj->{tag}{'track'}=$track;
    vote_track($track,$vote_value);

    # Let's raise the probability a bit for this artist vote
    $dataobj->{tag}{'artist'}=$artist;
    vote_artist($artist,$vote_value + $artist_bonus);

    $dataobj->{tag}{'title'}=$title;
    vote_title($title,$vote_value);

    debug("8 - Guessing track: " . $track . "\n",4);
    debug("8 - Guessing artist: " . $artist . "\n",4);
    debug("8 - Guessing title: " . $title . "\n\n",4);

    bless($dataobj, "main");
    return $dataobj;
} 

sub number_first {
    # The semanics of a <=> b is:
    # a = 1; b = 2 => a <=> b = -1
    # Thus a is less than b, which 
    # means that a will be sorted before b
    # in a sorted list, thusly if I want
    # numbers to bes sorted before words
    # a = <a number> and b = <a word> should
    # yield -1 ie a < b

    my $r1 = ($a =~ /^\d+$/);
    my $r2 = ($b =~ /^\d+$/);

    debug( "a = $a : r1 = $r1\n",1);
    debug( "b = $b : r2 = $r2\n",1);

    if( $r1 && $r2 )
    {
	my $r = $a <=> $b;
	debug( "Both numbers, r is $r\n\n",1);
	
	return $a <=> $b;
    }
    elsif( $r1 )
    {
	debug( "r1=a wins -1\n\n",1);
    	return -1;
    }
    elsif( $r2 )
    {
	debug( "r2=b wins 1\n\n",1);
    	return 1;
    }
    else
    {
	# In this case I want the routine to be stable
	# so let's not compare them just say they are
	# equal, then 'sort' seems to keep the order
	#my $r = $a cmp $b;

	#debug( "No numbers r is $r\n\n",1);
	# return $a cmp $b;
	return 0;
    }
    
    return 1;
}

sub guess_format2 {
    my $fn = shift;

    my @info = split(/-/,$fn);
    my $dataobj = {};

    my $track = "";
    my $title = "";
    my $artist = "";
    my $album = "";

    my $artist_bonus = 0;
    my $vote_value = 10;

    $dataobj->{tag} = ();

    #pretty_print(@info);

    @info = map { wash ($_) } @info;
    @info = sort { number_first } @info;

    #pretty_print(@info);

    #Guess it's more usual to have the title rather than the artist
    #if either is missing
    if (@info == 1 ) {
	$title=$info[0];
	$track="";
	$artist="";
    }
    elsif (@info == 2 ) {
	if( $info[0] =~ /\d/ )
	{
	    $track=$info[0];
	    $title=$info[1];
	}
	elsif( $info[1] =~ /\d/ )
	{
	    $track=$info[1];
	    $title=$info[0];
	}
	else
	{
	    $artist=$info[0];
	    $title=$info[1];
	}
    }
    elsif (@info == 3 ) {
	# If it is ONLY a number...
	if ( $info[0]=~ /^(\d)+$/ )
	{
	    $track=$info[0];
	    $artist=$info[1];
	    $title=$info[2];
	    debug( "2 - First guess track: $track \n",4) if not $track eq "";
	    debug( "2 - First guess artist: $artist \n",4) if not $artist eq "";
	    debug( "2 - First guess title: $title \n\n",4) if not $title eq "";
	}
	else
	{
	    $album=$info[0];
	    $artist=$info[1];
	    $title=$info[2];
	}	    
    }
    elsif (@info == 4 ) {
	$track=$info[0];
	$artist=$info[1];
	$album=$info[2];
	$title=$info[3];
    }
    elsif (@info > 4) {
	
	foreach my $info (@info)
	{
	    $info =~ tr/_-/  /;
	    $info = trim($info);
	    
	    if( $info =~ /^(\d)+$/ )
	    {
		$dataobj->{tag}{'track'}=$info;
		vote_track($info,$vote_value);
		debug( "2 - Guessing track: $info \n",4) if not $info eq "";
	    }
	    elsif ( possible_album($info) )
	    {
		$dataobj->{tag}{'album'}=$info;
		vote_album($info,$vote_value + 1);
		debug( "2 - Guessing album: $info \n",4) if not $info eq "";
	    }
	    elsif ( possible_artist($info) )
	    {
		$dataobj->{tag}{'artist'}=$info;
		vote_artist($info,$vote_value + 1);
		debug( "2 - Guessing artist: $info \n",4) if not $info eq "";
	    }
	    else
	    {
                # Here is pure guessing, let's not give it a high score
		$dataobj->{tag}{'title'}=$info;
		vote_title($info,$vote_value - 2);
		debug( "2 - Guessing title: $info \n",4) if not $info eq "";
	    }
	}
	debug( "\n",4);

	bless($dataobj, "main");
	
	return $dataobj;

    }

    $title = wash($title);
    $artist = wash($artist);
    $track = wash($track);
    $album = wash($album);
        
    if( possible_artist($title) || possible_album($title))
    { 
	# Ok, so we fond the title among the possible artists
	# or album, let's guess it's the artist....
	# We thusly switch places on title and artist...
	my $tmp;
	
	$tmp = $title;
	$title = $artist;
	$artist = $tmp;

	$artist_bonus += 1;
    }
   
    if( most_possible_artist($artist,$album) < 0 )
    {
	# This tells us that it is MORE probable that 
	# the album is the artist rather than the current artist
	my $tmp = $album;
	$album = $artist;
	$artist = $tmp;
	
	$artist_bonus += 2;
    }

    $dataobj->{tag}{'track'}=$track;
    vote_track($track,$vote_value);

    $dataobj->{tag}{'album'}=$album;    
    vote_album($album,$vote_value);

    # Le't raise the probability a bit for this artist vote
    $dataobj->{tag}{'artist'}=$artist;
    vote_artist($artist,$vote_value + $artist_bonus);

    $dataobj->{tag}{'title'}=$title;
    vote_title($title,$vote_value);

    debug( "2 - Guessing track: $track \n",4) if not $track eq "";
    debug( "2 - Guessing artist: $artist \n",4) if not $artist eq "";
    debug( "2 - Guessing title: $title \n",4) if not $title eq "";
    debug( "2 - Guessing album: $album \n\n",4) if not $album eq "";

    bless($dataobj, "main");

    return $dataobj;
} 


sub guess_format3 {
    my $fn = shift;

    my ($u1, $artist, $u2) = ($fn =~ /(.*)\(([a-zA-Z -_]+)\)(.*)/);

    my $vote_value = 3;

    debug( "**********************\n",4) unless (not defined $u1) || (not defined $artist) || (not defined $u2) ;
    debug( "U1 is = $u1\n",4) unless not defined $u1;
    debug( "Artist is = $artist\n",4) unless not defined $artist;
    debug( "U2 is = $u2\n",4) unless not defined $u2;
    debug( "**********************\n",4) unless (not defined $u1) || (not defined $artist) || (not defined $u2) ;

    my $dataobj = {};
    $dataobj->{tag} = ();
    $dataobj->{tag}{'artist'}=$artist;
    vote_artist($artist,$vote_value);
}

sub guess_format4 {
    my $fn = shift;

    my ($u1, $track, $u2) = ($fn =~ /(.*)\(([0-9]+)\)(.*)/);

    my $vote_value = 3;

       debug( "**********************\n",4) unless (not defined $u1) || (not defined $track) || (not defined $u2) ;
       debug( "U1 is = $u1\n",4) unless not defined $u1;
       debug( "Track is = $track\n",4) unless not defined $track;
       debug( "U2 is = $u2\n",4) unless not defined $u2;
       debug( "**********************\n",4) unless (not defined $u1) || (not defined $track) || (not defined $u2) ;

    my $dataobj = {};
    $dataobj->{tag} = ();
    $dataobj->{tag}{'track'}=$track;
    vote_track($track,$vote_value);
}

sub guess_format5 {
    my $fn = shift;

    my ($u1, $track, $u2) = ($fn =~ /(.*)-[ ]*([0-9]+)[ ]*-(.*)/);

    my $vote_value = 3;

        debug( "#####################\n",4) unless (not defined $u1) || (not defined $track) || (not defined $u2) ;
        debug( "U1 is = $u1\n",4) unless not defined $u1;
        debug( "Track is = $track\n",4) unless not defined $track;
        debug( "U2 is = $u2\n",4) unless not defined $u2;
        debug( "#####################\n",4) unless (not defined $u1) || (not defined $track) || (not defined $u2) ;

    my $dataobj = {};
    $dataobj->{tag} = ();
    $dataobj->{tag}{'track'}=$track;
    vote_track($track,$vote_value);
}

sub guess_format6 {
    my $fn = shift;

    my ($u1, $album, $u2) = ($fn =~ /(.*)\(([a-zA-Z -_]+)\)(.*)/);

    my $vote_value = 3;

    debug( "**********************\n",4) unless (not defined $u1) || (not defined $album) || (not defined $u2) ;
    debug( "U1 is = $u1\n",4) unless not defined $u1;
    debug( "Album is = $album\n",4) unless not defined $album;
    debug( "U2 is = $u2\n",4) unless not defined $u2;
    debug( "**********************\n",4) unless (not defined $u1) || (not defined $album) || (not defined $u2) ;


    my $dataobj = {};
    $dataobj->{tag} = ();
    $dataobj->{tag}{'album'}=$album;
    vote_album($album,$vote_value);
}


sub fixed_format{
    #-g "%n - %a - %t - %s"
    my ($file) = @_;
    my $dataobj = {};
    my $vote_value = 100;

    $_ = $file;
    my $opt_save = $opt_g;

    debug ( "********************************\n",2);
    debug ( "File is $_\n\n",2);

    my $expression;
    my @matches;

    if($opt_g =~ /%n/)
    {
	$expression = ($opt_g =~ s/%n/([\\d]\+?)/);
	$expression = ($opt_g =~ s/%s/\.\*?/);
	$expression = ($opt_g =~ s/%t/\.\*?/);
	$expression = ($opt_g =~ s/%a/\.\*?/);
	debug ( "opt_g is $opt_g\n",2);
	my ($track) = (eval $opt_g);
	@matches = (eval $opt_g);
	if ($track) 
	{
	    $dataobj->{tag}{'track'}=$track;
	    vote_track($track,$vote_value);
 
	    debug ( "Track was $track\n",2);
	}
	
	foreach my $match (@matches)
	{
	    debug ( "Matches where $match\n",2);
	}
	debug ( "\n",2);
    }

    $opt_g = $opt_save;

    if($opt_g =~ /%a/)
    {
	$expression = ($opt_g =~ s/%n/\.\*?/);
	$expression = ($opt_g =~ s/%s/\.\*?/);
	$expression = ($opt_g =~ s/%t/\.\*?/);
	$expression = ($opt_g =~ s/%a/(\.\+?)/);
	debug ( "opt_g is $opt_g\n",2);
	my ($artist) = (eval $opt_g);
	@matches = (eval $opt_g);
	if ($artist) 
	{ 
	    $dataobj->{tag}{'artist'}=$artist;
	    vote_artist($artist,$vote_value);
	    debug ( "Artist was $artist\n",2);
	}
	
	foreach my $match (@matches)
	{
	    debug ( "Matches where $match\n",2);
	}
	debug ( "\n",2);
    }

    $opt_g = $opt_save;

    if($opt_g =~ /%t/)
    {
	$expression = ($opt_g =~ s/%n/\.\*?/);
	$expression = ($opt_g =~ s/%s/\.\*?/);
	$expression = ($opt_g =~ s/%t/(\.\+?)/);
	$expression = ($opt_g =~ s/%a/\.\*?/);
	debug ( "opt_g is $opt_g\n",2);
	my ($album) = (eval $opt_g);
	@matches = (eval $opt_g);
	if ($album) 
	{ 
	    $dataobj->{tag}{'album'}=$album;    
	    vote_album($album,$vote_value);
	    debug ( "Album was $album\n",2);
	}
	
	foreach my $match (@matches)
	{
	    debug ( "Matches where $match\n",2);
	}
	debug ( "\n",2);
    }


    $opt_g = $opt_save;

    if($opt_g =~ /%s/)
    {
	$expression = ($opt_g =~ s/%n/\.\+?/);
	$expression = ($opt_g =~ s/%s/(\.\+?)/);
	$expression = ($opt_g =~ s/%t/\.\+?/);
	$expression = ($opt_g =~ s/%a/\.\*?/);
	debug ( "opt_g is $opt_g\n",2);
	my ($song) = (eval $opt_g);
	@matches = (eval $opt_g);
	if ($song) 
	{ 
	    $dataobj->{tag}{'title'}=$song;
	    vote_title($song,$vote_value);
	    debug ( "Title was $song\n",2);
	}
	
	
	foreach my $match (@matches)
	{
	    debug ( "Matches where $match\n",2);
	}
	debug ( "\n",2);
    }

    $opt_g = $opt_save;

    bless($dataobj, "main");

    return $dataobj;
}


#case sensitive
sub isSuffix {
    my ($suffix, $comp) = @_;
    return substr($comp, 0, length($suffix)) eq $suffix;
}

#case INsensitive
sub issuffix {
    my ($suffix, $comp) = @_;
    return lc(substr($comp, 0, length($suffix))) eq lc($suffix);
}

sub trim {
  $_ = shift;
  s/^\s*//;
  s/\s*$//;
  return $_;
}

if($sharp)
{
    foreach my $old (keys %Hack) 
    {
	my $new = $Hack{$old};

	if (!$opt_D) 
	{
	    debug( "\nRenaming $old \n      to $new\n",5);
	    if (!$opt_S) 
	    {
		if (-e $new && !defined($opt_F) ) {
		    warn "FILE EXISTS.  Skipping.\n";
		    next;
		}
	    }
	    if ($old ne $new) 
	    {
		rename ($old, $new) or warn "COULDN'T RENAME: $!\n";
		if($opt_L)
		{
		    mlog("rename",$old,$new);
		}
	    }
	}
    }
}

############################

sub get_mp3s {
	my ($dir, $recursive) = @_;

	my $path;
	my @files;

	unless (opendir(DIR, $dir)) {
		warn "Can't open $dir\n";
		closedir(DIR);
		return;
	}

	#$dir =~ s/ /\\ /g;

#	debug("dir is $dir\n",9);

	#He, who do you do 'ls' on a mac?? =)
#	my $dircmd = ((($^O =~ /MSWin32/i) || ($^O =~ /dos/i)) ? 
#		      "dir $dir" : (($^O =~ /mac/i) ? "/bin/ls $dir" : "/bin/ls $dir"));

#	my @dirfiles = `$dircmd`;

#	debug("dircmd is $dircmd\n",9);

#	debug("dirfiles are @dirfiles\n",9);

	# I'll keep this but since it wont work I'll exit the prog
	# if opt_M is tried under MAC
#	if( ($^O =~ /mac/i) )
#	{
	    foreach (readdir(DIR)) {
		next if $_ eq '.' || $_ eq '..';
		$path = "$dir/$_";
		next if (-l $path);
		if (-d $path) {		# a directory
		    if (defined ($recursive) && $recursive == 1) {
			push(@files, get_mp3s($path, $recursive));
		    }
		} elsif (-f _) {	# a plain file
		    if (/\.mp3$/i) {
			push(@files,$path); 
		    }
		}
	    }
#	}
#	else
#	{
#	    foreach (@dirfiles) {
#		debug("looking at $_\n",9);
#		chomp;
		
#		s/ /\\ /g;
		
#		next if $_ eq '.' || $_ eq '..';
#		$path = "$dir/$_";
#		debug("dir is $dir\n",9);
#		debug("path is $path\n",9);
#		next if (-l $path);
#		if (-d $path) {		# a directory
#			debug("recursing to $path\n",9);
#		    if (defined ($recursive) && $recursive == 1) {
#			push(@files, get_mp3s($path, $recursive));
#		    }
#		} elsif (-f $path) {	# a plain file
#		    if (/\.mp3$/i) {
#			push(@files,$path); 
#			debug("pushing $path\n",9);
#		    }
#		}
#	    }
#	}
	closedir(DIR);

	return @files;
}

sub leading_zero {
	my $num = shift;

	if ($num =~ /^[+-]?\d+$/) {
		if (length($num) == 1) {
			return "0$num";
		}
	} 

	return $num;
}

################################################################

use IO::File;

my $DEBUG = 0;

my @id3_genres_array = (
		'Blues', 'Classic Rock', 'Country', 'Dance',
		'Disco', 'Funk', 'Grunge', 'Hip-Hop', 'Jazz',
		'Metal', 'New Age', 'Oldies', 'Other', 'Pop', 'R&B',
		'Rap', 'Reggae', 'Rock', 'Techno', 'Industrial',
		'Alternative', 'Ska', 'Death Metal', 'Pranks',
		'Soundtrack', 'Euro-Techno', 'Ambient', 'Trip-Hop',
		'Vocal', 'Jazz+Funk', 'Fusion', 'Trance',
		'Classical', 'Instrumental', 'Acid', 'House',
		'Game', 'Sound Clip', 'Gospel', 'Noise',
		'AlternRock', 'Bass', 'Soul', 'Punk', 'Space',
		'Meditative', 'Instrumental Pop',
		'Instrumental Rock', 'Ethnic', 'Gothic', 'Darkwave',
		'Techno-Industrial', 'Electronic', 'Pop-Folk',
		'Eurodance', 'Dream', 'Southern Rock', 'Comedy',
		'Cult', 'Gangsta', 'Top 40', 'Christian Rap',
		'Pop/Funk', 'Jungle', 'Native American', 'Cabaret',
		'New Wave', 'Psychadelic', 'Rave', 'Showtunes',
		'Trailer', 'Lo-Fi', 'Tribal', 'Acid Punk',
		'Acid Jazz', 'Polka', 'Retro', 'Musical', 'Rock & Roll',
		'Hard Rock', 'Folk', 'Folk/Rock', 'National Folk',
		'Swing', 'Fast Fusion', 'Bebob', 'Latin', 'Revival',
		'Celtic', 'Bluegrass', 'Avantgarde', 'Gothic Rock',
		'Progressive Rock', 'Psychedelic Rock',
		'Symphonic Rock', 'Slow Rock', 'Big Band',
		'Chorus', 'Easy Listening', 'Acoustic', 'Humour', 'Speech',
		'Chanson', 'Opera', 'Chamber Music', 'Sonata',
		'Symphony', 'Booty Bass', 'Primus', 'Porn Groove',
		'Satire', 'Slow Jam', 'Club', 'Tango', 'Samba',
		'Folklore', 'Ballad', 'Power Ballad',
		'Rhythmic Soul', 'Freestyle', 'Duet',
		'Punk Rock', 'Drum Solo', 'Acapella',
		'Euro-house', 'Dance Hall' );

sub get_id3_info {
	my($mp3_file,$readonly) = @_;
	my $self = {};
	$readonly = 1 unless defined($readonly);
	$self->{FileHandle} = new IO::File;
	if( -w $mp3_file || !$readonly)	{
		$self->{FileHandle}->open("+<${mp3_file}") or (warn("Can't open ${mp3_file}: $!") and return undef);
		$self->{readonly} = 0;
	} else {
		$self->{FileHandle}->open("<${mp3_file}") or (warn("Can't open ${mp3_file}: $!") and return undef);
		$self->{readonly} = 1;
	}
	$self->{filename} = $mp3_file;
	$self->{tag} = ();

	bless($self, "main");

	my $initialized = $self->init();

	if ($self->got_tag() && $id3_vote && !defined($opt_I)) 
	{
	    vote_track(lc(wash($self->get_track())),15);
	    vote_title(lc(wash($self->get_title())),15);
	    vote_artist(lc(wash($self->get_artist())),15);
	    vote_album(lc(wash($self->get_album())),15);
	}	       
	
	return $self;
}

## Some generic initialization
## Find the headers and be ready for questions.
sub init {
	my($self) = @_;
	my $bytestring ="";
	$bytestring = $self->find_tag_id3v1();
	if(!defined($bytestring)) {
		return 0;
	} else {
		$self->decode_tag_id3v11($bytestring);
	}
	return 1;
}

sub find_tag_id3v1 {
	my($self) = @_;
	my($bytes,$line);
	$self->{FileHandle}->seek(-128,SEEK_END); # Find the last 128 bytes
	while($line = $self->{FileHandle}->getline()) { $bytes .= $line; }
	return undef if $bytes !~ /^TAG/; # Must have Tag Ident to be valid.
	return $bytes;
}

sub write_tag_id3v1 {
    my($mp3_file,$tag) = @_;

    my $self = {};
    my $readonly = 1;

    $self->{FileHandle} = new IO::File;
    if( -w $mp3_file || !$readonly)	{
	$self->{FileHandle}->open("+<${mp3_file}") or (warn("Can't open ${mp3_file}: $!") and return undef);
	$self->{readonly} = 0;
    } else {
	$self->{FileHandle}->open("<${mp3_file}") or (warn("Can't open ${mp3_file}: $!") and return undef);
	$self->{readonly} = 1;
    }
    $self->{filename} = $mp3_file;
    $self->{tag} = ();

    bless($self, "main");

    $self->{FileHandle}->seek(0,SEEK_END); # Find the end of the file

    my $the_tag = "TAG";
    my $title;
    my $artist;
    my $album;
    my $year;
    my $comment;
    my $track;
    my $genre_num;
    my $zero;

    if( defined($tag->{title}) )
    {
	$title= substr($tag->{title},0,30);
    }
    else
    {
	$title = create_padding(30);
    }
    if( defined($tag->{artist}) )
    {
	$artist = substr($tag->{artist},0,30);
    }
    else
    {
	$artist = create_padding(30);
    }
    if( defined($tag->{album}) )
    {
	$album = substr($tag->{album},0,30);
    }
    else
    {
        $album = create_padding(30);
    }
    if( defined($tag->{year}) )
    {
	$year = substr($tag->{year},0,4);
    }
    else
    {
	$year =  create_padding(4);
    }
    if( defined($tag->{comment}) )
    {
	$comment = substr($tag->{comment},0,28);
    }
    else
    {
	$comment = create_padding(28);
    }

    # Indicates that the last char is used for the tracknumber
    $zero = "0";

    if( defined($tag->{track}) )
    {
	$track = $tag->{track};
    }
    else
    {
	$track = 3;
    }

    if( defined($tag->{genre_num}) )
    {
	$genre_num = $tag->{genre_num};
    }
    else
    {
	$genre_num = 255;
    }

      debug( "Title: *" . $title . "*\n",1);
      debug( "Artist: *" . $artist  . "*\n",1);
      debug( "Album: *" . $album . "*\n",1);
      debug( "Year: *" . $year . "*\n",1);
      debug( "Comment: *" . $comment . "*\n",1);
      debug( "Track: *" . $track . "*\n",1);
      debug( "Genre Num: *" . $genre_num . "*\n",1);

    my @list = ($the_tag, $title, $artist, $album, $year, $comment, $zero, $track, $genre_num);

    my $pack = pack('A3A30A30A30A4A28A1C1C1', @list);
    
    debug( "Length of pack is: " . length($pack) . "\n",1);
    debug( "TAG is: \n*" . $pack . "*\n",1);

    $self->{FileHandle}->write($pack,128);
    $self->{FileHandle}->close();
}

sub remove_tag_id3v1 {
    my $mp3_file = shift;

    my $self = {};
    my $readonly = 1;

    debug("Removing ID3 tag in file'$mp3_file'\n",5);

    $self->{FileHandle} = new IO::File;
    if( -w $mp3_file || !$readonly)	{
	$self->{FileHandle}->open("+<${mp3_file}") or (warn("Can't open ${mp3_file}: $!") and return undef);
	$self->{readonly} = 0;
    } else {
	$self->{FileHandle}->open("<${mp3_file}") or (warn("Can't open ${mp3_file}: $!") and return undef);
	$self->{readonly} = 1;
    }
    $self->{filename} = $mp3_file;
    $self->{tag} = ();

    bless($self, "main");

    $self->{FileHandle}->seek(-128,SEEK_END); # Find the last 128 bytes
    my ($line, $bytes);
    while($line = $self->{FileHandle}->getline()) { $bytes .= $line; }
    if($bytes !~ /^TAG/)# Must have Tag Ident to be valid.
    {
	debug("Warning: '$mp3_file' did not contain ID3 tag, cannot remove it!\n",5);
    }

    $self->{FileHandle}->seek(-128,SEEK_END); # Find the last 128 bytes
    my $currpos = $self->{FileHandle}->tell();

    $self->{FileHandle}->truncate($currpos);
    $self->{FileHandle}->close();
}

sub create_padding {
    my ($length) = @_;
    my $pad = "";

    for( my $i = 0; $i < $length; $i++)
    {
	$pad .= " "; 
    } 
    return $pad;
}


## Decode the ID3v1.1 Tag into useful tidbits.
sub decode_tag_id3v11 {
	my($self,$buffer) = @_;
	## Unpack the Audio ID3v1
	(undef, @{$self->{tag}}{qw/title artist album year comment zero track genre_num/}) = 
	    unpack('a3a30a30a30a4a28a1C1C1', $buffer);
		#unpack('a3a30a30a30a4a30C1', $buffer);
	
	## Clean em up a bit
	foreach (sort keys %{$self->{tag}}) 
	{
	    if(defined($self->{tag}{$_})) 
	    {
		$self->{tag}{$_} =~ s/\s+$//;
		$self->{tag}{$_} =~ s/\0.*$//;
		
		# debug(sdebug(f("ID3v11: %s = ", $_ ) . $self->{tag}{$_}),5);
	    }
	}

	if (hex($self->{tag}{'track'}) >= 50) {
		$self->{tag}{'track'} = ''; 
	} 
		
	$self->{tag}{'genre'} = $id3_genres_array[$self->{tag}{'genre_num'}];
}

sub get_title {
  my($self) = @_;
  return $self->{tag}{'title'};
}

sub get_artist {
  my($self) = @_;
  return $self->{tag}{'artist'};
}

sub get_album {
  my($self) = @_;
  return $self->{tag}{'album'};
}

sub get_year {
  my($self) = @_;
  return $self->{tag}{'year'};
}

sub get_comment {
  my($self) = @_;
  return $self->{tag}{'comment'};
}

sub get_genre {
  my($self) = @_;
  return $self->{tag}{'genre'};
}

sub get_genre_num {
  my($self) = @_;
  return $self->{tag}{'genre_num'};
}

sub get_track {
  my($self) = @_;
  return $self->{tag}{'track'};
}

sub debug_tag {
  my($self) = @_;

  if(defined($self->{tag})) {
    foreach (sort keys %{$self->{tag}}) {
      debug((sprintf("%-10s = ",$_ ) . $self->{tag}{$_} . "\n"),5);
    }
  } else {
    debug( "No ID3v1 Tag Found\n",5);
  }
}

sub got_tag {
  my($self) = @_;
  #return ($self->find_tag_id3v1())?1:0;
  return defined($self->{tag})
}

my $level = -1; # Level of indentation
my %already_seen;

sub pretty_print {
    my $var;
    foreach $var (@_) {
        if (ref ($var)) {
            print_ref($var);
        } else {
            print_scalar($var);
        }
    }
}

sub print_scalar {
    ++$level;
    my $var = shift;
    print_indented ($var);
    --$level;
}

sub print_ref {
    my $r = shift;
    if (exists ($already_seen{$r})) {
        print_indented ("$r (Seen earlier)");
        return;
    } else {
        $already_seen{$r}=1;
    }
    my $ref_type = ref($r);
    if ($ref_type eq "ARRAY") {
        print_array($r);
    } elsif ($ref_type eq "SCALAR") {
        debug("Ref -> $r",5);
        print_scalar($$r);
    } elsif ($ref_type eq "HASH") {
        print_hash($r);
    } elsif ($ref_type eq "REF") {
        ++$level;
        print_indented("Ref -> ($r)");
        print_ref($$r);
        --$level;
    } else {
        print_indented ("$ref_type (not supported)");
    }
}

sub print_array {
    my ($r_array) = @_;
    ++$level;
    print_indented ("[ # $r_array");
    foreach my $var (@$r_array) {
        if (ref ($var)) {
            print_ref($var);
        } else {
            print_scalar($var);
        }
    }
    print_indented ("]");
    --$level;
}

sub print_hash {
    my($r_hash) = @_;
    my($key, $val);
    ++$level; 
    print_indented ("{ # $r_hash");
    while (($key, $val) = each %$r_hash) {
        $val = ($val ? $val : '""');
        ++$level;
        if (ref ($val)) {
            print_indented ("$key => ");
            print_ref($val);
        } else {
            print_indented ("$key => $val");
        }
        --$level;
    }
    print_indented ("}");
    --$level;
}

sub print_indented {
    my $spaces = ":  " x $level;
    debug( "${spaces}$_[0]\n",5);
}

sub debug {
    my ($msg,$lvl) = @_;

    if(!defined $lvl)
    {
	$lvl = $mindebuglevel;
    }

    # Exact level
    if($verbosity_filter == 0 )
    {       
	if($lvl == $debuglevel)
	{
	    print $msg;
	}
    }
    # All above
    elsif ($verbosity_filter == 1 )
    {
	if($lvl >= $debuglevel)
	{
	    print $msg;
	}
    }
    # Interval
    else
    {
	if($lvl >= $mindebuglevel && $lvl <= $maxdebuglevel)
	{
	    print $msg;
	}
    }
}

sub show_all_levels {
    $verbosity_filter = 1;
}

sub show_one_level {
    $verbosity_filter = 0;
}

sub wash {
    my ($to_be_washed) = @_;

    if(defined($to_be_washed))
    {
	debug("Unwashed: " . $to_be_washed . "\n", 1);
	
	$to_be_washed =~ tr/-//d;
	
	debug("Newly washed: " . $to_be_washed . "\n", 1);
    }

    $to_be_washed = trim($to_be_washed);
    
    return $to_be_washed;
}

sub add_prompt_cond{
    my $new_cond = shift;
    push(@prompt_conds, $new_cond);
}

sub do_prompt{
    foreach my $cond (@prompt_conds)
    {
	if( eval $cond )
	{
	    return eval $cond;
	}
	if( ref ($cond) )
	{
	    return &$cond;
	}
    }
    return 0;
}

sub prompt_set_val{
    my ($pr, $value) = @_;

    %prompts->{$pr} = $value;
}

sub prompt_get_val{
    my ($pr) = @_;

    return %prompts->{$pr};
}

sub prompt_is_set{
    my ($pr) = @_;
    return defined %prompts->{$pr};
}

sub lprompt {
    my $lvl = shift;
    if( $prompt_lvl == $lvl)
    {
	return prompt(@_);
    }
    return -1;
}

sub prompt {
    my ($pr, @args) = @_;
    my $cnt = 0; 
    
    return prompt_def($pr,0,@args);
}

sub lprompt_generic {
    my $lvl = shift;
    if( $prompt_lvl == $lvl)
    {
	return prompt_generic(@_);
    }
    return -1;
}

sub prompt_generic {
    my ($pr) = @_;
    
    print "$pr> ";
    my $result = <STDIN>;
    
    chomp $result;
    
    return $result;
}

sub lprompt_def {
    my $lvl = shift;
    if( $prompt_lvl == $lvl)
    {
	return prompt_def(@_);
    }
    return -1;
}

sub prompt_def {
    my ($pr, $def, @args) = @_;
    my $cnt = 0; 

    if(prompt_is_set($pr))
    {
	print "Already answered ($pr) : " . prompt_get_val($pr) . "\n";
	print "Continuing...\n";
	return prompt_get_val($pr);
    }
    else
    {
	foreach my $arg (@args)
	{
	    if($cnt == $def)
	    {
		print "=> Alt [" . $cnt . "]: " . $arg . "\n";
	    }
	    else
	    {
		print "   Alt [" . $cnt . "]: " . $arg . "\n";
	    }

	    $cnt++;
	}
	print "   Usage: ?\n";
	$cnt--;
	
	print "$pr> ";
	my $result = <STDIN>;

	my $resultval = ($result =~ tr/[a-zA-Z]/ /);

	if( $result eq "\n")
	{
	    return $args[$def];
	}
	elsif ( $result =~ /[\?]/)
	{
	    def_prompt_usage(\&prompt_def,@_);
	}
	elsif ( $result =~ /^-$/)
	{
	    return prompt_generic("Enter value:");
	}
	elsif( $result !~ /\d+/ || $resultval < 0 || $resultval > $cnt)
	{
	    print "cnt == $cnt; resultval = $resultval\n";
	    print "Sorry, invalid answer, retry!\n";
	    return prompt($pr,@args);
	}
	else
	{
	    if($result =~ /[Aa]/)
	    {
		$result =~ tr/[a-zA-Z]/ /;
		prompt_set_val($pr,$args[$result]);
	    }
	    return $args[$result];
	}
    }
}

sub def_prompt_usage{    

    my $caller = shift;

    print STDERR <<EUS;

    Prompt help.
    ------------

    The default choice is arrowed (=>).
    Possible choizes are:

    <digit> =  select alternative 
    <digit>A = always this alternative
    <digit>a = always this alternative
    ? = this help text
    - = enter your own value

EUS

&$caller(@_);

}

sub lprompt_yn {
    my $lvl = shift;
    if( $prompt_lvl == $lvl)
    {
	return prompt_yn(@_);
    }
    return -1;
}

sub prompt_yn {
    my ($pr,$default) = @_;

    my $val = 1;

    if(prompt_is_set($pr))
    {
	print "Already answered ($pr) : " . prompt_get_val($pr) . "\n";
	print "Continuing...\n";
	return prompt_get_val($pr);
    }
    else
    {
	my $defstr = "[Y/n/a/e/?]";
	
	if(defined($default))
	{
	    if( $default =~ /[nN]/ || $default <= 0)
	    {
		$defstr = "[y/N/a/e/?]";
		$val = 0;
	    }
	}
	
	print "$pr " . $defstr . " > ";
	my $answ = <STDIN>;
	
	if( $answ eq "\n" )
	{
	    return $val;
	}
	
	if( $answ =~ /[yY]/)
	{
	    $val = 1;
	}
	elsif ( $answ =~ /[nN]/)
	{
	    $val = 0;
	}
	elsif ( $answ =~ /[\?]/)
	{
	    return yn_prompt_usage(\&prompt_yn,@_);
	}
	elsif ( $answ =~ /[Aa]/)
	{
	    prompt_set_val($pr,1);
	    $val = 1;
	}
	elsif ( $answ =~ /[Ee]/)
	{
	    prompt_set_val($pr,0);
	    $val = 0;
	}

    }

    return $val;
}

sub yn_prompt_usage{

    my $caller = shift;

    print STDERR <<EUS;

    Prompt help.
    ------------

    The default choice is capitalized.
    Possible choizes are:

    Y/y = yes
    N/n = no
    A/a = always
    E/e = nEver 

    ? = this help text

EUS

return &$caller(@_);

}

sub init_log {
    my $command;
    my $args;

    my $lgfile = shift;

    debug("Logfile is: $lgfile\n",3);
    if( -e $lgfile )
    {
	open(LOGFILE, "+>> $lgfile") or die "Couldn't open $lgfile for logging: $!\n";
	seek LOGFILE, 0, 0;
	while (<LOGFILE>)
	{
	    while ( /^([\d]+):([^:]*):*(.*)/g ) 
	    {
		$logid = $1;
		$command = $2;
		chomp $command;
		$args = $3;
		chomp $args;
		if($command eq "map")
		{
		    my ($cmd,$numargs) = ($args =~ /([^:]*):([\d]+)/);
		    debug("parsed '$cmd' '$numargs'\n",1);
		    %log_map->{$cmd}=$numargs;
		}
		debug("command was $command\n",2);
		debug("args was $args\n",2);
	    }
	}
    }
    else
    {
	open(LOGFILE, "> $lgfile") or die "Couldn't open $lgfile for logging: $!\n";
	$logid = 0;
    }
    $have_logfile = 1;
    my $time = `date`;
    chomp $time;
    mlog("mark",$time);
}

sub make_logentry {
    my $logcmd = shift;
    my @content = @_;

    $logid++;

    my $entry;
    
    if($logcmd eq "rename")
    {
	$entry = "$logid:$logcmd:";
	my $files = "[" . $content[0] . "] " . "[" . $content[1] . "]";
	$entry = $entry . $files;
    }
    else
    {
	$entry = "$logid:$logcmd:@content";
    }

    return $entry;
}

sub mlog {
    my $cmd = shift;
    my @args = @_;
    my $log_dest;

    my $entry = make_logentry($cmd,@args);

    $log_dest = *STDOUT;

    if($have_logfile)
    {
	$log_dest = *LOGFILE;
    }

    print($log_dest $entry . "\n");
    flush LOGFILE;
}

#This suck, is there no member function for arrays in perl??
#And the Perl FAQ: How can I tell whether an array contains a certain element?
#doesn't give any good suggestions either...
#First: make a hash; well the array keeps changing so the I must constantly
#rebuild the hash.. 
#The rest assumes integers, which I'm not dealing with...
sub member {
    my $elm = shift;
    my @arr = @_;

    debug("elm is $elm; members are:\n",1);
    debug("@arr\n",1);

    foreach my $el (@arr)
    {
	if( $el eq $elm )
	{
	    return 1;
	}
    }
    return 0;
}

sub reverter {
    my $logfile = shift;
    my $startind = shift;
    my $stopind = shift;
    
    open(LGFILE, "< $logfile") or die "Couldn't open $logfile for logging: $!\n";
    
    my @origlines = <LGFILE>;
    
    debug("Lines are now \n@origlines\n\n",2);

    my @lines = grep { $_ =~ /rename/ }  @origlines;
    my @dirs = grep { $_ =~ /mkdir/ }  @origlines;

    debug("Lines are now \n@lines\n\n",2);
    
    if( defined $startind )
    {
	@lines = grep {  my ($val) = ($_ =~ /^([\d]+)/); $val >= $startind } @lines;
	@dirs = grep {  my ($val) = ($_ =~ /^([\d]+)/); $val >= $startind } @dirs;
    }

    debug("Lines are now \n@lines\n\n",2);

    if( defined $stopind )
    {
	if($stopind == -1)
	{
	    $stopind = $logid;
	}

	@lines = grep {  my ($val) = ($_ =~ /^([\d]+)/); $val <= $stopind } @lines;
	@dirs = grep {  my ($val) = ($_ =~ /^([\d]+)/); $val <= $stopind } @dirs;
    }

    debug("Lines are now \n@lines\n\n",2);

    foreach my $line (@lines)
    {
	my ($file1,$file2) = ($line =~ /^[\d]+:rename:\[([^\]]+)\] \[([^\]]+)\]/);
	print "reverting $file2 to $file1\n";
	
	if( !$opt_D )
	{
	    rename ($file2, $file1) or warn "COULDN'T RENAME: $!\n";
	}
	
	mlog("rename",$file2,$file1);
    }


    debug("\n\nDirs are: @dirs\n",4);

    #Ok, we have now hopefully revered all files,
    #remove the direcories if they are empty
    #We have to do it in reverse order or else
    #the direcory will never be empty
    my $i = @dirs;
    for ($i--; $i >= 0; $i--) {
	# do something with $ARRAY[$i]

	debug("\n\ni is: $i\n",2);
	debug("\n\ndirs[i] is: $dirs[$i]\n",2);

	my ($dir) = ($dirs[$i] =~ /^[\d]+:mkdir:(.*)/);
	
	if( !$opt_D )
	{
	    debug("\n\nTrying to remove: $dir\n",2);
	    my $rmres = rmdir "$dir";
 	    if($rmres)
	    {
		mlog("rmdir",$dir);
	    }
	    else
	    {
		print STDERR "cannot rmdir $dir: $!";
	    }
	}
    }
}

sub usage {

    print STDERR <<USAGE;

smartid3 (A Smart (haha) MP3 File Renamer in Perl) v$version

Usage: smartid3.pl [-rDShwc][_s][ult][f "format"] [dir]

   -h  Help (this)
   -i  take the filenames from the commandline
   -r  recursively process subdirectories
   -R  Remove the ID3 tag. 
   -D  Debug mode (shows what would happen)
   -S  Turn Smart/Stoopid mode off
   -w  Write id3 info if there is no info in the file
   -c  Create subdirectories for artist and album (if they exist)
   -A  "<Artist>" sets the artist for all mp3s to Artist
   -T  "<Album Title>" sets the artist for all mp3s to Album Title
   -N  "<Track number>" sets the tracknumber for all mp3s to Track Number
   -O  "<Song Title>" sets the song title for all mp3s to Song Title
   -I  Ignore the ID3 tag
   -o  Use ONLY id3 tag.
   -F  Force writing of file even is it exists (which is not done per
       default)	
   -W  Force writing of ID3 tag even is it exists (which is not done per
       default)
   -g  "<format>" Takes the format of files on the command line
   -L  "<logfile>" use logfile
   -B  "<logfile>" revert files from logfile
   -z  "<logindex>" the lower bound for the logindex (used with -B)
   -Z  "<logindex>" the upper bound for the logindex (used with -B)
   -M  "<templatefile>" use templatefile 
   -m  use ms-dos >yuck< compatible file_names
   -U  write UNDO script

   Verbosity:
   Levels are 0-10.
   
   -V  "<level>" Set the verbosity level to exactly 'level', only that 
       level will be printed
   -v  "<level>" Set the verbosity level to 'level', all above will be printed
     
   Separator:
   -p  "<separator>" (Will have no effect if not -f is used)

   Output format:
   -f  "Format string"
       %f = filename (default)

       if mp3 has ID3 tag or can be deduced from the filename:
       %a  Artist
       %s  Song
       %t  Album Title
       ID3v1.1 only:
       %n  Track Number

   Space Option:
   -_  change spaces to underscores
   -s  change underscores to spaces

   Case Option:
   -u  upper case name
   -l  lower case name
   -t  title case name

EXAMPLES

To see the ID3 tags and the heuristic guesses on the mp3 files in the directory 
execute the following:

     perl smartid3.pl -D

To write id3 tags to files which have none and create subdirectories for artist
and album exectute this:

     perl smartid3.pl -w -c

To use ' - ' as a separator and put the songs in subdirectories according to artist
and album, and format the songname as Tracknumber - Songname.mp3 and title case
the songname (so for instance 'Michael Jackson-10-are you my life.mp3' with the 
ID3 tag 'Album' set to Invincible would become 
'./Michael Jackson/Invincible/10 - Are You My Life.mp3') execute the following: 

     perl smartid3.pl -f "%n%s" -p " - " -t -c

To remove the ID3 tag in some files do:

     perl smartid3.pl -R


To work only on the files beginning with 'michael_jackson' execute the line below
(this option will assumes it will only be given .mp3 filenames)

     perl smartid3.pl -i michael_jackson-*

To force rewriting of the ID3 tag and set the artist to 'Bob Dylan' execute the
command below (the -F is to force writing of the file since this is not done per
default if the file already exists). (OBSERVE the old entries in the ID3 tag will
be overwritten whith the most probable values)

     perl smartid3.pl -W -A "Bob Dylan" -F

To rename the file '01 - Dylan  Ashville Nc  50101.mp3' to 'where teardrops fall'
and force the rewriting of the ID3 tag with songname 'where teardrops fall' and 
artist 'Bob Dylan' execute the following:

     perl smartid3.pl -W -f "%n %s" -O "where teardrops fall" -A "Bob Dylan" -F -i "01 - Dylan  Ashville Nc  50101.mp3"

To log all file operations to the logfile /tmp/mylog.log see the following example:

     perl smartid3.pl -L /tmp/mylog.log -f "%s%n" -t -p " - "

To revert the file operations with logindex from 430 and up do: 

     perl smartid3.pl -B /tmp/mylog.log -z 430

To revert the file operations with logindex index 0 to 430 do: 

     perl smartid3.pl -B /tmp/mylog.log -Z 430

To revert the file operations with logindex between 400 and 430 do: 

     perl smartid3.pl -B /tmp/mylog.log -z 400 -Z 430

The following line, logs operations to the file '/tmp/usenet2.log' (-L) and 
uppercases the first letter in the filename parts (-t) renames the songs to
format 'Artist - Tracknumber - Songname.mp3' (-f). It also writes the id3 tag
in files which have none (-w).

     perl smartid3.pl -L /tmp/usenet2.log -t -f "%a%n%s" -p " - " -w

The next line revers the operations made by the above line:

     perl smartid3.pl -B /tmp/usenet2.log


AUTHOR
       Written by Leif Jonsson (lejon\@ju-jutsu.com) based on mp3frip 
       (MP3 File Renamer in Perl) by Ryan Lathouwers (ryanlath\@pacbell.net)

LOCATION

       http://www.ju-jutsu.com/smartid3/

USAGE

exit;
}

#------------------------------------------------------------------------------
#
# POD
#
#------------------------------------------------------------------------------

=head1 NAME

smartid3.pl - script for organizing mp3 files

=head1 SYNOPSIS

    smartid3.pl
       [ -hirDSRwcIFW_s ][u|l|t]
       [ -A  <artist> ] 
       [ -T  <album Title> ]
       [ -N  <track number> ]
       [ -O  <song title> ]
       [ -V  <level> ]
       [ -v  <level> ]
       [ -p  <separator> ]
       [ -f  <Format string> ]
       [ -L  <log file> ]
       [ -B  <log file> ]
       [ -z  <lower logindex> ]
       [ -Z  <upper logindex> ]
       [ -M  <templatefile> ]
       dir

=cut

=head1 DESCRIPTION

B<smartid3.pl> aims at organizing mp3 files automatically for you. The
idea is that you should be able to run the script on a large amount of
files to get them organized in a consistent manner according to your 
desires.

It works by giving the filename of the mp3 to a number of methods which
each has it's own special way of guessing the song, album, artist title
and track number. Each method has a B<vote_value> which is a notation
on how reliable the method is. 

Before all methods vote, there is a preprocessing phase done on the files,
which looks at all the files given and tries to figure out possible albums
and artists. The idea is that albums and artists, shows up in several
filenames.

After all methods have voted there are some postprocessing done on the
votes such as checking for strange values such as for instance 'http'
in either entry, which would lead to a reduction of that entrys score,
the entries are also checked to see it the artist is the same as the
album and so on.

=head1 OPTIONS

=head2 -h

Prints a short helptext.

=head2 -i

Makes the script take the filenames as command line arguments rather than
working on a directory.

=head2 -r

Recursive down in subdirectories.

=head2 -D

Debug mode, will not modify any files, just print some info.

=head2 -S

Misc usable functionallity. =)

=head2 -w

Makes the script write id3 tags to files which have no id3 tags.

=head2 -c

Makes the script create subdirectories for artist and album.

=head2 -A <artist>

Give the artist name on the command line. Can be used with -w to write
id3 tags to files which have none.

=head2 -T <album>

Give the album name on the command line. Can be used with -w to write
id3 tags to files which have none.

=head2 -O <song title>

Give the song title on the command line. Can be used with -w to write
id3 tags to files which have none.

=head2 -N <track number>

Give the track number on the command line. Can be used with -w to write
id3 tags to files which have none.

=head2 -I

Ignore the id3 tag, good if the tag is set to strange things.

=head2 Use ONLY id3 tag.

=head2 -R

Remove the ID3 tag. (This is done first, so if -W is also invoked the
file will still have a ID3 tag after the operation)

=head2 -L  "<logfile>" 

use logfile

=head2 -M  "<templatefile>" 

This option takes a file of filenames, and renames the files fed to
this script to each flename in the templatefile. The order is highly
significant

=head2 -B "<logfile>" 

revert files from logfile

=head2 -z "<logindex>" 

the lower bound for the logindex (used with -B)

=head2 -Z  "<logindex>" 

the upper bound for the logindex (used with -B)

=head2 -F

Force writing of the file even if it exists, good to use if for instance you
want to change the id3 tag. USE WITH CAUTION

=head2 -W

Force writing of the id3 tag even if it exists. USE WITH CAUTION

=head2 -V <level>

Verbosity, this option specifies a specific verbosity level, so only messages
whith that level set will be printed.

=head2 -v <level>

Verbosity, this option specifies a minimum verbosity level, so messages
whith 'level' and above will be printed.

=head2 -p <separator>

Separator, inserted between artist, album, track and songname.

=head2 -f <format string>

Output format

=over 4

=item %f = filename 

Filename.

=item %a  Artist

Artist name.

=item %s  Song

Song title

=item %t  Album Title

Album Title

=item %n  Track number

Track number

=back

=head2 -_  

Change spaces to underscores

=head2 -s  

Change underscores to spaces

=head2 -u  

Uppercase name

=head2 -l  

Lowercase name

=head2 -t  

Title case name

=head2 -g <format>

The -g option takes the format of the files on the command line, if for
instance you know that all the files are on the format 
Artist-Album-Track-Title.mp3  this option let's you tell that to the script

=head1 EXAMPLES

To see the ID3 tags and the heuristic guesses on the mp3 files in the directory 
execute the following:

     perl smartid3.pl -D

To write id3 tags to files which have none and create subdirectories for artist
and album exectute this:

     perl smartid3.pl -w -c

To use ' - ' as a separator and put the songs in subdirectories according to artist
and album, and format the songname as Tracknumber - Songname.mp3 and title case
the songname (so for instance 'Michael Jackson-10-are you my life.mp3' with the 
ID3 tag 'Album' set to Invincible would become 
'./Michael Jackson/Invincible/10 - Are You My Life.mp3') execute the following: 

     perl smartid3.pl -f "%n%s" -p " - " -t -c

To remove the ID3 tag in some files do:

     perl smartid3.pl -R


To work only on the files beginning with 'michael_jackson' execute the line below
(this option will assumes it will only be given .mp3 filenames)

     perl smartid3.pl -i michael_jackson-*

To force rewriting of the ID3 tag and set the artist to 'Bob Dylan' execute the
command below (the -F is to force writing of the file since this is not done per
default if the file already exists). (OBSERVE the old entries in the ID3 tag will
be overwritten whith the most probable values)

     perl smartid3.pl -W -A "Bob Dylan" -F

To rename the file '01 - Dylan  Ashville Nc  50101.mp3' to 'where teardrops fall'
and force the rewriting of the ID3 tag with songname 'where teardrops fall' and 
artist 'Bob Dylan' execute the following:

     perl smartid3.pl -W -f "%n %s" -O "where teardrops fall" -A "Bob Dylan" -F -i "01 - Dylan  Ashville Nc  50101.mp3"

To log all file operations to the logfile /tmp/mylog.log see the following example:

     perl smartid3.pl -L /tmp/mylog.log -f "%s%n" -t -p " - "

To revert the file operations with logindex from 430 and up do: 

     perl smartid3.pl -B /tmp/mylog.log -z 430

To revert the file operations with logindex index 0 to 430 do: 

     perl smartid3.pl -B /tmp/mylog.log -Z 430

To revert the file operations with logindex between 400 and 430 do: 

     perl smartid3.pl -B /tmp/mylog.log -z 400 -Z 430

The following line, logs operations to the file '/tmp/usenet2.log' (-L) and 
uppercases the first letter in the filename parts (-t) renames the songs to
format 'Artist - Tracknumber - Songname.mp3' (-f). It also writes the id3 tag
in files which have none (-w).

     perl smartid3.pl -L /tmp/usenet2.log -t -f "%a%n%s" -p " - " -w

The next line revers the operations made by the above line:

     perl smartid3.pl -B /tmp/usenet2.log

=head1 ENVIRONMENT

B<smartid3.pl> doesn't use any environment variables.

=head1 PREREQUISITES

    Perl.

=head1 OSNAMES

    linux 2.4.9 i686-linux 

=head1 SEE ALSO

mp3frip (MP3 File Renamer in Perl) by Ryan Lathouwers (ryanlath\@pacbell.net)

=head1 BUGS

Not thoroughly tested. 

Revert has some problems, I ran the program on 380 files and the tried
revert, and four files was not succsessfully reverted.

Empty directories is not removed when reverting. [fixed]

=head1 AUTHOR

Leif Jonsson E<lt>lejon@ju-jutsu.comE<gt>

=head1 HOMEPAGE

http://www.ju-jutsu.com/smartid3/

=head1 DOWNLOAD

http://www.ju-jutsu.com/smartid3/smartid3.pl

=head1 COPYRIGHT

License: (to quote Mr Ryan Lathouwers =)
This program is free software; you can redistribute it and/or modify 
it under the same terms as Perl itself (like I've ever read 'em).

=head1 SCRIPT CATEGORIES

Audio

=cut

#------------------------------------------------------------------------------
#
# EO POD
#
#------------------------------------------------------------------------------

