#!/usr/local/bin/perl

$VERSION = "1.14";

# CGI code.pl
# Version 1.14
# Part of "Cyrillic Software Suite"
# Get docs and newest version from
#	http://www.neystadt.org/cyrillic/
#
# Copyright (c) 1997-98, John Neystadt <http://www.neystadt.org/john/>
# You may install this script on your web site for free
# To obtain permision for redistribution or any other usage
#	contact john@neystadt.org.
#
# Drop me a line if you deploy this script on your site.

=head1 NAME

code.pl v1.14 - CGI script to convert on-the-fly html pages across cyrillic charsets

=cut

use Convert::Cyrillic;
use LWP::UserAgent;
use HTTP::Headers::UserAgent;

$path="..";     # <==== path from cgi-bin to the server root.
$defcode="WIN"; # <==== default source encoding
$maxsize=500000; # maximum file size
$IndexFileName = 'index.html';
$UserAgent=$ENV{HTTP_USER_AGENT};
$scrname=$ENV{SCRIPT_NAME};
$file=$ENV{PATH_INFO};
$file=~s/^$scrname//;
$file=~s/\+/ /go;
$file=~s/%(..)/pack("c",hex($1))/ge;
if ($file=~/[\.\/\\]([^\.\/\\]+)$/o) {$ext=lc($1);} else {$ext='html';}
$file=~s%^\/([^\/]*)%%o;
$lang=uc($+);
if ($lang eq 'RUS') {
	print "Content-type: text/html\n
	<html><body><h3>Select Russian encoding:</h3>
	<ul>
	<li><a href=\"$scrname/koi8$file\">KOI8-r</a> Îœƒ…“œ◊À¡
	<li><a href=\"$scrname/win$file\">CP1251</a> MS-Windows  Ó‰ËÓ‚Í‡
	<li><a href=\"$scrname/iso$file\">ISO-8859-5</a> ∫ﬁ‘ÿ‡ﬁ“⁄–
	<li><a href=\"$scrname/dos$file\">CP866</a> DOS (alternative) Ë´Òøa´Û¨·
	<li><a href=\"$scrname/utf8$file\">UTF-8</a> Unicode
	<li><a href=\"$scrname/mac$file\">MAC</a> Macintosh
	<li><a href=\"$scrname/vol$file\">volapuk</a> transliteraciya
	<li><a href=\"$scrname/nocs$file\">KOI8-r without Metatag</a> Îœƒ…“œ◊À¡
	</ul></body></html>";
	goto end;
}
if ($lang=~/(.*)-(.*)/o) { $charset=$1; $lang=$2; }
if (!(',ISO,KOI8,KOI,DOS,WIN,VOL,MAC,UTF8,NOCS,AUTO,' =~ /,$lang,/i)) {
	$err = "Unsupported code - $lang"; 
	goto error;
}

$file =~ s|http:/([^/])|http://$1|oi; # Some vers of Ms-IIS merge '//' into '/' in Urls

