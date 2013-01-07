#!/usr/local/bin/perl
#
######################################################################
#
# (c) 1998, 1999 by "Soenke J. Peters" <peters@simprovement.com>
#
# Version 1.00 (1999-02-11)
#
# This is a graphical counter that is called from the <img> tag.
# The only external resource is it's data file.
# It produces the count in GIF or XBM format.
#
# This script contains documentation in pod format.
#
######################################################################
#
# Routines to write a two-color GIF are "heavily inspired" by code
# (c) by Jeffrey Friedl (jfriedl@omron.co.jp), most of the XBM stuff
# has been taken from a perl script by ???.
#
######################################################################
#
# Syntax is:
# <img src="pathToScript/img_counter.pl/path/to/countedpage.gif">
# or
# <img src="pathToScript/img_counter.pl/path/to/countedpage.xbm">
# depending on wether you want a XBM or GIF image.
#
# The document to be counted has to be accessible under the url
# "http://$ENV{'SERVER_NAME'}/path/to/countedpage.html"
#
# If you want a colored GIF image, you may append the hex rgb value 
# as the query-string (e.g. "?ff0080") or use one of the well-known
# color names as mentioned in the HTML3.2 specification
# (e.g. "?navy", "?red", "?blue").
#
# The background remains transparent.
#
# The script should be chmod 0755, the data file chmod 0666 or 0777.
#
######################################################################
# Some vars
#
   $minLen = 6;		# minimum number of digits in bigmap
   $isHigh = 1;		# if 1, digits are 16 pixels high, to
			# allow room for border
   $isInverse = 0;	# 1 = digits are white on black
			# 0 = black on white
   $fake = 1;		# 0 = real count
			# 1 = slightly higher count

   # the location of the data file:
   $counterFile = "$ENV{'DOCUMENT_ROOT'}/cgi-bin/data/cnts";

######################################################################
# Main
#
eval {
   $|=1;	# flush STDOUT
   $countedPage = $ENV{'PATH_INFO'};
   $countedPage =~ s/\.(.*?)$/\.html/i;		# counted page must have
						# .html extension
   $imgtype=$1;

   &initialize;

   &incrementCount;
   &generateBitmap;
};

   # spit out error xbm if any errors occured during previous eval
   if ($@) {
     &error_xbm;
     exit(1);
   }

   if ($imgtype =~ /gif/i) {
     &writeGif;
   }
   else {
     &writeBitmap;
   }
   exit(0);

######################################################################
#
#
######################################################################
#
#


sub mkcolor {
   %knowncolors=("black", 	"000000",
		"silver",	"c0c0c0",
		"gray",		"808080",
		"white",	"ffffff",
		"maroon", 	"800000",
		"red",		"ff0000",
		"purple",	"800080",
		"fuchsia",	"ff00ff",
		"green",	"008000",
		"lime",		"00ff00",
		"olive",	"808000",
		"yellow",	"ffff00",
		"navy",		"000080",
		"blue",		"0000ff",
		"teal",		"008080",
		"aqua",		"00ffff"
	       );

  $color = lc($ENV{'QUERY_STRING'});
  if (defined $knowncolors{$color}) {
    $color=$knowncolors{$color};
  }
  
  if ($color =~ m/([0-9a-f]{6})/gi) {
    return  unpack("C3", pack("H6", "$color"));
  }
  else {
    return (0, 0, 0);
  }
}

