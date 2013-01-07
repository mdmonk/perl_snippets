######################################################
# Program Name: dirsz2.pl
# Programmer:   Me
# Description:  Gets directory size (recursively) for 
#               $ARGV[0] ($dir).                      
######################################################

if(@ARGV) {
  $root = $ARGV[0];
} else {
  $root = "c:\\";
}
print "Root dir is: $root\n";
chomp($root);
$total_bytes = recurse_dirs($root);

sub recurse_dirs {
   my ($dir) = @_;
   my $bytes = 0;
   if (opendir(DIR, $dir)) {
      my (@filenames) = grep(!/^\.\.?$/, readdir(DIR));
      closedir(DIR);
      for my $tmp (@filenames) {
         if (!-d $dir.$tmp) {
            $bytes += (stat($dir.$tmp))[7];
         } else {
            $bytes += recurse_dirs($dir.$tmp."\\");
         }
      }
   } else {
      print "couldn't open $dir: $!"
   }
   return $bytes;
}

print $total_bytes;
