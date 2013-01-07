#!/usr/bin/perl
# $Id: quotes,v 1.2 1999/01/17 21:31:35 grimaldo Rel $
#-----------------------------------------------------------------------
#       quotes (c)1998 Dídimo Emilio Grimaldo Tuñón
#-----------------------------------------------------------------------
# AUTHOR: D. Emilio Grimaldo T.         grimaldo@panama.iaehv.nl
# DESCRIPTION:
#	A networking Perl script that fetches financial quotes from the
#	web using the HTTP protocol. It has the capability to fetch
#	currency exchange quotes as well as company stock quotes (up
#	to 10). As a bonus it can also fetch Linux daily news. 
#	It works with a direct connection and also via a Proxy server.
#
#	The script was inspired by the 'slashes.pl' script written by
# 	Alex Shnitman <alexsh@linux.org.il> which fetches Slashdot.Org
#	headlines and uses the Perl/GTK module to provide a GUI for the
#	script.
#	Based on the inspired script I removed the GUI part for which I
#	had no need and rewrote some of the code for generalization and
#	then I wrote the financial quotes. Quotes was originally just a
#	testbed for accessing data behind a proxy and evolved into 
#	something serious and useful.
#
# OPTIONS:
#	-h	Help
#	-q	Quiet mode
#	-n	Company names
#	-s F	Save URL to file F
#	-u F	Use prefetched URL from file F
#	-d	Debug
# PARAMETERS:
#	money	 Fetch currency exchange quotation
#	stock	 Fetch stock quotes
#	slashdot Fetch Linux news
#	update   Fetch info about latest release 
# USAGE:
#	quotes [options] parameter
#
# ********* CONFIGURATION SECTION *********
my $PROXY = "www-proxy";	# Proxy hostname, otherwise leave empty
my $PROXYPORT = 8001;		# Proxy port
my $Browser = '/usr/local/bin/netscape';
# ********* ********************* *********

# *********    I N C L U D E S    *********
use Socket;
use IO::Handle;
use Getopt::Long;
use strict;
# ********* ********************* *********

# ********* G L O B A L  V A R S  *********
my $cvsId   = '$Revision: 1.2 $';
my %product = ( 'title'	=> 'Financial quotations and Linux headlines',
		'name'	=> 'Quotes',
		'exec'  => 'quotes');
my $optHelp;
my $optQuiet;
my $optCNames;
my $optSave;
my $optPrefetched;
my $optDebug;
my %Spif = ();
my %Cfg = ();
my $stockCnt = 0;
# ********* ********************* *********

# *********************************************************************
# *	U t i l i t y   F u n c t i o n s
# *********************************************************************
sub Initialize {
    $cvsId =~ m/Revision:\s+(\d+\.\d+\.*\d*\.*\d*)/;
    $cvsId = $1;
    $Spif{'host'} = 'www.iaehv.nl';
    $Spif{'file'} = 'users/grimaldo/OpenSoft/spif.txt';
    $Cfg{'anonpwd'} = 'nobody@localhost';
}

sub Status {
    print "@_\n" if (!$optQuiet);
}

sub Qwack {
    my $errno = shift;
    my $msg   = shift;
    print "ERROR #$errno: $msg\n";
    exit($errno);
}

sub Squeal {
    my $warnno = shift;
    my $msg   = shift;
    print "WARN #$warnno: $msg\n";
}

sub ConfigureProxy {
    if ($ENV{'http_proxy'}) {
        $ENV{'http_proxy'} =~ m$http://(.*?):(.*?)/$;
	$PROXY = $1;
	$PROXYPORT = $2;
    }
}

