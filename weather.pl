#! perl.exe
##########################################################################################
#This is script which connects to the internet and parses
#the weather.com pages for different cities to give you
#weather information, now rather pointless by itself,
#it could be modified to say, parse out stock quotes,
#boxscores, or anything else you could think of.
##########################################################################################
#	weather.pl - Perl Script the connects to weather.com's website and parses city   #
#	weather information, can do RDU or GNV.						 #
##########################################################################################

use Win32::Internet;

$INET = new Win32::Internet();
print "Weather Script v0.0.1\n";
print "Enter City?";
chop ($city = <STDIN>);
$city = uc $city;
if ($city eq "BMI"){
print "Looking up Bloomington now...\n";
$_ = $INET->FetchURL("http://www.weather.com/weather/us/cities/IL_Bloomington.html");
#this is so I can add it radar download and put it in a graphical container..
#$img_radar = $INET->FetchURL("http://www.weather.com/images/radar/single_site/122loc_450x284.gif");
}
#Change those web addresses to reflect the location you want
if ($city eq "SF"){
print "Looking up San Francisco now...\n";
$_ = $INET->FetchURL("http://www.weather.com/weather/us/cities/CA_San_Francisco.html");
#$img_radar = $INET->FetchURL("http://www.weather.com/images/radar/single_site/122loc_450x284.gif");
}
if ($city eq "DEN"){
print "Looking up Denver now...\n";
$_ = $INET->FetchURL("http://www.weather.com/weather/us/cities/CO_Denver.html");
}
if ($city eq "RDU"){
print "Looking up Raleigh-Durham now...\n";
$_ = $INET->FetchURL("http://www.weather.com/weather/us/cities/NC_Raleigh-Durham.html");
}
if ($city eq "") {
	exit 0 if $city=!/RDU|DEN|SF|BMI/;
}
($date)=/SIZE=3>(.*)<BR>/;
($time)=/SIZE=2>last\supdated\s(.*)<BR>/;
($temp, $weather)=/<B>current\stemp:\s(.*)&deg;F\s<BR>\n\n(.*)<BR>/;
($city)=/<B>(.*)<\/B>/;
($wind)=/<\/B>\n\s+<FONT SIZE=2>\n\s+wind:\s+(.*)<BR>/;
($humidity)=/relative humidity:\s(.*)<BR>/;
($baro)=/barometer:\s(.*)<BR>/;
(@five_day_otlk) = /<FONT\sFACE="ARIAL,HELVETICA"\sSIZE=2><B>(.*)<\/B><\/FONT>/g;
(@type1) = /SIZE=2><B>(.*)<BR>(.*)<\/B>/g;
(@five_day_temp)= /hi\s(.*)&deg;<BR>/g;
(@lo)= /lo\s(.*)&deg/g;	

$TotStr = "CITY:\t\t$city\nDATE:\t\t$date\nLAST UPDATE\t$time\nTEMP:\t\t$temp\nCONDITION:\t$weather\nWIND:\t\t$wind\nHUMIDITY:\t$humidity\nPRESS:\t\t$baro\n";

print $TotStr;

foreach (@five_day_otlk[0..4]){
	print("$_\t\t");
	}
print "\n";
foreach(@type1[0,2,4,6,8]){
	print("$_\t");
}
print "\n";
foreach (@type1[1,3,5,7,9]){
	print("$_\t");
}
print "\n\n";
foreach(@five_day_temp){
	print("$_\t\t");
}
if ($#lo == 3){
print"\t\t";	
foreach(@lo){
	print("$_\t\t");
}
}
if ($#lo ==4){
foreach(@lo){
	print("$_\t\t");
}
}
