#!/usr/bin/perl
use strict;

=head1 NAME

  WebAlbum v. 0.41 - Web (photo) Album generating script. 

=cut

# Simple Tags are those which do not require any special action, except noting their value. 
my %SIMPLE_TAGS = ( "INDEX", "TOP_DIR", "AUTHOR", "EMAIL", "HOME", "TITLE", 
		    "ABSTRACT", "COL_NUMBER", "CONVERT", "THUMBNAIL_DIM",
		    "PREVIEW_DIM", "MAX_FILE_SIZE", "IMAGE_LEGEND", 
		    "IMAGE_TYPE", "IMAGE_LINK", "TEXT_COLOR", "BG_COLOR",
		    "BG_IMAGE", "TAIL" 
		  );
# default values of some options, see the documentation 
# for explanation how to change them

my $DIR = qx/pwd/ ; $DIR =~ s/(.*)\n/$1/;
#my $INDEX_FILE="index.txt";

my %album = 
  ( 
   VERSION    => "v. 0.41",
   TEMPLATE      => "index.txt", # Name for index-template files. 
   INDEX      => "index.html", # Name of the (html) "index" files. I find index.shtml convenient...
   TOP_DIR     => $DIR,          # Main album directory 
   CONVERT    => "convert -interlace line",   # name of the "convert" program 
   AUTHOR     => "Denis Havlik, 1998,1999", # It's me! 
   EMAIL      => "havlik\@ap.univie.ac.at", # my e-mail
   HOME       => "http://www.ap.univie.ac.at/users/havlik/Downloads", # my home-page
   TITLE      => "WebAlbum v. 0.41",
   ABSTRACT   => "This script will help you to make a web-based photo album. Please read the html documentation for details. Newest version of the WebAlbum can be downloaded on my home-page. The script is a free software, published under GNU-licence.",
   TAIL       => '"<P><H1><A HREF=\"../$$hr{INDEX}\" TARGET=\"$TARGETS[0]\">UP</A>    <A HREF=\"$$hr{HOME}\" TARGET=\"$TARGETS[0]\">HOME</A></H1>\n<hr><address><a href=\"$$hr{HOME}\" TARGET=\"WebAlbum\">WebAlbum $$hr{VERSION}</a></address><hr>\n</P>\n"', 
   COL_NUMBER => 3,
   THUMBNAIL_DIM => "150x150", #new name for IMAGE_SIZE tag
   PREVIEW_DIM => "600x600",
   MAX_FILE_SIZE => "100k",
   IMAGE_COLSPAN => 1,
   IMAGE_LINK => '"<P><A HREF=\"$$hr{IMAGE_FILE}\" TARGET=\"$TARGETS[2]\">Original image ($img_size kb)</A></P>\n"',
   TEXT_COLOR => "black",
   BG_COLOR   => "silver",
   BG_IMAGE   => undef,
   IMAGE_TYPE	=> "jpg", 
   TARGETS => ",,newframe",
   TABLE_STYLE => "ALIGN=CENTER BORDER=1 CELLSPACING=10 CELLPADDING=10",
  );
#use CGI;
chdir $album{TOP_DIR} || die "cannot change the dir to $album{TOP_DIR}" ;

=head1 DESCRIPTION

=for html <P>

WebAlbum is a html photo-album generator written in perl. The "Album"
is divided into "chapters". "Chapters" consist of a title,
introductory text and an array of thumbnails (i.e. scaled-down
photos), possibly with legend. Each chapter "lives" in separate sub-directory
of the main "Album" directory. 
When run, "WebAlbum" starts searching the main directory, and sub-directories 
for "index.txt" templates. Based on the info found there, the script builds 
a main "album" html - page and "chapters" pages in the subdirectories. 
Furthermore, "Thumbnail"-s and possibly "preview"-s are produced "on the fly" 

=for html <strong>

if they do not exist allready.

=for html </strong>

If no "index-file" is found, a simple one is produced on-the-fly, too 
(see "QUICK START" below).

=for html </P><P>

Each Thumbnail can have a "legend" below it. 
Normaly, thumbnails are linked to original file, but if the original file is too large they are linked to a larger "preview" picture instead. 
(In this case, an additional link to original file appears below the legend.)  

=for html </P><P>

WebAlbum does not care about the formate of your images. However, you are efectively limited to formates known to "convert" (many, see the man page) and your web-browser. Independently on the format of your images, thumbnails and previews will all have the same format (per default jpg), which can be handy if your image-files cannot be seen with web-browsers (postscript, dvi, pdf,...)

