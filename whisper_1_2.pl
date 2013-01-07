#!/usr/local/bin/perl -w

# whisper_1_2.pl
# Scott Parks	code@levitator.org
# 01/26/00
# Modified: 09/28/00,12/09/00
# streaming mp3 server. Works with Winamp client. 

use Socket;
use Getopt::Std;
use File::Basename;
use File::Find;
use Fcntl;

my $VERSION = 1.2;
$|=1;

getopt('plqsrdD',\%args);
&help() if(!defined $args{l} && !defined $args{d} && !defined $args{D});

$port = 2020 ;
$port=$args{p} if(defined $args{p});
&help() if($port < 1 || $port > 65535);

$quiet=0; $quiet=1 if(exists $args{q});
$loop=1; $loop=0 if(exists $args{s});

print "Searching for mp3's, one moment...\n" if(!$quiet);
@songs=();
&make_list();
$len=@songs;
print "$len mp3's in list.\n" if(!$quiet);

($name, $aliases, $protocol) = getprotobyname('tcp');
($name, $aliases, $port) = getservbyport($port, 'tcp') if ($port !~ /^\d+$/);

print "Listening on port $port...\n"  if(!$quiet);

socket(S,AF_INET,SOCK_STREAM,$protocol) || die "socket : $!";
setsockopt(S, SOL_SOCKET, SO_REUSEADDR, 1) or die "Can't set sock option\n"; 

$sockaddr = 'S n a4 x8';
$this = pack($sockaddr, AF_INET, $port, "\0\0\0\0");
bind(S, $this) || die "bind : $!";

listen(S,10) || die "listen: $!";
select(S); $| = 1; select(STDOUT);

for ($con = 1; ; $con++) {
   ($addr = accept(NS,S)) || die $!;

   select(NS); $| = 1; select(STDOUT);

   $cli_ip=&get_cli_ip();
   if ((fork()) == 0) {
      &shuffle(\@songs) if(exists($args{r}));
      &serv_client();   
   }
   $SIG{CHLD} = \&reaper;
   close(NS);
} 

#### subs start here  ##########


sub clean_str() {
   local $str=$_[0];

   $str=~tr/\r|\n//d;
   $str=~tr/\t/ /;
   $str=~tr/ //s;
   return $str;
}

sub start_stream() {
   local $agent=$_[0];

   local $buff="HTTP/1.1 200 OK\n\n";
   print NS $buff;
}

sub serv_client() {
   local $ip=&get_cli_ip();
   printf "%-16.16s Connected\n",$ip if(!$quiet);

   local $agent="",$buf="",$lin="";
   while (<NS>) {
      $buf=$_;
      $lin = &clean_str($buf);
      $agent="winamp" if($lin=~/winamp/gi);
      next if(length($lin));

      &start_stream($agent);
      if($loop) {
         local $cnt=1;
         do { 
            printf "%-16.16s Playlist pass: $cnt\n",$ip if(!$quiet); 
            $cnt++;
         } while(&stream_data($ip));
      } else {
         print "Single pass through $args{l}\n" if(!$quiet); 
         &stream_data();
      }
      print "Playlist done.\n" if(!$quiet);
      close(NS);
   }
   print "Client be gone .\n" if(!$quiet);
   close(NS);
   exit;
}

