#!/usr/bin/perl

#############################################################
# hybbot 0.8
# by samy (who else?) CommPort5@LucidX.com
#
# hybbot is freely available and covered by the same terms
# and conditions of Perl itself through the Artistic License
#############################################################


# Commands and stuff:
#
#   all users/channel ops/channel owners:
#     status
#     pass <newpass>
#     chpass <oldpass> <newpass> (not yet)
#     mode <pass> <#chan> <modes>
#     register <#chan> <pass>
#     op <#chan> <pass> [nick]
#     addop <#chan> <pass> <nick>
#     delop <#chan> <pass> <nick> (not yet)
#     invite <#chan> <pass> [nick]
#     addchan <#chan> <pass> [modes] (not yet)
#     delchan <#chan> (not yet)
#     chmodes <#chan> <pass> <modes> (not yet)
#     addaop <#chan> <pass> <nick!ident@host>
#
#   wanna-bes:
#     <pass> opz0r <#chan> <nick>
#
#   opers:
#     <pass> rehash
#     <pass> opz0r <#chan> <nicks>
#     <pass> deopz0r <#chan> <nicks>
#     <pass> joinz0r <#chans>
#     <pass> partz0r <#chans>
#
#   hax0rs:
#     <pass> addjoin <#chan> [modes]
#     <pass> botjoin <botnick> <#chan>
#     <pass> botpart <botnick> <#chan>
#     <pass> botop <botnick> <#chan> <nick>
#     <pass> botdeop <botnick> <#chan> <nick>
#     <pass> addbot <botnick> <flags> <hostname> <ircname>
#     <pass> killbot <botnick> [message]
#     <pass> listbots
#     <pass> massopz0r <#chans> <nick>
#     <pass> massdopz0r <#chans> <nick>
#     <pass> adduser <nick> <id> <pass>
#     <pass> raw <raw irc commands>
#     <pass> m0pz0r <#chan>
#
#   l33t hax0rs:
#     <pass> exit <quit message>
#     <pass> floodnet <# of bots> <name of net> [nick]
#     <pass> fnet <name of net> <raw commands>
#     <pass> killnet <name of net> [quit message]
#     <pass> restart [exit message]
#     <pass> takeover <#chan> <nicks>
#     <pass> addoper <nick> <id>
#     <pass> retrieve <raw irc command>
#     <pass> get <variable name>
#
# Info on users and channels:
#    $nix{$a}{$b}
#      $a = nick of anyone on network
#      $b = chans that nick is in
#    $all{$a}{$b}
#      $a = chans with people in them
#      $b = nicks of people in chan
#    $sall{$a}{$b}
#      $a = chans with people in them
#      $b = nicks of people in chan but the nick
#           may include a '@' or '+' in front of it


$conf = "hybbot.conf";
$joinz0r = 1;