sub writeGif {
   print "Content-type: image/gif\n\n";
   binmode STDOUT;	# the lame part of the world could need this
   if ($isHigh) {
     &start("STDOUT", $len*8, 16, &mkcolor, 255,255,255, 1);
   }
   else {
      &start("STDOUT", $len*8, 10, &mkcolor, 255,255,255, 1);
   }
   for($i = 0; $i < ($#bytes + 1); $i++) {
      &bits(unpack("b8", pack("H2", "$bytes[$i]")));
   }
   &end;
   close STDOUT;
}

sub writeBitmap {
   print ("Content-type: image/x-xbitmap\n\n");
   if ($isHigh) {
      printf "#define count_width %d\n#define count_height 16\n", 
              $len*8;
   }
   else {
      printf "#define count_width %d\n#define count_height 10\n", 
              $len*8;
   }
   printf STDOUT "static char count_bits[] = {\n";
   for($i = 0; $i < ($#bytes + 1); $i++) {
      print("0x$bytes[$i]");
      if ($i != $#bytes) {
         print(",");
         if (($i+1) % 7 == 0) {
            print("\n");
         }
      }
   }
   print("};\n");
}

# generateBitmap() - $count contains number to display
#                    $minLen contains minimum number of digits to display
#                    $isHigh is one for 16 bit high numbers (else 10)
#                    $isInverse is one for reverse (white on black);
sub generateBitmap {
   $count = $totalReads;
   @bytes = ();
   $len = length($count) > $minLen ? length($count) : $minLen;
   $formattedCount = sprintf("%0${len}d",$count);
   if ($isHigh) {
      for ($i = 0; $i < $len*3; $i++ ) {
         if ($isInverse) {
            push(@bytes,"ff");       # add three blank rows to each digit
         }
         else {
            push(@bytes,"00");
         }
      }
   }
   for ($y=0; $y < 10; $y++) {
       for ($x=0; $x < $len; $x++) {
           $digit = substr($formattedCount,$x,1);
           if ($isInverse) {             # $inv = 1 for inverted text
               $byte = substr($invdigits[$digit],$y*3,2);
           } 
           else {
               $byte = substr($digits[$digit],$y*3,2);
           }
           push(@bytes,$byte);
       }
   }
   if ($isHigh) {
      for ($i = 0; $i < $len*3; $i++ ) {
         if ($isInverse) {
            push(@bytes,"ff");       # add three blank rows to each digit
         }
         else {
            push(@bytes,"00");
         }
      }
   }
}

sub initialize {
   # bitmap for each digit
   #  Each digit is 8 pixels wide, 10 high
   #  @invdigits are white on black, @digits black on white
   @invdigits = ("c3 99 99 99 99 99 99 99 99 c3",  # 0
                 "cf c7 cf cf cf cf cf cf cf c7",  # 1
                 "c3 99 9f 9f cf e7 f3 f9 f9 81",  # 2
                 "c3 99 9f 9f c7 9f 9f 9f 99 c3",  # 3
                 "cf cf c7 c7 cb cb cd 81 cf 87",  # 4
                 "81 f9 f9 f9 c1 9f 9f 9f 99 c3",  # 5
                 "c7 f3 f9 f9 c1 99 99 99 99 c3",  # 6
                 "81 99 9f 9f cf cf e7 e7 f3 f3",  # 7
                 "c3 99 99 99 c3 99 99 99 99 c3",  # 8
                 "c3 99 99 99 99 83 9f 9f cf e3"); # 9
   
   @digits = ("3c 66 66 66 66 66 66 66 66 3c",  # 0
              "30 38 30 30 30 30 30 30 30 30",  # 1
              "3c 66 60 60 30 18 0c 06 06 7e",  # 2
              "3c 66 60 60 38 60 60 60 66 3c",  # 3
              "30 30 38 38 34 34 32 7e 30 78",  # 4
              "7e 06 06 06 3e 60 60 60 66 3c",  # 5
              "38 0c 06 06 3e 66 66 66 66 3c",  # 6
              "7e 66 60 60 30 30 18 18 0c 0c",  # 7
              "3c 66 66 66 3c 66 66 66 66 3c",  # 8
              "3c 66 66 66 66 7c 60 60 30 1c"); # 9
}

sub incrementCount {
   &incrementTotalReads;
}


sub incrementTotalReads {
  if (-e $counterFile) {
    open(COUNT,"<$counterFile") or die("Can't open $counterFile: $!\n");
    flock(COUNT,2);seek(COUNT,0,0);
  }

  while (<COUNT>) {
    chomp $_;
    ($Page, $counts)=split(/=/,$_);
    $hashy{$Page}=$counts;
  }
  flock(COUNT,8);
  close(COUNT);
  if (-r $ENV{'DOCUMENT_ROOT'}.$countedPage) {
    if (! defined $hashy{$countedPage}) {
      $hashy{$countedPage}=0;
    }
    $totalReads=$hashy{$countedPage};
    # make the pages become accessed more frequently (at least once per hour):
    $totalReads=int( (time() - 850_000_000) / 360 - 140_000 + $hashy{$countedPage})
      if ($fake==1);
    $hashy{$countedPage}++;
   }
  else {
    die("Counter $countedPage does not exist.\n");
  }

  open(COUNT,">$counterFile") || die "$0: can\'t open $counterFile: $!\n";
  flock(COUNT,2);seek(COUNT,0,0);
  while (($Page, $counts) = each %hashy) {
    print COUNT $Page.'='.$counts."\n";
  }
  flock(COUNT,8);
  close(COUNT);
}

######################################################################
# gif encoding routines
#

sub start
{
    $MAX = 1 << 12; ## maximum GIF compression value
    ($FH, $w, $h, $fg_r, $fg_g, $fg_b, $bg_r, $bg_g, $bg_b, $trans) = @_;

    $w    =   0 if !defined $w;
    $h    =   0 if !defined $h;
    $fg_r = 255 if !defined $fg_r;
    $fg_g = 255 if !defined $fg_g;
    $fg_b = 255 if !defined $fg_b;
    $bg_r =   0 if !defined $bg_r;
    $bg_g =   0 if !defined $bg_g;
    $bg_b =   0 if !defined $bg_b;
    $trans =  0 if !defined($trans);

    print $FH ($trans ? "GIF89a" : "GIF87a"),
	pack('CC CC C C C  CCC CCC',
	  $w & 0xff, ($w >> 8),
	  $h & 0xff, ($h >> 8),
	  0x80,                  # global color map. no color. 1 bit/pixel
	  0,                     # background is color 0
	  0,                     # pad
          $bg_r, $bg_g, $bg_b, $fg_r, $fg_g, $fg_b,
	  0);

    if ($trans)
    {
	print $FH pack('CCC CCCC C',
	    0x21,  ## magic: "Extension Introducer"
	    0xf9,  ## magic: "Graphic Control Label"
	       4,  ## bytes in block (between here and terminator)
	    0x01,  ## indicates that 'transparet index' is given
	    0, 0,  ## delay time.
	       0,  ## index of "transparent" color.
	    0x00); ## terminator.
    }

    print $FH ',', pack('CC CC CC CC CC',
	0,0,0,0,
	$w & 0xff, $w >> 8,
	$h & 0xff, $h >> 8,
	0, 2);

    &lzw_clear_dic();
}


sub end
{
    &lzw_out();
    &lzw_raw_out($EOF);
    &lzw_flush_raw();
    print $FH pack("C", 0);
    undef $FH;
}

sub bits
{
    return 0 if !defined $FH;
    local($cleartext) = join('',@_);
    local($index) = 0;
    local($leng) = length $cleartext;
    $working = substr($cleartext, $index++, 1) if !defined $working;

    while ($index < $leng)
    {
	$K = substr($cleartext, $index++, 1);
	if (defined $dic{$working.$K}) {
	    $working .= $K;
	} else {
	    &lzw_out();
	    $dic{$working.$K} = $code++;
	    $working = $K;
	}
    }
    1;
}

sub lzw_clear_dic
{
    undef %dic;
    $bits = 2;
    $Clear = 1 << $bits;
    $EOF   = $Clear + 1;
    $code  = $Clear + 2;
    $nextbump = 1 << ++$bits;
    $WaitingBits = ''; ## init stuff.
    &lzw_raw_out($Clear);
    undef $working;
}

##
## Inherits: $bits, $working %dic
## Output the appropriate code for $working.
##
sub lzw_out
{
   &lzw_raw_out(($working eq '0' || $working eq '1')?$working:$dic{$working});
   if ($code >= $nextbump) {
       &lzw_clear_dic() if ($nextbump = 1 << ++$bits) > $MAX;
   }
}

##
## Given a raw value, write it out as a $bit-wide value.
##
## Inherits: $WaitingBits, $bits
##
sub lzw_raw_out
{
    local($raw) = @_;
    for ($b = 1; $b < $nextbump; $b <<= 1) {
	$WaitingBits .= ($raw & $b) ? '1' : '0';
    }
    while (length $WaitingBits >= 8) {
	&send_data_byte(unpack("C", pack("b8", $WaitingBits)));
	substr($WaitingBits, 0, 8) = '';
    }
}

##
## Flush out a byte to represent the remaining bits in $WaitingBits,
## if there are any.
## Inherits: $WaitingBits
##
sub lzw_flush_raw
{
    if (length $WaitingBits) {
	$WaitingBits .= "00000000"; ## enough padded 0's to make a byte
	&send_data_byte(unpack("C", pack("b8", $WaitingBits)));
	$WaitingBits = '';
    }
    &flush_data();
}

sub send_data_byte
{
    push(@out, @_);
    if (@out == 255) {
	print $FH pack("C256", 255, @out);
	@out = ();
    }
}

sub flush_data
{
    local($count) = scalar(@out);
    if ($count) {
	local($c2) = $count + 1;
	print $FH pack("C$c2", $count, @out);
	undef @out;
    }
}


sub error_xbm {
  # shit happens, so print an error xbm in that case
    print "Content-type: image/x-bitmap\n\n";
    print STDOUT <<EndOfXbm;
#define ErrorPic_width 48
#define ErrorPic_height 16
static char ErrorPic_bits[] = {
 0x00,0x00,0x00,0x00,0x00,0x00,0xff,0xfc,0xf0,0x03,0x0f,0x3f,0x03,0x8c,0x31,
 0x86,0x19,0x63,0x03,0x0c,0x33,0xcc,0x30,0xc3,0x03,0x0c,0x33,0xcc,0x30,0xc3,
 0x03,0x0c,0x33,0xcc,0x30,0xc3,0x03,0x0c,0x33,0xcc,0x30,0xc3,0x3f,0x8c,0x31,
 0xc6,0x30,0x63,0x03,0xfc,0xf0,0xc3,0x30,0x3f,0x03,0xcc,0x30,0xc3,0x30,0x33,
 0x03,0x8c,0x31,0xc6,0x30,0x63,0x03,0x8c,0x31,0xc6,0x30,0x63,0x03,0x0c,0x33,
 0x8c,0x19,0xc3,0xff,0x0c,0x33,0x0c,0x0f,0xc3,0x00,0x00,0x00,0x00,0x00,0x00,
 0x00,0x00,0x00,0x00,0x00,0x00};
EndOfXbm
}

1;

__END__

=pod

=head1 NAME

cnt.pl - This is a graphical counter that is called from the <IMG> tag.

=head1 SYNOPSIS

Syntax is:

  <IMG SRC="pathToScript/img_counter.pl/path/to/countedpage.gif">

or

  <IMG SRC="pathToScript/img_counter.pl/path/to/countedpage.xbm">

depending on wether you want a XBM or GIF image.

You should also supply a B<WIDTH> and a B<HEIGHT> tag.

The document to be counted has to be accessible under the url
"B<http://$ENV{'SERVER_NAME'}/path/to/countedpage.html>"

If you want a colored GIF image, you may append the hex rgb value
as the query-string (e.g. "?ff0080") or use one of the well-known
color names as mentioned in the HTML3.2 specification
(e.g. "?navy", "?red", "?blue").

The background remains transparent.

The script should be chmod 0755, the data file chmod 0666 or 0777.

=head1 README

This is a graphical web access counter that is called from the E<lt>IMGE<gt>
tag.
The only external resource is it's data file, meaning that no additional
modules are required.
It produces the count in GIF (colored) or XBM (black&white) format.

=head1 EXAMPLES

This counter is used on
  B<http://www.simprovement.com>

You may for example try

=item B<http://www.simprovement.com/cgi-bin/cnt.pl/index.gif?0>

for a black gif output,

=item B<http://www.simprovement.com/cgi-bin/cnt.pl/index.gif?red>

for a red gif output,

=item B<http://www.simprovement.com/cgi-bin/cnt.pl/index.xbm>

for an output in xbm format.

=head1 CAVEATS

Due to the nature of a script that has to be interpreted on each access,
this counter is only useful for sites with a low hit ratio.

=head1 BUGS

If you find any bugs or have suggestions, please mail the author.

=head1 COPYRIGHT

(c) 1998, 1999 by B<Soenke J. Peters> E<lt>peters@simprovement.comE<gt>

Routines to write a two-color GIF are "heavily inspired" by code
(c) by Jeffrey Friedl (jfriedl@omron.co.jp), most of the XBM stuff
has been taken from a perl script by ???.

=head1 AUTHOR

B<Soenke J. Peters> E<lt>peters@simprovement.comE<gt>
http://www.simprovement.com

=head1 SCRIPT CATEGORIES

CGI

=head1 PREREQUISITES

No CPAN modules required.

=head1 COREQUISITES

No optional CPAN modules needed.

=head1 OSNAMES

Hopefully C<any>.
This script has been tested on C<Linux> and misc. C<BSD> derivates.

=cut