=for html </P>

=head2 REQUIRES

This program is written in perl. Furthermore, it uses the "convert" program from ImageMagick package to produce thumbnails.  ImageMagick package can be found at: http://www.wizards.dupont.com/cristy/ImageMagick.html

=head2 QUICK START

In order to produce an album, you mast have: photos (!), an idea 
on what you want to say about them, perl interpretor, Image Magick 
and a web browser. 

=for html <ul><li>

Put the "WebAlbum.pl" in /usr/local/bin (or any other directory which is in your "PATH").

=for html </li><li>

Make a directory where your photo-album will live ("TOP"-directory). 

=for html </li><li>

Divide the photos into "chapters", make one sub-directory for each of the chapters, and fill these sub-directories with photos.

=for html </li><li>

Now change your working directory to "TOP" and start the "WebAlbum.pl". This
will produce simple templates files (index.txt) in each sub-directory and produce a simple album. 

=for html </li><li>

In order to customize your album, edit templates ("index.txt") files and run the "WebAlbum" again. Templates files are simple ASCII text consisting of "TAG=value" pairs, separated with empty lines.  Tags and possible values are described in the next chapter.

=for html </li></ul>

=head1 OPTIONS

At the moment, WebAlbum does not have any run-time options. Simply "cd" to the directory where your "album" lives and invoke the "WebAlbum". I will include some run-time options in the future (see TO DO section).

=head1 TAGS

Following tags are understood by the "WebAlbum" at the moment:

=head2 PREAMBLE TAGS

First group of the tags should be in the beginning of the index.txt file, i.e. before any photos:

=over 4

=item AUTHOR=your name, EMAIL=you@your.site, HOME=your home-page

Three optional tags with obvious function. Put them in the main index.txt file, or re-define them for each chapter as you please.

=for html <P></P>


=item TITLE=Title of the chapter/album : 

This tag should exist in every "index.txt". It sets the title for the chapter/album. Its value is usualy a plain ASCII text, although in principe you could add any HTML-tags to it. If not set, it defaults to name of the directory where the chapter lives.

=for html <P></P>

=item ABSTRACT=Abstract of the chapter/album : 

Use this tag to add some comments to the album/chapter. ASCII + HTML tags allowed. No default value. You can also use it in-between the picture-tags if you want to split the page in several tables.

=for html <P></P>

=item COL_NUMBER=number of columns in the chapter/album : 

Default number of columns in all the chapters is set to 3. If you want to change this value for all the chapters, add "WA_COLUMNS=N" to index.txt in the main album. the same entry in a chapters "index.txt" changes the number of columns for the current chapter.

=for html <P></P>

=item THUMBNAIL_DIM=NxM :

This tag determines the size of the thumbnails to be produced. N and M are maximal sizes of thumbnails in x and y direction respectively. Old name for this tag was "IMAGE_SIZE". Please note - this breaks a compatibility with pre 0.41 versions of the WebAlbum! If you have been using "IMAGE_SIZE" tag in WA 0.4 or earlier before, you will have to change all "IMAGE_SIZE" tags in "index.txt" files to "THUMBNAIL_DIM" yourself!!!

Although this tag usually sits in preamble section, you can also use it later, i.e. you can have differently-sized thumbnails in a single "chapter". In that case you will probably want to use the "IMAGE_COLSPAN" tag, too.
Thumbnails are produced by calling the "convert" program - one of the programs in the "ImageMagick" package. This package can be found at: http://www.wizards.dupont.com/cristy/ImageMagick.html

=for html <P></P>

=item PREVIEW_DIM=NxM :

This tag determines the preffered size for the preview image. For image-files smaller than MAX_FILE_SIZE, this tag has no effect at all.
In case the original photo is larget than MAX_FILE_SIZE, in addition to 
thumbnail, an "preview" picture is made, and thumbnail is linked to this 
picture instead of beeing linked to original picture. 
N and M are maximal sizes of preview in x and y direction respectively. 

In addition, a link to original is put below the legend. The look of this 
link can be tweaked by changing the IMAGE_LINK tag. 
It defaults to "<A HREF=\"\">Original image (size)</A>"

=for html <P></P>

=item MAX_FILE_SIZE=N(kb):

