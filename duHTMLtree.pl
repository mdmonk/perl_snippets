#!/usr/bin/perl
use strict;
use File::stat;
use Getopt::Std;
use POSIX;

# duHTMLtree - Can be used as a CGI or called from the command line
#  
my $VERSION='1.0.3';

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Start of configuration 
#   edit these as you see fit
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::

#---------------------------
# IP ACCESS CONTROL
#---------------------------

   # What remote IPs can use the CGI version . This is a REGULAR EXPRESSION
   # so don't forget to escape . and it's probably good to bind it with ^

my $OK_REMOTE_IP = '^(192\.168\.0\.|127\.0\.0\.1)'
  if (exists($ENV{'GATEWAY_INTERFACE'}));

my @dusk_files;
my @dusk_names;

#---------------------------
# INPUT FILE CHOICES
#---------------------------

    # There's two ways to populate the choices for file lists in CGI mode:

    # 1. The unsafe but easy way it to scan some directory for files matching
    # a particular regexp and use those (don't forget the trailing / on
    # SCAN_DIR and remember that SCAN_MATCH is a regexp!

my $SCAN_FILESYSTEM=1 if (exists($ENV{'GATEWAY_INTERFACE'}));
my $SCAN_DIR='/tmp/disktree/' if (exists($ENV{'GATEWAY_INTERFACE'}));
my $SCAN_MATCH='^duk_' if (exists($ENV{'GATEWAY_INTERFACE'}));

    # 2. The safe way is to explicitly set the two arrays - one contains filenames
    # and the other printable names (comment out the above two lines as well):

# my $SCAN_FILESYSTEM=0;
# @dusk_files = qw (/Users/msells/bin/dutr/duk_Ayyyeee.txt /Users/msells/bin/dutr/duk_gehenna.txt);
# @dusk_names= qw (Ayyyeee Gehenna);

#---------------------------
# SIZE CHOICES
#---------------------------

    # These are the sizes shown in the left column when in CGI mode

my @size_choices = (
#    '100k','500k','1M','5M','10M',
    '50M','100M','200M','300M','500M','650M',
    '1G','2G','3G','5G','10G')
if (exists($ENV{'GATEWAY_INTERFACE'}));

#---------------------------
# COLORIZATION CONFIG
#---------------------------
# NOTE: This is used in command line mode as well as CGI mode.

    # This controls how we colorize our nodes -- largest size must be listed
    # first in each string!

    # you can use #F0F8FF style colors or W3C HTML 4.0 standard also defines
    # 16 colors by name:
    #    aqua, black, blue, fuchsia, gray, green, lime, maroon, navy,
    #    olive, purple, red, silver, teal, white, and yellow

my %colorstrings = (
	'1'	=> "5G red,2G green,1G purple,500M black,300M aqua",
	'2'	=> "3G red,2G green,1G purple,500M black,200M aqua",
	'3'	=> "100G red,20G green,10G purple,5G black,500M aqua",
    '4' => "400M red,200M green,100M purple,50M black,5M aqua",
	'5'	=> "10G red,5G green,2G purple,1G black,500M aqua",
);

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::
# End of configuration 
#   Nothing below here should require editing
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::
# CGI Mode Handling
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::

