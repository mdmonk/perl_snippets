#!/usr/bin/perl
#
# If you want to use this code with my consent, then you must include
# this message:
# This code was made for my website and my private use
# I do not consider it stable or finnished. It still has
# bugs and may need some changing to work in your configuration.
# Use at your own risk.
# C. 2003, 2004, 2005. Jason Kenney.

use CGI qw(:standard);
#----------------------
# Initialize variables
# These variables will be changed when
# the site moves
# Mostly the files come as such...
# vars: These are for simple text for intro sections and
# for my links.
# files: They are my files separated by where in the site menu
# they will be listed.
#----------------------
$var = "var=\"on\"";
$webdir = "<a href=\"http://www.cs.hartford.edu/~jkenney/files/";
&#36;vardir = "../vars/";
&#36;filedir = "../files/";

#-----------------
# Flash loads information into variables used in
# actionscript. With the way the file dir is
# structured each directory in files is a variable
# name that will contain the list of files in its
# directory. Stories for example has all my stories.
# The text is loaded as html content, and so I put html
# tags in here.
#---------------------
@vars = `ls &#36;filedir`;
while(@vars) &#123;
&#36;dir = pop(@vars);
chomp(&#36;dir);
&#36;y = &#36;filedir . &#36;dir;
@list = `ls &#36;y`;
#Flash separates variables by the '&'.
&#36;var = &#36;var . "&" . &#36;dir . "=";
@list = reverse @list;
while(@list) &#123;
&#36;file = pop(@list);
chomp(&#36;file);
#----------
# If I put a file called intro then
# It tags the text contained in it
# to the top of the file list
#--------------
if(&#36;file eq "intro") &#123;
&#36;y = &#36;filedir . &#36;dir . "/intro";
open(FH, &#36;y);
while(<FH>) {
#------------------------
# Flash takes variable strings with no spaces
# instead a '+' denotes a whitespace
# And it also doesnt like newlines so I put
# A <br> instead
#--------------------
tr/ /+/;
s/\n/<br>/;
$var = $var . $_;
}
}
else {
#-----------------------
# A cosmetic cleanup
# This code changes the filename to be displayed
# without the extension
# Then puts the extension
# inside a pair of ().
# Just makes it look better
#---------------------
$_ = $file;
tr/./:/;
($_, $ext) = split(/:/,$_);
#--------------
# Again change spaces to '+'
# And it embeds the file name (with ext)inside a html link
# and then concatonates it to var
#-----------------------------
tr/ /+/;
$x = $webdir . $dir . "/" . $file . "\">" . $_ . "+(" . $ext . ")</a><br>+";
$var = $var . "<br>" . $x;
#With the other <br> you have double spacing.
}
}
#So that each link is on a separate line
$var = $var . "</br>";
}
#---------------------------
# This is for static text that
# just gets loaded for certain sections
#--------------------------
@vars = `ls $vardir`;
while(@vars)
{
$name = pop(@vars);
chomp($name);
$file = $vardir . $name;
open(FH, $file);
$var = $var . "&" . $name . "=";
while(<FH>)
{
tr/ /+/;
s/\n/<br>/;
$var = $var . $_;
}
close(FH);
}
#------------
#Little section to get blogging in flash
#It doesnt always work right, for whatever
#reason. I'm working on it, but hey this code
# is forcing the blogging script to do something
# very unatuaral. Display blogs in flash.
#-------------------
$y = `blosxom.cgi`;
#Find the number of chars before <center>
$x = index($y, "<center>");
#Get rid of the heading code.
substr($y, 0, $x) = "<br>";
$_ = $y;
tr/ /+/;
s/\n/<br>/;
$var = $var . "&blog=" . $_;
#---------
# Saves it to the
# flash file actionscript
# loads
#-----------
open(FH,">loadir.txt");
print FH $var;
close(FH);

#-----------
#This loads the html file and prints it out
#-----------
print header();
$file = "../flash/base.html";
open(FH, $file);
while(<FH>) {
print $_;
}