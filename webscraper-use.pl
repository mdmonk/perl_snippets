#!/usr/bin/perl -w

use strict; 
use FindBin;
use lib $FindBin::Bin;

use CGI::Carp qw(fatalsToBrowser);
use WebScraper;
use CGI;

my $q=new CGI;
print $q->header(-charset=>'utf-8');

my $newsurl='http://news.google.com/news?pz=1&ned=us&topic=b&hl=en&q';

my $g=WebScraper->new(
 debuglevel=>0,
 trim=>1
 );

$g->loadTemplate('newslist.htm'); 

$g->getPage($newsurl);

my @a=$g->grabListedData();

foreach my $k (@a){
 foreach my $p (keys %$k){
 print "$p => $$k{$p}<br>\n";
 }
 print '<hr>';
 
}
