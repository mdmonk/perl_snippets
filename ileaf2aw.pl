#!/usr/bin/perl

# push @INC, "/net/teddy.central/usr/local/lib/perl5";
require "flush.pl";

$ZCAT="/usr/bin/zcat";
$TARXF="tar xf ";
$TARTF="tar tf ";
$TARCF="tar cf ";
$TEE = "| tee ";

$UNZ="/usr/bin/uncompress";
$Z="/usr/bin/compress";

$STARLEN=55;

# where ftp'd files are processed
$FTPDIR="/export/ftp/pub";
$PID=$$;

# for substituting .. and .
$curdir=`pwd`;
chomp $curdir;

$PROG=`basename $0`;
chomp $PROG;


$PID=$$;
$curdir= `pwd`;
chomp $curdir;

$PROG=`basename $0`;
chomp $PROG;

# logfile contains transcript of session
#$LOG = "$curdir/$PROG.LOG.$PID"; 

$LOG = "/tmp/Conversion_Results.$PID"; 

open ( LOG, ">>$LOG" );


 ########################################
 #   SUBROUTINES
 ########################################

  ########################################
  #   print a line of stars
  sub print_stars{

      print "*" x $STARLEN;
      print "\n\n";

  }

  sub now {

	$the_time=`date '+%m%d%y_%T'`;
	chomp $the_time;
	return $the_time;
  }




########################################
# CENTERMENU	
sub centermenu {

@STRING = @_ ;

$str= join ( " ", @STRING );

$strlen=length $str;

$indent=( ( $STARLEN - $strlen ) / 2 );



print_stars;
print " " x $indent;
print "$str\n\n";

}

########################################
#	LEFTMENU
sub leftmenu {

@STRING = @_ ;

$STRING = join(" ", @STRING );

write;

format =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
"*******************************************************"
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$STRING
~ \
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$STRING
~ \
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$STRING
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
"*******************************************************"
.

}

########################################
#	BEGINNING OF MAIN ROUTINES
########################################

########################################
#	Get cmd line arguments and process
########################################

print_stars;
centermenu ( "DOCUMENT CONVERSION PROGRAM" );
print_stars;
centermenu "Beginning Conversion"; 
system ("sleep 1");
if ( $ARGV[1] ) {
  $USER_EMAIL="$ARGV[1]"; 
  print "User email is $USER_EMAIL\n";
}

if  ( ++$#ARGV < 1 ) { 
 print  "USAGE: $0 <directory to convert> or\n       $0 <file.tar.Z>\n\n";
 print  "Press [RETURN] to exit, or enter a \nfile or directory to convert:\n\n";
 print "--> ";
 $ans=<STDIN>;
 chomp $ans;

   if ( $ans ){
	 $file = $ans;
   }else{
	 exit ; 
   }

}else{
  $file=$ARGV[0];
}

# figure out whether a dir to convert or a file to untar

$file =~ s/^\~/$ENV{"HOME"}/;

# if they entered '.'
$file =~ s/^\.$/$curdir/;

if ( ! -e $file ){
 print "File $file doesn't exist\n"; 
 getc;
 exit;
}

( $file, $type ) = split(":\t", `file $file`);


# Work only with a directory or tar file
if ( $type =~  /compressed/ || $type =~ /directory/  
	 || $type =~ Interleaf ){ 
 chomp $type;
}else {
 print "    Can't work with file type:\n    $type\n" ;
 exit;
}

########################################
########################################
#	If a directory --
########################################
########################################

