#!/usr/bin/perl

# recursively suck mp3s from apache-type directory structures
# v0.21 - [3/4/02]
# 
# this will only go deeper into directory structures but will
# never go higher than where it's at, for example:
# > mp3get blah.com/x/
#  mp3get will suck all .mp3's in /x/ and recursively go into
#  all dirs in blah.com/x/ looking for more mp3s, locally
#  creating the dirs with mp3s in them but it will NEVER go
#  down to ../ (blah.com/) even if there are direct links to
#  it or just a link to "/" so you never end up wasting time
#  like wget makes you :)
#
# also it doesn't waste time getting images or anything, only
# dirs and mp3s (and .ogg's)
#
# -samy [cp5@LucidX.com]

my @requests = (    # when you get mp3s/dirs, the user agent
                    # will be randomly chosen from this array
 "User-Agent: Mozilla/4.0 (compatible; MSIE 4.0; Windows 95)",
 "User-Agent: Mozilla/4.0 (compatible; MSIE 5.5; Windows 98)",
);


die "usage: $0 [-d (debugging)] <url1> [url2] [url3]..\n" if @ARGV == 0;

my $debug;
if ($ARGV[0] eq "-d") {
 shift(@ARGV);
 $debug = 1;
 print STDERR "<Debugging Mode Enabled>\n\n";
}
my $urls = @ARGV;
my $cur;
my $os;
if ($^O =~ /Win32/i) {
 $os = "> NUL 2> NUL";
}
else {
 $os = "> /dev/null 2> /dev/null";
}
$os = " " if $debug;

$SIG{INT} = sub {
 unlink($cur) if $cur;
 close(CUR);
 die "\nExiting...\n";
};

use IO::Socket;

my @urls;
for (my $i = 0; $i < $urls; $i++) {
 ($urls[$i][0], $urls[$i][1], $urls[$i][2]) = $ARGV[$i] =~ /^(?:http:\/\/)?([^\/:]+)(?::(\d+))?(\/.*)?$/i;
 $urls[$i][1] = 80 if !$urls[$i][1];
 $urls[$i][2] .= "/" if (!$urls[$i][2] || $urls[$i][2] !~ /\/$/);
 ($urls[$i][3]) = $urls[$i][2] =~ /\/([^\/]*)\/?$/;
}

for ($i = 0; $i < $urls; $i++) {
 &recur(@{$urls[$i]});
}

sub recur {
 my @addr = @_;
 my $sock = IO::Socket::INET->new(
  PeerAddr => $addr[0],
  PeerPort => $addr[1],
  Timeout  => 5,
  Proto    => "tcp",
 ) or print STDERR "Can't connect to http://$addr[0]:$addr[1]...moving on\n";
 if ($sock) {
  $addr[2] =~ s/&amp;/&/g;
  print $sock "GET $addr[2] HTTP/1.0\nHost: $addr[0]\nAccept: */*\n"
   . $requests[int(rand(@requests))] . "\n\n";
  my $httpResponse = join('', <$sock>);
  close($sock);
  my (@mp3s, @dirs);
  print "Scanning http://$addr[0]:$addr[1]$addr[2]\n";
  while ($httpResponse =~ s/<a\s+href\s*=\s*(?:"([^"]*)"|'([^']*)'|`([^`]*)`|(\S*))//is) {
   my $tmp = $1;
   if ($tmp =~ /\.ogg|\.mp3|\.m3u$/i) {
    push(@mp3s, $tmp);
   }
   elsif ($tmp =~ /\/$/ && $tmp !~ /^http:\/\/|^\.|^\/|\?/i) {
    push(@dirs, $tmp);
   }
  }
  if (@mp3s) {
   my $temp = $addr[3];
   $addr[3] =~ s/%(.{2})/pack("H2", $1)/eg;
   $addr[3] =~ s/[\?\*:<>|"\\]//g;
   $addr[3] =~ s/\/?$/\//;
   &mkd($addr[3]) unless $addr[3] eq "1";
   $addr[3] =~ s/&amp;/&/g;
   foreach (@mp3s) {
    s/&amp;/&/g;
    s/"/\\"/g;
    my $mp3 = $_;
    $mp3 =~ s/%(.{2})/pack("H2", $1)/eg;
    $mp3 =~ s/[\?\*:<>|"\/\\]//g;
    next if -e $addr[3] . $mp3;
    unlink($addr[3] . $_) if -e $addr[3] . $_;
    print " Getting $addr[3]$mp3\n";
    if ($^O !~ /Win32/i) {
     print "  http://$addr[0]:$addr[1]$addr[2]$_\n";
    }
    $cur = $addr[3] . $_;
    open(CUR, "wget \"--directory-prefix=$addr[3]\" \"http://$addr[0]:$addr[1]$addr[2]$_\" --user-agent=\""
     . $requests[int(rand(@requests))] . "\" --execute=robots=off $os |");
    while (<CUR>) { }
    $cur = "";
    rename($addr[3] . $_, $addr[3] . $mp3);
   }
  }
  foreach (@dirs) {
   my @tmp = @addr;
   $tmp[2] =~ s/\/?$/\/$_/;
   $tmp[3] =~ s/\/?$/\/$_/;
   &recur(@tmp);
  }
 }
}

sub mkd {
 my $dr = $_[0];
 if (!-e $dr && $dr ne "") {
  my $t = $dr =~ s/[^\/]*\/$//;
  &mkd($t);
  mkdir($dr, "755");
  print "MKDIR $dr\n" if $debug;
 }
}