if (exists($ENV{'GATEWAY_INTERFACE'})) {

if ( (exists($ENV{'GATEWAY_INTERFACE'})) && ($SCAN_FILESYSTEM) ) {
   opendir(DIR, $SCAN_DIR) || die "can't opendir $SCAN_DIR : $!";
   my @goodones = grep { /$SCAN_MATCH/ } readdir(DIR);
   closedir DIR;
   foreach my $f (@goodones) {
     push (@dusk_files,"$SCAN_DIR" . $f);
     my $name=$f;
     # strip off leading duk_ and trailing .txt to make a nicer name
     $name =~ s#^duk_##;
     $name =~ s#\.txt$##;
     push (@dusk_names,$name);
   }
}


my $qs=$ENV{'QUERY_STRING'};
my $script_uri = $ENV{'SCRIPT_URL'};

my $cgi_size = ($qs =~ m#size=([\dkmgKMG]+)#) ? "$1" : "100M";
my $cgi_color = ($qs =~ m#color=(\d+)#) ? "$1" : "1";
my $cgi_title = ($qs =~ m#title=([^&]+)#) ? "$1" : "Disk Usage Tree";
my $cgi_name = ($qs =~ m#name=([^&]+)#) ? "$1" : "Disk Usage Tree";
my $cgi_file = ($qs =~ m#file=(\d+)#) ? "$1" : "-1";

$cgi_title = "Disk Usage Tree for " . @dusk_names[$cgi_file-1]
  if ( ($cgi_file > 0) && ($cgi_file-1 <= $#dusk_files) );

print "Content-type: text/html\n\n<html><title>$cgi_title</title>\n";
cgi_die ("I don't like your IP") if ($ENV{'REMOTE_ADDR'} !~ m#$OK_REMOTE_IP#);


print "<table border=5><tr><th>Show Size</th><th>Color Scheme</th><th>Which File</th></tr>\n<tr>\n";

print "<td>\n";
for my $s (@size_choices) {
  my $link = self_query('size',$s);
  print ( ($cgi_size ne $s) ?
      qq!<a href="$link">$s</a><br>\n! :
      qq!$s<br>\n!);
}

print "</td>\n<td>\n";

for my $c (sort keys %colorstrings) {
  my $link = self_query('color',$c);
  my $htmlstring='';
  for my $itm (split(/,/,$colorstrings{$c})) {
    my ($size,$color) = split(/\s+/,$itm);
    $htmlstring .= "<font color=$color>$size</font> "; 
  }
  print ( ($cgi_color != $c) ?
      qq!<a href="$link">Colorset $c</a> - $htmlstring<br>\n! :
      qq!Colorset $c - $htmlstring<br>\n!);
}
print "</td>\n<td>\n";

for my $i (1 .. $#dusk_files+1) {
  my $link = self_query('file',$i);
  my $name=@dusk_names[$i-1];
  print ( ($cgi_file != $i) ?
    qq!<a href="$link">$name</a><br>\n! :
    qq!$name<br>\n!);
}
print "</td></tr>\n</table>\n<br>\n";

@ARGV=();
push (@ARGV,"-b","-s$cgi_size", "-c$cgi_color", "-t$cgi_title");

if ( ($cgi_file > 0) && ($cgi_file-1 <= $#dusk_files) ) {
  push (@ARGV,"-n Disk Usage Tree for @dusk_names[$cgi_file-1]");
  push (@ARGV,@dusk_files[$cgi_file-1]);
} else {
  cgi_die ("Please pick which file you want a tree for!");
}
print "<br><hr width=85%>\n";
}

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::
# End of CGI mode handling
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::

# output document template
#
my $template = <<'EOM';
	<h3><a name="_LINKNAME_">_NAME_</a></h3>
	<ul>
	<li>Data file last updated: _TIME_
	<li>Total size: _ROOT_
	<li>Showing items larger than: <b>_MINSIZE_</b>
	</ul>
	<pre>_BODY_</pre>
EOM

# init()

# Handle command line options
#
my %opts;
getopts('c:s:l:n:t:pbh', \%opts);

if ( (defined($opts{h})) || ($#ARGV <0) ) {

print <<"EOM";
	$0 [options] inputfiles
	   -sSIZE   Minimum size we care about
	   -tTITLE  Title for the HTML document
	   -b       Output body only
	   -nNAME   Name for heading
	   -cSTRING Colorstring or just 1,2,3,4 for built in ones
	   -lLINK   Name for <a name> tag
       -p       Do not colorize output (plain)
EOM
	exit(0);
}

my $doctitle = defined($opts{t}) ? $opts{t} : "Disk Usage Tree";
my $name =     defined($opts{n}) ? $opts{n} : "disktree";
my $link =     defined($opts{l}) ? $opts{l} : "disktree";

my $bigger=0;
$opts{s}  = "100M" if (!defined($opts{s}));
$bigger = sizearg($opts{s});

$opts{c} = '1' if (!defined($opts{c}));

my @colors = split(/,/,$colorstrings{$opts{c}});
for my $i (0 .. $#colors) { $colors[$i] =~ s/^(\S+)\s/sizearg($1) . "\t"/e; }

# main()
#

print "<html><head><title>$doctitle</title></head><body bgcolor=\"white\">\n<br>\n" if ( ! defined($opts{b}) );

for my $fn (@ARGV) {
	my $shortname = $name; $shortname =~ s/.*duk_//; $shortname =~ s/\....$//;
	$name = $shortname if (! defined($opts{n}));
	$link = $shortname if (! defined($opts{l}));

	my ($rootitm, $ptr_sizes, $ptr_subdirs) = readdf($fn);
	my %itmsize = %{$ptr_sizes};
	my %subdirs = %{$ptr_subdirs};

	my $body = treeoutput($rootitm,$ptr_sizes,$ptr_subdirs);
	my $sb = stat($fn);
    my $timestring = strftime '%A %d %B %Y at %H:%M:%S', localtime $sb->mtime;

	for (my $output = $template) {
		s/_LINKNAME_/$link/gm;
		s/_BODY_/$body/gm;
		s/_NAME_/$name/gm;
		s/_TIME_/$timestring/gm;
		s/_MINSIZE_/nicesize($bigger)/gme;
		s/_ROOT_/nicesize($itmsize{$rootitm})/gme;
		print $_;
	}

}
print "</html>\n" if ( ! defined($opts{b}) );
exit;


###################################
# SUBROUTINES BELOW HERE

sub colorize {
	my ($line,$size)=@_;
	return $line if defined($opts{p});
	for my $color (@colors) {
		my ($minsize,$code) = split(/\t/,$color);
		return qq!<font color="$code">$line</font>! if ($size >= $minsize);
	}
	return $line;
}

sub nicesize {
	my($size) = @_;
	return sprintf("%.2fG",$size / (2**20) ) if ($size >= (2**20));
	return sprintf("%liM",$size /  (2**10) ) if ($size >= (2**10));
	return sprintf("%lik",$size );
}

sub sizearg {
	my($arg) = @_;
	my %suffixes = ( '' => 1, 'k' => 1, 'm' => 2**10, 'g' => 2**20 );

	return ($arg =~ /(\d+)([kmgMGK])?/) ? ($1 * $suffixes{lc($2)}) : $arg;
}

sub readdf {
	my %itmsize;
	my %subdirs;
	my $rootitm;
	my ($fn) = @_;

	open FILE,"<$fn" || die "Can't open $fn for reading\n";
	while (<FILE>) {
		chop;
		my($size, $parent);
		if (m#^(\d+)\s+(.*)#) { $size=$1; $rootitm=$2; }
		$itmsize{$rootitm} = $size;
		($parent = $rootitm) =~ s#/[^/]+$##;
		push @{ $subdirs{$parent} }, $rootitm unless eof;

		if ( ($size) &&  ($subdirs{$rootitm}) ) {
				my $subsize;
				for my $kid (@{ $subdirs{$rootitm} }) { $subsize += $itmsize{$kid}; }
				if ( ($subsize != $size) && ($subsize) ) {
					$itmsize{"$rootitm/."} = ($size - $subsize);
					push @{ $subdirs{$rootitm} }, "$rootitm/.";
				}
		}
	}
	close FILE;
	return ($rootitm,\%itmsize,\%subdirs);
}

sub treeoutput {
	my ($rootitem,$ptr_sizes,$ptr_subdirs) = @_;
	my %itmsize = %{$ptr_sizes};
	my %subdirs = %{$ptr_subdirs};

	my @worklist;
	my @prefixes;
	my $output_buffer;
	push (@worklist,$rootitem);

	while (my $itm=pop(@worklist)) {
		if ($itm eq "\t") { shift(@prefixes); next; }

		my $prefix=$prefixes[0];
		my $path = $itm;
		$path =~ s#.*/##;
		my $size = $itmsize{$itm};
		my $line = sprintf("%s %s", nicesize($size), $path);
		my $html = colorize($line,$size);
		$output_buffer .= $prefix . $html . "\n" if ($size > $bigger);

		if ($subdirs{$itm}) {
			my @subdirs = @{ $subdirs{$itm} };
			@subdirs = sort { $itmsize{$a} <=> $itmsize{$b} } @subdirs;
			$itmsize{$subdirs[0]} =~ /(\d+)/;

			push (@worklist, "\t");
			for ($prefix .= $line) { s/\d[kMG] /| /; s/[^|]/ /g; }
			unshift(@prefixes, $prefix);

			for my $kid (@subdirs) {
				 push(@worklist, $kid) if ($itmsize{$kid} > $bigger);
			}
		}
	}
	return $output_buffer;
}

sub cgi_die {
  my ($string) = @_;
  print "<h1>$string</h1></html>\n";
  exit;
}

sub self_query {
  my ($param,$value) = @_;

  my $result=$ENV{'QUERY_STRING'};
  # remove the param
  $result =~ s#([\?&])?$param=[^&]*##;
  $result .= "&$param=$value";
  return $ENV{'SCRIPT_URL'} . '?' . $result;
}