SWITCH: {
	if ( -d $file ) {
	 print <<EOF;
*******************************************************

  In order to convert your files, file and directory 
  permissions in the directory you specified:

  $file

  will need to be changed by this program to mode '777' 
  for any directories, and mode '666' for any Interleaf 
  files.  This procedure is done only to allow the 
  program to access the files.

*******************************************************

EOF
	 flush ( STDIN );
	 print "Press return if you wish to continue,";
	 print "or 'q' to quit: ";
	 $ans = <STDIN>;

	 CHECK: {
		if ( $ans eq "q\n" ){
		 exit;
		}
		if ( $ans eq "\n" ){
		 last CHECK;
		}
	  } 


	 print "Processing files in directory:\n$file\n" ;

	 # check if .. in pathname
	 if ( $file =~ /^\.\./ || $file =~ /\/\.\.\// 
		  || $file =~ /\/\.\.$/ ) {
	  print "Please use a file in the current directory\n";
	  print "or an absolute pathname.\n";
	  exit;
	 }
	 
	 # get list of files
     @list = `find $file -print` ; 

	 # get the first entry
	 @topdir = $file; 

         # need to create absolute path

		 ENTRY:
		  foreach $entry ( @list ){
			# . or .. or .....
			# ok if has '/'
			if ( $entry =~ /^\// ) {
		     next ENTRY; 
			 # substitute current dir for ./ 
			}elsif ( $entry =~ /^\.\// ){
			 $entry =~ s/^\./$curdir/;
			}else{
			 # prepend current dir
			 $entry =~ s/^(.*)\//${curdir}\/\1\//;
			}
			 
		  }

	 last SWITCH;
	}

########################################
########################################
# End of directory processing routine 
########################################
########################################

	if ( -f $file && $type =~ Interleaf ) {
#	 print "Processing file $file ..\n";
	 @list = $file;
	 last SWITCH;
	}

########################################
########################################
#	If a tar file 
########################################
########################################

	if ( $file =~ /\.tar\.Z$/ && $type =~ /compressed/ ){
	  # check type
		print "Uncompressing ..\n";

		@status = `$UNZ $file`;
		print "@status";

	   $tarfile = $file; 
	   $tarfile =~ s/\.Z$//; 

	   @tarindex=`$TARTF $tarfile`;
	   @topdir = split "/", $tarindex[0]; 


	   if ( $topdir[0] =~ /^\// ) {
		print "Tar file was created with absolute path\n";
		print "(Starts with /). Cannot process\n";
		print "Tar file must begin with directory name or ./\n";
		exit;
	   }elsif ( -d $topdir[0] ) {
		print "File $topdir[0] already exists in directory\n";
		$curdir=`pwd`;
	    print "$curdir\n";	
		print "Cannot continue\n";
		print "Re-compressing $tarfile ...\n";
		`compress $tarfile`;
		exit;
	   }
	          
	   # Create new directory to put tar file in
	   # So doesn't overwrite other files in dir

		$time=now();
		$CONVERTDIR=$tarfile;
		$CONVERTDIR =~ s/\.tar$//;
		$CONVERTDIR =~ s/$/_$time/;

		`mkdir $CONVERTDIR`;

		# move tarfile into convertdir

		`mv $tarfile $CONVERTDIR`;
		$savedir=`pwd`;
		chdir "$CONVERTDIR" ;

	   $basetarfile=`basename $tarfile`;
	   print "Untar'ing $basetarfile in directory\n";
	   print `pwd`;
	   `$TARXF $basetarfile` ; 

	   # need to create absolute path
	   $curdir = `pwd`;
	   chomp $curdir;

	   foreach $entry ( @tarindex ){
		# . or .. or .....
		if ( $entry =~ /^\.*\// ){
		 $entry =~ s/^\.*\//$curdir/;
		}else {
		 # prepend current dir
		 $entry =~ s/^(.*)\//${curdir}\/\1\//;
	    }
		 push @list, $entry;
	   }
    last SWITCH ;
   }

    if ( $file ) {
	 print "$0 cannot process this type of file\n";
	 print "$type\n";
	 exit;
	}

	$nothing = 1;
} # ENDSWITCH

########################################
########################################
# End of tar.Z processing routine	
########################################
########################################

#switch statement based on file type
# tar.Z, tar, Z, dir, file, link, other



########################################
########################################
# We should by now have a @list, whether
# working w/ a file, dir or tar.Z file
########################################
########################################
 


########################################
#	CHANGE PERMISSIONS OF FILES
#   IN ORDER TO PROCESS THEM
########################################