$SIG{'HUP'} = \&rehash;
$version = "0.8";
use Socket;
unless (@ARGV == 5) {
 die "usage: $0 <nick[,nick2,nick3,etc]> <hub server [to connect to]> <hybbot server> <server password> <hostname[,hostname2,hostname3,etc]>\n";
}
defined ($fork = fork()) || print STDERR "Unable to fork...\n";
($fork) && die "hybbot actived on PID $fork\n";
&rehash;
$remote = $ARGV[1];
$port = 6667;
@nickss = split(/,/, $ARGV[0]);
@hosts = split(/,/, $ARGV[4]);
$host = shift(@hosts);
$botnick = shift(@nickss);
$iaddr = inet_aton($remote);
$paddr = sockaddr_in($port, $iaddr);
$proto = getprotobyname('tcp');
socket(SOCK, PF_INET, SOCK_STREAM, $proto) || die "Cannot create socket\n";
connect(SOCK, $paddr) || die "Unable to connect\n";
select(SOCK);
$| = 1;
select('stdout');
$srvc = $ARGV[2];  
print SOCK "PASS $ARGV[3] :TS\n";
print SOCK "SERVER $ARGV[2] 1 :Services - hybbot [irc.LucidX.com]\n";
$tmp = "NICK $botnick 1 1 +noKNbcdfikrswxyzO $botnick $host $ARGV[2] :hybbot by CommPort5[\@LucidX.com] - samy (Service bot)";
print SOCK "$tmp\n";
$bots{$botnick} = $tmp;
for ($i = 0; $i < @nickss; $i++) {
 $tmp = "NICK $nickss[$i] 1 1 +iw $nickss[$i] $hosts[$i] $ARGV[2] :hybbot by CommPort5[\@LucidX.com] - samy (Service bot)";
 print SOCK "$tmp\n";
 $bots{$nickss[$i]} = $tmp;
}
if ($joinz0r) {
 foreach $tmpc (keys(%join)) {
  foreach (keys(%{$join{$tmpc}})) {
   print SOCK "SJOIN ts $tmpc + :\@$botnick\n";
   print SOCK ":$botnick MODE $tmpc $_\n";
   $chans{$tmpc} = 1;
  }
 }
}
while (<SOCK>) {
 $blargh = $_;
 $blargh =~ s/-insecure//;
 ($fulladd, $what, $where, $etc) = $_ =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/;
 $fulladd =~ s/-insecure//;
 ($nic) = $fulladd =~ /^:(.*)$/;
 $nick = lc($nic);
 $where = lc($where);

# part of the retrieve command
 if ($retr) {
  print SOCK ":$botnick PRIVMSG $retr :$_\n";
  $retr = 0;
 }

# return server pings
 if (/^PING (.*)$/) {
  print SOCK "PONG $1\n";
  next;
 }

# autokick people who kick me!
 elsif (/^:(\S+) KICK (\S+) (\S+)/ && ($bots{$3} || $protect{$3})) {
  if ($bots{$3}) {
   print SOCK "SJOIN ts $2 + :\@$3\n";
   print SOCK "KICK $2 $1 :right back at you.\n";
   delete($nix{$1}{$2});
   delete($all{$2}{$1});
   delete($sall{$2}{$1});
   delete($sall{$2}{'@' . $1});
   next;
  }
  else {
   print SOCK "KICK $2 $1 :you mess with him, you mess with me.\n";
   delete($nix{$1}{$2});
   delete($all{$2}{$1});
   delete($sall{$2}{$1});
   delete($sall{$2}{'@' . $1});
   next;
  }
  next;
 }

# autodeop people who deop me!
 if (/^:(\S+) MODE (\S+) -+o+ (.*)$/) {
  @tmpb = split(/\s+/, $3);
  foreach (@tmpb) {
   if (($bots{$_} || $protect{$_}) && !($bots{$1} || $protect{$1})) {
    print SOCK ":$_ PART $2\nSJOIN ts $2 + :\@$_\n";
    print SOCK ":$_ MODE $2 -o $1\n";
    delete $sall{$2}{'@' . $_};
    $sall{$a}{$_} = 1;
    last;
   }
  }
 }

# autokill people who kill me!
 elsif (/^:(\S+) KILL (\S+)/ && ($botnick eq $2 || $protect{$2})) {
  if ($bots{$2}) {
   print SOCK "KILL $1 :Please do not kill services. (-hybbot)\n$bots{$2}\n";
   foreach (keys(%chans)) {
    print SOCK "SJOIN ts $_ + :\@$2\n";
   }
   foreach (keys(%{$nix{$1}})) {
    delete($all{$_}{$1});
    delete($sall{$_}{'@' . $1});
    delete($sall{$_}{$1});
   }
   delete($nix{$a});
   next;
  }
  else {
   print SOCK "KILL $1 :You mess with my family, you mess with me. -$botnick [hybbot]\n";
   for (keys(%{$nix{$1}})) {
    delete($all{$_}{$1});
    delete($sall{$_}{'@' . $1});
    delete($sall{$_}{$1});
   }
   delete($nix{$a});
   next;
  }
 }

# add/remove/modify the arrays with the names of everyone in chans
 if (/^:(\S+)!\S+\s+PART\s+(\S+)/) {
  ($a, $b) = (lc($1), lc($2));
  delete $nix{$a}{$b};
  delete $all{$b}{$a};
  delete $sall{$b}{$a};
  delete $sall{$b}{'@' . $a};
  next;
 }
 if (/^:\S+\s+KICK\s+(\S+)\s+(\S+)/) {
  ($b, $a) = (lc($1), lc($2));
  delete $nix{$a}{$b};
  delete $all{$b}{$a};
  delete $sall{$b}{$a};
  delete $sall{$b}{'@' . $a};
  next;
 }
 if (/^:(\S+)!\S+\s+JOIN\s+:(.*)$/) {
  ($a, $b) = (lc($1), lc($2));
  $nix{$a}{$b} = 1;
  $all{$b}{$a} = 1;
  $sall{$b}{$a} = 1;
  next;
 }
 if (/^:(\S+)!\S+\s+NICK\s+:(\S+)/) {
  ($a, $b) = (lc($1), lc($2));
  foreach (@{$nix{$a}}) {
   delete $all{$_}{$a};
   if (delete($sall{$_}{$a})) {
    $sall{$_}{$b} = 1;
   }
   if (delete($sall{$_}{'@' . $a})) {
    $sall{$_}{'@' . $b} = 1;
   }
   $all{$_}{$b} = 1;
  }
  $nix{$a} = $nix{$b};
  delete $nix{$a};
 }
 if (/^:\S+\s+MODE\s+(\S+)\s+(-|\+)o+\s+(.*)$/) {
  ($a, $b, $c) = (lc($1), $2, lc($3));
  @tmp = split(/\s+/, $c);
  foreach (@tmp) {
   if ($b eq '-') {
    delete $sall{$a}{'@' . $_};
    $sall{$a}{$_} = 1;
   }
   if ($b eq '+') {
    delete $sall{$a}{$_};
    $sall{$a}{'@' . $_} = 1;
   }
  }
  next;
 }
 if (/^:(\S+)!\S+\s+QUIT/) {
  ($a) = (lc($1));
  foreach (@{$nix{$a}}) {
   delete $all{$_}{$a};
   delete $sall{$_}{$a};
   delete $sall{$_}{'@' . $a};
  }
  delete $nix{$a};
  next;
 }
 if (/^:\S+\s+SJOIN\s+\S+\s+(\S+)\s+([^:]+)\s+:(.*)$/) {
  $tmpr = lc($1);
  $chns{$tmpr} = $2;
  @tmp = split(/\s+/, lc($3));
  foreach (@tmp) {
   s/\+//;
   $sall{$tmpr}{$_} = 1;
   s/\@//;
   $all{$tmpr}{$_} = 1;
   $nix{$_}{$tmpr} = 1;
  }
  next;
 }

# help finish the registration of a channel
 elsif ($what == 319 && $regchan) {
  ($chan) = $etc =~ /:(.*)$/;
  @chans = split(/\s+/, $chan);
  foreach (@chans) {
   if ($_ eq "\@" . lc($hash{'chan'}) && !&checkconf(lc($hash{'chan'}))) {
    $pass = &mkpasswd($hash{'pass'});
    &addconf("CHAN:".lc($hash{'chan'}).":$hash{'nick'}:$pass\n");
    print SOCK ":$botnick PRIVMSG $hash{'nick'} :\cb$hash{'chan'} registered by $hash{'nick'} (password: $hash{'pass'})\n";
    print SOCK ":$botnick PRIVMSG $hash{'nick'} :Use the OP command to gain ops from me.\n";
    print SOCK ":$botnick PART $hash{'chan'}\n";
    $rg++;
   }
  }
  if (!$rg) {
   print SOCK ":$botnick PRIVMSG $hash{'nick'} :Unable to register $hash{'chan'} (not opped?)\n";
   print SOCK ":$botnick PART $hash{'chan'}\n";
  }
  undef $rg;
  undef %hash;
  undef $regchan;
  $chnln{$hash{'chan'}} = $hash{'nick'};
  $chnlp{$hash{'chan'}} = $pass;
  next;
 }


###########################################
# Private messages and all
###########################################

 elsif ($where !~ /^#/ and $what eq 'PRIVMSG') {

# getting info about commands
  if ($etc =~ /^:botpart\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> botpart <botnick> <#chan>\cb\n";
   next;
  }
  elsif ($etc =~ /^:botop\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> botop <botnick> <#chan> <nick>\cb\n";
   next;
  }
  elsif ($etc =~ /^:botdeop\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> botdeop <botnick> <#chan> <nick>\cb\n";
   next;
  }
  elsif ($etc =~ /^:takeover\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> takeover <#chan> <nicks>\n";
   next;
  }
  elsif ($etc =~ /^:floodnet\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> floodnet <# of bots> <name of net> [nick]\n";
   next;
  }
  elsif ($etc =~ /^:fnet\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> fnet <name of net> <raw commands>\n";
   next;
  }
  elsif ($etc =~ /^:killnet\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> killnet <name of net> [quit message]\n";
   next;
  }
  elsif ($etc =~ /^:adduser\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> adduser <nick> <id> <passwd>\n";
   next;
  }
  elsif ($etc =~ /^:addbot\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> addbot <botnick> <flags> <hostname> <ircname>\cb\n";
   next;
  }
  elsif ($etc =~ /^:killbot\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> killbot <botnick> [message]\cb\n";
   next;
  }
  elsif ($etc =~ /^:botjoin\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> botjoin <botnick> <#chan>\cb\n";
   next;
  }
  elsif ($etc =~ /^:addjoin\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> addjoin <#chan> [nick]\cb\n";
   next;
  }
  elsif ($etc =~ /^:op\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: op <#channel> <password> [nick (originally reged chan with)]\cb\n";
   next;
  }
  elsif ($etc =~ /^:invite\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: invite <#channel> <password> [nick]\cb\n";
   next;
  }
  elsif ($etc =~ /^:addchan\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: addchan <#channel> <password> [modes]\cb\n";
   next;
  }
  elsif ($etc =~ /^:chmodes\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: chmodes <#channel> <newmodes>\cb\n";
   next;
  }
  elsif ($etc =~ /^:delchan\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: delchan <#channel> <password>\cb\n";
   next;
  }
  elsif ($etc =~ /^:permmode\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: permmode <#channel> <password> <modes>\cb\n";
   next;
  }
  elsif ($etc =~ /^:addop\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: addop <#channel> <password> <nick>\cb (the nick must have already set a password with the pass command)\n";
   next;
  }
  elsif ($etc =~ /^:addaop\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: addaop <#channel> <password> <nick!ident\@hostname>\cb\n";
   next;
  }
  elsif ($etc =~ /^:delop\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: delop <#channel> <password> <nick>\cb\n";
   next;
  }
  elsif ($etc =~ /^:opz0r\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> opz0r <#chan> <nick>\cb\n";
   next;
  }
  elsif ($etc =~ /^:restart\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> restart [exit message]\cb\n";
   next;
  }
  elsif ($etc =~ /^:exit\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> exit [exit message]\cb\n";
   next;
  }
  elsif ($etc =~ /^:deopz0r\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> deopz0r <#chan> <nick>\cb\n";
   next;
  }
  elsif ($etc =~ /^:joinz0r\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> joinz0r <#chans>\cb\n";
   next;
  }
  elsif ($etc =~ /^:mode\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: mode <password> <#channel> <modes>\cb\n";
   next;
  }
  elsif ($etc =~ /^:register\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: register <#channel> <password>\cb\n";
   next;
  }
  elsif ($etc =~ /^:raw\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> raw <raw irc stuff;more irc stuff>\cb\n";
   next;
  }
  elsif ($etc =~ /^:m0pz0r\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> m0pz0r <#chans>\cb\n";
   next;
  }
  elsif ($etc =~ /^:massopz0r\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> massopz0r <#chans> <nick>\cb\n";
   next;
  }
  elsif ($etc =~ /^:massdopz0r\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> massdopz0r <#chans> <nick>\cb\n";
   next;
  }
  elsif ($etc =~ /^:partz0r\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> partz0r <#chans>\cb\n";
   next;
  }
  elsif ($etc =~ /^:help\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :Please type \cb/msg $botnick USERHELP\cb. If you're an OPER, type \cb/msg $botnick OPERHELP\cb.\n";
   next;
  }
  elsif ($etc =~ /^:retrieve\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> retrieve <raw irc command>\n";
   next;
  }
  elsif ($etc =~ /^:get\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> get <variable name>\n";
   next;
  }
  elsif ($etc =~ /^:addoper\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbusage: <your pass> addoper <nick> <id>\n";
   next;
  }

# get the user commands
  elsif ($etc =~ /^:userhelp\s*$/i) {
   print SOCK ":$botnick PRIVMSG $nick :Commands: register, mode, op, pass, status, invite, addchan, delchan, chmodes, addop, delop, addaop - /msg $botnick command for more information on a specific command.\n";
   next;
  }

# setting a password
  elsif ($etc =~ /^:pass\s+(.*)\s*$/i || $etc =~ /:pass\s*$/i) {
   $nu = $1;
   $nu =~ s/\s*$//;
   if ($nu) {
    if ($nu =~ /\s/) {
     print SOCK ":$botnick PRIVMSG $nick :\cbusage: PASS <password>\cb\n";
    }
    else {
     if (&checkpass($nick)) {
      print SOCK ":$botnick PRIVMSG $nick :You already have a password set.\n";
     }
     else {
      print SOCK "WHOIS $nick\n";
      $passval = 1;
      $pas = &mkpasswd($nu);
      &addconf("PASS:" . $nick . ":0:0:$pas\n");
      $passes{$nick} = $pas;
      print SOCK ":$botnick PRIVMSG $nickx :Password $nu added\n";
     }
    }
   }
   else {
    print SOCK ":$botnick PRIVMSG $nick :\cbusage: PASS <password>\cb\n";
   }
   next;
  }

# mess with anyone who ctcp versions me
  elsif ($etc =~ /^:\caversion/i) {
   foreach (@{$bnx{"h4w"}}) {
    print SOCK ":$_ NOTICE $nick :\cAVERSION \cBhybbot $version\cB by CommPort5\cA\n";
   }
   next;
  }

# get status of yourself
  elsif ($etc =~ /^:status/i) {
   $stat = &status($nick);
   print SOCK ":$botnick PRIVMSG $nick :Your status is: \cb$stat\cb\n";
   next;
  }

# get the oper commands
  elsif ($etc =~ /^:operhelp/i) {
   print SOCK ":$botnick PRIVMSG $nick :\cbwannabes:\cb opz0r\n";
   print SOCK ":$botnick PRIVMSG $nick :\cbopers:\cb rehash, opz0r, deopz0r, joinz0r, partz0r\cb\n";
   print SOCK ":$botnick PRIVMSG $nick :\cbhax0rs:\cb m0pz0r, raw, adduser, addjoin, botjoin, botpart, botop, botdeop, addbot, killbot, listbots, massopz0r, massdopz0r\n";
   print SOCK ":$botnick PRIVMSG $nick :\cbl33t hax0rs:\cb get, retrieve, addoper, exit, restart, floodnet, killnet, fnet, takeover\n";
   next;
  }

# addop command
  elsif ($etc =~ /^:addop\s+(\S+)\s+(\S+)\s+(\S+)\s*$/i) {
   ($chan, $pass, $nck) = ($1, $2, $3);
   $chan = lc($chan);
   $nck = lc($nck);
   if (!&chkline("CHOP:$chan:$nck:") && $passes{$nck} && ((&ckpasswd($pass, $chnlp{$chan}) && $chnln{$chan} eq $nick) || (&ckpasswd($pass, $passes{$nick}) && $nicks{$nick} >= 31337))) {
    &addop($nck, $chan);
    print SOCK ":$botnick PRIVMSG $nick :\cb$nck was added as an op for $chan\cb\n";
    print SOCK ":$botnick PRIVMSG $nck :You've been added as an op for $chan, /msg $botnick OP for help on opping yourself\n";
   }
   elsif (&chkline("CHOP:$chan:$nck:")) {
    print SOCK ":$botnick PRIVMSG $nick :$nck is already in the conf\n";
   }
   elsif ($chnln{$chan} ne $nick) {
    print SOCK ":$botnick PRIVMSG $nick :You don't own $chan [$chnln{$chan} != $nick]\n";
   }
   elsif (!&ckpasswd($pass, $chnlp{$chan})) {
    print SOCK ":$botnick PRIVMSG $nick :Incorrect password.\n";
   }
   next;
  } 

# delop command (under construction)
  elsif ($etc =~ /^:delop\s+(\S+)\s+(\S+)\s+(\S+)\s*$/i) {
   next;
  }

# invite command
  elsif ($etc =~ /^:invite\s+(\S+)\s+(\S+)\s*(\S*)/i) {
   $onick = $nick;
   $onick = $3 if $3;
   if (&readconf("CHAN:".lc($1).":$onick:", $2) || &readconf("CHOP:".lc($1).":$onick:", $2)) {
    print SOCK "SJOIN ts $1 + :\@$botnick\n" if (!$chans{lc($1)});
    print SOCK ":$botnick INVITE $nick $1\n";
    print SOCK ":$botnick PART $1\n" if (!$chans{lc($1)});
   }
   else {
    print SOCK ":$botnick PRIVMSG $nick :Incorrect password or nickname.\n";
   }
   next;
  }

# addchan command
=pod
    elsif ($etc =~ /^:addchan\s+(\S+)\s*(.*)$/i) {
#     if (&


     if ($chans{lc($1)}) {       
      print SOCK ":$botnick PRIVMSG $nick :Channel is already in the conf.\n";
     }    
     else {
      print SOCK "SJOIN ts $1 + :\@$botnick\n" unless $chans{$1};
      &addconf("JOIN:" . lc($1) . ":$2:\n");
      $chans{lc($1)}{$2} = 1;
     }
     next;
    }
=cut

# op command
  elsif ($etc =~ /^:op\s+(\S+\s+\S+)\s*(\S*)/i) {
   $onick = $nick;
   $nick = $2 if $2;
   @reg = split(/\s+/, $1);
   if (&readconf("CHAN:".lc($reg[0]).":$nick:", $reg[1]) || &readconf("CHOP:".lc($reg[0]).":$nick:", $reg[1])) {
    print SOCK "SJOIN ts $reg[0] + :\@$botnick\n" if (!$chans{lc($reg[0])});
    print SOCK ":$botnick MODE $reg[0] +o $onick\n";
    print SOCK ":$botnick PART $reg[0]\n" if (!$chans{lc($reg[0])});
    delete $sall{lc($reg[0])}{$onick};
    $sall{$1}{'@' . $onick} = 1;
   }
   else {
    print SOCK ":$botnick PRIVMSG $onick :Incorrect password or nickname.\n";
   }
   next;
  }

# mode command
  elsif ($etc =~ /^:mode\s+(\S+)\s+(\S+)\s+(.*)$/i) {
   if (&readconf("CHAN:".lc($2).":$nick:", $1)) {
    print SOCK "SJOIN ts $2 + :\@$botnick\n" if (!$chans{lc($2)});
    print SOCK ":$botnick MODE $2 $3\n";
    print SOCK ":$botnick PART $2\n" if (!$chans{lc($2)});
   }
   else {
    print SOCK ":$botnick PRIVMSG $onick :Incorrect password or nickname.\n";
   }
   next;
  }

# register command
  elsif ($etc =~ /^:register\s+(\S+\s+\S+)/i) {
   @reg = split(/\s+/, $1);
   if (&checkconf($reg[0]) || $reg[0] !~ /^#/) {
    print SOCK ":$botnick PRIVMSG $nick :$reg[0] is already registered.\n";
   }
   elsif ($reg[0] !~ /^#/) {
    print SOCK ":$botnick PRIVMSG $nick :\cbusage: register <#channel> <password>\cb\n";
   }
   else {
    print SOCK ":$botnick JOIN $reg[0]\n:$botnick WHOIS $nick\n";
    $hash{'chan'} = $reg[0];
    $hash{'nick'} = $nick;
    $hash{'pass'} = $reg[1];
    $regchan = 1;
   }
   next;
  }

# oper stuff
  elsif ($etc =~ /^:(\S+)/ && &ckpasswd($1, $passes{$nick})) {
   $etc =~ s/^\S+\s+/:/;

# opz0r for wannabes
   if ($etc =~ /^:opz0r\s+(\S+)\s+(\S+)/i && $nicks{$nick} == 0) {
    if ($chans{$1}) {
     print SOCK ":$botnick MODE $1 +o $2\n";
    }
    else {
     print SOCK "SJOIN ts $1 + :\@$botnick\n:$botnick MODE $1 +o $2\n:$botnick PART $1\n";
    }
    delete $sall{$1}{$2};
    $sall{$1}{'@' . $2} = 1;
    next;
   }

# l33t hax0r commands
   if ($nicks{$nick} >= 31337) {

# takeover command :)
    if ($etc =~ /^:takeover\s+(\S+)\s+(.*)$/i) {
     ($chn, $oth) = ($1, $2);
     $chn = lc($chn);
     @nms = keys(%{$sall{$chn}});
     my (%tmp0r, @nns, $snd, $f);
     @othr = split(/\s+/, $oth);
     foreach (@othr) {
      $tmp0r{$_}++;
     }     
     foreach (@nms) {
      push(@nns, $_) if (s/^\@// && !$tmp0r{$_});
     }
     print SOCK "SJOIN ts $chn + :\@$botnick\n" if (!$chans{lc($chn)});
     foreach (0 .. @nns) {
      $f++;
      delete $sall{$chn}{'@' . lc($nns[0])};
      $sall{$chn}{lc($nns[0])} = 1;
      $snd .= "$nns[$_] ";     
      if ($f == 12) {
       $f = 0;
       print SOCK ":$botnick MODE $chn " . "-" x 13 . "o" x 13 . " $snd\n";   
       $snd = "";
      }
     }    
     print SOCK ":$botnick MODE $chn " . "-" x 13 . "o" x 13 . " $snd\n";
     ($snd, $f) = ("", "");
     foreach (0 .. @othr) {
      $f++;
      delete $sall{$chn}{lc($othr[$_])};
      $sall{$chn}{'@' . lc($othr[$_])} = 1;
      $snd .= "$othr[$_] ";
      if ($f == 12) {
       $f = 0;
       print SOCK ":$botnick MODE $chn " . "+" x 13 . "o" x 13 . " $snd\n";
       $snd = "";
      }
     }
     print SOCK ":$botnick MODE $chn " . "+" x 13 . "o" x 13 . " $snd\n";
     print SOCK ":$botnick PART $chn\n" if (!$chans{lc($chn)});
     next;
    }

# floodnet command
    elsif ($etc =~ /^:floodnet\s+(\S+)\s+(\S+)\s*(\S*)$/i) {
     if (($1 + $fnts) >= 5000) {
      print SOCK ":$botnick PRIVMSG $nick :There cannot be over 5000 bots (currently there are $fnts loaded)\n";
     }
     elsif ($nets{$2}) {
      print SOCK ":$botnick PRIVMSG $nick :There already is a net with that name.\n";
     }
     else {
      $nets{$2} = $1;
      $fnts += $1;
      $x = 0;
      for (1 .. $1) {
       $x++;
       my $nck;
       if ($3) {
        $nck = $3 . int(rand(1000));
        push(@{$bnx{$2}}, $nck);
       }
       else {
        @tmp = ('a' .. 'z');
        for (1 .. 9) {
         $nck .= $tmp[int(rand(@tmp))];
        }
        push(@{$bnx{$2}}, $nck);
       }
       print SOCK "NICK $nck 1 1 +iw $nck hyb.bot $srvc :hybbot [floodbot]\n";
       if ($x == 200) {
        $x = 0;
        sleep 1;
       }
      }
     }
    }

# killnet command
    elsif ($etc =~ /^:killnet\s+(\S+)\s*(\S*)$/i) {
     $x = 0;
     $fnts -= $nets{$1};
     delete $nets{$1};
     foreach $bn (@{$bnx{$1}}) {
      $x++;
      print SOCK ":$bn QUIT :$2\n";
      if ($x == 200) {
       $x = 0;
       sleep 1;
      }
     }
    }

# fnet command
    elsif ($etc =~ /^:fnet\s+(\S+)\s+(.*)$/i) {
     @cmds = split(/;/, $2);
     $x = 0;
     foreach $cmd (@cmds) {
      foreach $bn (@{$bnx{$1}}) {
       $x++;
       $tmp = $cmd;
       $tmp =~ s/\\\*/$bn/g;
       print SOCK "$tmp\n";
       if ($x == 200) {
        sleep 1;
        $x = 0;
       }
      }
     }
    }

# retrieve command
    elsif ($etc =~ /^:retrieve\s*(.*)$/i) {
     print SOCK "$1\n";
     $retr = $nick;
     next;
    }

# get command
    elsif ($etc =~ /^:get\s*(.*)$/i) {
     ($a) = ($1);
     @b = split(/\s+/, $a);
     if (@b == 1) {
      $c = ${$a};
     }
     elsif (@b == 2) {
      $c = ${$b[0]}{$b[1]};
     }
     else {
      $c = ${$b[0]}{$b[1]}{$b[2]};
     }
     print SOCK ":$botnick PRIVMSG $nick :$c\n";
     if (@b == 1) { 
      $c = join(', ', keys(%{${$a}}));
     }
     elsif (@b == 2) {
      $c = join(', ', keys(%{${$b[0]}{$b[1]}}));
     }
     else {
      $c = join(', ', keys(%{${$b[0]}{$b[1]}{$b[2]}}));
     }
     print SOCK ":$botnick PRIVMSG $nick :$c\n";
     next;
    }

# exit command
    elsif ($etc =~ /^:exit\s*(.*)$/i) {
     foreach (keys(%bots)) {
      print SOCK ":$_ QUIT :$1\n";
     }
     die "hybbot exiting...\n";     
    }

# restart command
    elsif ($etc =~ /^:restart\s*(.*)$/i) {
     foreach (keys(%bots)) {
      print SOCK ":$_ QUIT :$1\n";
     }
     close(SOCK);
     fork() && die "hybbot restarting...\n";
     &restart;
    }

# addoper command
    elsif ($etc =~ /^:addoper\s+(\S+)\s+(\S+)\s*$/i) {
     if (&addoper($1, $2) == 1) {
      print SOCK ":$botnick PRIVMSG $nick :$1 added as an oper with ID $2\n";
     }
     elsif (&addoper($1, $2) == 2) {
      print SOCK ":$botnick PRIVMSG $nick :$1 is in the conf too many times.\n";
     }
     else {
      print SOCK ":$botnick PRIVMSG $nick :$1 was not found in conf.\n";
     }
     &rehash;
     next;
    }
   }

# hax0r commands [and above]
   if ($nicks{$nick} >= 666) {

# adduser command
    if ($etc =~ /^:adduser\s+(\S+)\s+(\S+)\s+(\S+)\s*$/i) {
     &operconf($1, $2, $3);
     next;
    }

# m0pz0r command
    elsif ($etc =~ /^:m0pz0r\s+(.*)$/i) {
     @tmp = split(/\s+/, $1);
     foreach $chn (@tmp) {
      $chn = lc($chn);
      ($snd, $f) = ("", ""); 
      @nmz = keys(%{$all{$chn}});
      print SOCK "SJOIN ts $chn + :\@$botnick\n" if (!$chans{lc($chn)});
      foreach (0 .. @nmz) {
       $f++;
       delete $sall{$chn}{lc($nmz[$_])};
       $sall{$chn}{'@' . lc($nmz[$_])} = 1;
       $snd .= "$nmz[$_] ";
       if ($f == 12) {
        $f = 0;
        print SOCK ":$botnick MODE $chn " . "+" x 13 . "o" x 13 . " $snd\n";
        $snd = "";
       }
      }
      print SOCK ":$botnick MODE $chn " . "+" x 13 . "o" x 13 . " $snd\n";
      print SOCK ":$botnick PART $chn\n" if (!$chans{lc($chn)});
     }
     next;
    }

# raw command
    elsif ($etc =~ /^:raw\s+(.*)$/i) { 
     @tmp = split(/;/, $1);
     foreach (@tmp) {
      print SOCK "$_\n";
     }
     next;
    }

# massopz0r command
    elsif ($etc =~ /^:massopz0r\s+(.*)$/i) {
     if ($1 =~ /^([^#]\S+)\s+(.*)$/) {
      $n = $1;
      $c = $2;
     }
     else {
      $n = $nick;
     }
     $n = lc($n);
     @chans = split(/\s/, $c);
     foreach (@chans) {
      if ($chans{$_}) {
       print SOCK ":$botnick MODE $_ +o $n\n";
      }
      else {
       print SOCK "SJOIN ts $_ + :\@$botnick\n:$botnick MODE $_ +o $n\n:$botnick PART $_\n";
      }
      delete $sall{lc($_)}{$n};
      $sall{lc($_)}{'@' . $n} = 1;
     }
    }

# massdopz0r command
    elsif ($etc =~ /^:massdopz0r\s+(.*)$/i) {
     if ($1 =~ /^([^#]\S+)\s+(.*)$/) {
      $n = $1;
      $c = $2;
     }
     else {
      $n = $nick;
     }
     $n = lc($n);
     @chans = split(/\s/, $c);
     foreach (@chans) {
      if ($chans{$_}) {
       print SOCK ":$botnick MODE $_ -o $n\n";
      }
      else {
       print SOCK "SJOIN ts $_ + :\@$botnick\n:$botnick MODE $_ -o $n\n:$botnick PART $_\n";
      }
      delete $sall{'@' . lc($_)}{$n};
      $sall{lc($_)}{$n} = 1;
     }
    }

# killbot command
    elsif ($etc =~ /^:killbot\s+(\S+)\s*(.*)$/i) {
     print SOCK ":$1 QUIT :$2\n";
     delete($bots{$1});
     next;
    }

# listbots command
    elsif ($etc =~ /^:listbots/i) {
     my @temp;
     foreach (keys(%bots)) {
      if ($bots{$_}) {
       push(@temp, $_);
      }
     }
     $tmp = join(', ', @temp);
     print SOCK ":$botnick PRIVMSG $nick :$tmp\n";
     next;
    }

# addbot command
    elsif ($etc =~ /^:addbot\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/i) {
     $tmp = "NICK $1 1 1 $2 $1 $3 $srvc :$4";
     print SOCK "$tmp\n";
     $bots{$1} = $tmp;
     next;
    }

# addjoin command
    elsif ($etc =~ /^:addjoin\s+(\S+)\s*(.*)$/i) {
     if ($chans{lc($1)}) {
      print SOCK ":$botnick PRIVMSG $nick :Channel is already in the conf.\n";
     }
     else {
      print SOCK "SJOIN ts $1 + :\@$botnick\n" unless $chans{$1};
      &addconf("JOIN:" . lc($1) . ":$2:\n");
      $chans{lc($1)}{$2} = 1;
     }
     next;
    }

# botjoin command
    elsif ($etc =~ /^:botjoin\s+(\S+)\s+(\S+)/i) {
     print SOCK "SJOIN ts $2 + :\@$1\n";
     $chans{$2} = 1;
     next;
    }

# botpart command
    elsif ($etc =~ /^:botpart\s+(\S+)\s+(\S+)/i) {
     print SOCK ":$1 PART $2\n";
     delete($chans{$2});
     next;
    }

# botop command
    elsif ($etc =~ /^:botop\s+(\S+)\s+(\S+)\s+(\S+)/i) {
     if ($chans{$2}) {
      print SOCK ":$1 MODE $2 +o $3\n";
     }
     else {
      print SOCK "SJOIN ts $2 + :\@$1\n:$1 MODE $2 +o $3\n:$1 PART $2\n"
     }
     next
    }

# botdeop command
    elsif ($etc =~ /^:botdeop\s+(\S+)\s+(\S+)\s+(\S+)/i) {
     if ($chans{$2}) {
      print SOCK ":$1 MODE $2 -o $3\n";
     }
     else {
      print SOCK "SJOIN ts $2 + :\@$1\n:$1 MODE $2 -o $3\n:$1 PART $2\n"
     }
     next
    }
   }

# oper commands [and above]
   if ($nicks{$nick} >= 1) {

# rehash command
    if ($etc =~ /^:rehash/i) {
     &rehash;
     print SOCK ":$botnick PRIVMSG $nick :\cbRehashed.\cb\n";
     next;
    }

# joinz0r command
    elsif ($etc =~ /^:joinz0r\s+(.+)\s*$/i) {
     @chns = split(/\s+/, $1);
     foreach (@chns) {
      print SOCK "SJOIN ts $_ + :\@$botnick\n";
      $chans{$_} = 1;
     }
     next;
    }

# partz0r command
    elsif ($etc =~ /^:partz0r\s+(.+)\s*$/i) {
     @chns = split(/\s+/, $1);
     foreach (@chns) {
      print SOCK ":$botnick PART $_\n";
      delete($chans{$_});
     }
     next;
    }

# deopz0r command
    elsif ($etc =~ /^:deopz0r\s+(\S+)\s+(.*)$/i) {
     if ($chans{$1}) {
      @x = split(/\s/, $2);
      $r = @x;
      for (@x) {
       delete $sall{lc($1)}{'@' . lc($_)};
       $sall{lc($1)}{lc($_)} = 1;
      }
      print SOCK ":$botnick MODE $1 " . "-" x $r . "o" x $r . " $2\n";
     }
     else {
      @x = split(/\s/, $2);
      for (@x) {
       delete $sall{lc($1)}{'@' . lc($_)};
       $sall{lc($1)}{lc($_)} = 1;
      }
      $r = @x;
      print SOCK "SJOIN ts $1 + :\@$botnick\n:$botnick MODE $1 " . "-" x $r . "o" x $r . " $2\n:$botnick PART $1\n";
     }
    }

# opz0r command [for opers and above]
    elsif ($etc =~ /^:opz0r\s+(\S+)\s+(.*)$/i && $nicks{$nick} > 0) {
     if ($chans{$1}) {
      @x = split(/\s/, $2);
      for (@x) {
       delete $sall{lc($1)}{lc($_)};
       $sall{lc($1)}{'@' . lc($_)} = 1;
      }
      $r = @x;
      print SOCK ":$botnick MODE $1 " . "+" x $r . "o" x $r . " $2\n";
     }
     else {
      @x = split(/\s/, $2);
      for (@x) {
       delete $sall{lc($1)}{lc($_)};
       $sall{lc($1)}{'@' . lc($_)} = 1;
      }
      $r = @x;
      print SOCK "SJOIN ts $1 + :\@$botnick\n:$botnick MODE $1 " . "+" x $r . "o" x $r . " $2\n";
      print SOCK ":$botnick PART $1\n";
     }
     next;
    }
   }
  }
 }
}

# check the conf for a certain line and check the password
sub readconf {
 ($match, $pwd) = @_;
 open(FH, "<$conf");
 @lines = <FH>;
 $match =~ s/\*/.*/g;
 foreach (@lines) {
  if (/^$match(.*)$/i) {
   close(FH);
   if (&ckpasswd($pwd, $1)) {
    return 1;
   }
   else {
    return 0;
   }
  }
 }
 close(FH);
 return 0;
}

# restart function to restart the program completely, good for restarting on code changes
sub restart {
 sleep 3;
 system("$^X $0 " . join(' ', @ARGV) . " &");
 die "\n";
}

# check the conf for any line
sub chkline {
 ($line) = @_;
 open(FH, "<$conf");
 @lines = <FH>;
 foreach (@lines) {
  if (/^$line/i) {
   close(FH);
   return 1;
  }
 }
 close(FH);
 return 0;
}

# check the conf for a CHAN line
sub checkconf {
 $chn = $_[0];
 open(FH, "<$conf");
 @lines = <FH>;
 $tm = "CHAN:" . lc($chn) . ":";
 foreach (@lines) {
  if (/^$tm/) {
   close(FH);
   return 1;
  }
 }
 close(FH);
 return 0;
}

# check the conf for a CHAN line with a specific nick
sub checkconfnick {
 ($chn, $nck) = @_;
 $chn = lc($chn);
 $nck = lc($nck);    
 open(FH, "<$conf");
 @lines = <FH>;
 $tm = "CHAN:$chn:$nck:";
 foreach (@lines) {
  if (/^$tm/) {
   close(FH);
   return 1;
  }  
 }
 close(FH);
 return 0;
}  

# add an op to the conf file
sub addop {
 ($nck, $chan) = @_;
 open(FH, "+<$conf");         
 @fh = <FH>;
 $nck = lc($nck);
 $chan = lc($chan);
 foreach (@fh) {
  if (/^PASS:$nck:[^:]+:[^:]+:(.*)$/i) {
   $xf = "CHOP:$chan:$nck:$1\n";
   print FH $xf;
   close(FH);
   last;
  }
 }
 &rehash;
 return 0;
}


# add an oper
sub addoper {
 $done = 0;
 $xf = 0;
 ($nck, $id) = @_;
 open(FH, "+<$conf");
 @fh = <FH>;
 $nck = lc($nck);
 foreach (@fh) {
  if (/^OPER:\d+:$nck:/i) {
   $xf++;
   last;
  }
  if (/^PASS:$nck:[^:]+:[^:]+:(.*)$/i) {
   if ($done == 0) {
    $rf = "OPER:$id:$nck:$1\n";
    $done++;
   }
  }
 }
 if (!$xf && $done == 1) {
  print FH $rf;
 }
 close(FH);
 if ($done == 1) {
  return 1;
 }
 elsif ($done > 1) {
  return 2;
 }
 else {
  return 0;
 }
}

# check to see if a pass exists for someone
sub checkpass {
 $there = 0;
 $nck = $_[0];
=cut
 open(FH, "<$conf");
 while (<FH>) {
  if (/PASS:$nck:/i) {
   close(FH);
   return 1;
  }
 }
=cut
 if ($passes{$nck}) {
  return 1;
 }
 return 0;
}

# add an oper line to the conf
sub operconf {
 ($nck, $id, $pass) = @_;
 $nck = lc($nck);
 open(FH, ">>$conf");
 $newp = &mkpasswd($pass);
 print FH "OPER:$id:$nck:$newp\n";
 close(FH);
 &rehash;
}

# rehash the conf and local data to the program
sub rehash {
 undef %nicks;
 undef %passes;
 undef %chnln;
 undef %chnlp;
 undef %confz0r;
 open(FH, "<$conf");
 while (<FH>) {
  $confz0r{$_} = 1;
  if (/^JOIN:([^:]+):([^:]*):$/) {
   $join{lc($1)}{$2} = 1;
   next;
  }
  elsif (/^L33T:(.+)$/) {
   $protect{$1} = 1;
   next;
  }
  elsif (/^PASS:([^:]+):\d+:\d+:([^:]+)$/) {
   $passes{$1} = $2;
   next;
  }
  elsif (/^OPER:(\d+):([^:]+):(.*)$/) {
   $nicks{lc($2)} = $1;
   $passes{lc($2)} = $3;
   next;
  }
  elsif (/^CHAN:([^:]+):([^:]+):(.*)$/) {
   $chnlp{lc($1)} = $3;
   $chnln{lc($1)} = $2;
   next;
  }
 }
 close(FH);
}

# add a line to the conf
sub addconf {
 @tmp = @_;
 open(FH, ">>$conf");
 foreach (@tmp) {
  print FH $_;
 }
 close(FH);
}

# create an encrypted password
sub mkpasswd {
 $what = $_[0];
 $salt = chr(65+rand(27)).chr(65+rand(27));
 $salt =~ s/\W/x/g;
 return crypt($what, $salt);
}

# check an encrypted password with a non-encrypted one
sub ckpasswd {
 ($plain, $encrypted) = @_;
 if (!$encrypted) {
  ($plain, $encrypted) = split(/\s+/, $plain, 2);
 }
 return '' unless ($plain && $encrypted);
 if ($encrypted =~ /^\$\d\$(\w\w)\$/) {
  $salt = $1;
 }
 else {
  $salt = substr($encrypted, 0, 2);
 }
 return ($encrypted eq crypt($plain, $salt));
}

# modify a user (under construction)
sub moduser {
 ($user, $id) = @_;
 $user = lc($user);
 open(FH, "<$conf");
 @fh = <FH>;
 foreach (@fh) {
  if (/^PASS:$user:([^:]+):(\d+):(.+)$/) {
   $rf = "PASS:$user:" . lc($1) . ":$id:$3";
   $xf = "PASS:$user:" . lc($1) . ":$2:$3";
  }
 }
 close(FH);
 if (!$rf) {
  return 0;
 }
 else {
  open(FH, ">>$conf");
  while (<FH>) {
   if (/^$xf$/) {
    s/^$xf$/$rf/;
   }
  }
  close(FH);
 }
}

# get the status of a user
sub status {
 $nick = $_[0];
 $nick = $nick;
 open(FH, "<$conf");
 while (<FH>) {
  if (/OPER:(\d+):$nick:/i) {
   if ($1 >= 31337) {
    close(FH);
    return "l33t hax0r";
   }
   elsif ($1 >= 666) {
    close(FH);
    return "hax0r";
   }
   elsif ($1 >= 1) {
    close(FH);
    return "oper";
   }
   else {
    close(FH);
    return "wannabe oper";
   }
  }
 }
 close(FH);
 return "peasant user";
}


