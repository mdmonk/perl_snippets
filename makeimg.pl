# makeimg.pl
# Makes an empty file of size multiple of 516096
#
# vu1tur.eu.org/tools/

my $size = 0;
my $t = "\x00";
for (0..10) { $t.=$t; }
my $b = "";
for (0..504) {$b.=$t; }

if (@ARGV."" != 2)
{
	print "Syntax: makeimg.pl <filename> <size>\n";
	print "Examples:\nmakeimg.pl disk.img 3000M\nmakeimg.pl disk.img 1000k\nmakeimg.pl disk.img 1048576";
}
else 
{
if ($ARGV[1] =~ /(\d+)[mMKk]?[bB]?$/)
{
	if ($ARGV[1] =~ /(\d+)(M|m|mb|Mb|MB)$/)
	{ $t = 1048576 }
	if ($ARGV[1] =~ /(\d+)(K|k|kb|Kb|KB)$/)
	{ $t = 1024}
	if ($ARGV[1] =~ /(\d+)$/)
	{ $t = 1}
	open(FH,">".$ARGV[0]) or die "Can't open file";
	
	for (1..$1*$t/516096)
	{
	 syswrite(FH,$b,516096);
	}
	close FH;
}
else { print "Wrong size\nExample: 140,2k,100M"; }
}