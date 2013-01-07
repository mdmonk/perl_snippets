#!/usr/bin/perl -w
#
# $Id: fw1_alert.pl,v 1.11 2000/04/03 21:12:24 bln Exp bln $
# Author: Oscar Wahlberg <oscar.wahlberg@connecta.se>
#
# Log and react to user defined alerts from FW1.
#
# This is more or less a straight perl port of  
# Lance Spitzners <lance@spitzner.net> alert.sh script.
# The first release is dubbed "The blatant ripp".
#
### WARNING: Don't use $AlertAdmin or $AlertBlock they're untested and might
###		cause the script to do something really *nasty*!
#
# Exit codes:
# 10	Over $AlertLimit, exited to prevent a DoS

### Modules used
use strict;
use Net::DNS;
use Net::Whois;
use Net::SMTP;


### Configuration, FIXME: should be read from a config file!
  my $FWDIR      = '/opt/CKPfw';
  my $AlertDir   = '/home/fwadmin/alerts';
  my $AlertFile  = "$AlertDir/alert.log";
  my $AlertUniq  = "$AlertDir/alert.uniq";
  my $AdminEmail = 'fwadmin@firewall.your.dot.com';
  my $MailHost  = 'mailhost';
  my $AlertLimit = 5;

  my $AlertAdmin = 0;	# 0/1, run TrackDown() to alert system admin in Phase3
  my $AlertBlock = 0;	# 0/1, run BlockSource() to block system in Phase3
  my $BlockTimeout = 3600;


### Setup the environment
  $ENV{'PATH'} = '/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin';
  umask (0177);



################################################################################
### MAIN SCRIPT, nothing should *need* to be modified below this line.
###		 Except if you want to add/remove modules.

  # Get/Parse/Split alert from fw1.
  my $message = <STDIN>;		
  my @msg_parts = split (/[ ]+/, $message, 16);


  # store the most used info.
  my $date   = $msg_parts[0];
  my $time   = $msg_parts[1];
  my $src_ip = $msg_parts[9];
  my $dst    = $msg_parts[11];

  # Write this alert to the log
  open (AFILE, ">> $AlertFile");
  print AFILE "$message\n";
  close (AFILE);

  # Get the number of scans from this $src_ip.
  open (AFILE, "< $AlertFile");
  my $scans = grep (/$src_ip/, <AFILE>);
  close (AFILE);

  # If over $AlertLimit we exit quietly to prevent a DoS.
  exit (10) if ($scans >= $AlertLimit); 
  
  
  # Check if the logstring contains ICMP or NAT information.
  my $nat_check  = 1 if ( $message =~ /\(Valid Address\)/ );
  my $icmp_check = 1 if ( $message =~ / icmp / );
  
  # Get the scanned service
  my $service;
  # ouch, dirty hack if statements ... ;) FIXME: Convert to conditionals.
  if ( ! defined ($nat_check) ) {
    if ( ! defined ($icmp_check) ) {
      $service = $msg_parts[13];
    }
    else { 
      $service = "$msg_parts[14] $msg_parts[15] $msg_parts[16] $msg_parts[17]";
    }
  } 
  else {
    if ( ! defined ($icmp_check) ) {
      $service = $msg_parts[15];
    }
    else { 
      $service = "$msg_parts[16] $msg_parts[17] $msg_parts[18] $msg_parts[19]";
    }
  } 


  # Try to resolv an ipaddress.
  my $src = Resolve($src_ip);

  # Create the email alert.
  my @email_msg = BuildMail();


### PHASES START: 
### What to do in addition to email alerts, depending on
### the number of scans.

# ##### PHASE 1 #####
# First unauthorized connection from the remote system.
  if ( $scans == 1 ) {
    open (UFILE, ">> $AlertUniq");
    print UFILE "$src      $date   $time   $service\n";
    close (UFILE);
  }

# ##### PHASE 2 #####
# Second to $Alertlimit connections from the remote system

  elsif ( $scans > 1 && $scans < $AlertLimit ) {
   ### Customize as you wish 

  }

