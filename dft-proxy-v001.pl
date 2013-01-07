#!/usr/bin/perl
#############################################################################
# Program Name: dft-proxy.pl
# Input       : That's Top Secrety
# Output      : This is too.
# Dependencies: All sorts of IO stuff and POSIX stuff
# Description : Script to act as a "go-between" between the user(s) and SFQ.
# Usage       : Please see your nearest Fortune Teller
# Contact     : dev.null@127.0.0.1
# Notes       : I prefer POP3 or IMAP rather than Notes.
# Keywords    : DFT, SFQ
#############################################################################
# More Notes  : This code was originally written by Ben Reed (gotta give
#               him props for it). With much of the socket comm code coming
#               from Merlyn (Thanks Randal!). I, your humble coder, will
#               be attempting to finish the script and make it into the
#               Automation Team SFQ Proxy.
#############################################################################
# Copyright (C) 1999-2000, DFT
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#############################################################################

=head1 NAME

dft-proxy.pl - Mini daemon (of sorts) acting as a proxy between Automation and SFQ.

=head1 SYNOPSIS

There isn't really a synopsis....
at least none that I can think of right now.

=head1 DESCRIPTION

Blah blah blah.
No really, this is a pretty cool script. Some wild socket programming, and using globs for namespace mangling.

=cut

use IO::Socket;
use IO::Select;
use sigtrap qw(die INT QUIT HUP);
use File::Basename;
use POSIX;
use SF::SFQ;

use vars qw(
  $command
  $VERSION
  $fileName
  $notImplemented
  @queue
  $lastRun
);

$VERSION        = "0.0.1";
$fileName       = basename($0);
$notImplemented = "This function is not yet implemented.";
%config = ();
$confDir        = "d:/tmp/dft-proxy";
$confFile       = "dft-proxy.cnf";

loadCfg(\%config, $confDir, $confFile);

if($config{debug}) {
  while (($k, $v) = each %config) {
     print "$k => $v\n";
  } # end while
} # end if

my $proto = 'tcp';

# create a new listening port
my $master = IO::Socket::INET->new(
        Listen     => $config{listen},
        Reuse      => 1,
        LocalHost  => $config{listenAddress},
        LocalPort  => $config{port},
        Proto      => $config{proto},
        Timeout    => $config{timeout},
        MultiHomed => 1,
) or die "Cannot open socket.  $!\n";

warn "Master is on ", sockHostPort($master), "\n" if $config{verbose};

my $listen = IO::Select->new($master);

# Get funky and start the main loop
# <sarcasm>
# Patent pending on this really 31337 daemon code.
# </sarcasm>
while (1) {

  # run SFQ commands in the queue that are over $waitTime old
  if (($lastRun + $config{waitTime}) > time) {
    my $entry = shift @queue;
    print "- Running $entry->{attributes}->{customercall}'s entry in the queue.\n";
  } # end if

  my @ready = $listen->can_read($config{timeout});
  redo unless @ready;           # no socket is ready

  for my $ready (@ready) {      # loop through each ready socket

    if ($master eq $ready) {    # new connection

      my $slave = $master->accept;
      warn "Connection from ", peerHostPort($slave) if $config{verbose};
      ${*$slave}{__Buf} = "";

      ${*$slave}{__SessionID} = generateSID($config{sessionLength}, $ready->sockhost, $ready->sockport);
      $slave->sockopt( POSIX::FIONBIO , 1 );

      $listen->add($slave);

      $slave->print("DFT-proxy v$VERSION.  Type 'HELP' for more information.\015\012");
      $slave->print("> ");

    } else {

      if ((my $count = $ready->sysread(my $buf, 8192)) > 0) {

        if (not defined $ {*$ready}{__Term}) {
          ${*$ready}{__Term} = "dos" if (${*$ready}{__Buf} =~ /\r\n/);
          ${*$ready}{__Term} = "unix" if (${*$ready}{__Buf} =~ /\r{0}\n/);
        }
        ${*$ready}{__Buf} .= $buf;
        ${*$ready}{__Buf} =~ s/\r?\n/\n/g;

        if ((${*$ready}{__Buf}) =~ s/^(.*)?\n//s) {
          my $input        =  $1;
             $input        =~ s/^\s*(\w+)\s*//;
          my $inputCommand =  uc($1);

          warn "Message from ", peerHostPort($ready), ": (", ${*$ready}{__SessionID} , ") ", $1, "\n" if $config{verbose};

          if (defined $command->{$inputCommand}) {
            
            printMessage($ready, ${*$ready}{__SessionID}, "Input is ($input).\n") if ($config{debug});
            
	    &{$command->{$inputCommand}}($listen, $ready, ${*$ready}{__SessionID}, $input);
          } else {
            printMessage($ready, ${*$ready}{__SessionID}, "$inputCommand ($input): Unknown command.\n");
          } # end if-else

          $ready->print("> ");

        } # end if
      } else {

        warn "Shutting down $ready\n" if $config{verbose};
        $listen->remove($ready);
        $ready->close;

      } # end if-else
    } # end if-else
  } # end for
} # end while

