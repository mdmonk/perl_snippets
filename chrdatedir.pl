#!perl.exe
my $root = "c:\\";
my ($day,$month,$year) = (localtime(time))[3,4,5];
$month++;
$year += 1900;
$dir = sprintf("%s%d%02d%2d",$root,$year,$month,$day);
mkdir($dir,'0777') unless (-d $dir);
print "Directory $dir is all set.\n";
exit 0;

#
# Or...
# mkdir ( ((localtime)[3] . '_' . (localtime)[4] . '_' . (localtime)[5]), 0 );
#