if ($file =~ s|^/(http://)|$1|oi) {
	$url=$ENV {'QUERY_STRING'}; 
	if ($url) { $url= "?" . $url; }
	$url = $file . $url;

	my $ua = new LWP::UserAgent;
	$ua->agent("code.pl/$VERSION " . $ua->agent);
	$ua->from ('leonid@neystadt.org');
	
	my $req = new HTTP::Request (GET => $url);
	my $res = $ua->request ($req);

	if (!$res->is_success) {
		my $err = $res->error_as_HTML();
		print <<"EOF";
Content-Type: text/html

<h1>Failure</h1>
Failed to retrive url: <b>$url</b>.
Remote server returned the following reponse:
<hr>
$err
EOF
		goto end;
	}

	$type = $res->content_type;
	$buffer = $res->content;

	#neystadt::http_rtr::Http_Retrieve ($url, $buffer, $hdrs);
	#$hdrs=~/Content-Type: (.*)\n/io; $type = $1;
} else {
	if ($file=~/cgi-bin/io) {
		$err = "Incorrect file name"; 
		goto error;
	}

	$file = "$path$file";
	if (-d $file) {
		$file = "$file/$IndexFileName"; 
		$ext = 'htm';
	}
	if (open In,"$file") {
		binmode In; read (In, $buffer, $maxsize); close In;
	} else {
		print "Content-type: text/html

<title>HTTP Error</title><h2>Error: 404 Not Found</h2>
<HR>
The requested URI $file does not exist.
<HR>";
		goto end;
	}
}

if ($lang=~/auto/io){
	$platform = HTTP::Headers::UserAgent::GetPlatform ($UserAgent);
	$lang='koi';
	$lang='win' if $platform=~/WIN/io;
	$lang='mac' if $platform eq 'MAC';
	$lang='koi' if $platform eq 'UNIX';
	$lang='dos' if $platform eq 'OS2';
	$lang='nocs' if $platform eq 'Linux';
}

$newcharset = "koi8-r" if $lang=~/koi|nocs/io; 
$newcharset = "windows-1251" if $lang=~/win/io; 
$newcharset = "x-mac-cyrillic" if $lang=~/mac/io; 
$newcharset = "ibm866" if $lang=~/dos/io;
$newcharset = "ISO-8859-5" if $lang=~/iso/io;
$newcharset = "utf-8" if $lang=~/utf8/io;

if ($buffer=~s/<\s*META\s+HTTP-EQUIV\s*=\s*"?Content-Type"?\s+CONTENT\s*=\s*"?(.*);\s+charset\s*=\s*(.*)"?\s*>/<META HTTP-EQUIV="Content-Type" CONTENT="$1; charset=$newcharset">/io) {
	$type=$1; $charset=$2 if !$charset;
	if ($lang=~/nocs|vol/io){
		$buffer=~s/<\s*META\s+HTTP-EQUIV\s*=\s*"?Content-Type"?\s+CONTENT\s*=\s*"?(.*);\s+charset\s*=\s*(.*)"?\s*>//io;
	}
}
else {
	$type="text/html"  if $ext eq 'html' || $ext eq 'htm';
	$type="text/plain"  if $ext eq 'txt';
	$type="image/gif"  if $ext eq 'gif';
	$type="image/jpeg" if $ext eq 'jpg' || $ext eq 'jpeg';
}

$lang="koi8" if $lang=~/nocs/io;
$type="text/html" if  !$type;
$slang=$defcode;
$slang="KOI8" if $charset=~/koi/io;
$slang="WIN" if $charset=~/1251/io;
$slang="ISO" if $charset=~/iso/io;
$slang="DOS" if $charset=~/alt/io;
$slang="MAC" if $charset=~/mac/io;
$slang="UTF8" if $charset=~/utf/io;
$slang="UTF8" if $charset=~/unicode/io;

# translate the page
$buffer = Convert::Cyrillic::cstocs ($slang,$lang,$buffer)
	if $type =~ /text/o; 

if ($hdrs) {
	binmode STDOUT; 
	print $hdrs;
} else {
	print("Content-type: $type\n\n");
	binmode STDOUT; 
}

print $buffer;
goto end;
error:
	ermsg($err);
end:;

sub ermsg {
	if (!$sw) {$sw=1; print "Content-type: text/plain\n\n";}
	print "@_[0]\n";
}

__END__

=head1 DESCRIPTION

Many Russia WWW servers are based on modified APACHE so, that different encodings are returned when clients connect to
different server ports or to different subdomains. This is convenient for servers in Russia, but cannot be used abroad for
Web sites using virtual servers or just having some space at an Internet provider's server. The following approach solves
the problem by using one CGI script without any changes in WWW server software. 

Those are code.pl features:

=over

=item *

Can translate localy stored files

=item *

Can translate remote files, retrieving them via HTTP

=item *

Recognizes source encoding from <META HTTP-EQUIV="Content-Type" ...> tag inside

=item *

Adjusts the above tag for new encoding or deletes it for buggy browsers.

=item *

Charsets supported: 

=over

=item *

B<KOI8> - KOI8-R 

=item *

B<WIN> - WINDOWS-1251

=item *

B<MAC> - Macintosh

=item *

B<DOS> - DOS, alternative, CP-866

=item *

B<ISO> - ISO-8859-5

=item *

B<ISO> - UTF-8 (Unicode)

=item *

B<VOL> - Volapuk (transliteration)

=item *

B<NOCS> - KOI8-R, deleting Content-Type META tag, for buggy browsers

=back

=back

=head1 USAGE

=over

=item 1

Put the script in your cgi-bin directory.

=item 2

Edit the script to set script parameters to your configuration

=over

=item *

$path=".."; # <==== path from cgi-bin to the server root. 

=item *

$defcode="WIN"; # <==== default source encoding 

=item *

$IndexFileName = 'index.html'; # default.htm or index.html, depending on your server 

=back

=item 3

Refer to the script as:
I<http://www.youserver.here/cgi-bin/code.pl/B<TAB>/URL> to be translated.

=over 

=item 1

B<TAB> is one of the above encodings

=item 2

B<TAB> can also also be of form 'fromcode-tocode' for
explicit definition of the original file encoding. 

=item 3

B<URL> is absolute URL from the server root (Don't forget to set B<$path> in code.pl) or full URL like http://cnn.com. 

=back

=back

All relative references from this page to other WEB pages will be also translated through the same code table (isn't
supported yet for full URLs).

Source encoding is determined by the following algorithm. The first matching rule from this list is selected. 

=over

=item 1

If B<TAB> specified by B<src-dst> form, B<src> is the source encoding. 

=item 2

If Metatag like: <META HTTP-EQUIV="Content-Type" CONTENT="text/plain; charset=win"> is present its charset is used. The tag
is updated during translation by replacing source encoding by the destination one. 

=item 3

Default encoding is taken from variable $defcode in code.pl. 

=back

=head2 CAVEATS

It is recommended that you put <META HTTP-EQUIV="Content-Type" ...> on all your pages, and choose only destination encoding
in urls. Do not worry for old buggy browsers which can't display correctly pages with this metatag NOCS encoding converts
page to koi8 and deletes the metatag.

=head1 TIPS AND TRICKS

If you use APPACHE you can add the lines similar to those to your webserver configuration files: 

 ScriptAlias /koi8       /home/www/neystadt/cgi-bin/code.pl/koi8
 ScriptAlias /win        /home/www/neystadt/cgi-bin/code.pl/win
 ScriptAlias /dos        /home/www/neystadt/cgi-bin/code.pl/dos
 ScriptAlias /mac        /home/www/neystadt/cgi-bin/code.pl/mac
 ScriptAlias /iso        /home/www/neystadt/cgi-bin/code.pl/iso
 ScriptAlias /utf8       /home/www/neystadt/cgi-bin/code.pl/utf8
 ScriptAlias /vol        /home/www/neystadt/cgi-bin/code.pl/vol
 ScriptAlias /lat        /home/www/neystadt/cgi-bin/code.pl/vol
 ScriptAlias /nocs       /home/www/neystadt/cgi-bin/code.pl/nocs

From now you will be able to translate urls like http://www.neystadt.org/russia/ simply by prefixing the url with encoding:
http://www.neystadt.org/koi8/russia/ or http://www.neystadt.org/lat/russia/. 

Note that code.pl automatically finds index.html if directory names is given (like in example above). The index file name
can be changed by $IndexFileName parameter in the script. 

=head1 EXAMPLES

To translate http://www.neystadt.org/vist/ from Windows-1251 to KOI8: 

 http://www.neystadt.org/cgi-bin/code.pl/win-koi8/vist/ 

To translate output of the script http://www.neystadt.org/cgi-bin/miitqr.pl?abc from its default encoding to KOI8: 

 http://www.neystadt.org/cgi-bin/code.pl/koi8/http://www.neystadt.org/cgi-bin/miitqr.pl?abc 

=head1 PREREQUISITES

This script requires the C<LWP>, C<Convert::Cyrillic> and C<HTTP::Headers::UserAgent> 
modules available from CPAN or at http://www.neystadt.org/cyrillic/.

=pod OSNAMES

All UNIXes, Windows NT

=pod SCRIPT CATEGORIES

CGI/Filter

=cut