leftmenu ( "Changing permissions of directories to 777");
leftmenu ( "Changing permissions of Interleaf files to 666 ..\n" ) ;
leftmenu ( "NOTE: Only files with .doc extension will have permissions changed " );

open(STDERR, ">&LOG");

select ( STDERR );  $| = 1;

print "DOCUMENT CONVERSION RESULTS\n\n";
print  "Changing permissions of directories to 777\nChanging permissions of Interleaf files to 666 ..\n" ;
print  "NOTE: Only files with .doc extension will have permissions changed \n\n" ;


########################################
#	CHANGING FILE PERMISSIONS

# $topdir[0] is first entry in tar file
open ( FIND, "find $topdir[0] -print|" );

foreach $file ( <FIND> ){
  chomp $file;
  $quotfile = quotemeta $file; 

  SWITCH: {
   
   if ( -d $file ) { 
    chmod 0777, $file; 
    print "Chmod 0777 dir $file\n"; 
    #select ( STDOUT ); $| = 1;
    #print "chmod 0777 dir $file\n"; 
    last SWITCH; 
   }

   if ( -f $file && $file =~ /\.doc$/ ) { 
	 chmod 0666, $file;
	 print "Chmod 0666 file $file\n"; 
     #select ( STDOUT ); $| = 1;
	 #print "chmod 0666 file $file\n"; 
	 last SWITCH; 
   }

#   if ( $quotfile =~ /\.doc$/ ) { 
#    push @quotlist, $quotfile ; last SWITCH }

  } # END SWITCH

    $nothing = 1;
}



print_stars();

########################################;

#resave in ascii;
#/dcs/ileaf,v6.1 (everyone)


$resave="/net/softd.central/dcs/ileaf,v6.1/bin/ileaf6 -resave :format :ascii";


$convert="applix -nobackground -nokill -macro ileaf2aw_stdout -pass ";





########################################
########################################
#  Iterate through list, 
#  RESAVE and CONVERT
########################################
########################################

$files_processed = 0;
$files_successful = 0;
$files_unsuccessful = 0;

