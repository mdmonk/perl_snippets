#!/usr/bin/perl

# server/daemon for netshow [mp3]
# by samy [CommPort5@LucidX.com]

$port = 1337;
$dev = "/dev/dsp";
$mp3dir = "/mp3";
$kilobytes = 64;
$mp3first = 1;

sub hashes {
 %set = (
	create    => 'yes',
	exclusive => 'no',
	mode      => 0644,
	destroy   => 'yes',
 );
 %read = (
	create    => 'no',
	exclusive => 'no',
	mode      => 0644,
	destroy   => 'no',
 );
 return (\%set, \%read);
}
($setx, $readx) = hashes();
%set = %$setx;
%read = %$readx;
tie my $kb, 'IPC::Shareable', 'kilobytes', { %set };
$kb = $kilobytes * 1024;
use IPC::Shareable;
print "Running server on port $port at $kilobytes kb per packet\n";
fork() && front($mp3first, $kb);
fork() && ipc($kilobytes);
sock($port, $mp3dir, $mp3first);

sub front {
 $SIG{INT} = sub { close(DEV); die "exiting...\n"; };
 ($setx, $readx) = hashes();
 %set = %$setx;
 %read = %$readx;
 tie my $kb, 'IPC::Shareable', 'kilobytes', { %set };
 tie my $playmp, 'IPC::Shareable', 'micormp', { %set };
 $playmp = $_[0];
 $kb = $_[1];
 tie my $mp3, 'IPC::Shareable', 'mpeg', { %read };
 while (1) {
  chomp($tmpp = <STDIN>);
  s/^\s*//;
  if ($tmpp =~ /^help/) {
   print << "EOC";

commands:

status - status of stream
mic - switch to microphone
mp3 - switch to mp3s
exit - close daemon
kb [#] - view/change kbps
help - this help

EOC
  }
  elsif ($tmpp =~ /^status/) {
   if ($playmp % 2 == 1) {
    print "status: MP3 playing ($mp3)\n";
   }
   else {
    print "status: microphone in use\n";
   }
  }
  elsif ($tmpp =~ /^kb\s*(\S*)/) {
   if ($1) {
    $kilobytes = $1;
    $kb = $kilobytes * 1024;
   }
   else {
    print "kilobytes: $kilobytes\n";
   }
  }
  elsif ($tmpp =~ /^exit/) {
   close(DEV);
   die "exiting...\n";
  }
  elsif ($tmpp =~ /^mic/) {
   if ($playmp % 2 == 1) {
    $playmp++;
    print "Changing audio input to microphone...\n";
   }
   else {
    print "Microphone already in use.\n";
   }
  }
  elsif ($tmpp =~ /^mp3/) {
   if ($playmp % 2 == 1) {
    print "MP3 already playing.\n";
   }
   else {
    print "Changing audio input to MP3...\n";
    $playmp++;
   }
  }
  elsif ($tmpp !~ /^$/) {
   print "Invalid command...type 'help' for help.\n";
  }
 } 
}

sub sock {
 ($setx, $readx) = hashes();
 %set = %$setx;
 %read = %$readx;
 ($port, $mp3dir, $playmp3) = @_;
 tie my $kb, 'IPC::Shareable', 'kilobytes', { %read };
 tie my $mp3, 'IPC::Shareable', 'mpeg', { %set };
 opendir(MPEG, $mp3dir);
 @mp3s = grep { /^[^\.]/ } readdir(MPEG);
 closedir(MPEG);
 use IO::Socket;
 $con = IO::Socket::INET->new(
	LocalPort => $port,
	Listen    => 5,
        Reuse     => 1,
 );
 $con->autoflush(1);
 tie my $tmmp, 'IPC::Shareable', 'micormp', { %read };
 while ($sock = $con->accept) {
  $peerhost = $sock->peerhost();
  print "$peerhost connected\n";
  $child = fork();
  unless ($child) {
   $con->close;
   while ($sock) {
    $mp3 = $mp3s[int(rand(@mp3s))];
    if ($playmp3 % 2 == 1) {
     print $sock "HTTP/1.0 200 OK\n";
     print $sock "Content-Type: audio/x-mp3stream\n";
     print $sock "Cache-Control: no-cache\n";
     print $sock "Pragma: no-cache\n";
     print $sock "Connection: close\n";
     print $sock "x-audiocast-name: CommPort5 owns youz0r!\n\n";
     open(MPEG, "lame -b 32 --resample 44.1 $mp3dir/$mp3 - 2>> /dev/null |");
     while (sysread(MPEG, $au, 32 * 1024)) {
      print $sock $au;
      if ($tmmp % 2 != $playmp3 % 2) {
       $playmp3++;
       last;
      }
     }
     close(MPEG);
    }
    else {
     print $sock "HTTP/1.0 200 OK\n";
     print $sock "Content-Type: audio/x-mp3stream\n";
     print $sock "Cache-Control: no-cache\n";
     print $sock "Pragma: no-cache\n";
     print $sock "Connection: close\n";
     print $sock "x-audiocast-name: CommPort5 owns you!\n\n";
     while (     tie $aud, 'IPC::Shareable', 'audio', { %read }){
      print $sock $aud;
      if ($tmmp % 2 != $playmp3 % 2) {
       $playmp3++;
       last;
      }
     }
    }
   }
   exit 0;
  }
 }
}

sub ipc {
 ($kb) = @_;
 ($setx, $readx) = hashes();
 %set = %$setx;
 %read = %$readx;
 open(DEV, "sox -w -t ossdsp $dev -t wav - speed 0.5 2>>/dev/null | lame -b 32 --resample 44.1 - - 2>> /dev/null|") or die
"Can't open sox/lame: $!\n";
 while (tie  $aud, 'IPC::Shareable', 'audio', { %set }) {
  sysread(DEV, $aud, 32 * 1024);
 }
}
