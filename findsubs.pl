# get subroutines from all files in startdir

use File::Recurse; # from File-Tools

# $startdir = "F:\\PWORK";
$startdir = "D:\\DATA\\DEV\\PERL";
$out = "SUBS.TXT";

open(OUTFILE, ">".$out);

recurse(\&CheckFile, $startdir);

sub CheckFile {
  my($level) = 0;
  my($t) = "";

  if (/.pl$/) {
    $file = $_;
    open(WORKFILE, $_);
    $level = 0;
    while (<WORKFILE>) {
      $t = $_;
      s/(^\s+)|(\s+$)//g;              # strip leading and trailing spaces
      if (/^sub/) {
        print OUTFILE ($t);
        print "$t\n";
        if ($t =~ /{/) { $level = 1; } # just in case the sub line has no brace
        while (($level > 0) && ($t = <WORKFILE>)) {
          print OUTFILE ($t);
          if ($t =~ /{/) { $level++; }
          if ($t =~ /}/) { $level--; }
        }
      }
    }
    close(WORKFILE);
  }
}
