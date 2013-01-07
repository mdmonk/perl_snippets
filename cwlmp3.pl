#!perl.exe
####################################
#
####################################
use Getopt::Std;
# use File::Find;
# use File::Basename;

getopts('d:o:hv');

$VERSION = "0.0.1";
$VDATE = "8 Feb 2000";

if($opt_v) {
  print "\nMP3 PlayList Creator. Version $VERSION, $VDATE\n\n";
  exit;
} elsif ($opt_h) {
  usage();
  exit;
} elsif (!($opt_d && $opt_o)) {
  print "\nINCORRECT! Type '$1 -h' for proper usage....\n";
  print "Thank you...please drive through\n\n";
  exit;
}

sub usage {
  print "\nMP3 PlayList Creator. Version $VERSION\n\n";
  print "Usage: $1 [-v | -h | -d | -o]\n";
  print "       $1 -d <beginning dir> -o <outputfile>\n";
  print "       $1 -d e: -o cwl_mp3.pls\n";
}

open (OUTFILE, ">$opt_o") or die "Unable to open output file: $!\n";

@tmp = `find $opt_d | grep .mp3`;

printOUT();

sub printOUT {
  my $i = 1;
  print OUTFILE "[playlist]\n";
  foreach $line (@tmp) {
    chomp($line);
    $line =~ s/\//\\/g;
    print OUTFILE "File" . $i . "=$line\n";
    $i++;
  }
  $i--;
  print OUTFILE "NumberOfEntries=$i\n";
}

#################################
# Plz ignore this...it no workie
#################################
#find (\&wanted, 'e:\\');
#sub wanted {
#  $_ =~ m/\.mp3$/;
#  print "\$_ is: $_\n";
#  my ($name, $path, $suffix) = fileparse("$_");
#  print OUTFILE "$path" . "$name\n";
#}

# foreach $line (<DIR>) {
#  print OUTFILE $line;
#}
#closedir (DIR);
#################################

close (OUTFILE);

###########################################
############ END OF SCRIPT ################
###########################################