LIST:
foreach $file ( @list ) {  # list has absolute pathnames

  chomp $file;
  $quotfile="";

  next LIST if ( ! -f $file ); 
  select( STDOUT ); $| = 1;
  print_stars();
  print "Processing FILE: $file\n\n";
  select ( STDERR );  $| = 1;
  print_stars();
  print "Processing FILE: $file\n\n";

########################################
#	Check for .doc extension

 if ( $file !~ /\.doc$/ ){

  select( STDERR ); $| = 1;
  print "Skipping file:\n** $file **\n";
  print "File doesn't contain .doc extension \n\n";
  select( STDOUT ); $| = 1;
  print "Skipping file:\n** $file **\n";
  print "File doesn't contain .doc extension \n\n";
  select( STDERR ); $| = 1;
  $files_processed++;
  next LIST; 
 }



########################################
#	Check for file type "Interleaf"

  $quotfile = quotemeta $file;
 ( $file, $type ) = split(":\t", `file $quotfile`);
 if ( $type !~ /Interleaf/ ){
  select( STDERR ); $| = 1;
  print "FILE:\n $file \n is not an Interleaf file\n";
  print "Type is: $type\n\n";
  select( STDOUT ); $| = 1;
  print "FILE:\n $file \n is not an Interleaf file\n";
  print "Type is: $type\n\n";



  $files_processed++;
  next LIST;
 }

########################################
########################################
# Skip file if .aw equivalent exists	
########################################
########################################

  $awfile = $file;
  $awfile =~ s/\.doc$/\.aw/;


########################################
#	If .aw file EXISTS, SKIP

  select( STDERR ); $| = 1;

  if ( -f $awfile ){
	print "File $awfile exists, skipping\n\n"; 
	print "Please move file:\n\n";
	print "$awfile\n\n";
	print "out of the directory, if you would like to convert the file:\n\n";
	print "$file\n\n";

	select( STDOUT ); $| = 1;

	print "File $awfile exists, skipping\n\n"; 
	print "Please move file:\n\n";
	print "$awfile\n\n";
	print "out of the directory, if you would like to convert the file:\n\n";
	print "$file\n\n";


	$files_processed++;
	next LIST; 
  }


########################################
########################################
#	RESAVE FILE
########################################
########################################

  select( STDOUT ); $| = 1;
  #print "Processing File:\n$file\n";
  print "Resave ..\n";

  select( STDERR ); $| = 1;
  #print "Processing File:\n$file\n\n";
  print "Resave results for file:\n$file\n\n";

  $quotfile = quotemeta $file;
  @result =    `$resave $quotfile` ; 
  print "@result";

   select( STDOUT ); $| = 1;
  print "Convert ..\n\n";;

  select( STDERR ); $| = 1;

  $awfile = $quotfile;
  $awfile =~ s/\.doc$/\.aw/;

  print "\n\nConversion results for file:\n$file\n\n";
  $newfile=$file;
  chomp $newfile;
  $newfile =~ s/\.doc$/\.aw/; 
  #print "$file\n";

############################################################
  #$return_code = system ( "$convert $file $newfile" );

$ppid=-1;
FORK: {
	if ($pid = fork) {

		# parent here
		# child process pid is available in $pid
        #print "(Child) \$pid is $pid\n";
		#print STDOUT "Waiting for $pid to finish ..\n";
		waitpid( $pid, 0 );
		#print STDOUT "$pid finished\n";

	} elsif (defined $pid || $pid == 0) { # $pid is zero here if defined

		# child here
		# parent process pid is available with getppid
		#$ppid=getppid();
        #print "Parent ppid $ppid\n"; 
        system ( "$convert $file $newfile" );
		exit;

	} elsif ($! =~ /No more process/) {     

		# EAGAIN, supposedly recoverable fork error
		print "Hi, redoing FORK\n";
		sleep 5;
		redo FORK;

	} else {
		# weird fork error
		die "Can't fork: $!\n";
	}
}

############################################################
  if ( -e $newfile ){
	print "$newfile CREATED\n\n";
	push @files_converted, "$newfile\n";
	$files_successful++; 
  }

  $files_processed++;
  # remove interleaf tmp files
  if ( -f "$file,1" ){
   #print "Removing tmp file $file,1\n";
   unlink "$file,1";
  }
}

   print_stars();
   print "$files_successful files converted ";
   print "out of $files_processed files processed\n";

   if ( $files_successful > 0 ){
	 print "The following files were converted from Interleaf files:\n";
	   foreach $item ( @files_converted ) {
		print "$item";
	   }
   }
   print "Done\n\n";
   select ( STDOUT ); $| = 1;
   print_stars();
   print "$files_successful files converted ";
   print "out of $files_processed files processed\n";
   print "Done\n\n";
# end loop
########################################

########################################
#	close filehandles

close ( STDERR );
close ( LOG );

print_stars();
print "\n\nConversion Results are in file $LOG\n\n"; 
print_stars();
print "You may view this file with an editor, or\n";
print "enter 'c' to view the file now, 'q' to quit:\n\n";
print "(Enter a 'c' or 'q'): ";


INPUT:
while ( <STDIN> ){
  next INPUT if $_ eq "\n";
  $ans=$_; 
  chomp $ans;
  if ( $ans eq "c" ){
  
		 select( STDOUT ); 
		 flush ( STDIN );
		 flush ( STDOUT );
		 $|=1;
		 open ( LOG, "$LOG" );
		 @LOG=<LOG>;
         $ctr=0;
		 $index=0;
		 $key="c";
		 $ROWS=21;
		 LOG:
		 foreach $line ( @LOG ){ 

			if ( $ctr < $ROWS && $key == "c" ) {
			 print $line;
			 $ctr++;
			 $index++;
			}else{
			   if ( ! $line ){
				last LOG;
			   }else{
				print $line;
			   }
			 
			   print "\n( Press any key to view another screen of output:)";
			   $ctr=0; 
			

				if ($BSD_STYLE) {
				  system "stty cbreak </dev/tty >/dev/tty 2>&1";
				} else {
				  system "stty", "-icanon", "eol", "\001";
				}

				$key = getc;

				if ($BSD_STYLE) {
				  system "stty -cbreak </dev/tty >/dev/tty 2>&1";
				} else {
				  system "stty", "icanon", "eol", "^@"; # ASCII NUL
				}
				print "\n";
		     }
          }
  } 
  last INPUT;

  if ( $ans eq "q" ){
         exit;
  }
  next INPUT; 
}
print "Processing Finished\n\n";
print "Press [Return] key to exit, or close this window\n"; 
print "if running from a mail program\n\n";
getc;


 #call script to tar up directory and logfile
