#!/usr/local/bin/perl
#############################################################################################
#Upload.pl
#
#DISCLAIMER: I AM IN NO WAY RESPONSIBLE FOR ANY DAMAGE THIS SCRIPT MAY CAUSE
#############################################################################################

#############################################################################################
#Configuration Section
#
#$meurl
#	URL for this script
#
#$basedir
#	You can upload to this directory and subdirectories of it.
#
#$windows
#	If you run a Windows server set this to 'yes'.  If not set to 'yes,' when the upload
#	is completed the script will chmod the uploaded file to 777.  Windows servers do not
#	require this.
#
#@valid
#	These are the urls that are allowed to access the script.  For example, I have set it
#	up so that only pages set up on my sites can access them.  As long as the page is on my 
#	site, even if it's http://www.zonecoaster.com/Scripts/upload/index.html, it has the root
#	http://www.zonecoaster.com/ in it so it can use the script.  
#
#	If you try to set up an upload form on your site(http://www.yoursite.here/~you/)to upload 
#	to *my* site, it won't allow it because your site doesn't contain either of the root 
#	addresses in @valid.  This prevents people from uploading to directories you don't want
#	them to upload to unless you let them edit that part of the from.  Because of this, I
#	suggest that if you're allowing others to upload to your site and don't want them uploading
#	to any directory they want, you put the directory in a hidden field as it is in the sample
#	upload form.
#
#	**Set @valid to contain the URL representing $basedir and you should be fine.
#
#	As it's set up below, only upload forms located on my websites can access the script.
#
#$dircommand
#	The command for "list files in this directory."  For unix systems, the best choice
#	is "ls -l" and for windows you'll probably want to go with "dir" unless you have
#	downloaded a windows port of "ls."
#############################################################################################

$meurl="http://www.zonecoaster.com/cgi-bin/upload.pl";
$basedir='/usr/local/www/bernard/html/guest/';
$windows = 'no';	#'yes' or 'no'
@valid = ('http://www.zonecoaster.com/');
$dircommand = 'ls -l';

#############################################################################################
#If method=get
#############################################################################################

if($ENV{'REQUEST_METHOD'} =~ /get/i)
{
	if($ENV{'QUERY_STRING'} ne "")
	{
		&get_form_data;
		$current = $formdata{'directory'};
	}
	else
	{
		$current = $basedir;
		$inbase = "yes";
	}

	print "Content-type: text/html\n\n";
	print "<html>\n";
	print "<title>Upload a File</title>\n";
	print "<body bgcolor=\"\#ffffff\" text=\"\#000000\">\n";
	print "<center><h2>Change Directory</h2></center>\n";
	print "<center><table border=1>\n";
	print "<tr><td><center><b>Current Directory</b></center></td></tr>\n";
	print "<tr><td>$current</td></tr></table></center>\n";
	if($inbase eq "yes")
	{
		opendir(DIR,"$basedir") || &unable("$basedir");
	}
	else
	{
		opendir(DIR,"$formdata{'directory'}") || &unable("$formdata{'directory'}");
	}
	@dirs=grep(/\w/,readdir(DIR));
	close(DIR);

	foreach $item (@dirs)
	{
		if($item =~ /\w/)
		{
			if(-d "$basedir$item")
			{
				push(@direct,"$basedir$item\/",$item);
			}
		}
	}
	%direct=@direct;
	$number=@direct;
	if($number ne "0")
	{
		print "<br><br>You can change directories by selecting a directory from the \n";
		print "drop-down list below.  Also on this page is a listing of files in the \n";
		print "current directory.  You can upload to the current directory using the \n";
		print "form at the bottom of this page.\n";
		print "<form method=get action=\"$meurl\">\n";
		print "<center>Change directory: \n";
		print "<select name=\"directory\">\n";
		foreach $key (sort keys(%direct))
		{
			print "<option value=\"$key\">$direct{$key}\n";
		}
		print "</select>\n";
		print "<input type=submit value=\"Change Directory\"></center>\n";
	}
	else
	{
		print "<br><br>Below you will find a list of files in the \n";
		print "current directory.  If you wish to upload a file to this directory, just \n";
		print "fill out the form at the bottom of the page and press the button.<br>\n";
		print "<br><center><b>This directory has no subdirectories.</b></center>\n";
	}
	print "</form>\n";

	print "<hr>\n";
	print "<center>\n";
	print "<table border=1>\n";
	print "<tr><td><center><b>Directory Listing</b></center></td></tr>\n";
	print "<tr><td>\n";
	$dirlisting = `$dircommand $current`;
	print "<pre>$dirlisting</pre>\n";
	print "</td></tr></table>\n";
	print "</center>\n";
	print "<hr>\n";

	print "<center><h2>Upload to the current directory</h2></center>\n";
	print "<form ENCTYPE=\"multipart/form-data\" method=post action=\"$meurl\">\n";
	print "<center>Select a File: <input type=file name=\"uploaded_file\">\n";
	print "<input type=hidden name=\"directory\" value=\"$current\">\n";
	print "<input type=submit value=\"Upload This File\">\n";
	print "</form></center>\n";
	print "<br><br><center>This script can be obtained from <a href=\"http://www.zonecoaster.com/\">";
	print "The Zone Coaster</a>\n";
	print "</html>\n";
	exit 0;
}

