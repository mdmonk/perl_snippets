#!/usr/bin/perl -w

# gallery.pl v170 (c) 2005 Darxus@ChasoReigns.com
# http://www.chaosreigns.com/code/dxgallery/
# Released under the GPL.  
# The accompanying *frame_*.png images are not, however you are welcome
# to use them with gallery.pl without modifying the images or the script.
#
# Creates a statically rendered (html) image gallery.
# Example output:  http://www.chaosreigns.com/gallery/
# Reqires the Perl::Magick and Image::EXIF perl modules.
# (Debian packages: libimage-exif-perl perlmagick)

# Example usage ssuming the web root of your site is contained in
# ~/public_html/ and the images you want to use and dxgallery.tar.gz are
# in ~/:
# 
#  tar -zxvf frames.tar.gz
#  mkdir -p ~/public_html/frame/ ~/public_html/gallery/large/
#  cp -a dxgallery/*.png ~/public_html/frame/
#  cp -a *.jpg ~/public_html/gallery/large/
#  cd ~/public_html/gallery/
#  ~/dxgallery.pl
#
# Will create:
# * ~/public_html/gallery/medium/ directory containing images with
#   $medium pixels.
# * ~/public_html/gallery/small/ direcotory containing images with
#   $small pixels.
# * ~/public_html/gallery/index.html displaying small images (thumbnails)
#   with descriptions, #   as links to the medium images.
#
# Optional:
#  To get descriptions under your pictures, create a file called
#  config/index.txt, with 1 line for each image, containing the filename,
#  a space, and then the description., and a file named
#  config/monthindex.txt for your month descriptions.
#
# Features:
# * Consistant pixel count among generated images (based on
#   http://www.chaosreigns.com/code/thumbnail/).
# * Resolution independant index layout (using css floating <div>s).
#   (None of this "Best if viewed at XxY." garbage.)
# * Completely static output - can be generated on one machine and hosted
#   on another that only serves static content.
# * Written in perl.
# * Updates small & medium images based on file timestamps.
# * Shows exif timestamps in image display page 
#   (inspired by http://linux.kaybee.org/tabs/autoscrapbook/)
# * Use (link to) originals instead of generating new images if the
#   resolution to generate is smaller then or equal to the original
#   resolution
# * Supports all ("over 87 major") image formats supported by imagemagick 
#   (http://www.imagemagick.org/www/formats.html)
# * Conforms to XHTML 1.0 Transitional.
#
# I strongly recommend running "jhead -dt *" in small/ to strip out
# exif thumbnails (tends to reduce filesize by half, and thumbnails
# really don't need to contain an extra thumbnail).
# (http://www.sentex.net/~mwandel/jhead/)
#
#
# Thanks to darkspur for the css layout method.
#
# todo:
# (inspired by http://linux.kaybee.org/tabs/autoscrapbook/:)
# * use exif thumbnails if exif or exiftags are available but imagemagick isn't
# * handle absence of exif
#
# * move index/month.html to month/index.html ?
# * work without exif
# * merge %cache into %data
#
# done:
# * width/height values for thumbnails
# * chmod go+r stuff that the public should be able to read
# * prev/next links in month indexes
# * month link in image page
# * readdir instead of globbing
# * fail if large/ doesn't exist
# * main footer defined by text file
#
# bugs:
# * prev/next thumbnails will break if original is <= small size
#
# Version history:
# 167 20766 Nov 12 23:22  Initial public release.
# 168 20901 Nov 13 14:50  Replaced center with css.
# 169 20952 Nov 13 15:14  Fixed unsightly wrapping.
# 170 21840 Dec 08        XHTML Strict

#
# (version, bytes, date, description)

my $version = '170';

use strict;
use Date::Parse;
use Image::Magick;
use Image::EXIF;

my $medium = "640x480"; # configuruable main image display size
my $small = "100x100";  # configurable thumbnail size
my $framedir ='/frame'; # location of frame images relative to web root
#my $comments = "<a href='/cgi-bin/referercomment.cgi'>Comments</a>";
my $comments = "";