sub Help {
    print "\n\t$product{'name'} version $cvsId\n";
    print "\tCopyleft (c)1998-1999 D.Emilio Grimaldo T.\n";
    print "\tEmail:   grimaldo\@panama.iaehv.nl\n";
    print "\t-------------------------------------------------\n";
    print "\t$product{'title'}\n";
    print "\t-------------------------------------------------\n";

    print  "\tUsage: $product{'exec'} \[options\] mode\n";
    print  "\tOptions are:\n";
    print  "\t\t-h | -help  This information\n";
    print  "\t\t-q | -quiet Don't give status messages\n";
    print  "\t\t-n | -names Show company names (Stocks)\n";
    print  "\t\t-s FILE | -save  Save fetched URL.\n";
    print  "\t\t-u FILE | -use   Use a pre-fetched URL.\n";
    print  "\tModes are:\n";
    print  "\t\tmoney    Currency exchange quotation\n";
    print  "\t\tstock    Company stock quotation\n";
    print  "\t\tslashdot Fetch Linux headlines from Slashdot.org\n";
    exit(0);
}

sub SaveAndQuit {
    my $NetPath = shift;

    $optSave = '-' if ($optSave eq 'stdout');
    open(SAVE, ">$optSave");
    while (<$NetPath>) {
        print SAVE $_;
    }
    close($NetPath);
    close(SAVE);
    exit(0);
}

#************************************************
# FUNCTION : NetworkConnection
# PROTOTYPE: NetworkConnection($Host, $File, $Method, \$FormalUrl)
# RETURNS  : Socket descriptor
# GLOBALS  : PROXY PROXYPORT
# PRIVATES : -
# DESCRIPTION
#	  Opens a network connection to fetch an object/file from the
#	given host using either 'ftp' or 'http' methods. It returns
#	a proper URL taking into account the presence/absence of
#	a proxy server.
#	  This deals only with the network connection, the caller is
#	responsible for actually issuing the proper protocol request.
sub NetworkConnection {
    my $Host 	= shift;
    my $Object  = shift;
    my $Method  = shift;
    my $UrlRef	= shift;	# Return the proper URL here
    my ($iaddr, $proto, $port, $paddr);

    if ($Method ne 'ftp' && $Method ne 'http') {
        &Qwack(4, "cannot recognize method: $Method");
    }
    if (ref($UrlRef) ne 'SCALAR') {
        &Qwack(6, 'NetworkConnection: improper parameter (URLREF)');
    }
    # Use a pre-fetched URL (file) instead of a real network connection.
    # This is good for testing whenever the HTML source of the remote
    # site has been changed in a way that my Regular Expressions are
    # not ok anymore.
    if ($optPrefetched ne '') {
	&Status("Using prefetched URL $optPrefetched...");
	if (-f $optPrefetched) {
	    open(PURL,"<$optPrefetched") || &Qwack(7, "NetworkConnection: $!");
	} else {
	    &Qwack(7, 'NetworkConnection: Not a file!');
	}
	return(\*PURL);
    }

    # Now do the network stuff
    if($PROXY) {
	$iaddr = gethostbyname($PROXY);
	$port = $PROXYPORT;
	$$UrlRef = "$Method://$Host/$Object";
    } else {
	$iaddr = gethostbyname($Host);
	if ($Method eq 'http') {
	    $port = 80;		# Standard HTTP port
	} else {
	    $port = 21;		# Standard FTP port
	}
	$$UrlRef = "/$Object";
    }

    $proto = getprotobyname("tcp");
    $paddr = sockaddr_in($port, $iaddr);
    &Status("Connecting to $Host...");
    socket(NETPATH, PF_INET, SOCK_STREAM, $proto) or &Qwack(5,"socket: $!");
    connect(NETPATH, $paddr) or &Qwack(7,"connect: $!");
    autoflush NETPATH 1;
    &Status("Connected; issuing request...");
    return(\*NETPATH);
}

