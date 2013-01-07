#!/usr/bin/perl
use Getopt::Std;
use IO::Socket;
use IO::Handle;
use Thread;
getopts("le:p:", \%arg);
$SIG{INT} = \&Catch_Fun;
$SIG{QUIT} = \&Catch_Fun;

my $sock;
if (defined $arg{l}){
 	if (defined $arg{p}){
 		my $lsock=IO::Socket::INET->new(Listen=>1,LocalPort=>$arg{p}) || die "Can't Create Listen: $!";
 		next unless $sock=$lsock->accept;
 		if (defined $arg{e}){
 			*STDIN =$sock;
 			*STDOUT=$sock;
 			exec $arg{e};
 		}else{
 			Thread->new(\&SendMsg);
 			&RecvMsg;
 		}
 	}
}else{
 	$sock=IO::Socket::INET->new(PeerAddr=>$ARGV[0],PeerPort=>$ARGV[1]) || die
"Can't connect: $!";
 	Thread->new(\&SendMsg);
 	&RecvMsg;
}
sub SendMsg{
 	while(<STDIN>){
 		print $sock $_;
 	}
}
sub RecvMsg{
 	while(<$sock>){
 		print $_;
 	}
}
sub Catch_Fun{
 	die "exit!";
}