sub make_list() {
   local ($sng,$idx=0,$playlist="",@tsongs=());

   open(OLDERR,">&STDERR");
   open(STDERR,">/dev/null");

   if(defined($args{l})) {
      $playlist=$args{l};
      @tsongs=qx{cat $playlist};
   } elsif (defined($args{d})) {
      $playlist=$args{d};
      @tsongs=<$playlist/*.mp3>;
   } elsif (defined($args{D})) {
      $playlist=$args{D};
      find sub {$sng=$File::Find::name; $tsongs[$idx++]=$sng if($sng=~/^.*\.mp3/gi);},$playlist;
   }
   close(STDERR);
   open(STDERR,">&OLDERR");
   close(OLDERR);

   for($idx=$jdx=0; $idx < @tsongs; $idx++) {
      $tsongs[$idx]=~tr/\n|\r//d;
      $songs[$jdx++]=$tsongs[$idx] if($tsongs[$idx]=~/^.*\.mp3$/i && !($tsongs[$idx]=~/^ /));
   } 
   die "No mp3's found in $playlist\n" if(!@songs);
   &shuffle(\@songs) if(exists($args{r}));

}

sub stream_data() {
   local $sze=4096, $buf="", $song="";
   local $ip=$_[0];

   foreach $song(@songs) {
      if(!open(FDS,"<$song")) {
         print "NOT FOUND, is path correct\?: $song\n";
         sleep(3); next;
      }
      printf "%-16.16s %s\n",$ip, $song if(!$quiet); 
      while(read(FDS, $buf, $sze)) {
         print NS $buf if(length($buf) > 2) or return 0;
      }
      sleep 1;
   }
   return 1;
}

sub shuffle() {
   local ($i=0, $j=0, $array = shift);

   srand(time());
   for($i = @$array; --$i; ) {
      $j = int rand($i+1);
      next if $i == $j;
      @$array[$i,$j] = @$array[$j,$i];
   }
}

sub reaper() { 
   printf "%-16.16s Disconnected\n",$cli_ip if(!$quiet);
   my $child_pid = wait(); 
} 

sub get_cli_ip() {
   local ($af,$port, $inetaddr) = unpack($sockaddr, $addr);
   $af="";
   local @inetaddr = unpack('C4', $inetaddr);
   local $ip="$inetaddr[0].$inetaddr[1].$inetaddr[2].$inetaddr[3]";
   return $ip;
}
sub help() {
   print "Usage: $0 [-l | -d | -D] -p -q -s -r\n";
   print "\tNote: -l or -d or -D must be specified\n";
   print "\t-l playlist, file containing full path to each .mp3 file. \n";
   print "\t-d directory to search for mp3's, non-recursive\n";
   print "\t-D directory to search for mp3's, recursive\n";
   print "\t-p port number. Default is 2020\n";
   print "\t-q Quiet mode. No informative messages.\n";
   print "\t-s Single pass through playlist. Default is constant loop\n";
   print "\t-r Shuffle the playlist. Make sure it's the last switch on\n\t   the command line.\n";
   print "\nExample:\n";
   print "\t$0 -l ./playlist\n";
   print "\tUsing default port (2020). Use your WinAmp player and 'Play Location'\n";
   print "\thost.domain.com:2020 and it will magically start streaming.\n\n";

   exit;
}

=head1 NAME
whisper_1_2.pl

=head1 DESCRIPTION
MP3 Server for UNIX that works with the WinAmp client

=head1 README

whisper_1_2.pl - MP3 streaming server used with WinAmp client.
It'll run on any UNIX system with PERL. No special CPAN mods
required. WinAmp can be obtained at www.winamp.com

code@levitator.org
Scott Parks 01/26/00


whisper_1_2.pl - How to run it.

1. Use the WinAMP Client. That's what it's designed
   around.

2. Create a playlist
   This is a file with a complete path to a mp3 file.
   A playlist might look like this:

   /export/mp3/song1.mp3
   /export/mp3/song2.mp3
   /export/mp3/song3.mp3

3. Ensure the first line of whisper_1_1.pl points to your
   perl binary:

   #!/usr/local/bin/perl 

4. Run the script:
   
   ./whisper_1_1.pl -l playlist

5. Start your winamp client and 'Play Location' 
   http://your.server.dom:2020 

That'll get you running.

Options Summary
Run the program without any parameters to get the help 
message. Here's a summary of each option:
  
   -l the playlist file

   -d directory to look in for mp3's, non-recursive

   -D directory to look in for mp3's, recursive

   -p port to listen on. The default is 2020. Remeber, 
      you must use a port number above 1023 if you
      don't have root.

   -s Single pass through the playlist file. With this
      switch each song in the playlist will be played 
      once and the client will be dropped. The default
      is to continuosly loop through the playlist until
      the client bails or the server stops.

   -q Quiet mode. Turn off information messages.

   -r shuffle your playlist, be it a directory or file


That would be just about it.


=head1 PREQUISITES
PERL 5.004 or greater
Any Unix OS or more precisely, anything that has a fork system call
and runs PERL

=pod SCRIPT CATEGORIES
Audio/MP3

=cut