#####################################################

sub sockHostPort {
  my $io_socket_inet = shift;
  sprintf "%s:%d", $io_socket_inet->sockhost, $io_socket_inet->sockport;
} # end sub

#####################################################

sub peerHostPort {
  my $io_socket_inet = shift;
  sprintf "%s:%d", $io_socket_inet->peerhost, $io_socket_inet->peerport;
} # end sub 

#####################################################

sub loadCfg ($$$) {
  my $href     = shift;
  my $confDir  = shift;
  my $confFile = shift;
  print ("in the loadCfg sub.\n") if ($config{debug});
  open (INPUT, "$confDir/$confFile") or die "Cannot open $confDir/$confFile.  Aborting.  $!\n";

  while (<INPUT>) {
    chomp;
    next if (/^\s*\#/);
    next if (/^\s*$/);

    /^\s*(.*?)\s*\=\s*(.*)\s*$/;

    $href->{$1} = $2;
  
  } # end while
  
  close (INPUT);

} # end sub

#####################################################

sub generateSID {
  
  my ($length, $peer, $port) = @_;
  print ("in the generateSID sub.\n") if ($config{debug});
  print "\$peer is $peer\n" if ($config{debug});
  print "\$port is $port\n" if ($config{debug});

  if (not defined $Seeded) {
    srand(time ^ $peer ^ $port);
    $Seeded = 1;
  } # end if

  my $random_chars = "ABCDEFGHIJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  # $length = 20 if ($length < 20);
  $length = 8 if ($length != 8);  # added date to beginning to help signify when ticket was
                                  # opened. so date, with random chars equal 20 chars total.
  my $returnKey;
  
  $returnKey = getTime();
  
  for (my $i = 0;  $i < $length;  ++$i) {
    $returnKey .= substr($random_chars, int(rand(length($random_chars))), 1);
  } # end for
  
  $returnKey;

} # end sub

#####################################################

sub getTime {

   my $dftTime;

   ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

   $mon++;
   $mon  = "0" . $mon  if ($mon  < 10);
   $mday = "0" . $mday if ($mday < 10);
   $sec  = "0" . $sec  if ($sec  < 10);
   $min  = "0" . $min  if ($min  < 10);
   $year+=1900;

   $dftTime = $year . $mon . $mday . $hour . $min;

   print "dftTime is: $dftTime\n" if ($config{debug});
   
   return ($dftTime);

} # end sub

#####################################################

BEGIN {

  # Signal handlers.  duh.

  $SIG{__WARN__} = sub {
    if ($config{verbose}) {
      warn map "[".localtime()."] [$$] (" . __FILE__ . ") $_\n", (join "", @_) =~ /(.+)\n*/g;
    } else {
      warn map "[".localtime()."] $_\n", (join "", @_) =~ /(.+)\n*/g;
    }

  };

  $SIG{__DIE__} = sub {
    if ($config{verbose}) {
      die map "[".localtime()."] [$$] (" . __FILE__ . ") $_\n", (join "", @_) =~ /(.+)\n*/g;
    } else {
      die map "[".localtime()."] $_\n", (join "", @_) =~ /(.+)\n*/g;
    }
  };
  
#  $SIG{__HUP__} = sub {
#   if ($config{verbose}) {
#    die map "[".localtime()."] [$$] (" . __FILE__ . ") $_\n", (join "", @_) =~ /(.+)\n*/g;
#    } else {
#      die map "[".localtime()."] $_\n", (join "", @_) =~ /(.+)\n*/g;
#    }
#    &{$command->{RELOADCFG}}($listen, $peer, $sessionID, @args);
#  };

  # print a message to the peer with localtime attached
  sub printMessage (@) {
    my $peer      = shift;
    my $sessionID = shift;
    my $message   = join("", @_);

    for my $line (split(/\r?\n/, $message)) {
        #my $cr = $peer->input_record_separator;
        my $cr = "\015\012";  # set like this for unix and win32 compatibility.
        $peer->print("[".localtime()."] ", $line, $cr);
    }
  }

  # command tokens for input
  $command = {

    'SET' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      my $args      =  join(" ", @args);
      if ($args      =~ /^\s*(.*?)\s*\=\s*(.*?)\s*$/) {
        my ($key, $value) = ($1, $2);
        ${*$peer}{__attributes}{$key} = $value;
        printMessage($peer, $sessionID, $key, " set.\n");
      } else {
        printMessage($peer, $sessionID, "No value set.  Current values in session are:\n");
        for my $key (sort keys %{${*$peer}{__attributes}}) {
          printMessage($peer, $sessionID, "  ", $key, " = \"", ${*$peer}{__attributes}{$key}, "\"\n");
        }
      }

    },

    'NEWSID' => sub($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;
     
      ${*$peer}{__SessionID} = generateSID($config{sessionLength}, $config{listenAddress}, $config{port});
      printMessage($peer, $sessionID, "Your new session ID is \"" . ${*$peer}{__SessionID} . "\".\n");
      printMessage($peer, $sessionID, "Clearing session variables for new sid.\n");
      &{$command->{CLEAR}}($listen, $peer, $sessionID, @args);

    },

    'CREATE' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      printMessage($peer, $sessionID, $main::notImplemented, "\n");

    },

    'DELETE' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      printMessage($peer, $sessionID, $main::notImplemented, "\n");

    },

    'HELLO' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      printMessage($peer, $sessionID, "$fileName v$VERSION Ready.\n");
      printMessage($peer, $sessionID, "Your session ID is \"" . ${*$peer}{__SessionID} . "\".\n");
    },

    'HELO' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = shift;

      &{$command->{HELLO}}($listen, $peer, $sessionID, @args);
    },

    'HELP' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      my $type = uc(shift @args);

      if ($type eq "HELP") {
        printMessage($peer, $sessionID, "You're swimmin' in it!\n");
      } elsif ($type eq "HELLO") {
        printMessage($peer, $sessionID, "Tells you your session ID and the server version number.\n");
      } elsif ($type eq "SET") {
        printMessage($peer, $sessionID, <<END);
Usage: SET <key>=<value>
------------------------
Required attributes for opening an SFQ ticket:
  - command=<command>
    currently, only "create" is available (TODO: "update")
  - customercall=<value>
  - priority=<value>
  - categorycall=<value>
  - callstatus=<value>
  - wgcall=<value>
  - problem=<value>

Required for getting the status of an SFQ ticket:
  - sfqnum=<sfq ticket number>
  - rule="RS_CallStatus" or "CallStatus"
  
For more specific information and a list of attributes,
see the perl SF::SFQ and/or SF::SFQ2 module documentation.
END
      } elsif ($type eq "QUIT") {
        printMessage($peer, $sessionID, "Duh.\n");
      } else {
        printMessage($peer, $sessionID, <<END);
$fileName v$VERSION
----------------------------------------
valid commands:
  HELLO    Check server status.
  HELP     This message.
  SET      Set an attribute.  Type 'HELP SET'
           for more info.
  STATUS   Coming Soon! Available in dft-proxy.pl v1.0.
  CLEAR    Clears the session variables.
  NEWSID   Gets a new Session ID (SID)
  COMMIT   Commit attributes to the queue.
  QUIT     Close connection.
END
      }
    },

    'QUIT' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      printMessage($peer, $sessionID, "Disconnecting.\n");

      warn "Shutting down $peer\n" if $config{verbose};
      $listen->remove($peer);
      $peer->close;

    },

    'STATUS' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      printMessage($peer, $sessionID, $main::notImplemented, "\n");

    },

    'CLEAR' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      for my $key (sort keys %{${*$peer}{__attributes}}) {
        delete(${*$peer}{__attributes}{$key});
      }
    },

    'COMMIT' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;
      
      if ($config{debug}) {
        
	printMessage($peer, $sessionID, "#################\n");
        printMessage($peer, $sessionID, "Session vars are:\n");
        
	for my $key (sort keys %{${*$peer}{__attributes}}) {
          printMessage($peer, $sessionID, "  ", $key, " = \"", ${*$peer}{__attributes}{$key}, "\"\n");
        } # end for
        
	printMessage($peer, $sessionID, "#################\n");
      
      } # end if
      if (${*$peer}{__attributes}{sfqnum}) {
        &{$command->{SFQSTATUS}}($listen, $peer, $sessionID, @args);
      } # end if

    },

    'SFQSTATUS' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      my $sfq = SF::SFQ::initiateSFQ(rule=>'RS_CallStatus', sfqnum=>"${*$peer}{__attributes}{sfqnum}");
      while( ($key, $value) = each %{$sfq}) {
        printMessage($peer, $sessionID, "$key => $value\n");
      } # end while
    
    },

    'RULESTATUS' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      printMessage($peer, $sessionID, $main::notImplemented, "\n");

    },
    
    'DOC' => sub ($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;

      printMessage($peer, $sessionID, `perldoc $0`, "\n");

    },
    
    'RELOADCFG' => sub($$$@) {
      my $listen    = shift;
      my $peer      = shift;
      my $sessionID = shift;
      my @args      = @_;
     
      printMessage($peer, $sessionID, "Reloading master configuration file.\n");
      ${*$peer}{__SessionID} = loadCfg(\%config, $confDir, $confFile);
      printMessage($peer, $sessionID, "Clearing session variables for new sid.\n");
      if ($config{debug}) {
         while (($k, $v) = each %config) {
            print "$k => $v\n";
         } # end while
      } # end if

    },

  } # end $command

} # end BEGIN

# Below is the stub of documentation for your module. You better edit it!
# Note from author: I did edit it!

=head1 AUTHOR

MdMonk, DFT; RangeRick, DFT; Merlyn, Stonehenge Consulting.

I<Name That Movie>
"Good...Bad...I'm the guy with the gun."

=head1 SEE ALSO

perl(1), SF::SFQ(1), SF::SFQ2(1)

=cut

#####################################################
################## END OF SCRIPT#####################
#####################################################
