#!/usr/bin/perl -w
use strict;

use LWP::Simple;
use XML::RSS;

my @files = qw(http://nvd.nist.gov/download/nvd-rss-analyzed.xml);
# http://use.perl.org/useperl.rss
# http://search.cpan.org/rss/search.rss
# http://jobs.perl.org/rss/standard.rss
# http://www.perl.com/pace/perlnews.rdf
# http://www.perlfoundation.org/perl-foundation.rdf
# http://www.stonehenge.com/merlyn/UnixReview/ur.rss
# http://www.stonehenge.com/merlyn/WebTechniques/wt.rss
# http://www.stonehenge.com/merlyn/LinuxMag/lm.rss

my $base = '/Users/little-admin/RSS/';

foreach my $url ( @files )
	{
	my $file = $url;

	$file =~ s|.*/||;

	my $result = open my $fh, "> $base/$file.html";

	unless( $result )
		{
		warn "Could not open [$file] for writing! $!";
		next;
		}

	select $fh;

	my $rss = XML::RSS->new();
	my $data = get( $url );
	$rss->parse( $data );

	my $channel = $rss->{channel};
	my $image   = $rss->{image};

	print <<"HTML";
	<table cellpadding=1><tr><td bgcolor="#000000">
	<table cellpadding=5>
		<tr><td bgcolor="#aaaaaa" align="center">
HTML

	if( $image->{url} )
		{
		my $img = qq|<img src="$$image{url}" alt="$$channel{title}">|;

		print qq|<a href="$$channel{link}">$img</a><br>\n|;
		}
	else
		{
		print qq|<a href="$$channel{link}">$$channel{title}</a><br>\n|;
		}

	print qq|<font size="-1">$$channel{description}</font>\n|;

	print <<"HTML";
	</td></tr>
	<tr><td bgcolor="#bbbbff" width=200><font size="-1">
HTML

	foreach my $item ( @{ $rss->{items} } )
		{
		print qq|<b><</b><a href="$$item{link}">$$item{title}</a><br><br>\n|;
		}

	print <<"HTML";
		</font></td></tr>
	</td></tr></table>
	</td></tr></table>
HTML

	close $fh;
	}