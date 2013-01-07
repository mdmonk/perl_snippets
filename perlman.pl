#!D:/Apps/Perl/bin/perl.exe 
# -sw

$pod_dir = "D:/Apps/perl/5.005/lib/pod";	# directory where pod files are

#
# copyright 1998 $Bill Luebkert - you may use/modify freely
#
# make perl manual from pods into single text file
# Usage: perl perlman.pl >perl.man
#

$| = 1;

print <<EOD and exit 0 if $h;

Usage: $0 [-s] >perl.man
	-s	silent (no progress lines)

Combines all of the Perl man pages into a single file 
for searching and reference.

EOD

%sections = (
  "00perl" => "Perl overview (this section)", 
  "01perldelta" => "Perl changes since previous version", 
  "02perlwin32" => "Perl on Win32", 
  "03perldata" => "Perl data structures", 
  "04perlsyn" => "Perl syntax", 
  "05perlop" => "Perl operators and precedence", 
  "06perlre" => "Perl regular expressions", 
  "07perlrun" => "Perl execution and options", 
  "08perlfunc" => "Perl builtin functions", 
  "09perlvar" => "Perl predefined variables", 
  "10perlsub" => "Perl subroutines", 
  "11perlmod" => "Perl modules: how they work", 
  "12perlmodlib" => "Perl modules: how to write and use", 
  "13perlform" => "Perl formats", 
  "14perllocale" => "Perl locale support", 
  "15perlref" => "Perl references", 
  "16perldsc" => "Perl data structures intro", 
  "17perllol" => "Perl data structures: lists of lists", 
  "18perltoot" => "Perl OO tutorial", 
  "19perlobj" => "Perl objects", 
  "20perltie" => "Perl objects hidden behind simple variables", 
  "21perlbot" => "Perl OO tricks and examples", 
  "22perlipc" => "Perl interprocess communication", 
  "23perldebug" => "Perl debugging", 
  "24perldiag" => "Perl diagnostic messages", 
  "25perlsec" => "Perl security", 
  "26perltrap" => "Perl traps for the unwary", 
  "27perlstyle" => "Perl style guide", 
  "28perlpod" => "Perl plain old documentation", 
  "29perlbook" => "Perl book information", 
  "30perlembed" => "Perl ways to embed perl in your C or C++ application", 
  "31perlapio" => "Perl internal IO abstraction interface", 
  "32perlxs" => "Perl XS application programming interface", 
  "33perlxstut" => "Perl XS tutorial", 
  "34perlguts" => "Perl internal functions for those doing extensions", 
  "35perlcall" => "Perl calling conventions from C", 
  "36perlfaq" => "Perl frequently asked questions", 
  "37perlfaq1" => "Perl frequently asked questions 1", 
  "38perlfaq2" => "Perl frequently asked questions 2", 
  "39perlfaq3" => "Perl frequently asked questions 3", 
  "40perlfaq4" => "Perl frequently asked questions 4", 
  "41perlfaq5" => "Perl frequently asked questions 5", 
  "42perlfaq6" => "Perl frequently asked questions 6", 
  "43perlfaq7" => "Perl frequently asked questions 7", 
  "44perlfaq8" => "Perl frequently asked questions 8", 
  "45perlfaq9" => "Perl frequently asked questions 9", 
  "46perltoc" => "Perl table of contents", 
);

&main;

exit 0;

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

sub main {
open (OUTFILE, ">perlpod.man");
	my ($ii, $key);
	my ($sect_hdr) = "\tSection of Perl Manual";
	use Pod::Text;

  foreach $key (sort keys %sections) {
 	 $key =~ /^(\d{2})(.*)$/;
	 $ii = $1; $section = $2;
	 print STDERR "$ii: $section\n" if !$s;
	 print "$section $sect_hdr\n\n";
#	 pod2text ("-80", "$pod_dir/$section.pod");
# 	 pod2text ("-80", "$pod_dir/$section.pod", \*STDOUT);
 	 pod2text ("-80", "$pod_dir/$section.pod", OUTFILE);
  }
  close(OUTFILE);
}
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
1 if ($s or $h);	# single refs
__END__
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
sub wanted {
  pod2text ("$poddir/$_") if /\.pod/;
}
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__END__