my $debug = 0;
my $publicmode = 0644; # the 0 at the beginning, and lack of quotes, is very important
my $publicmodedir = 0755; # the 0 at the beginning, and lack of quotes, is very important
my $maxoffset = 3;  # number of previous / next thumbnails to display
#my $doctype = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">';
#my $doctype = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">';
my $stylesheet = "/light.css";
#my $body = "<body bgcolor='#D7D7D7' text='#000000'><div>";
my $body = "<body><div>";
#my $doctype = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">';
my $doctype = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">';
my $footer = "<small>Generated by <a href='http://www.ChaosReigns.com/code/dxgallery/'>dxgallery</a> v$version.</small>";

# You probably don't want to change anything else beyond here.

my $dupeindex = 1; # should be 1 unless padding indexes for demos

$| = 1; # do not buffer output

my ($mwidth,$mheight) = split(/\D/,$medium);
my ($swidth,$sheight) = split(/\D/,$small);

my $mpixels = $mwidth * $mheight;
my $spixels = $swidth * $sheight;

undef $mwidth;
undef $mheight;
undef $swidth;
undef $sheight;

my $tablewidth = $maxoffset*2+1;
my $cellpercent = int(100 / $tablewidth)+1;
my @images;
my %imagedesc;
my %monthdesc;
my %html;
my %data;
my %cache;
my %monthnav;

my %monthname = (
  1, 'January',
  2, 'February',
  3, 'March',
  4, 'April',
  5, 'May',
  6, 'June',
  7, 'July',
  8, 'August',
  9, 'September',
  10, 'October',
  11, 'November',
  12, 'December'
);

#my $basedir = `$pwd`;
my $basedir = $ENV{'PWD'};
chomp $basedir;

unless (-d "$basedir/large" ) {
  die "Error: the directory $basedir/large/ does not exist.\n";
}