This tag determines the size of the original images at which "preview" 
image will be produced:  
In case the original photo is larget than MAX_FILE_SIZE, in addition to 
thumbnail, an "preview" picture (see PREVIEW_DIM) is made, and thumbnail 
is linked to this picture instead of beeing linked to original picture. 
"N" is file-size in kb. 

=for html <P></P>

=item IMAGE_TYPE=<TYPE>

This tag determines the image format for "thumbnails" and "preview" images. Default value is "jpg". I have decided to implement this tag after reading the slashdot article about GIF-patents on Aug. 30. 1999. Another good reason for this tag is that many of the formats known to "convert" program (like postscript, dvi...) are not supported by standard web browsers. Third thing is - "thumbnails" and "previews" should be as small as possible - one can always offer the huge original TIFF file for download to those who really want to download it, but for most of us, small jpg-s are quite sufficient. 

=for html <P></P>

=item TEXT_COLOR=color :

Optional tag for setting the textcolor. It can be put just about anywhere, but in my opinion it only makes sense in the preamble of the index.txt. If all you want is change the color in one sentence, use html tags. Default value is "black"

=for html <P></P>

=item BG_COLOR=color :

Optional tag for setting the background color. Default value is "silver"

=for html <P></P>

=item BG_IMAGE=file name

Optional tag for setting the background image. No default value.

=for html <P></P>

=item TARGETS=<FRAME0,FRAME1,FRAME2>

Optional tag for setting the frames-structure of the album. Three values correspond to frames used for table-of-contest, album and "big pictures" respectively. Default value is: "TARGETS=,,newframe", meaning "no frame, no frame, pop-up frame". If you do not want any pop-up windows, simply set this tag to "TARGETS=,,".

=for html <P></P>

=item TABLE_STYLE=<table format> 

Use this tag to change the table format. Any standard HTML-tag which is allowed in <TABLE> tag will do. Default value is "ALIGN=CENTER BORDER=1 CELLSPACING=10 CELLPADDING=10"

=for html <P></P>

=back

=head2 PHOTOS-RELATED TAGS

Following tags form the "body" of the photo albums: They determine which photos should be shown, how and where.

=over 4

=item BEGIN_IMAGES

This tag ends the PREAMBLE section. It must be present in the index.txt for every chapter. It has no meaning in the main index.txt file.

=for html <P></P>

=item IMAGE_FILE=file name

I strongly suspect this one to be rather obvious. Still: Every time you want an image to appear in a chapter of your album, you have to put a "IMAGE_FILE=file name" tag in index.txt. 

=for html <P></P>

=item IMAGE_LEGEND=text + html tags

If you put this tag before the "IMAGE_FILE" tag, the thumbnail will get a legend below it. Else, only a thumbnail is produced. 

=for html <P></P>

=item IMAGE_COLSPAN=integer

From time to time you might want to give more space to a particular thumbnail. Default value is 1, but it may be handy to change it to 2 or 3 for broader images. Also usefull if you temporary change size of thumbnails with "THUMBNAIL_DIM".

=for html <P></P>

=back

=head1 TO DO

  As it appears, I usually work on the script when someone complains... 
  If you want me to change anything, send me an e-mail. The list below
  is allready getting old, I have added a lot of other things to the script, 
  but these items remained untouched. If you want to do the changes yourself, 
  you are welcome to do so.

  - add sub-albums and/or page-splitting
  - add run-time switches, for instance:
  --thumbnails=force|no|standard  = to control thumbnails production
  --templates=(no|standard|rich) = to control authomatic templates production.
  -D --directory = to set the directory where the album lives

=cut
  
#@dirstat = stat($album{TOP_DIR});
#@filestat= stat($FILE);
#if ($filestat[10] >= $dirstat[10] ) { 
#  print "files in directory $album{TOP_DIR} are older than $FILE\n";
#  die "no need for update!\n";
#exit;
#}
  
  ;# ??

if (! -f "$album{TOP_DIR}/$album{TEMPLATE}") {
  warn "found no $album{TOP_DIR}/$album{TEMPLATE} file!\n";
  warn "Creating a simple one...\n";
  make_template($album{TOP_DIR},\%album);
}
open(IN,"<$album{TOP_DIR}/$album{TEMPLATE}")
  || die "cannot read $album{TOP_DIR}/$album{TEMPLATE}";
while (<IN>){
  parse_template($_, \%album);
}

open (M_OUT,">$album{INDEX}") || die "cannot open $album{INDEX} for write!";
&print_head(*M_OUT, \%album);
print M_OUT "<ul>\n";