#
# RemoveHtmlTags
#	Takes an HTML-encoded line and strips it out of all the tags.
#	may fail if a line is truncated or tags are not closed in the
#	same line!.
#
sub RemoveHtmlTags {
    my $raw = shift;
    my $isTag = 0;
    my $len;
    my ($posBeg, $posEnd, $current);
    my $clean = '';
    my $done = 0;
    my $char;
    my $filled = 0;
    
    $len = length($raw);
    foreach $current ( 0 .. $len ) {
	$char = substr($raw, $current, 1);
        if ($isTag) {
	    # We are in a tag, see if we reached the end of it
	    if ($char eq '>') {
		$isTag = 0;
		if ($filled = 0) {
		    # Just in case there was no filling space but
		    # don't add too many, just one!
		    $clean .= ' ';
		    $filled = 1;
		}
		next;
	    }
	}
        if ($char eq '<') {
	    $isTag = 1;
	    $clean .= ' ';
	    $filled = 0;
	    next;
	}
	if (! $isTag) { $clean = $clean . $char; }
    }
    $clean =~ s|\&nbsp;| |gi;
    $clean =~ s|\&copy;|(c)|gi;
    $clean =~ s|\s+| |g;
    return($clean);
}

sub ReadResource {
    my $rStock	= shift;
    my $rCurrency = shift;
    my @data = ();

    if (ref($rStock) ne 'HASH' && ref($rCurrency) ne 'HASH') {
	&Qwack(2, "ReadResource with bad parameter types!");
    }
    if (!open(RC, "< $ENV{'HOME'}/.quotesrc")) {
        &Qwack(3, "$ENV{'HOME'}/.quotesrc: $!");
    }
    $$rCurrency{'qty'} = 1;	# Default quantity if not specified
    while (<RC>) {
	chomp;
        next if (/^\s*$/);	# empty lines
	next if (/^\s*#/);	# comment lines
	@data = split(/\s+/, $_, 3);
	if ($data[0] eq 'addStock') {
	    $$rStock{$data[1]} = $data[2];
	    $stockCnt += 1;
	} elsif ($data[0] eq 'fromCurrency') {
	    $$rCurrency{'from'} = $data[1];
	} elsif ($data[0] eq 'toCurrency') {
	    $$rCurrency{'to'} = $data[1];
	} elsif ($data[0] eq 'qtyCurrency') {
	    $$rCurrency{'qty'} = $data[1];
	} elsif ($data[0] eq 'setProxy') {
	    $PROXY = $data[1];
	} elsif ($data[0] eq 'setProxyPort') {
	    $PROXYPORT = $data[1];		# numerical!
	} elsif ($data[0] eq 'setBrowser') {
	   $Browser = $data[1];
	} elsif ($data[0] eq 'setSpifHost') {
	   $Spif{'host'} = $data[1];
	} elsif ($data[0] eq 'setSpifFile') {
	   $Spif{'file'} = $data[1];
	} elsif ($data[0] eq 'setAnonPass') {
	   $Cfg{'anonpwd'} = $data[1];
	}
    }
    close(RC);
}

# This knows how to launch netscape communicator/navigator. I don't
# know of any 'worthy' browser for Unix, either you watch the web
# in all its splendor with Netscape or miss a lot...
sub LaunchBrowser {
    my $url = shift;
    my $browseCmd;
    
    if ($Browser eq '') {
        &Squeal(2, 'No browser has been specified!');
	return;
    }
    if (! -x $Browser) {
        &Squeal(3, "$Browser is not an executable!");
	return;
    }
    $browseCmd = "$Browser -remote 'OpenURL(##, new_window)'";
    $browseCmd =~ s/##/$url/;
    system("$browseCmd &");
}

# *********************************************************************
# *	L i n u x   H e a d l i n e s   f r o m  S L A S H D O T
# *********************************************************************
# Revision    : 2
# Ref. Version: 1.3 (Slashes.pl)
# Update Date : 11 Dec 1998
sub LinuxHeadlines {
    my $Host = shift;
    my $File = shift;
    my @articles;
    my $url;
    my $NetPath;

    $NetPath = &NetworkConnection($Host, $File, 'http', \$url);
    print $NetPath "GET $url HTTP/1.0\r\n\r\n";

    # This part updated with the Generic ultramode.txt parser
    # by Steve haslam. It handles the number of fields between 
    # delimiters # being extended.
    # Skips HTTP header
    local $/ = "\r\n\r\n";
    my $http_header = <$NetPath>;
    my @http_headerlist = split(/\r\n/, $http_header);
    my $http_status = shift @http_headerlist;
    my ($httpver, $nstatus, $vstatus) = ($http_status =~ /(.*?) (.*?) (.*)/);

    if ($nstatus !~ /^2/) {
	&Qwack(1, "Connecting to server: $nstatus: $vstatus");
	return;
    }

    &Status("Collecting Headlines...");
    &SaveAndQuit($NetPath) if ($optSave);

    undef @articles;
    # Get text data
    local $/ = "\n%%\n";
    # Remove the intro
    my $intro = <$NetPath>;
    printf "%-16s %12s Rsp. Title\n", 'Type', 'Author';
    printf "%-16s %12s ---- %s\n", '-'x16, '-'x12, '-'x30;
    foreach (<$NetPath>) {
	my ($title, $link, $time, $author, $dept, $topic, $numcomments,
            $storytype, $imagename) = split(/\n/);
	push(@articles, $link);
	printf "%-16s %12s (%s) %s\n", $topic, $author, $numcomments, $title;
    }
    close($NetPath);

    &Status("Headlines retrieved.");
}

# *********************************************************************
# *	E m i l i o ' s   O p e n  S o f t w a r e   U p d a t e s
# *********************************************************************
sub SpifedNews {
    my $Host = shift;
    my $File = shift;
    my $url;
    my $NetPath;

    $NetPath = &NetworkConnection($Host, $File, 'http', \$url);
    print $NetPath "GET $url HTTP/1.0\r\n\r\n";

    &SaveAndQuit($NetPath) if ($optSave);
    my(@header, @body, $hdr);
    $hdr = 1;
    while(<$NetPath>) {
	s/\r?\n$//;  # Strip the newline; chop won't work as it won't
                     # strip the \r
	if(/^$/) {
	    $hdr = 0;
	    next;
	}
	push @header, $_ if $hdr;
	push @body, $_ unless $hdr;
    }
    close $NetPath;

    if($header[0] !~ m:^HTTP/1.[01] 200:) {
	&Qwack(1, "Connecting to server: $header[0]");
	return;
    }
    &Status("Information retrieved.");
    #
    # sp Quotes		: Tell user what's the latest version
    # sl Perl		: Find out about all my Perl jewels
    # list		: Just list everything I have made available
    &DecodeSpifNews(\@body, 'sp', $product{'name'});
}

# Revision    : 1
# Ref. Version: 1.0
# Update Date : 13 Dec 1998
sub DecodeSpifNews {
    my $bRef = shift;
    my $operation = shift;
    my $key = shift;
    my $SPifVersion;		# Smart PIF (tm) revision
    my $SPifFormat;		# Smart PIF (tm) file format
    my $i;

    # First determine if this is a SPif file and if so
    # whether we have an up-to-date parser by checking the
    # major version number of the PIF descriptor.
    if (! ($$bRef[0] =~ m/^#\s+@\(#SPIF-([\d.]+)#\)\s+(\w+)/) ) {
        &Squeal(100, "It is not a SmartPIF (tm) file\n");
	return;
    }
    $SPifVersion = $1;
    $SPifFormat  = $2;
    $SPifVersion =~ m/(\d+).(\d+)/;
    if ($1 > '1') {
        &Squeal(101, "Your SmartPIF(tm) parser is old\n");
	return;
    }
    if ($SPifFormat ne 'Simple' && $SPifFormat ne 'Extended') {
        &Squeal(102, "Unrecognized SmartPIF(tm) format $SPifFormat\n");
	return;
    }
    #
    # Now we are ready to parse the SPif
    #
    foreach $i ( 1 .. $#$bRef ) {
	next if ($$bRef[$i] =~ m/^\s*$/);
	next if ($$bRef[$i] =~ m/^\s*#/);
        my @data = ();
	if ($SPifFormat eq 'Simple') {
	    # <ProgramName> <LatestVersion> <ReleaseDate> <Lang> <URL>
	    @data = split(/\s+/, $$bRef[$i], 5);
	} else {
	    &Squeal(103, "SmartPIF(tm) format $SPifFormat not supported\n");
	}
	&SPifShow($SPifFormat, \@data, 'list') if ($operation eq 'l' || 
						   $operation eq 'list');
	&SPifShow($SPifFormat, \@data, 'srch-p', $key) if ($operation eq 'sp');
	&SPifShow($SPifFormat, \@data, 'srch-l', $key) if ($operation eq 'sl');
    }
}

sub SPifShow {
    my $fmt  = shift;
    my $dRef = shift;
    my $mode = shift;
    my $key  = shift;		# Optional, only if mode is search

    if (($mode eq 'srch-p' && $$dRef[0] ne $key) ||
        ($mode eq 'srch-l' && $$dRef[3] ne $key)) {
	return;
    }
    if ($fmt eq 'Simple') {
	print "\tThis is : $product{'name'} v$cvsId\n";
	print "\tLatest  : $$dRef[0] v$$dRef[1]\n";
	print "\tReleased: $$dRef[2]\n\tLanguage: $$dRef[3]\n";
	print "\tURL     : $$dRef[4]\n";
    }
}
# *********************************************************************
# *	C u r r e n c y   E x c h a n g e  f r o m  Y A H O O
# *********************************************************************

#
# Function: DecodeYahoo
# Revised : 4 dec 1998
# CGI     : m5
#	Decodes a money exchange quotation
#
# Revision    : 3
# Ref. Version: unknown
# Update Date : 14 Dec 1998
sub DecodeYahoo {
    my  $bRef = shift;
    my $curr_from = shift;
    my $curr_to = shift;
    my $raw;
    my $i;
    my $found = 0;
    my @date;
    my ($time, $market);

    $i = 0;
    while ($i <= $#$bRef && $found == 0) {
        if (! ($$bRef[$i] =~ m/^<P>/i)) {
	    $i++;
	    next;
	}
	@date = split(/\s+/, $$bRef[$i + 1]);
	if (lc($date[7]) eq 'markets') {
	    $found = 1;
	    $time = $date[3];
	    if ($date[8] =~ m/close/i) {
	        # Closed, no other indication
		$market = $date[8];
	    } elsif ($date[9] eq 'in') {
	        # Closed but says it will open in x hours y minutes
		$market = "Closed (will open in $date[10]:$date[12] hrs.)";
	    } elsif ($date[9] eq 'in') {
		$market = $date[8];
	    }
	} else {
	    $i++;
	}
    }
    if (! $found) {
        &Squeal(8, "Cant decipher that\n");
	return;
    }
    
    $found = 0;
    while ($i <= $#$bRef && $found == 0) {
        if (! ($$bRef[$i] =~ m/^<hr>/i)) {
	    $i++;
	    next;
	}
	if ($$bRef[$i + 1] =~ m/^<table /i) {
	    $found = 1;
	} else {
	    $i++;
	}
    }
    $raw = $$bRef[$i + 1];
    # The huge HTML table with the data we want seems to come in two
    # flavours, if the market is closed for the weekend it shows
    # "Market closed" and the exchange rate cell shows a date "Dec 11"
    # whereas during weekdays (close or open) it may show "open" or
    # "open in 4 hours 31 minutes" and a time such as "6:43AM".
    if ($raw =~ m|<td>(\d+)</td><td>(\w+)\s(\d+)</td><td>([\d.]+)</td><td><b>([\d.]+)</b></td>|i) {
	my ($exchrate, $exch, $qty, $on);
        $qty = $1;  $on = "$2 $3";
	$exchrate = $5; $exch = $5;
	&ShowExchange($time, $market, $qty, $curr_from, $curr_to, 
		      $exch, $exchrate);
    } elsif ($raw =~ m|<td>(\d+)</td><td>(\d+):(\d+)([AP]M)</td><td>([0-9]+.[0-9]+)</td><td><b>([\d.]+)|i) {
	my ($exchrate, $exch, $qty, $on);
        $qty = $1;  $on = "$2:$3 $4";
	$exchrate = $5; $exch = $6;
	&ShowExchange($on, $market, $qty, $curr_from, $curr_to, 
		      $exch, $exchrate);
    } else {
        print "Can't decipher quote (HTML follows)\n$raw\n";
    }
}

sub ShowExchange {
    my $time = shift;
    my $market_state = shift;
    my $qty = shift;
    my $from = shift;
    my $to = shift;
    my $exchange = shift;
    my $rate = shift;

    print  "\t**********************************************\n";
    print  "\t*        C u r r e n  c y   Q u o t e        *\n";
    print  "\t**********************************************\n";
    printf "\t* Local time: %s\n", $time;
    printf "\t* Market is : %s\n", $market_state;
    printf "\t* Exchange  : %d %s = %s %s\n", $qty, $from, 
					   $exchange, $to;
    printf "\t* Rate      : %s\n",$rate;
    print  "\t**********************************************\n";
    print  "\t* Quotation data (c)1998-1999 Yahoo!         *\n";
    print  "\t**********************************************\n";
}

sub MoneyExchange {
    my $Host = shift;
    my $File = shift;
    my $from = shift;
    my $to   = shift;
    my $url;
    my $NetPath;

    $NetPath = &NetworkConnection($Host, $File, 'http', \$url);
    print $NetPath "GET $url HTTP/1.0\r\n\r\n";
    &Status("Connected; waiting for reply...");
    &SaveAndQuit($NetPath) if ($optSave);

    my(@header, @body, $hdr);
    $hdr = 1;
    while(<$NetPath>) {
	s/\r?\n$//;  # Strip the newline; chop won't work as it won't
                     # strip the \r
	if(/^$/) {
	    $hdr = 0;
	    next;
	}
	push @header, $_ if $hdr;
	push @body, $_ unless $hdr;
    }
    close $NetPath;

    if($header[0] !~ m:^HTTP/1.[01] 200:) {
	&Qwack(1, "Connecting to server: $header[0]");
	return;
    }
    &Status("Quotes retrieved.");
    &DecodeYahoo(\@body, $from, $to);
}

# *********************************************************************
# *	Q u i c k   S t o c k    Q u o t e s  F r o m    N A S D A Q
# *********************************************************************
#
# Function: DecodeNasdaq
# Revised : 4 dec 1998
# CGI     : quotes_quick.asp
#	Decodes a stock quotation from NASDAQ.
#
# Revision    : 2
# Ref. Version: unknown
# Update Date : 10 Jan 1999
sub DecodeNasdaq {
    my $raw = shift;
    my $qtyRef = shift;
    my $aRef = shift;
    my $i;
    my @data;

    substr($raw, 0, index($raw, "Mutual Funds", 0) + 12) = "";
    $raw = substr($raw, 0, index($raw, "* Information", 0));
    $raw =~ s|^\s+||;

    if ( $raw =~ m/Market\s+(Open|Closed)/i ) {
	$$aRef{'Market'} = $1;
	$i = index($raw, "arket", 0);
    } else {
	&Squeal(1,"Bad Nasdaq, no market");
	return("ERROR");
    }
    $$aRef{'Date'} = substr($raw, 0, $i - 2);
    $i = index($raw, "Share Volume", 0);
    if ($i == -1) {
	&Squeal(1,"Bad Nasdaq, no market");
	return("ERROR");
    }
    $i += 12;
    $raw = substr($raw, $i, length($raw) - $i + 1);
    $raw =~ s|\$\s+|\$|g;	# No space between $ and ammount
    # Now proceed to retrieve information
    print "$raw\n" if $optDebug;
    @data = split(/\s+/, $raw);
    $$qtyRef = $#data / 6;	# Six fields per symbol
    # There is something strange happenning with the first quote, has
    # some invisible characters there?.
    # Symbol Index LastSale NetChange %Change Volume
    shift(@data);	# Discard the phantom field
    foreach $i ( 0 .. $$qtyRef - 1 ) {
	$raw = join("  ", shift(@data), shift(@data), shift(@data),
			  shift(@data), shift(@data), shift(@data));
#        $raw = $$aRef{$i + 1} = $raw;
        $$aRef{$i + 1} = $raw;
    }
}

sub StockQuotes {
    my $Host = shift;
    my $File = shift;
    my $StockSymbols = shift;
    my $url;
    my $NetPath;

    $NetPath = &NetworkConnection($Host, $File, 'http', \$url);
    print $NetPath "GET $url HTTP/1.0\r\n\r\n";
    &Status("Connected; waiting for reply...");
    &SaveAndQuit($NetPath) if ($optSave);

    my(@header, @body, $hdr);
    $hdr = 1;
    while(<$NetPath>) {
	s/\r?\n$//;  # Strip the newline; chop won't work as it won't
                     # strip the \r
	if(/^$/) {
	    $hdr = 0;
	    next;
	}
	push @header, $_ if $hdr;
	push @body, $_ unless $hdr;
    }
    close $NetPath;

    if($header[0] !~ m:^HTTP/1.[01] 200:) {
	&Qwack(1, "Connecting to server: $header[0]");
	return;
    }
    &Status("Quotes retrieved.");

    my $i;
    my $line;
    my $rel;
    my %nasdaq = ();
    my @stock;
    # Nasdaq Output is all of the HTML in ONE (the first) line!.
    # 1. Unfortunately the "Net Change" data is not in text format (+/-)
    #    but in an image:
    #	   <img src="/images/nc_down.gif" border=0 width=11 height=10>
    #	   <img src="/images/nc_up.gif" border=0 width=11 height=10>
    #      unch
    #	 So before removing the HTML tags let's hack it to convert
    #	 this data into textual form without breaking the decode part.
    # 2. Then remove all HTML tags 
    # 3. Decode the resulting plain-text
    $body[0] =~ s|<img\s+src=\"[\w/]+nc_down|(-)<|ig;
    $body[0] =~ s|<img\s+src=\"[\w/]+nc_up|(+)<|ig;
    # For Rev. 2 of the decoder we have to filter out the last part 
    # (Nasdaq delay info) so that it does not break the rest. It can
    # be recognized by the CENTER tag.
    $body[0] = substr($body[0], 0, index($body[0], '<CENTER>', 0));

    $line = &RemoveHtmlTags($body[0]);
#    print $body[0] if $optDebug;
    # Since RemoveHtmlTags tries to remove spaces as much as possible,
    # it also adds some so that the decoding is not broken by putting
    # fields without intervening spaces. Since we know it is only one
    # space we do a pattern replace to fix that.
    $line =~ s|\s+\(\+\)|(+)|g;
    $line =~ s|\s+\(\-\)|(-)|g;
    &DecodeNasdaq($line, \$StockSymbols, \%nasdaq);

    print  "\t**********************************************\n";
    print  "\t*        S t o c k          Q u o t e        *\n";
    print  "\t**********************************************\n";
    print "\t* Market : $nasdaq{'Market'}\n";
    print "\t* Date   : $nasdaq{'Date'}\n";
    print "\t*                             Last     Value     Perc.  Exchange\n";
    print "\t*           Symbol Index      sale     change    change volume\n";
    print "\t* -------   ------ ---------  -------- --------- ------ ------------\n";
    foreach $i ( 1 .. $StockSymbols ) {
        @stock = split(/\s+/, $nasdaq{$i}, 6);

	if ($stock[2] =~ m/(\W+)\s*(\d+).(\d+)/) { # Last Sale Value
	    # Let's try to do a pretty job in formatting and extracting
	    # the currency symbol
	    $stock[2] = sprintf"%s%3s.%3s",$1,$2, substr($3,0,3);
	}
	if ($stock[3] =~ m/\(([+-]{1})\)$/) {	   # + or - 
	    if ($1 eq '+') { $rel = '+'; }
	    elsif ($1 eq '-') { $rel = '-'; }
	    $stock[3] = $`;
	} else { $rel = ''; }
        printf "\t* Company: %5s   %9s  %8s %s%7s  %4s %+11s\n",
		$stock[0], $stock[1], $stock[2], $rel, $stock[3], 
		$stock[4], $stock[5];
    }
    undef %nasdaq;
    print "\t* Quotation data (c)1999 Nasdaq Stock Market\n";
}

# *****************************************************
# *                   M A I N                         *
# *****************************************************
my %Stocks = ();
my %Currency = ();

&Initialize;
&ReadResource(\%Stocks, \%Currency);
&ConfigureProxy;
&GetOptions('h|help'	=> \$optHelp,
	    'n|names'	=> \$optCNames,
	    's|save=s'	=> \$optSave,
	    'u|use=s'	=> \$optPrefetched,
	    'd|debug'	=> \$optDebug,
	    'q|quiet'	=> \$optQuiet);
&Help if $optHelp;

if ($ARGV[0] eq 'money' | $ARGV[0] eq 'exch') {
    # This gets via HTTP.
    #	ATS Austrian Schilling
    #  	NLG Dutch Guilder
    #	USD US Dollar
    my ($from, $to, $qty);
    print "**** Money Exchage Quotes ****\n";
    $from = $Currency{'from'};
    $to   = $Currency{'to'};
    $qty  = $Currency{'qty'};
    &MoneyExchange("quote.yahoo.com", "m5?a=$qty&s=$from&t=$to", $from, $to);
} elsif ($ARGV[0] eq 'slashdot') {
    print "**** Linux Headlines ****\n";
    &LinuxHeadlines('slashdot.org', 'ultramode.txt');
} elsif ($ARGV[0] eq 'update') {
#    &SpifedNews('localhost','~grimaldo/prodinfo.txt');
    &SpifedNews($Spif{'host'}, $Spif{'file'});
} elsif ($ARGV[0] eq 'stock' || $ARGV[0] eq 'market') {
    # Get Stock quotations from Nasdaq (up to 10)
    my $query;
    my ($ticker, $company_name);
    print "**** Stock Quotes ****\n";
    $query = 'asp/quotes_quick.asp?mode=Stock';
    foreach $ticker (keys %Stocks) {
	$query .= '&symbol=' . $ticker;
    }
    $query .= '&quick.x=41&quick.y=11';	# is it necessary?
    &StockQuotes('www.nasdaq.com',$query, $stockCnt);
    if ($optCNames) {
        print "\tCompany names\n";
	foreach $ticker (keys %Stocks) {
	    printf "\t%-6s %s\n", $ticker, $Stocks{$ticker};
	}
    }
} else {
    &Help();
}
# ***************************************************************
#              H  I  S  T  O  R  Y
# ***************************************************************
# 11.Dec.1998 DEGT LinuxHeadlines updated per Alex Shnitman's slashes.pl 1.3
# 11.Dec.1998 DEGT Read data from resource file ~/.quotesrc
# 13.Dec.1998 DEGT Yahoo decoder updated for their newest m5 CGI
# 13.Dec.1998 DEGT v1.1-0 First public release
# 14.Dec.1998 DEGT Cater for more DecodeYahoo cases.
# 23.Dec.1998 DEGT PR-001 Was searching hardcoded MoneyExchange currencies!
# 10.Jan.1999 DEGT PR-002 Updated Nasdaq decoder (they changed CGI output)
# 10.Jan.1999 DEGT CR-001 Renamed option (-s) and added options (-s,-u,-d)
