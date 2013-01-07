## make_news_site Version 0.02

## RELEASE NOTES
## 0.01->0.02 : Reversed the article numbering to make updating easier.

## This perl script is released under the GNU GPL Version 2 which can be found at
## http://www.gnu.org/copyleft/gpl.html. 
## Copyright (C) 1998 Simon Damberger <simon.damberger@idt-ltd.com>

## This perl script creates a news site from a database with the following format:
## Date/Time Stamp|URL|Headline|Abstract of article. So a sample database would look
## like the following:

## 11/19|http://www.microsoft.com|Microsoft Implodes Due to the Size of Windows 2000|Blah blah blah.
## 11/20|http://www.freshmeat.com|FreshMeat Gets Fresh|Using a new virtual deodorizer...
## 11/20|http://www.concentric.net/~damberge/news/|MouseOver News|Check out this site!

## The perl script parses the database and spits out a bunch of news articles as
## well as a file currently hard coded to be called f_left.html. When your mouse
## hovers over the article link in f_left.html then the proper news article is 
## pulled out of the (once again) hardcoded articles directory and plopped into
## the f_uright frame. This site should use the following index.html file:

## <html>
## <head>
## </head>
## <frameset cols="437,*" border=0>
##  <frame src="f_left.html" name="left">
##  <frameset rows="250,*" border=0>
##   <frame src="f_uright.html" name="uright">
##   <frame src="f_lright.html" name="lright">
##  </frameset>
## </frameset>
## <body bgcolor="DDDDE0" vlink= "1111AA" link="1111AA">
## </body>
## </html>

## You can put any thing you like into the f_lright.html file and, of course, you
## can change the sizes of all the frames. Don't like frames? Then send me something
## better at simon.damberger@idt-ltd.com. Also, add a f_uright.html file to the site
## as well. It should be some sort of introductory message, or not.

## ---CODE STARTS HERE---

## MASTER VARIABLES
$FileNumber = 0;
$HeaderFile = "mouseover2.jpg";

## Open up the database file (which is currently called database in the current
## directory.
open(DBFILE, "database") || die "Couldn't find database\n";

open(MAINFILE, "> f_left.html") || die "Couldn't create f_left.html";

## Count the number of lines and then move back to the start of the database file.
while ($line = <DBFILE>)
{
   $FileNumber++;
}
close(<DBFILE>);
open(DBFILE, "database") || die "Couldn't find database\n";

## Add the JavaScript mouseOver function and basic html to f_left.html.
print MAINFILE "<html><head><script language=\"JavaScript\"> function updateit(status,url) {if(status != 0) {parent.uright.location.href=\'articles/\' + url\; } else { parent.uright.location.href=\'f_uright.html\'\;}}</script></head>\n";
print MAINFILE "<body bgcolor=\"DDDDE0\" vlink=\"111166\" link=\"111166\">\n";
print MAINFILE "<center><img src=\"$HeaderFile\"></center><table border=0 width=99%>\n";

## The main loop pulls a line out of the database and then makes a news file and
## a table entry into f_left.html.
while ($line = <DBFILE>)
{
   &makenewsfile($line, $FileNumber);
   &maketableentry($line, $FileNumber);
   $FileNumber--;
}

## Finish off f_left.html so we have a valid html file.
print MAINFILE "</table></body></html>";
close(MAINFILE);

## Simple, simple, simple news file abstract.
sub makenewsfile
{
   local($line, $filenumber) = @_;

   ( $timedate, $link, $headline, $description ) = split(/\|/, $line);

   $blah = "> articles/" . $filenumber . ".html";
   open(NEWSFILE, $blah) || die "Couldn't create newsfile"; 
   print NEWSFILE "<html>\n";
   print NEWSFILE "<head>\n";
   print NEWSFILE "</head>\n";
   print NEWSFILE "<body>\n";

   print NEWSFILE "<h2>" . $headline . "</h2>\n"; 
   print NEWSFILE $description;

   print NEWSFILE "</body>\n";
   print NEWSFILE "</html>\n";
}

## Here is where the table entry is created and the mouseOver link is implemented.
sub maketableentry
{
   local($line, $filenumber) = @_;

   ( $timedate, $link, $headline, $description ) = split(/\|/, $line);

   print MAINFILE "<tr><td>" . $timedate . "</td><td>\n<a target=\"_top\" href=\"" . $link . "\" onMouseover=\"updateit(1,\'" . $filenumber . ".html\'\)\"><b>" . $headline . "</b></a>\n</td></tr>\n";
}