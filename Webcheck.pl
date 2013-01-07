use strict;
use LWP::UserAgent;
my $code;

my $server = shift || die "Must enter a server.\n";

my %urls = ("IDC" => "/*.idc",
      "Site Server 2.0 Repost" => "/scripts/repost.asp",
      "Site Server 3.0" => "/msadc/Samples/SELECTOR/showcode.asp",
      "FPCount" =>
"/_vti_bin/fpcount.exe?Page=default.htm|Image=3|Digits=15",
      "AdSamples" => "/adsamples/config/site.csc",
      "IISAdmin" => "/IISADMIN",
      "Scripts1" => "/scripts/iisadmin/bdir.htr",
      "New DSN" => "/scripts/tools/newdsn.exe",
      "Query" => "/iissamples/issamples/query.asp",
      "HTR" => "/iisadmpwd/aexp2.htr",
      "RFP9907" => "/msadc/msadcs.dll");

if (isIIS($server)) {
 print "$server: IIS web server.\n";
 foreach (keys %urls) {
  $code = testURL($server,$_,$urls{$_});
  print "$_ Code: $code\n";
 }
}
else {
 print "$server: NOT IIS.\n";
}

#-----------------------------------------------------------
# isIIS() - checks to see if web server is IIS
#-----------------------------------------------------------
sub isIIS {
 my($server) = @_;
 my $ua = new LWP::UserAgent;
 $ua->agent("IISProbe/0.1 ".$ua->agent);
 my $srv = "http://$server";
 my $req = new HTTP::Request Get => $srv;
 my $res = $ua->request($req);
 my $web = $res->server;
 (grep(/Microsoft-IIS/i,$web)) ? (return 1) : (return 0);
}

#-----------------------------------------------------------
# testURL() - fires URL at server, gets response code and
#             content (which can be saved for examination)
#-----------------------------------------------------------
sub testURL {
 my($server,$tag,$url) = @_;
 my $code;
 my $ua = new LWP::UserAgent;
 $ua->agent("IISProbe/0.1 ".$ua->agent);
 my $srv = "http://$server".$url;
 my $req = new HTTP::Request Get => $srv;
 my $res = $ua->request($req);
 $code = $res->code;
 my $content = $res->content;

# NOTE: This is the code for saving the content.  Uncomment
# the below 4 lines to save the returned web page to a file.
# my $file = $server."-".$tag.".html";
# open(FL,">$file") || die "Could not open $file: $!\n";
# print FL "$content\n";
# close(FL);

 return $code;
}