opendir (TOP,$album{TOP_DIR}) || die "cannot read the directory $album{TOP_DIR}";


# Parse the $album{TOP_DIR} directory for subdirectories
# Every subdirectory is considered a chapter of the album, 
# Subdirectories must contain "$INDEX_FILE" file!!!
# Formate of the TEMPLATE files is explained in the documentation.

foreach my $SUB_DIR ( sort (readdir(TOP)) ) {
  # set defaults
  my %chapter =%album;
  my $i = $chapter{COL_NUMBER};
  $chapter{IMAGE_COLSPAN} = 1;
  $chapter{SUB_DIR} = $SUB_DIR;
  $chapter{TITLE} = $SUB_DIR;
  $chapter{ABSTRACT} =   "This page has been authomatically produced by WebAlbum $chapter{VERSION}. If you want to change the appereance, please edit <A HREF=\"./$chapter{TEMPLATE}\">$chapter{TEMPLATE} (template) file</A>.\n\n";    
  # find a template file or make one!
  if ( (-d $SUB_DIR) && !($SUB_DIR =~ /^\./)) {
    warn "Scanning sub-directory: $SUB_DIR... \n";
    if (! -f "$album{TOP_DIR}/$SUB_DIR/$chapter{TEMPLATE}") {
      warn "found no $album{TOP_DIR}/$SUB_DIR/$chapter{TEMPLATE} file!\n";
      warn "Creating a simple one...\n";
      make_template("$album{TOP_DIR}/$SUB_DIR",\%chapter);
    }
    open(IN,"<$album{TOP_DIR}/$SUB_DIR/$chapter{TEMPLATE}")
      || die "cannot read $album{TOP_DIR}/$SUB_DIR/$chapter{TEMPLATE}";
    while (<IN>) {
      parse_template($_, \%chapter);
      # BEGIN_IMAGES tag marks the end of the preamble. 
      # Now we can open the file for the new chapter, write its header 
      # and make a link to it in the main album page.
      if (/^BEGIN_IMAGES/) {
	my @TARGETS=split (",",$chapter{TARGETS});
	open(OUT,">$album{TOP_DIR}/$SUB_DIR/$chapter{INDEX}")
	  || die "cannot write to $album{TOP_DIR}/$SUB_DIR/$chapter{INDEX}";
	&print_head(*OUT, \%chapter);
	print OUT "<TABLE $chapter{TABLE_STYLE}>";
	print M_OUT "<li><A HREF=$SUB_DIR/$chapter{INDEX} TARGET=\"$TARGETS[1]\">$chapter{TITLE} </A></li>\n";
	$i = $chapter{COL_NUMBER};
      }
      if (s/^ABSTRACT=(.*)/$1/) {
	print OUT "\n</TABLE>\n";
	print OUT $1;
	print OUT "\n<TABLE $chapter{TABLE_STYLE}>\n";
      }
      s/^IMAGE_COLSPAN=(.*)/$1/ && ($chapter{IMAGE_COLSPAN} = $1)  
	&& ($i= $i- $chapter{IMAGE_COLSPAN}+1);
      if (s/^IMAGE_FILE=(.*)/$1/) {
	($i == $chapter{COL_NUMBER}) && print OUT "<TR>\n";
	$chapter{IMAGE_FILE}  = "$1";
	$chapter{IMAGE_LEGEND} = ($chapter{IMAGE_LEGEND} || $1);
	$i--;
	&add_photo(*OUT,\%chapter);
	$chapter{IMAGE_COLSPAN} = 1;
	$chapter{IMAGE_LEGEND}  = undef;
	if ($i <= 0) { 
	  $i=$chapter{COL_NUMBER};
	  print OUT "</TR>\n";
	}
      }
    }
    print OUT "\n</TABLE>\n";
    &print_tail(*OUT,\%chapter);
    close(IN);
    close(OUT);
  }
}
print M_OUT "</ul>\n<BR>\n";
&print_tail(*M_OUT,\%album);
######################################################################## 
#
#  Subroutines
#
######################################################################## 
#
#  header of the album/chapter
#
######################################################################## 
sub print_head {
  local *OUT = shift;
  my $hr = shift;
  print OUT <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
<HTML>
  <HEAD>
    <TITLE> $$hr{TITLE} </TITLE>
    <META NAME="GENERATOR" CONTENT="$0 $$hr{VERSION}">
    <META NAME="AUTHOR" CONTENT="$$hr{AUTHOR}">
    <META NAME="DESCRIPTION" CONTENT="Photo Album, $$hr{TITLE}">
    <META NAME="KEYWORDS" CONTENT="$$hr{AUTHOR} , Photo Album">
  </HEAD>
  <BODY TEXT="$$hr{TEXT_COLOR}" BGCOLOR="$$hr{BG_COLOR}" BACKGROUND="$$hr{BG_IMAGE}">
    <H1 ALIGN=CENTER>$$hr{TITLE}</FONT></H1>
    <HR WIDTH=75% ALIGN=CENTER SIZE=3>
    <P>$$hr{ABSTRACT}</P>
EOF
  return ; 
}
######################################################################## 
#
#  add a photo and legend to the "chapter"
#
######################################################################## 
sub add_photo {

  local *OUT = shift;
  my $hr = shift;

  my $DIR="$$hr{TOP_DIR}/$$hr{SUB_DIR}";
  my $IMAGE="$$hr{IMAGE_FILE}";
  my $TYPE = $$hr{IMAGE_TYPE};
  my @TARGETS=split (",",$$hr{TARGETS});
  my ($dev,$ino,$mode,$nlink,
      $uid,$gid,$rdev,$size,
      $atime,$mtime,$ctime,
      $blksize,$blocks)      =  stat("$DIR/$IMAGE");
  my $img_size= sprintf "%.1f", $size/1024;
  # we will surely need a thumbnail
  my $thumbnail = "$IMAGE" ; 
  $thumbnail =~ s/(.*)\..*/thumbnail_$1\.$TYPE/ ;
  # if image is too large, a preview is also nessesary
  my $preview = "$IMAGE";
  my $PREVIEW_EXISTS=0;
  if ($img_size > $$hr{MAX_FILE_SIZE}) {
    $preview =~ s/(.*)\..*/preview_$1\.$TYPE/ ;
    $PREVIEW_EXISTS=1;
  }
  #warn "$IMAGE size= $img_size kB\n";
  my $T1= -M "$DIR/$thumbnail";
  my $T2= -M "$DIR/$IMAGE";
  #warn "$DIR/$thumbnail: $T1\n $DIR/$IMAGE: $T2\n";
  
  if ( ! (-f "$DIR/$preview") ) {
    warn "$$hr{CONVERT} -geometry $$hr{PREVIEW_DIM} \"$DIR/$IMAGE\" \"$DIR/$preview\"\n";
    system "$$hr{CONVERT} -geometry $$hr{PREVIEW_DIM} \"$DIR/$IMAGE\[0\]\" \"$DIR/$preview\"\n";
  }
  ($dev,$ino,$mode,$nlink,
   $uid,$gid,$rdev,$size,
   $atime,$mtime,$ctime,
   $blksize,$blocks)      =  stat("$DIR/$preview");
  my $preview_size= sprintf "%.1f", $size/1024;
  if ( ! (-f "$DIR/$thumbnail") ) {
    warn "$$hr{CONVERT} -geometry $$hr{THUMBNAIL_DIM} \"$DIR/$preview\" \"$DIR/$thumbnail\"\n";
    system "$$hr{CONVERT} -geometry $$hr{THUMBNAIL_DIM} \"$DIR/$preview\[0\]\" \"$DIR/$thumbnail\"";
  }
  $IMAGE =~ s/\s/%20/g;
  $thumbnail =~ s/\s/%20/g;
  $preview =~ s/\s/%20/g;
# have to add link to big picture here!
  print OUT <<EOF;
<td colspan="$$hr{IMAGE_COLSPAN}" align="center" valign="top"><A HREF="$preview" TARGET="$TARGETS[2]" ><img src="$thumbnail" align="top" ALT="Click on the image to enlarge ($preview_size kB)"></A>
<P>$$hr{IMAGE_LEGEND}</P>
EOF
;
if ($PREVIEW_EXISTS) {print OUT eval ($$hr{IMAGE_LINK});};
print OUT "</TD>\n";
}

