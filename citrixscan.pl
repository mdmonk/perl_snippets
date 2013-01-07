#!/usr/bin/perl
use Socket;

$SIG{ALRM}=sub { $connection=0; close(CON); };
$trick_master=
   "\x20\x00\x01\x30\x02\xFD\xA8\xE3" .
   "\x00\x00\x00\x00\x00\x00\x00\x00" .
   "\x00\x00\x00\x00\x00\x00\x00\x00" .
   "\x00\x00\x00\x00\x00\x00\x00\x00"
   ;

$get_pa=
   "\x2a\x00\x01\x32\x02\xfd" .
   "\xa8\xe3\x00\x00\x00\x00" .
   "\x00\x00\x00\x00\x00\x00" .
   "\x00\x00\x00\x00\x00\x00" .
   "\x00\x00\x00\x00\x21\x00" .
   "\x02\x00\x00\x00\x00\x00" .
   "\x00\x00\x00\x00\x00\x00"
   ;

$|=1;

print "\nCitrix Published Application Scanner version 2.0\
By Ian Vitek, ian.vitek\@ixsecurity.com\n";

die "\nUsage: $0 {IP | file | - | random } [timeout]\
\tIP\tIP to test\
\tfile\tRead IPs from file\
\t-\tRead IPs from standard input\
\trandom\tRead IPs from /dev/urandom\
\ttimeout\tTimeout\
\n" if(!$ARGV[0]);

$input=$ARGV[0];
$timeout=$ARGV[1];
$timeout=1 if(!$timeout);
if($input eq "-" || -r $input) {
  open(INPUTFD,"$input") or die "Cant open file $input: $!\n";
  $newHost=2;
} elsif ($input eq "random") {
  open(RANDOM,"/dev/urandom") or die "Cant open /dev/urandom: $!\n";
  binmode(RANDOM);
  $newHost=3;
} else {
  $newHost=1;
}

$loop=1;
while($loop==1) {
  undef $target;
  if($newHost==2) {
    $target=<INPUTFD> or exit;
    chomp $target;
    $target=~s/\s*(\S+)/$1/;
    redo if(!$target);
  } elsif ($newHost==1) {
    $loop=0;
    $target=$input;
  } elsif ($newHost==3) {
    undef @ch;
    $i=0;
    while($i<4) {
      while($ch[$i] < 1 || $ch[$i] > 254) {
         $ch[$i]=ord getc(RANDOM);
      }
      $i++;
    }
    $target=sprintf("%d.%d.%d.%d",$ch[0],$ch[1],$ch[2],$ch[3]);
  } else {
    die "Nothing to do? Check input!\n\n";
  }

  #
  # Get Master Browser
  #
  $server=inet_aton($target) or die "Is \"${target}\" a target?\n\n";
  $retry=0;
  $connection=0;
  while($retry++<2 and $connection==0) {
    $connection=1;
    socket(CON, PF_INET, SOCK_DGRAM, getprotobyname('udp'));
    send(CON, $trick_master, 0, sockaddr_in(1604, $server));
    alarm $timeout;
    $from_CON=recv(CON,$data,1500,0);
    alarm 0;
  }
  close(CON);
  if($connection==0) {
    print "$target not responding\n";
    next;
  }
  undef $master_raw;
  undef $master;
  ($master_raw)=$data=~/.+\x02\x00\x06\x44(....)/s;
  if($master_raw) {
    $master=sprintf("%d.%d.%d.%d",ord substr($master_raw,0,1),ord substr($master_raw,1,1),ord substr($master_raw,2,1),ord substr($master_raw,3,1));
  } else {
    $master="ERROR";
  }
  print "$target|$master";
  if($target eq $master) {
    print "|1|";
  } else {
    print "|0|";
  }

  #
  # Enumerate PA
  #
  $retry=0;
  $connection=0;
  while($retry++<2 and $connection==0) {
    $connection=1;
    socket(CON, PF_INET, SOCK_DGRAM, getprotobyname('udp'));
    send(CON, $get_pa, 0, sockaddr_in(1604, $server));
    alarm $timeout;
    undef $data;
    $from_CON=recv(CON,$data,1500,0);
    alarm 0;
  }
  if($connection==0) {
    print "Connection lost\n";
    next;
  }
  undef $pa;
  $pa=substr($data,40);
  chop $pa;
  $pa=~s/\x00/\;/sg;
  print "$pa";
  
  #
  # More packets?
  #
  $last_packet=ord substr($data,30,1);
  while($last_packet==0) {
    $connection=1;
    alarm $timeout*2;
    undef $data;
    $from_CON=recv(CON,$data,1500,0);
    alarm 0;
    if($connection==0) {
      print ",ERROR";
      last;
    }
    undef $pa;
    $pa=substr($data,39);
    chop $pa;
    $pa=~s/\x00/\;/sg;
    print "$pa";
    $last_packet=ord substr($data,30,1);
  }
  close(CON);
  print "\n";
}