# ##### PHASE 3 #####
# We are pretty sure this is a port scan or probe, since the
# same source has connected to us atleast $Alertlimit number of times.

  else {

#    TrackDown() if ( $AlertAdmin );

#    BlockSource() if ( $AlertBlock );

    push (@email_msg, "\nThis is alert number $scans, you have reached your".
	"maximum threshold. You will not receive anymore alerts\n");

  }


### Send email alert to fw admin
### FIXME: No error checks what so ever.

  my $smtp = Net::SMTP->new($MailHost);

  $smtp->mail($AdminEmail);
  $smtp->recipient($AdminEmail);

  $smtp->data();
  $smtp->datasend("From: $AdminEmail\n");
  $smtp->datasend("To: $AdminEmail\n");
  $smtp->datasend("Subject: ### SCAN ALERT ###\n");
  $smtp->datasend("\n");
  $smtp->datasend(@email_msg);
  $smtp->dataend();

  $smtp->quit;

exit (0);



################################################################################
### Subroutines. 
################################################################################

sub Resolve {
  my $src = $_[0];

  my ($res, $query, $rr);
  $res   = new Net::DNS::Resolver;
  $query = $res->search($src);
  if ($query) {
    foreach $rr ($query->answer) {
      return $rr->address  if ( $rr->type eq "A" );
      return $rr->ptrdname if ( $rr->type eq "PTR" );
    }
  }
  # not found, go with original $src.
  return $src;
}

sub BuildMail {
  # Build mail to FW Admin containing the alert information.

  my $email_msg = "

You have received this message because someone is potentially 
scanning your systems.  The information below is the packet 
that was denied and logged by the Firewall. This is email alert
number $scans, with a limit of $AlertLimit from $src. 

        ----- CRITICAL INFORMATION -----

        Date:        $date
        Time:        $time
        Source:      $src
        Destination: $dst
        Service:     $service

        ----- ACTUAL FW-1 LOG ENTRY -----

$message
";

  return $email_msg;
}

sub TrackDown {
### FIXME: DO NOT USE THIS FUNCTION, 
###        IT HASN'T BEEN TESTED AT ALL IN THE PERL PORT!

### This function determines who the admin is of the remote system
### and emails them about the scan.  Works only for .com, .edu, .net
### .mil, and .org.

  my $dom = $_[0]; 

  my $w = Net::Whois::Domain->new($dom);

  return unless ($w->ok);	# If no match, silently return.

  my ($c, $t, @email, $line);
  if ($c = $w->contacts) {	# whois doesn't always have contacs...
    foreach $t (sort keys %$c) {
      if ($t =~ /ADMINISTRATIVE|TECH/i ) { #admin or tech contact
        foreach $line (@{$c->{$t}}) {
          $line =~ s/\s+/ /g;
	  ### FIXME: Warning the regexp below is fragile and might fail...
          push (@email, $1) if ( $line =~ /^.*\s(.*?\@.*)$/ );
        }
      }
    }

  my $email = join ("\n", @email);
  my $msg=" Subject: Your system $src may be scanning the Internet.

I logged your system $src scanning my network.
It looks like they are scanning for the $service vulnerability.
I recommend you research this, as $src
may be scanning other networks as well.  Please respond to this
message informing me what you have found.  If you require
assistance from me, I would be more then happy to provide it.  
Below is an example one of the multiple connections I received
from $src.

--- Logged Information ---

Source:   $src
Date:     $date
Time:     $time
Service:  $service

--- snip snip ---

This notification has been sent to 
$email 
abuse\@$w->domain

Please respond to $AdminEmail for any issues concerning this.  
If you received this message in error, I apologize.

Thank you
";

print $msg;
  }

}


sub BlockSource {
### FIXME: DO NOT USE THIS FUNCTION, 
###        IT HASN'T BEEN TESTED AT ALL IN THE PERL PORT!

## This function blocks the source IP scanning/probing our 
## network.  Edit 'fw sam' command to your taste.  For more
## info, typte 'fw sam'.

  system ("$FWDIR/bin/fw sam -t $BlockTimeout -i src $src");

  push (@email_msg,"
        WARNING
        Intruder $src has been temporarily blocked at the Firewall
        $src will be blocked for the next $BlockTimeout seconds
        To enable $src, type the following command on the Firewall
        $FWDIR/bin/fw sam -t $BlockTimeout -C -i src $src\n");

}