######################################################################## 
#
#  tail of the album/chapter You can customize it by setting 
#  the "TAIL" tag! Use $$hr{TAG} in order to access previously defined tags
#  in the "TAIL"!
#
######################################################################## 

sub print_tail {
  local *OUT = shift;
  my $hr = shift;
  my @TARGETS=split (",",$$hr{TARGETS});
  print OUT eval ($$hr{TAIL});
  print OUT <<EOF;
</BODY>
</HTML>
EOF
;
}

######################################################################## 
#
# This procedure gets called whenever a subdirectory withouth 
# a template for "INDEX" file is found, to produce a simple one. 
# It is a rather stupid procedure, but it may still be handy.
#
######################################################################## 
sub make_template {
  my $DIR = shift;
  my $hr = shift;
  opendir (DIR,$DIR) || die "cannot read the $DIR directory";
  open (INDEX, ">$DIR/$$hr{TEMPLATE}");
    print INDEX "TITLE=$$hr{TITLE}\n\n";
    print INDEX "ABSTRACT=$$hr{ABSTRACT}\n";
  foreach my $key (keys %$hr) {
    if (! ($key =~ /TITLE|ABSTRACT/)) { 
      print INDEX "#$key=$$hr{$key}\n\n";
    }
  }
  print INDEX "BEGIN_IMAGES\n\n";

  foreach my $FILE ( sort (readdir(DIR)) ) {
    if (-f "$DIR/$FILE") {
      print INDEX "IMAGE_LEGEND=$FILE\n";
      print INDEX "IMAGE_FILE=$FILE\n\n";
    }
  }
  close INDEX; close DIR;
}
######################################################################## 
#
# This procedure parses the template for the INDEX file. 
# 
#
######################################################################## 
sub parse_template {
  local $_ = shift;
  my $hr = shift;
  # simple tags only need to be saved.
  if (/^([A-Z_]+)=(.*)/) {
    my ($TAG,$VAL)=($1,$2);
    $$hr{$1}=$2;
  }
}

