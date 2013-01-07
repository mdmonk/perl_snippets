my $newsurl='http://news.google.com/news?pz=1&ned=us&topic=b&hl=en&q';
#init webscraper module
my $g=WebScraper->new(
 debuglevel=>0,
 trim=>1&nbsp; #means remove left and right slashes from extracted data
 );

$g->loadTemplate('newslist.htm');&nbsp;&nbsp; #load template from file

$g->getPage($newsurl);&nbsp;&nbsp; #load page with url

my @a=$g->grabListedData();&nbsp;&nbsp;&nbsp; #start data extraction
#next code prints extracted data
foreach my $k (@a){
 foreach my $p (keys %$k){
 print "$p => $$k{$p}<br>\n";
 }
 print '<hr>';
}