#############################################################################################
#Check if the URL(HTTP REFERER) is valid
#############################################################################################

foreach $referer (@valid)
{
	if($ENV{'HTTP_REFERER'} =~ /$referer/)
	{
		$good_ref="yes";
	}
}
if($good_ref ne "yes")
{
	print "Content-type: text/html\n\n";
	print "<title>Please go away</title>";
	print "<body bgcolor=\"\#ffffff\" text=\"\#000000\">";
	print "You tried to access this script either through the location window or ";
	print "using an unauthorized form.  Neither of these activities is permitted.";
	print "</html>\n";
	exit 0;
}

#############################################################################################
#Do the upload stuff.
#############################################################################################

$| = 1;

read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
$buffer =~ /^(.+)\r\n/;
$bound = $1;
@parts = split(/$bound/,$buffer);

$filename=$parts[1];
$parts[1] =~ s/\r\nContent\-Disposition.+\r\n//g;
$parts[1] =~ s/Content\-Type.+\r\n//g;
$parts[1] =~ s/^\r\n//;

@subparts = split(/\r\n/,$parts[2]);
$directory = $subparts[3];
$directory =~ s/\r//g;
$directory =~ s/\n//g;	#got the directory name

$filename =~ s/Content-Disposition\: form-data\; name=\"uploaded_file\"\; filename\=//g;
@stuff=split(/\r/,$filename);
$filename = $stuff[1];
$filename =~ s/\"//g;
$filename =~ s/\r//g;
$filename =~ s/\n//g;

@a=split(/\\/,$filename);
$totalT = @a;
--$totalT;
$fname=$a[$totalT];

@a=split(/\//,$fname);		#then ignore stuff before last forwardslash for Unix machines
$totalT = @a;
--$totalT;
$fname=$a[$totalT];

@a=split(/\:/,$fname);		#then ignore stuff before last ":" for Macs?
$totalT = @a;
--$totalT;
$fname=$a[$totalT];

@a=split(/\"/,$fname);		#now we've got the real filename
$filename=$a[0];

if($parts[1] !~ /[\w\d]/)
{
	print "Content-Type: text/html\n\n";
	print "<html>\n<title>Error!</title>\n";
	print "<body bgcolor=\"\#ffffff\" text=\"\#000000\">\n";
	print "You did not provide a file to be uploaded or it is empty.\n";
	print "</html>\n";
	exit 0;
}

open(REAL,">$directory$filename") || &error($!);
binmode REAL;
print REAL $parts[1];
close(REAL);

if($windows ne 'yes')		#chmod it for unix systems
{
	`chmod 777 $directory$filename`;
}

#############################################################################################
#Let the user know that the upload's complete and give him the relevant information
#############################################################################################

if(-e "$directory$filename")
{
	print "Content-Type: text/html\n\n";
	print "<html>\n<title>Upload Successful</title>\n";
	print "<body bgcolor=\"\#ffffff\" text=\"\#000000\">\n";
	print "The upload was successful.  Here is the data concerning the file\:\n";
	print "<ul>\n";
	print "<li><b>New Filename</b>: $directory$filename\n";
	print "<li><b>Size</b>: $ENV{'CONTENT_LENGTH'} bytes\n";
	print "</ul><br>";
	print "</html>\n";
	exit 0;
}
else
{
	print "Content-Type: text/html\n\n";
	print "<html>\n<title>Upload Unsuccessful</title>\n";
	print "<body bgcolor=\"\#ffffff\" text=\"\#000000\">\n";
	print "The upload was unsuccessful\.\.\.unable to create $directory.\n";
	print "<br><b>Error Message</b>\n";
	print "<pre>$!</pre>\n";
	print "</html>\n";
	exit 0;
}

#############################################################################################
#Subroutines
#############################################################################################

sub error{

	print "Content-Type: text/html\n\n";
	print "<html>\n<title>Error!</title>\n";
	print "<body bgcolor=\"\#ffffff\" text=\"\#000000\">\n";
	print "Could not create <b>$directory</b>\n";
	print "<br><b>Error message:</b>$_[0]\n";
	print "</html>\n";
	exit 0;
}

sub get_form_data{

	@pairs=split(/\&/,$ENV{'QUERY_STRING'});
	foreach $pair (@pairs)
	{
		($name,$value) = split(/\=/,$pair);
		$name =~ s/\+/ /g;
		$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
		$value =~ s/~!/ ~!/g;
		$value =~ s/\+/ /g;
		$value =~ s/\n//g;
		$value =~ s/\r/\[ENTER\]/g;
		push (@formdata,$name);
		push (@formdata,$value);
	}
	%formdata=@formdata;
	return %formdata;
}

sub unable{
	print "Content-type: text/html\n\n";
	print "<html>\n";
	print "<title>Error</title>\n";
	print "<body bgcolor=\"\#ffffff\" text=\"\#000000\">\n";
	print "Unable to open: $_[0]\n";
	print "</html>\n";
	exit 0;
}