__END__
 CHANGESLOG:
v. 0.41 (Nov. 04, 1999)
 BUGFIX:
  found out how to get just a first page out of the multi-page document. 
  Thumbnails-production for multi-page docs should be much faster now. 
 NEW:
  added a third picture size. In case the original picture is really large, a 
  "preview" picture is produced in addition to "thumbnail". In this case, 
   thumbnail is linked to prewiev picture, and an additional link to 
   original picture appears below the legend. In order to get this working, 
   I had to add 3 more tags: "PREVIEW_DIM" "MAX_FILE_SIZE" and "IMAGE_LINK". 
 CHANGES:
   "IMAGE_SIZE" tag was misleading - therefore I have changed its name 
   to "THUMBNAIL_DIM". I have also changed "mini.*image(s)" to "thumbnail(s)" 
   everywhere in the code & documentation. 
   Note: this breaks the compatibility with pre 0.41 versions of the WA! 
 
v. 0.40 (Sep 18, 1999)
 BUG fixes: 
  problems with "TARGETS" tag
  better documentstion (I hope)
 NEW:
  better template-files generation!=> MUCH MORE USER-FRIENDLY!!!
v. 0.36 (Sep 13, 1999)
 BUG fixes:
  Standard "TAIL" tag fixed.
 NEW:
  added "QUICK START" to documentation
  changed default frames-configuration
v. 0.35 (Sep 9, 1999)
 BUG fixes: 
  spaces in file-names OK, 
  line starting with "#" == "comment"
 NEW: 
  works with "use strict" pragma (all variables are "my" or "local").
  "TARGETS" tag - controls the frame-structure
  "ABSTRACT" tag can be used more than once now! This way, several tables 
    can live in one chapter, separated by "ABSTRACT" TAGS. !!EXPERIMENTAL!!
  "TABLE_STYLE" tag. Change the table-style if you feel like it .-)
v. 0.34 (Sep 03, 1999)
 BUG-fix: 
  conversion of multi-image formates into single image thumbnails 
  (such as ".ps" or animated gifs -> ".jpg" now (correctly) 
   produces a thumbnail of a FIRST image found in the starting file.
 NEW: 
   simple index-file generation

v. 0.33 (Aug 30, 1999)
 NEW: 
   starting with this version, thumbnails are 
   all of the same type, per default "jpg"

v. 0.32 (Aug 02, 1999)
   BUG-fixes: fixed the "TEXT_COLOR" attribute 
   and documentation of "IMAGE_LEGEND" and "IMAGE_FILE" tags.
   (by L.J. Casimir Prikockis <alaric@eclipse.net>)

v. 0.31 (Jul 09, 1999)
 BUG-fix: 
   image-sizes calculation fixed.

v. 0.3  (Jul 06, 1999)  - First public release 
