#!/usr/bin/perl

use Mail::Sender;
use strict;

open (GM, "</tmp/gm.html") or die "Unable to open input file: $!\n";
open (GM_OUT, ">/tmp/gm_out.html") or die "Unable to open output file: $!\n";

my $getFunky = 0;
my $sendTo;
my $sendSubject;
my $junk;
my $debug = 1;

foreach (<GM>) {
  if (!$getFunky) {
    if (/^\<HTML\>/i) {
      $getFunky = 1;
      print GM_OUT $_;
    } else {
      if (/^To\:/i) {
        ($junk, $sendTo) = split (/^To\:\s*/i, $_);
	$sendTo =~ s/\s*$//;
	print "sendTo is: $sendTo.\n" if ($debug);
      } # end if
      if (/^Subject\:/i) {
        ($junk, $sendSubject) = split (/^Subject\:\s*/i, $_);
	$sendSubject =~ s/\s*$//;
	print "sendSubject is: $sendSubject.\n" if ($debug);
      } # end if
    } # end if-else
  } else {
    print GM_OUT $_; 
  } # end if-else
} # end foreach

close (GM);
close (GM_OUT);

sendThatFile();

####################################
#
####################################
sub sendThatFile {
  print "Sending the email now...\n" if ($debug);
  my $sender = new Mail::Sender
  $sendTo = 'sprint1@mouth.ip.qwest.net';
  # {smtp => 'qip.qwest.net', from => 'gmehta@qip.qwest.net'};
  {smtp => 'localhost', from => 'sprint1@mouth.ip.qwest.net'};
  $sender->MailFile({to => $sendTo,
                   subject => $sendSubject,
                   msg => "I'm sending you the HTML file you wanted.",
                   file => '/tmp/gm_out.html'
		 });
  print "\$sender is: $Mail::Sender::Error\n";
} # end sub
