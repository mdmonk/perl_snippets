#!/usr/bin/perl
#rtfeeder.pl v.0.3 by matt chisholm
#april 7, 1999
#converts rtf files to html files
#april 23, 1999
#fixed {} matching
#May 1, 1999
#added more tags, reworked whitespace cleanup
#6-6-99
#fixing accented characters
#converts https and emails to links now
#finds \\w-\d tags now
#this software is licensed under the GNU GPL
$i = 0;
while ($i <= $#ARGV){
  $infile = $ARGV[$i]; 
  $outfile = $ARGV[$i];
  if (($infile =~ m/\.rtf/i))  { #if the name contains ".rtf"
    $outfile =~ s/\.rtf//i; $outfile = $outfile."\.html"; 
    print "\"$infile\" -> \"$outfile\"\n";     
    open INFILE, $infile or die "Could not open $file: $!"; 
    open (OUTFILE, ">$outfile") or die; 
    print OUTFILE "<!--- This file htmlified by rtfeeder -->\n"; 
    while ($line = <INFILE>){
      $line =~ s/\\\'d2/\"/g; #quotes and special chars.
      $line =~ s/\\\'d3/\"/g; 
      $line =~ s/\\\'d4/\'/g; 
      $line =~ s/\\\'d5/\'/g; 
      $line =~ s/\\\'c9/\.\.\./g; #ellipsis
      $line =~ s/\\\'d0/-/g; #dash
      $line =~ s/\\\'d1/\&\#151;/g; #emdash
      #make this work!

      $line =~ s/\\\'88/\&\#224;/g; #agrave - not 136
      $line =~ s/\\\'8e/\&\#233;/g; #eacute - not 142
      $line =~ s/\\\'97/\&\#243;/g; #oacute - not 151
      $line =~ s/\\\'9f/\&\#252;/g; #uumlau - not 159
      $line =~ s/\\\'a4/\&\#167;/g; #section - not 164
      $line =~ s/\\\'a5/<li>/g; #bullet

      #get those hexadecimal-denoted accented-chars, 
      #and convert them to html codes, in decimal 
      while ( $line =~ m/\\\'(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f)(0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f)/ ) {
	$hex = (hex "0x".$1.$2);
	$line =~ s/\\\'$1$2/\&\#$hex;/g;
      }
      #<p> tags
      $line =~ s/\\pard/<p>/g; 
      $line =~ s/\\par/<\/p>/g; 
      #<b> and <i> tags
      $line =~ s[\\b(.+?)\\plain][<b>$1<\/b>]g; 
      $line =~ s[\\i(.+?)\\plain][<i>$1<\/i>]g; 
      $line =~ s[\\up6(.+?)\\plain][<sup>$1<\/sup>]g; 
      $line =~ s/\\\w*-\d*//g; #WTF
      #doccomm tags
      $line =~ s/{(\\doccomm .*?)}/<!--- RTF doccomm: "$1"-->\n\n/g;
      #misc tags that we neither understand nor care about 
      #$line =~ s[\\tab|\\s1|\\cf1|\\qj|\\tx\d+|\\f\d+|\\qc|\\fs\d+|\\fnil|\\plain|\\qr|\\sectd|\\s\d+|\\hyphhotz720|\\sl\d+|\\stylesheet|\\b|\\i][]g; 
      $line =~ s/\\expnd-3|\\expndtw-15//g;
      $line =~ s[\\\w+][]g;  
      while ($line =~ m/{[^\{\}]*;}/gsx) { #get rid of all these {}
	$line =~ s/{[^\{\}]*;}//gsx; 
      }
      $line =~ s/\s*{|}\s*//g; #get rid of stray {}
      $line =~ s/<p>\s+<\/p>//g; #random empty <p>s
      $line =~ s/<\/p>/<\/p>\n/g; #carriage returns => easily readable doc
      $line =~ s/\t/ /g; #coalition for a whitespace free document
      $line =~ s/  / /g; #coalition for a whitespace free document
      $line =~ s/\n\n/\n/g; #coalition for a whitespace free document

      $line =~ s/(http:\/\/\S+)/<a href=$1>$1<\/a>/g; #convert http links
      $line =~ s/(\S+\@\S+)/<a href=mailto:$1>$1<\/a>/g; #convert mailtos

      print OUTFILE $line;
    }
    close OUTFILE; 
    close INFILE; 
    $i++; 
  } else {
    print "$ARGV[$i] does not appear to be rtf file.\n"; 
    $i++;
  }
}