########################################
########################################

exit 0 if ! $USER_EMAIL;

########################################
########################################

########################################
#	Create tar file, email notice to user
#   Current dir: /export/ftp/pub

$time=now();

#$CONVERTDIR=$tarfile;
$logfname="$topdir[0]/Conversion_Results";

`cp $LOG $logfname`;



# If tar.Z, move into new dir, untar, convert, 
# tar.Z, send email, put back in /export/ftp/pub 

 print "Creating tar file of converted files ..\n";
 $return_file="${USER_EMAIL}_${time}.tar";

 if ( -f $tarfile ) {
  `mv $tarfile $tarfile.$$`;
 }
 
 # create list of .aw files

 @list=`find $topdir[0] -name \*aw -print`;
 open ( FILE, ">$return_file" ) || die "Error: $!";
 close ( FILE );
  foreach $file ( @list ) {
   `tar rf $return_file $file`; 
  }
	# add log file
   `tar rf $return_file $logfname`;
  `$Z $return_file`;

# add .Z, since now compressed
$return_file =~ s/$/.Z/ ;
# file is now $return_file.Z

 if ( -e $return_file ) {
   print "File $return_file created\n" ;  
 }

# chmod of file
chmod 0644, $return_file;

# move file to /export/ftp/pub

`mv $return_file $FTPDIR`;

########################################
#	Create email msg w/attachment

open ( TOP, "/export/dcs/ATTACHMENTS/getfiles.head" );
@msg = <TOP>;
close TOP;
push @msg, "Thank You for your request, your converted files are ready.\n\n";
push @msg, "Double-click the attached script and enter this filename:\n\n";
push @msg, "\t\t  $return_file\n\n";
push @msg, "Further directions are below, as well as a summary of the conversion\n\n"; 

push @msg, "DCS has converted the following files:\n\n";
push @msg, "$files_successful Interleaf files converted to Word Perfect files.\n\n";
push @msg, "Here is a summary of the conversion:\n";
push @msg, "Successful   conversions: $files_successful\n";
$files_unsuccessful = ( $files_processed - $files_successful);
push @msg, "Unsuccessful conversions: $files_unsuccessful\n";
push @msg, "See the details of the conversion in the ";
push @msg,  "'Conversion_Results' file, located in the top directory ";
push @msg, "of the files which you are about to retrieve.\n\n";
push @msg, "To receive your converted files, you will need to:\n\n";

#push @msg, "\t1.\tDouble click the attached script.\n\n";
#push @msg, "\t2.\tEnter the unique name of your file to retrieve when\n";
#push @msg, "\t\t  prompted by the script. Your file is:\n\n";
#push @msg, "\t\t  $return_file\n\n";


push @msg, "\t1.\t  Use your mouse to select the filename given above\n";
push @msg, "\t  \t  and then paste the filename into the window in which\n";
push @msg, "\t  \t  the script is running, when prompted by the script.\n\n";
push @msg, "\t2.\tSpecify the directory in which to unpack the file\n\n";
push @msg, "After you do this, the file will be transferred to your system,\n";
push @msg, "and unpacked into the directory you have chosen.\n";
push @msg, "The unpacked file will contain your converted files, and the\n";
push @msg, "CONVERSION_RESULTS file, containing a record of your conversion.\n";

open ( ATTACHMENT, "/export/dcs/ATTACHMENTS/getfiles.attachment" );

 push @msg, <ATTACHMENT>;
 close ATTACHMENT;

 open (MAIL, "| /usr/lib/sendmail $USER_EMAIL" );
 print MAIL @msg;
 close MAIL;

