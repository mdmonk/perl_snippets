######################################################
# Program Name: dirsz.pl
# Programmer:   Me
# Description:  Gets directory size (recursively) for 
#               $ARGV[0] ($dir).                      
######################################################
use File::Find;

chomp($ARGV[0]);
$dir = $ARGV[0];
find(\&wanted, "$dir");

sub wanted {
	$total_size += (-s $File::Find::name);
}
print "\nTotal directory size of $dir: \n$total_size bytes.\n";

