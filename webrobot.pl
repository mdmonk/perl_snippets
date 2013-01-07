#!/usr/bin/env perl
#Description: HTTP robot that collect E-mail addresses.
#Author: Arnon Ayal

#######################################################################
#
#
# That program demonstrate  the usage of LWP::RobotUA &LWP::UserAgent #
# The Robot start from base URL and from there start to 'travel'      #
# On the links, To make it useful somehow the robot collect E-mail    #
# addresses that its find in the URL's.                               #
# The robot save every URL its have visited so it wont return there   #
#                                                                     #
#######################################################################

require LWP::UserAgent;
require LWP::RobotUA;
use HTML::LinkExtor;
use URI::URL;

$url = $ARGV[0];

$url = 'http://www.hotwired.com/' if (!$url);
$Hash = "c:/test/robot_hash.txt";
my %Urls = ();

#Loading the URL's that already have been visited
open(IN,"$Hash");
while(<IN>)
{
	($key,$val)=split(/ = /,$_);
	chomp $val;
	$Urls{$key} = $val;
}
my $c = 0;
RecSub($url);

#==================================================
sub RecSub
#Get contents of a URL
{
	my($NewUrl) = $_[0];
	$c++;
	if($c % 5 == 0)
	{
		open(OUT,">$Hash");
		foreach $Key(sort keys(%Urls))
		{
			print OUT "$Key = $Urls{$Key}\n";
		}
		close OUT;
	}
	local $url = $NewUrl ;
	print "($c) $url\n";
	my $ua = new LWP::RobotUA 'my-robot/1.0', 'MyName@MyDomain.com'; 
	$ua->delay(0);
	$request = new HTTP::Request('GET', $url);
	$response = $ua->request($request);
	$res = $response->content;
	my $p1 = HTML::LinkExtor->new(\&FindMailTo, $url);
	$p1->parse($res);
	my $p = HTML::LinkExtor->new(\&NextLink, $url);
	$p->parse($res);
}
#==================================================
sub FindMailTo
#Find E-mail addresses in the content
{
   my($tag, %links) = @_;
   if($tag eq "a")
   {
  		 while(($v,$u) = each(%links))
   		{
	   		if($u =~ /mailto:/i)
	   		{
	   			FoundEmail($u);
	   			return;
	   		}
   		}
   }
}
#==================================================
sub NextLink
#Parse the next link in the page and call recursive to the next page
{
   my($tag, %links) = @_;
   if($tag eq "a")
   {
  		 while(($v,$u) = each(%links))
   		{
   			next if(($u =~ /$url/i));
   			next if($u =~ /javascript/i);
   			next if($u =~ /mailto:/i);
   			@h = split(/\//,$u);
   			$u = "http://".$h[2]."/";
   			($u,$d) = split(/\?/,$u);
   			next if (exists $Urls{$u});
   			$Urls{$u} = ".";
    		RecSub($u);
   		}
   }
}
#==================================================
sub FoundEmail()
#Parse the E-mail address
{
	($d,$s1) = split(/mailto:/i,$_[0]);
	if($s1)
	{
		($s2,$d) = split(/\?|\s+|\"|>/i,$s1);
		print "===>".$s2."\n";		
		$Urls{$url} = $s2;
	}
	return;
}