open(IN,"<$basedir/config/index.txt") or print STDERR "Could not read $basedir/config/index.txt: $!\n";
while (my $line = <IN>) {
  chomp $line;
  next if ($line =~ m#^s*$#);
  my ($name,$desc) = split(' ',$line,2);
  $imagedesc{$name} = $desc;
}
close IN;
open(IN,"<$basedir/config/monthindex.txt") or print STDERR "Could not read $basedir/config/monthindex.txt: $!\n";
while (my $line = <IN>) {
  chomp $line;
  my ($name,$desc) = split(' ',$line,2);
  $monthdesc{$name} = $desc;
}
close IN;

chdir "$basedir/large" or print STDERR "Could not chdir $basedir/large: $!\n";

for my $outdir ('medium','small','index','config') {
  unless (-d "$basedir/$outdir") {
    mkdir("$basedir/$outdir") or die "Could not mkdir $basedir/$outdir: $!\n";
  }
  chmod $publicmodedir, "$basedir/$outdir";
}

chmod $publicmodedir, "$basedir";
chmod $publicmodedir, "$basedir/large";


if (-e "$basedir/config/sizecache.txt") {
  print "Reading cache.\n";
  open (SIZECACHE,"<$basedir/config/sizecache.txt") or print STDERR "Could not read $basedir/config/sizecache.txt: $!\n";
  while (my $line = <SIZECACHE>) {
    my ($image,$width,$height,$stamp,$ltime) = split(' ',$line);
    $cache{$image}{width} = $width;
    $cache{$image}{height} = $height;
    $cache{$image}{ltime} = $ltime;
    $cache{$image}{stamp} = $stamp;
  }
  close SIZECACHE;
} else {
  print "No $basedir/config/sizecache.txt found.\n";
}


print "Reading file info:";

my $imagefh=Image::Magick->new;
opendir(LARGEDIR, "$basedir/large") or die "can't opendir $basedir/large: $!";
for my $image (readdir LARGEDIR) {
  next if ($image eq '.' or $image eq '..');
  my $width;
  my $height;
  my $taken;
  next if ($image eq 'index.html');
  next unless (-f "$basedir/large/$image");
  my $ltime = (stat("$basedir/large/$image"))[9];
  $imagedesc{$image} = $image unless $imagedesc{$image};
  if (($cache{$image}{ltime}) and $ltime == $cache{$image}{ltime}) {
    $width = $cache{$image}{width};
    $height = $cache{$image}{height};
    $data{$image}{stamp} = $cache{$image}{stamp};
  } else {
 
    
    my $exif = new Image::EXIF("$basedir/large/$image");
    my $image_info = $exif->get_image_info(); # hash reference
    $taken = ${$image_info}{'Image Created'};
    undef $exif;

    ($width, $height) = $imagefh->Ping("$basedir/large/$image") or print STDERR "Image::Magick::Ping failed on $basedir/large/$image: $!\n";
    if (!$width or !$height)
    {
      print STDERR "\nCould not get width or height for $basedir/large/$image.\n";
      next;
    } else {
      print '*';
    }

    my $takenstamp = 0;
    if ($taken)
    {
      $data{$image}{stamp} = str2time($taken);
    } else {
      $data{$image}{stamp} = 9999999999999;
    }

  }
  
  $data{$image}{width} = $width;
  $data{$image}{height} = $height;
  ($data{$image}{swidth}, $data{$image}{sheight}) = &conscale($width,$height,$spixels);
}
undef $imagefh;
closedir LARGEDIR;
print "\n";
undef %cache;

for my $image (sort {$data{$a}{stamp} <=> $data{$b}{stamp} } keys %data) {
  push(@images,$image);
}

my $maxtaken = "";
my $maxtakenstamp = 0;
print "Scaling images.\n";
open SIZECACHE, ">$basedir/config/sizecache.txt.tmp" or print STDERR "Could not write $basedir/config/sizecache.txt.tmp: $!\n";
for my $imagenum (0 .. $#images)
{
  my $image = $images[$imagenum];
  my $firstnum;
  my $lastnum;
  my $width = $data{$image}{width};
  my $height = $data{$image}{height};
  my $takenstamp = $data{$image}{stamp};
  my $taken;
  my $sfile;
  my $mfile;
  my $imagefh = new Image::Magick;
  my $ltime = (stat("$basedir/large/$image"))[9];
  if ($takenstamp and $takenstamp != 9999999999999) {
    $taken = scalar(localtime($takenstamp));
  }
  print "$image ";
  if (defined $takenstamp and defined $maxtakenstamp and $takenstamp > $maxtakenstamp)
  {
    $maxtakenstamp = $takenstamp;
    $maxtaken = $taken;
  } 

  my $lpixels = $width * $height;
  print "${width}x${height}";
  if ($lpixels <= $mpixels)
  {
    $mwidth = $width;
    $mheight = $height;
    $mfile = "large/$image";
    print " ${mwidth}x${mheight}";
    chmod $publicmode, "$basedir/large/$image";
  } else { 
    ($mwidth, $mheight) = &conscale($width, $height, $mpixels);
    print " ${mwidth}x${mheight}";
    unless (-s "$basedir/medium/m_$image" and (stat("$basedir/medium/m_$image"))[9] >= $ltime )
    {
      if ($debug)
      {
        my $mtime = (stat("$basedir/medium/m_$image"))[9];
        print "medium $mtime >= $ltime\n" if $debug;
      }
      &resize($mwidth,$mheight,"$basedir/large/$image","$basedir/medium/m_$image");
    }
    chmod $publicmode, "$basedir/medium/m_$image";
    $mfile = "medium/m_$image";
  }

  if ($lpixels <= $spixels)
  {
    $swidth = $width;
    $sheight = $height;
    $sfile = "large/$image";
    print " ${swidth}x${sheight}";
    chmod $publicmode, "$basedir/large/$image";
  } else {
    ($swidth,$sheight) = &conscale($width,$height,$spixels);
    print " ${swidth}x${sheight}";
    unless (-s "$basedir/small/s_$image" and (stat("$basedir/small/s_$image"))[9] >= $ltime )
    {
      if ($debug)
      {
        my $stime = (stat("$basedir/small/s_$image"))[9];
        print "small $stime >= $ltime\n";
      }
      &resize($swidth,$sheight,"$basedir/large/$image","$basedir/small/s_$image");
    }
    chmod $publicmode, "$basedir/small/s_$image";
    $sfile = "small/s_$image";
  }
  print "\n";

  $html{$image}{html} = "<div class='float'>
".&tnframe("../$image","../$sfile",$swidth,$sheight)."$imagedesc{$image}
</div>\n\n";

  $html{$image}{time} = $takenstamp;

  if ($images[$imagenum - 1])
  {
    $firstnum = $imagenum - 1;
  } else {
    $firstnum = $#images;
  }
  if ($images[$imagenum + 1])
  {
    $lastnum = $imagenum + 1;
  } else {
    $lastnum = 0;
  }

  open(IMAGEPAGE,">$basedir/$image.html");
  $taken = '' if (!defined $taken);
  my $month = &time2month($takenstamp);
  print IMAGEPAGE "$doctype
<html><head>
<meta name='generator' content='dxgallery v$version, http://www.chaosreigns.com/code/dxgallery/' />
<title>$image</title>
<link rel='up' href=\"index/$month.html\" />
<link rel='prev' href=\"". $images[$firstnum] .".html\" />
<link rel='next' href=\"". $images[$lastnum] .".html\" />
<link rel='StyleSheet' href=\"$stylesheet\" type=\"text/css\" />
<style type=\"text/css\">
body { text-align: center;}
img { border-style:none;}
td {text-align: center;}
body { text-align: center;}
table {
  margin-left: auto;
  margin-right: auto;
}
img {display: block;}
.inline {display: inline;}
</style>
</head>
$body
<table border='0' cellspacing='0' cellpadding='0'>
<tr>
<td colspan='$maxoffset' valign='top' style='text-align:right'><a href=\"". $images[$firstnum] .".html\">previous</a></td>
<td valign='top'><a href=\"index/$month.html\">index</a></td>
<td colspan='$maxoffset' valign='top' style='text-align:left'><a href=\"". $images[$lastnum] .".html\">next</a></td>
</tr>
<tr><td colspan='$tablewidth'>


<table border='0' cellspacing='0' cellpadding='0'>
<tr>
<td><img src=\"$framedir/mframe_tl.png\" width='8' height='8' alt=\"\" /></td>
<td><img src=\"$framedir/mframe_t.png\" width='$mwidth' height='8' alt=\"\" /></td>
<td><img src=\"$framedir/mframe_tr.png\" width='8' height='8' alt=\"\" /></td>
</tr>
<tr>
<td><img src=\"$framedir/mframe_l.png\" width='8' height='$mheight' alt=\"\" /></td>
<td><img src=\"$mfile\" width='$mwidth' height='$mheight' alt=\"$image\" /></td>
<td><img src=\"$framedir/mframe_r.png\" width='8' height='$mheight' alt=\"\" /></td>
</tr>
<tr>
<td><img src=\"$framedir/mframe_bl.png\" width='8' height='8' alt=\"\" /></td>
<td><img src=\"$framedir/mframe_b.png\" width='$mwidth' height='8' alt=\"\" /></td>
<td><img src=\"$framedir/mframe_br.png\" width='8' height='8' alt=\"\" /></td>
</tr>
</table>

</td></tr>";

  print IMAGEPAGE "<tr><td colspan='$tablewidth'>$imagedesc{$image}<small> (#". scalar($imagenum+1) . "/" . scalar(@images) .", $taken) $comments</small></td></tr><tr>\n\n";
  for my $offset ((reverse(1 .. $maxoffset))) {
    if ($imagenum - $offset >= 0) {
      my $thumbnail = $images[$imagenum-$offset];
      print IMAGEPAGE "<td style='width:".int($spixels/75)."px' valign='top'>
".&tnframe("$thumbnail","small/s_$thumbnail",$data{$thumbnail}{swidth},$data{$thumbnail}{sheight})."</td>\n";
    } else {
      print IMAGEPAGE "<td style='width:".int($spixels/75)."px'></td>";
    }
  }
  print IMAGEPAGE "<td style=\"width:90px\" valign='middle'><a href=\"index/$month.html\">month index</a><br /><a href=\".\">main index</a></td>\n";
  for my $offset (1 .. $maxoffset) {
    if ($imagenum + $offset <= $#images) {
      my $thumbnail = $images[$imagenum+$offset];
      print IMAGEPAGE "<td style='width:".int($spixels/75)."px' valign='top'>
".&tnframe("$thumbnail","small/s_$thumbnail",$data{$thumbnail}{swidth},$data{$thumbnail}{sheight})."</td>\n";
    } else {
      print IMAGEPAGE "<td style='width:".int($spixels/75)."px'></td>";
    }
  }
  print IMAGEPAGE "</tr></table></div></body></html>";

  close IMAGEPAGE;
  chmod $publicmode, "$basedir/$image.html";
  print SIZECACHE "$image $width $height $data{$image}{stamp} $ltime\n";
}
close SIZECACHE;
rename "$basedir/config/sizecache.txt.tmp", "$basedir/config/sizecache.txt" or print STDERR "Could not rename sizecache.txt.tmp to sizecache.txt: $!\n";

my %imagecount;
for my $image (keys %data) {
  my $month = &time2month($data{$image}{stamp});
  $imagecount{$month}++;
}


my @months = (sort keys %imagecount);
for my $month (0 .. $#months) {
  my $printmonth = '';
  my $year = '';
  my $monthnum;
  open (OUT,">$basedir/index/$months[$month].html") or print STDERR "Could not write to $basedir/index/$months[$month].html: $!\n";
  if ($months[$month] =~ m#^(\d{4})(\d{2})$#) {
    $year = $1;
    $monthnum = $2;
    $printmonth = $monthname{int($monthnum)} or print STDERR "unknown month: $monthnum\n";
  } else {
    $year = "unknown";
    $printmonth = '';
  }
  $monthdesc{$months[$month]} = '' if (!defined($monthdesc{$months[$month]}));
  print OUT "$doctype
<html><head>
<meta name='generator' content='dxgallery v$version, http://www.chaosreigns.com/code/dxgallery/' />
<title>$printmonth $year: $monthdesc{$months[$month]}</title>
<link rel='StyleSheet' href=\"$stylesheet\" type=\"text/css\" />
<style type=\"text/css\">
div.float {
  float: left;
  width: ".int($spixels/55)."px;
  height: ".int($spixels/55)."px;
  vertical-align: middle;
  padding: 5px;
  text-align: center;
  overflow: auto
}
td {text-align: center;}
body { text-align: center;}
img { border-style:none;}
table {
  margin-left: auto;
  margin-right: auto;
}
img {display: block;}
.inline {display: inline;}
</style>
</head>
$body\n";
  $monthnav{$month} .= "<table border='0'><tr><td style='width:130px' align='right'>";
  if ($month > 0) { 
    my $previous = $months[$month-1];
    $monthnav{$month} .= "<a href=\"$previous.html\">previous</a>\n";
  }
  $monthnav{$month} .= "</td><td style='width:130px'><a href=\"../\">main index</a></td><td style='width:130px' align='left'>\n";
  if ($month < $#months) { 
    my $next = $months[$month+1];
    $monthnav{$month} .= "<a href=\"$next.html\">next</a>\n";
  }
  $monthnav{$month} .= "</td></tr></table>\n";
  print OUT $monthnav{$month};
  print OUT "$printmonth $year: $monthdesc{$months[$month]}\n";
  print OUT "<hr /><div><table cellpadding='0' cellspacing='0' border='0' style='width:100%'><tr><td>\n\n";
  close OUT;
}

for (1 .. $dupeindex) {
  for my $image (sort {$html{$a}{time} <=> $html{$b}{time}} keys %html) {
    my $outpage;
    $outpage = &time2month($html{$image}{time});
    open (OUT,">>$basedir/index/${outpage}.html") or print STDERR "Could not write to $basedir/index/${outpage}.html: $!\n";
    print OUT $html{$image}{html};
    close OUT;
  }
}


for my $month (0 .. $#months) {
  open (OUT,">>$basedir/index/$months[$month].html") or print STDERR "Could not write to $basedir/index/$months[$month].html: $!\n";
  print OUT "</td></tr></table><hr />$monthnav{$month}<div class='right'>$footer</div></div></div></body></html>\n";
  #print OUT "</table>$monthnav{$month}</center></div></body></html>\n";
  close OUT;
  chmod $publicmode, "$basedir/index/$months[$month].html";
}






open (OUT,">$basedir/index.html") or print STDERR "Could not write to $basedir/index.html: $!\n";
print OUT "$doctype
<html>
<head>
<meta name='generator' content='dxgallery v$version, http://www.chaosreigns.com/code/dxgallery/' />
<title></title>
<style type=\"text/css\">
body {
  background: #D7D7D7;
  color: #000000;
  font-family: sans-serif;
}
div.right { text-align: right; }
</style>
</head>$body
<table border=\"1\">
<tr><th>Month (YYYYMM)</th><th></th><th>Description</th></tr>\n";
for my $outpage (sort keys %imagecount) {
  print OUT "\n<tr><td><a href=\"index/${outpage}.html\">$outpage</a></td><td align=\"right\">$imagecount{$outpage}</td>";
  if (defined ($monthdesc{$outpage})) {
    print OUT "<td><a href=\"index/${outpage}.html\">$monthdesc{$outpage}</a></td>";
  }
  print OUT "</tr>";
}
print OUT "\n</table>";
if (-e "$basedir/config/mainfoot.txt") {
  open IN,"<$basedir/config/mainfoot.txt" or print STDERR "Could not read $basedir/config/mainfoot.txt: $!\n";
  print OUT <IN>;
}
print OUT "<hr /><div class='right'>$footer</div></div></body></html>\n";
close OUT;
chmod $publicmode, "$basedir/index.html";

exit;
###################################################################

# consistent pixel scaling
sub conscale {
  my ($width, $height, $pixels) = @_; # input width and height, output pixels
  my $new_width = int($width / (sqrt($width * $height) / sqrt($pixels)));
  my $new_height = int($height / (sqrt($width * $height) / sqrt($pixels)));
  return ($new_width, $new_height);
}

# take unix timestamp as input and return YYYYMM or "unknown"
sub time2month {
  my $time = shift;
  my $month;
  if (!defined($time) or $time == 9999999999999) {
    $month = 'unknown';
  } else {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
    $year += 1900;
    $mon += 1;
    $month = sprintf("%d%02d",$year,$mon);
  }
  return $month;
}

sub tnframe {
my ($image,$sfile,$swidth,$sheight) = @_;
return "<table border='0' cellspacing='0' cellpadding='0'>
<tr>
<td><img src=\"$framedir/sframe_tl.png\" width='8' height='8' alt=\"\" /></td>
<td><img src=\"$framedir/sframe_t.png\" width='$swidth' height='8' alt=\"\" /></td>
<td><img src=\"$framedir/sframe_tr.png\" width='8' height='8' alt=\"\" /></td>
</tr>
<tr>
<td><img src=\"$framedir/sframe_l.png\" width='8' height='$sheight' alt=\"\" /></td>
<td><a href=\"$image.html\"><img src=\"$sfile\" width=\"$swidth\" height=\"$sheight\" alt=\"$image\" /></a></td>
<td><img src=\"$framedir/sframe_r.png\" width='8' height='$sheight' alt=\"\" /></td>
</tr>
<tr>
<td><img src=\"$framedir/sframe_bl.png\" width='8' height='8' alt=\"\" /></td>
<td><img src=\"$framedir/sframe_b.png\" width='$swidth' height='8' alt=\"\" /></td>
<td><img src=\"$framedir/sframe_br.png\" width='8' height='8' alt=\"\" /></td>
</tr>
</table>\n";
}

#sub tnframe {
#my ($image,$sfile,$swidth,$sheight) = @_;
#return "
#<img src=\"$framedir/sframe_tl.png\" width='8' height='8' alt=\"\" />
#<img src=\"$framedir/sframe_t.png\" width='$swidth' height='8' alt=\"\" />
#<img src=\"$framedir/sframe_tr.png\" width='8' height='8' alt=\"\" />
#<br>
#
#<img src=\"$framedir/sframe_l.png\" width='8' height='$sheight' alt=\"\" />
#<a href=\"$image.html\"><img src=\"$sfile\" width=\"$swidth\" height=\"$sheight\" alt=\"$image\" border='0' /></a>
#<img src=\"$framedir/sframe_r.png\" width='8' height='$sheight' alt=\"\" />
#<br>
#
#<img src=\"$framedir/sframe_bl.png\" width='8' height='8' alt=\"\" />
#<img src=\"$framedir/sframe_b.png\" width='$swidth' height='8' alt=\"\" />
#<img src=\"$framedir/sframe_br.png\" width='8' height='8' alt=\"\" />
#<br>
#\n";
#}

sub resize {
  my ($width,$height,$infile,$outfile) = @_;
  my $resizeimage=Image::Magick->new;
  $resizeimage->Read($infile);
  $resizeimage->Resize(width=>$width,height=>$height);
  $resizeimage->Write(filename=>$outfile);
  undef $resizeimage;
}
