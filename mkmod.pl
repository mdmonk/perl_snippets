#!/usr/bin/perl

# -sam k (commport5@lucidx.com)

# reads the perl program and outputs a module header that you
# have to add to the .pl to make it into a module

# e.g.,
# ./mkmod Inject.pl Packet::Inject 0.01 > Inject.pm ; cat Inject.pl >> Inject.pm ; rm Inject.pl

die "usage: $0 <file> <module name> <version>\n" unless @ARGV == 3;
open(TMP, $ARGV[0]) or die "Unable to open $ARGV[0]: $!\n";
while (<TMP>) {
 if (($f) = $_ =~ /^[^#]*[^#\\]*sub\s+(\S+)/) {
  $funcs .= "$f ";
 }
}
$funcs =~ s/\s*$//g;
$tmp{'@ISA'} = 1;
$tmp{'@EXPORT'} = 1;
$tmp{'$VERSION'} = 1;
($mod) = $ARGV[1] =~ /^([^:]+)/;
($pm = $ARGV[0]) =~ s/\.pl//;
print "
# $pm.pm $ARGV[2] (module: $ARGV[1])

package $ARGV[1];
require Exporter;
\@ISA = qw(Exporter);
\@EXPORT = qw($funcs);
\$VERSION = '$ARGV[2]';
";
