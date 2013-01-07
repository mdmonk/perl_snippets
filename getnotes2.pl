# This program extracts email messages from a
# Lotus Notes account. 
#
# Email messages will be saved in directories
# named for the mail folder they're stored in.  
# All of these directories will be stored
# under a new top-level directory named
# "C:\temp\mail" by default, but this can be
# overridden with the -d flag.
#
# For each email message, a subdirectory will 
# be created, containing the text and attachments 
# for that message. These subdirectories are 
# currently named by sequential numbers instead of 
# by their subject titles. That's on my TODO list
# to fix; it shouldn't be too hard.
#
# Some folders in the Notes mail database are not
# really mail folders, so I try to skip them.
# Currently I skip all folders whose names are in
# parentheses (except for Inbox), and the folders 
# in the array @badlist. You can customize @badlist
# as necessary.
# 
# By default, Lotus Notes will open the email
# database for the PC's default user. To access
# the email for a different user: open Notes
# and switch to another userid first; then run
# this program while Notes is still open.

use strict;
use English;
use warnings;
use vars qw($opt_d $opt_v);
use Getopt::Std;
use Win32::OLE;

# Command-line options:
# -d dirname    Save everything under the directory "dirname"
# -v            Verbose reporting of progress 
getopt("d");

# Define a directory to store the results
my $dir = $opt_d || 'C:/temp/mail';
mkdir ($dir, 0755) or die "Can't make $dir: $!";

# Define a list of "Normal" folders to skip
my @badlist = ('_Archiving', 'Archiving\\Age of Documents', 
               'Discussion Threads', 'Events');
                
# Auto-print carriage returns
$OUTPUT_RECORD_SEPARATOR = "\n";

# Open the email database in Lotus Notes
# (To use another person's email database, switch to
#  their userid in Notes before running this program)
my $notes = Win32::OLE->new('Notes.NotesSession')
             or die "Can't open Lotus Notes";
my $database = $notes->GetDatabase("","");
$database->OpenMail;

# Verify the server connection
print "Connected to ", $database->{Title}, 
      " on ", $database->{Server} if $opt_v;

# Loop over all of the folders
foreach my $viewname (GetViews($database)) {

  # Get the object for this View
  print "Checking folder $viewname...";
  my $view = $database->GetView($viewname);

  # Create a subdirectory to store the messages in
  $viewname =~ tr/()$//d;
  $viewname =~ s(\\)(.)g;
  my $path = "$dir/$viewname";
  mkdir ($path, 0755) 
      or die "Can't make directory $path: $!";
  chdir ($path);

  # Get the first document in the folder
  my $num = 1;
  my $doc = $view->GetFirstDocument;
  next unless $doc;
  GetInfo($num, $path, $doc);

  # Get the remaining documents in the folder
  while ($doc = $view->GetNextDocument($doc)) {
    $num++;
    GetInfo($num, $path, $doc);
  }
}

sub GetInfo {
  my ($num, $path, $doc) = @_;

  print "Processing message $num" if $opt_v;

  # Create a new subdirectory based on the message number
  my $subdir = sprintf("%02d",$num);
  mkdir ($subdir, 0755)
     or die "Can't make $subdir subdirectory: $!";

  # Write the contents of the message to a file
  open (TEXTFILE, ">$subdir/message.txt")
     or die "Can't create $subdir message file: $!";
  print TEXTFILE "From: ", $doc->{From}->[0];
  print TEXTFILE "Subject: ", $doc->{Subject}->[0];
  print TEXTFILE $doc->{Body};
  close TEXTFILE;

  # Save attachments as files, if any
  my $array_ref = $doc->{'$FILE'};
  foreach my $attachment (@$array_ref) {
    if ($attachment) {
      ExtractAttachment($doc, "$path/$subdir", $attachment);     
    }
  }
}

sub ExtractAttachment {
  my ($doc, $path, $filename) = @_;

  print "Extracting attachment $filename" if $opt_v;

  # Get a Windows-friendly pathname for the file
  $path = "$path/$filename";
  $path =~ tr/\//\\/;

  # Save the attachment to a file
  my $attachment = $doc->GetAttachment($filename);
  $attachment->ExtractFile($path);
}  

sub GetViews {
  my ($database) = @_;
  my @views = ();

  # Loop through all of the views in this database
  my $array_ref = $database->{Views};
  foreach my $view (@$array_ref) {
    my $name = $view->{Name};
    
    # We only want folders if it's the Inbox
    # or a normal folder name with no parentheses
    if (($name eq '($Inbox)') or ($name !~ /\(.+\)/)) {

      # Add the folder name to the @views list
      # if it's not in the @badlist
      push(@views, $name) unless (grep { $name eq $_ } @badlist);
    }
  }

  return @views;
}
