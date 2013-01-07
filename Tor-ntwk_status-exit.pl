#!/usr/bin/perl -w
# $Id: exit.pl,v 1.29 2006-03-20 23:19:35 goodell Exp $
$license = <<EOF
Copyright (c) 2005-2006 Geoffrey Goodell.

This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place - Suite 330, Boston, MA  02111-1307, USA.

EOF
;

use strict;
use Socket;

# global configuration parameters

my @portslist       = (22, 53, 80, 110, 119, 143, 443, 5190, 6667);
my @os_names        = ("Cygwin",
                       "Darwin",
                       "DragonFly",
                       "FreeBSD",
                       "IRIX64",
                       "Linux",
                       "NetBSD",
                       "OpenBSD",
                       "SunOS",
                       "Windows",
                       "Unknown");

my $CONFIG          = "/etc/exit.conf";
my $CACHE           = "/var/cache/www-data";
my $DIR_CACHE       = "/var/cache/tor/cached-directory";
my $A_STANDARD      = "standard";
my $A_UNVERIFIED    = "unverified";
my $TD_DEFAULT      = "td";
my $TITLE           = "Tor Network Status";
my $URL_FLAGS       = "http://afs.eecs.harvard.edu/~goodell/flags";
my $URL_ICONS       = "http://afs.eecs.harvard.edu/~goodell/icons";
my $URL_OSICONS     = "http://afs.eecs.harvard.edu/~goodell/os-icons";
my $URL_SOURCE      = "http://afs.eecs.harvard.edu/user/goodell/etc/exit.pl";
my $URL_HOME        = "http://tor.eff.org/";
my $URL_DIRECTORY   = "http://localhost:9030/tor/";
my $URL_STATUS      = "http://localhost:9030/tor/running-routers";
my $URL_WHOIS       = "http://alsatia.eecs.harvard.edu/cgi-bin/whois.pl\?q=";
my $LINK_DIRECTORY  = "http://serifos.eecs.harvard.edu:9030/tor/";
my $LINK_STATUS     = "http://serifos.eecs.harvard.edu:9030/tor/running-routers";
my $F_CCODES        = "/afs/eecs.harvard.edu/user/goodell/misc/country-codes.txt";
my $WGET            = "/usr/bin/wget -O -";
my $WHOIS           = "/usr/bin/whois";
my $DESC_SCRIPT     = "/cgi-bin/desc.pl";
my $WHOIS_SCRIPT    = "/cgi-bin/whois.pl";
my $ICON_HN         = "hn.gif";
my $ICON_UR         = "ur.gif";
my $ICON_S0         = "s0.gif";
my $ICON_S1         = "s1.gif";
my $ICON_V0         = "v0.gif";
my $ICON_V1         = "v1.gif";
my $ICON_V2         = "v2.gif";
my $ICON_V3         = "v3.gif";
my $P_FLAGS         = "width=18 height=12";
my $P_ICONS         = "width=12 height=12";
my $UV_TEXT         = "unverified node";
my $SYS             = "Tor";
my $DEFAULT_PORT    = "9030";
my $HTTP_PROXY      = "";
my $DESC_DIR        = "";
my $BLOSSOM         = 0;
my $CACHEDAYS       = 90;
my $CACHESECONDS    = 300;
my $MAX_PORT        = 65535;
my $MAXNETLENGTH    = 26;
my $MAXNICKLENGTH   = 20;
my $MAXHOSTLENGTH   = 58;
my $V1_MINBW        = 20;
my $V2_MINBW        = 60;
my $V3_MINBW        = 400;

do $CONFIG if -r $CONFIG;

# other global variables

my %bw              = ();
my %ccode           = ();
my %directory       = ();
my %hops            = ();
my %hr              = ();
my %hw              = ();
my %oses            = ();
my %summary         = ();
my %tr              = ();
my %tw              = ();
my %uptime          = ();
my %cc_matches      = ();

my $DISPLAY_ADDR    = undef;
my $TEXTONLY        = undef;
my $SORTBW          = undef;

# variables for parsing the URI

my %fields          = ();

my $uri             = "";
my $cachefile       = "exit.html";
my $invalid         = undef;
my $response        = "";
my $uri_text        = "";
my $uri_addr        = "";
my $uri_sort        = "";
my $uri_blossom     = "";
my $link_addr       = "";
my $link_sort       = "";
my $success         = undef;

# variables for parsing descriptors

my %all_r           = ();
my %all_u           = ();
my %blossom_path    = ();
my %lines           = ();
my %num             = ();

my @addrbytes       = ();
my @lines           = ();
my @policy          = ();
my @running_routers = ();

my $addr            = "";
my $cc              = "";
my $class           = "";
my $bandwidth       = "";
my $dpublished      = "";
my $dsignature      = "";
my $fingerprint     = "";
my $host            = "";
my $iaddr           = "";
my $icon            = "";
my $netname         = "";
my $p_router        = "";
my $router          = "";
my $router_td       = "";
my $platformline    = "";
my $service         = "";
my $spublished      = "";
my $system          = "";
my $version         = "";

my $hibernating     = undef;

my $fpublished      = 1;
my $maxlength       = 0;
my $maxname         = 0;
my $orport          = 0;
my $socksport       = 0;
my $dirport         = 0;

$num{"uhi"}         = 0;
$num{"uur"}         = 0;
$num{"uv0"}         = 0;
$num{"uv1"}         = 0;
$num{"uv2"}         = 0;
$num{"uv3"}         = 0;
$num{"u"}           = 0;
$num{"vhi"}         = 0;
$num{"vur"}         = 0;
$num{"vv0"}         = 0;
$num{"vv1"}         = 0;
$num{"vv2"}         = 0;
$num{"vv3"}         = 0;
$num{"v"}           = 0;

use vars qw($license);

# subroutines

sub license() {
    print $license;
    exit 0;
}

sub addrouters($) {
    my @sorted      = undef;
    my $href        = shift;
    my $response    = "";
    my %routers     = %$href;

    if($SORTBW) {
        @sorted = sort { $uptime{$a} <=> $uptime{$b} } keys %routers;
        @sorted = sort { $hr{$a} + $hw{$a} <=> $hr{$a} + $hw{$b} } @sorted;
        @sorted = reverse sort { $tr{$a} + $tw{$a} <=> $tr{$b} + $tw{$b} } @sorted;
    } else {
        @sorted = sort keys %routers;
    }

    foreach my $router (@sorted) {
        if($TEXTONLY) {
            $response .= $routers{$router};
        } else {
            $response .= "<tr>\n    " . $routers{$router} . "</tr>\n";
        }
    }
    return $response;
}

sub parsewhois($$$) {
    my ($tag, $default, $arrayref) = (shift, shift, shift);
    my $t;
    my @lines = @$arrayref;
    my @matches = grep /^$tag/i, @lines;

    if($matches[$#matches]) {
        chomp $matches[$#matches];
        ($t = $matches[$#matches]) =~ s/\S+\s+//g;
    } else {
        $t = $default;
    }
    return $t;
}

sub add_field($$) {
    my ($uri, $field) = (shift, shift);

    print STDERR "$uri\n";

    if($uri !~ /^$/) {
        $uri .= "&";
    }
    return $uri . $field;
}

sub remove_field($$) {
    my ($uri, $field) = (shift, shift);
    my @prompts = split /&/, $uri;
    my @returns = ();

    foreach my $prompt (@prompts) {
        push @returns, $prompt unless $prompt =~ /^$field=/;
    }
    return join "&", @returns;
}

sub padded_cell($;$) {
    my ($length, $class) = (shift, shift);
    my $tdclass = $class ? "<td class=\"$class\">" : "<td>";
    my $output = "$tdclass<tt>";

    for(my $x = 0; $x < $length; $x++) {
        $output .= "&nbsp;";
    }
    $output .= "</tt></td>";
    return $output;
}

sub sum($) {
    my @terms = split /,/, shift;
    my $total = 0;
    foreach my $term (@terms) {
        $term += 2<<32 if $term > 0;
        $total += $term;
    }
    return $total;
}

sub by_totals {
    my $aa = $oses{$a}[0] + $oses{$a}[1];
    my $bb = $oses{$b}[0] + $oses{$b}[1];

    if($aa == $bb) {
        return $oses{$a}[0] <=> $oses{$b}[0];
    } else {
        return $aa <=> $bb;
    }
}

sub reset_globals {
    $class          = $TD_DEFAULT;
    $p_router       = undef;
    $router         = undef;
    $router_td      = undef;
    $icon           = "<img $P_FLAGS src=\"$URL_ICONS/$ICON_V0\" alt=\"v0\">";
    $orport         = 0;
    $socksport      = 0;
    $dirport        = 0;
    $hibernating    = undef;

    @lines          = ();
    @policy         = ();
}

sub make_flag($) {
    my $cc = shift;
    my $ccy = lc $cc;
    my $f_ccode = $ccode{$cc} || "~~";
    my $flag = "<img $P_FLAGS src=\"$URL_FLAGS/$ccy.gif\" alt=\"$cc\">";
    return "<acronym title=\"$f_ccode\">$flag</acronym>";
}

# parse the URI parameters

if($ENV{"REQUEST_URI"} && $ENV{"REQUEST_URI"} =~ /\?/) {
    ($uri = $ENV{"REQUEST_URI"}) =~ s/.*\?//g;
}

my @prompts = split /&/, $uri;


foreach (@prompts) {
    my ($k, $v) = split /=/, $_;
    $fields{$k} = $v;
}

if($fields{"sortbw"}) {
    $cachefile = "exit.sortbw.html";
    $SORTBW = 1;
    $uri_sort = remove_field($uri, "sortbw");
    $link_sort = "by country";
} else {
    $uri_sort = add_field($uri, "sortbw=1");
    $link_sort = "by bandwidth";
}

if($fields{"ports"}) {
    $cachefile = undef;

    if($fields{"ports"} !~ /^([0-9]+,)*[0-9]+$/) {
        $invalid = 1;
    } else {
        @portslist = split /,/, $fields{"ports"};
        foreach my $port (@portslist) {
            $invalid = 1 if $port > $MAX_PORT;
        }
    }
}

if($fields{"textonly"}) {
    $cachefile = undef;
    $TEXTONLY = $fields{"textonly"};
} else {
    $uri_text = add_field($uri, "textonly=1");
}

if($fields{"addr"}) {
    $cachefile = undef;
    $DISPLAY_ADDR = 1;
    $uri_addr = remove_field($uri, "addr");
    $link_addr = "show hostnames";
} else {
    $uri_addr = add_field($uri, "addr=1");
    $link_addr = "show addresses";
}

if($fields{"blossom"}) {
    my $B_PORT      = $DEFAULT_PORT;
    $uri_blossom    = remove_field($uri, "blossom");
    $BLOSSOM        = $fields{"blossom"};
    $cachefile      = undef;

    if($fields{"textonly"}
            and $fields{"textonly"} eq "fingerprint"
            and $fields{"addr"}
            and not $fields{"sortbw"}) {
        $cachefile = "exit.blossom.$BLOSSOM.html";
    }

    if($BLOSSOM =~ /^([A-Za-z0-9]+):([0-9]+)$/) {
        $BLOSSOM = $1;
        $B_PORT = $2;
    }

    $TITLE          = "Blossom Network Status: $BLOSSOM";
    $URL_DIRECTORY  = "http://$BLOSSOM.exit:$B_PORT/tor/";
    $URL_STATUS     = "http://$BLOSSOM.exit:$B_PORT/tor/running-routers";
    $LINK_DIRECTORY = "http://$BLOSSOM.exit:$B_PORT/tor/";
    $LINK_STATUS    = "http://$BLOSSOM.exit:$B_PORT/tor/running-routers";
    $HTTP_PROXY     = "http_proxy=http://localhost:8119 ";
    $DESC_DIR       = "$BLOSSOM:$B_PORT";
    $V1_MINBW       = 0;
    $V2_MINBW       = 4;
    $V3_MINBW       = 60;
    $UV_TEXT        = "directory server";
    $URL_HOME       = "http://afs.eecs.harvard.edu/~goodell/blossom/";
    $SYS            = "Blossom";
}

if($invalid) {
    print "Content-type: text/plain\n\n";
    print "invalid input: " . $fields{"ports"} . "\n";
    exit -1;
}

if($cachefile) {
    my ($size, $modified) = (stat "$CACHE/$cachefile")[7, 9];
    if($size && $size > 600 && $modified > time-$CACHESECONDS) {
        open C, "<$CACHE/$cachefile" || die;
        print while(<C>);
        close C;
        exit 0;
    }
}

# parse file containing country codes

open F, "<$F_CCODES" || warn "country code mapping not available";
while(<F>) {
    if(!/^#/) {
        $ccode{$1} = $2 if /^(\S+)\s+(.+)$/;
    }
}
close F;

# compose the header and navigation links

$uri_text =~ s/&/&amp;/g;
$uri_addr =~ s/&/&amp;/g;
$uri_sort =~ s/&/&amp;/g;

if(defined $TEXTONLY) {
    $response = <<EOF
Content-type: text/plain

$TITLE

EOF
;
} else {
    $response = <<EOF
Content-type: text/html

<!doctype html public "-//W3C//DTD HTML 4.01//EN"
    "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>$TITLE</title>
<meta name="Author" content="Geoffrey Goodell">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Content-Style-Type" content="text/css">
<link rel="stylesheet" type="text/css" href="http://serifos.eecs.harvard.edu/style.css">
</head>

<body>

<h1>$TITLE</h1>

<p><tt>
    [<a href="#legend">explanation of symbols</a>]
    [<a href="?$uri_text">text only version</a>]
    [<a href="?$uri_addr">$link_addr</a>]
    [<a href="?$uri_sort">$link_sort</a>]
</tt></p>

<table>

EOF
;
}

# parse the descriptor

open W, "$HTTP_PROXY$WGET $URL_STATUS |" || die;

while(<W>) {
    if(/^published (.*)$/) {
        $spublished = "<a href=\"$LINK_STATUS\">network status</a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$1";
    } elsif(/^router-status /) {
        @running_routers = split;
        shift @running_routers;
        for(my $x = 0; $x <= $#running_routers; $x++) {
            $running_routers[$x] =~ s/=.*$//g;
            $running_routers[$x] =~ y/A-Z/a-z/;
        }
    }
}

close W;

if(1) {
    open W, "$HTTP_PROXY$WGET $URL_DIRECTORY |" || die;
} else {
    open W, "<$DIR_CACHE" || die;
}

while(<W>) {
    chomp;
    $success = 1;

    if(/^published (.*)$/ and $fpublished) {
        $dpublished = "<a href=\"$LINK_DIRECTORY\">directory published</a>&nbsp;$1";
        $fpublished = undef;
    } elsif(/^directory-signature (\S+)$/) {
        $dsignature = lc $1;
    } elsif(/^directory (\S+)\s+(\S+)\s*(\s+\S+)?$/) {
        $directory{$1} = $2;
    } elsif(/^summary (\S+)\s+(\S+)$/) {
        $summary{$1} = $2;
    } elsif(/^blossom-path (\S+)\s+(.+)$/) {
        $blossom_path{$1} = $2;
    } elsif(/^router (\S+) (\S+) (\S+) (\S+) (\S+)$/) {
        ($router, $addr, $orport, $socksport, $dirport) = ($1, $2, $3, $4, $5);
        $router = lc $router;
        $p_router = $router;

        $iaddr = inet_aton($addr);
        @addrbytes = split /\./, $addr;
        for(my $i = 0; $i < 4; $i++) {
            $addrbytes[$i] = int($addrbytes[$i]);
        }

        if(defined $DISPLAY_ADDR) {
            $host = sprintf "%-15s", $2;
            $host =~ s/ /&nbsp;/g if not defined $TEXTONLY;
        } else {
            ($host = gethostbyaddr($iaddr, AF_INET) || $2) =~ y/A-Z/a-z/;
            my ($name, $aliases, $addpe, $length, @addrs) = gethostbyname($host);
            if(not $addrs[0] or $addrs[0] ne $iaddr) {
                my ($a, $b, $c, $d) = unpack 'C4', $iaddr;
                $host = "$a.$b.$c.$d";
            }
        }
        $service = 1;
    } elsif(/^platform Tor (\S+) on (\S+)(\s(\S+))?/) {
        $version = substr $1, 0, 20;
        $system = $2;
        my $extra = "";
        if($4) {
            $extra = $4;
        }
        ($platformline = $_) =~ s/^platform //;
        $platformline =~ s/\"//g;

        $system = "Other" unless grep /^$system$/, @os_names;
        if($system eq "Linux" and ($extra eq "sparc64" or $extra eq "x86_64")) {
            $system .= "64";
        }
        if($system eq "Windows") {
            $system .= $extra;
        }
        $system =~ s/\"//g;
        unless(defined $oses{$system}) {
            my @zeroes = (0, 0);
            $oses{$system} = \@zeroes;
        }
    } elsif(/^(opt\s+)?uptime\s+([0-9]+)$/) {
        $uptime{$router} = $2;
    } elsif(/^(opt\s+)?hibernating\s+([0-9]+)$/) {
        $hibernating = $2;
    } elsif(/^(opt\s+)?fingerprint\s+(.+)$/) {
        ($fingerprint = $2) =~ s/ //g;
        $fingerprint =~ y/a-z/A-Z/;
    } elsif(/^bandwidth ([0-9]+) ([0-9]+) ([0-9]+)$/) {
        if($1 > $3) {
            $bandwidth = $3;
        } else {
            $bandwidth = $1;
        }
    } elsif(/^(opt\s+)?read-history\s+\S+\s+\S+\s+\(([0-9]+)\s+s\)\s+(\S+)$/) {
        my @terms = split /,/, $3;
        $tr{$router} = sum($3);
        $hr{$router} = $tr{$router} / ($#terms+1) / $2;
    } elsif(/^(opt\s+)?write-history\s+\S+\s+\S+\s+\(([0-9]+)\s+s\)\s+(\S+)$/) {
        my @terms = split /,/, $3;
        $tw{$router} = sum($3);
        $hw{$router} = $tw{$router} / ($#terms+1) / $2;
    } elsif(/^accept \S+$/) {
        push @policy, $_;
    } elsif(/^reject \S+$/) {
        push @policy, $_;
    } elsif(/^$/) { # ----- BEGIN ROUTER PROCESSING SECTION -----
        my $cache_succ  = undef;
        my $command     = undef;
        my $t           = undef;

        my $atag        = $A_STANDARD;
        my $b           = $directory{$router};
        my $length      = 0;
        my $whois_proxy = 0;
        my $slen        = 0;
        my $wrapper     = "";

        my @netlast     = ();
        my @matches     = ();

        unless($router){
            reset_globals();
            next;
        }

        # support old scheme for determining hibernating pre-0.1 routers

        if(($version =~ /^0\.0\./)
        && ($uptime{$router} ne "0")
        && ($dirport eq "0")
        && ($bandwidth eq "0")) {
            $hibernating = 1;
        }

        # obtain WHOIS data: check the cache first

        if(-e "$CACHE/$addr") {
            my ($size, $modified) = (stat "$CACHE/$addr")[7, 9];
            $command = "<$CACHE/$addr" if $size && $size > 600 && $modified > time-86400*$CACHEDAYS;
        }

        # otherwise obtain WHOIS data from the Internet

        if(not defined $command) {
            $command = "$WHOIS $addr |";
            $t = 1;
        }
        open X, $command || warn;

        $cache_succ = open Y, ">$CACHE/$addr" if $t;
        while(<X>) {

            # conditions for using an external proxy to conduct WHOIS lookups

            # if($t and /^% This is the RIPE Whois query server #2\.$/) {
            #     $t = 0;
            #     $whois_proxy = 1;
            #     last;
            # }

            push @lines, $_;
            push @netlast, $1 if /\((NET-\S+)\)/;
            print Y if $t && $cache_succ;
        }
        close X;

        # temporary workaround for permanent filtering

        if($whois_proxy) {
            @lines = ();
            open X, "$WGET $URL_WHOIS$addr |" or warn;
            while(<X>) {
                push @lines, $_;
                print Y if $cache_succ;
            }
            close X;
        }

        while(($#netlast > 0) and $t) {
            my $f = 1;
            my $netguess = pop @netlast;
            next unless $netguess and $netguess =~ /^[A-Za-z0-9-.]+$/;
            open X, "$WHOIS $netguess |" || warn;

            while(<X>) {
                push @lines, $_;
                print Y if $cache_succ;
                $f = 0 if /\((NET-\S+)\)/;
            }
            close X;
            last if $f;
        }
        close Y if $cache_succ;

        # parse router statistics

        @matches = grep /^!?$router$/, @running_routers;
        if(not defined $matches[0]) {
            if($BLOSSOM == 0) {
                $class = "td class=\"$A_UNVERIFIED\"";
                $atag = $A_UNVERIFIED;
                $p_router = "*$router";
                $service = undef;
            }
            @matches = grep /^!?\$$fingerprint/, @running_routers;
        }

        if($b) {
            $class = "td class=\"$A_UNVERIFIED\"";
            $atag = $A_UNVERIFIED;
            $p_router = "*$router";
        }

        # a router is VERIFIED iff $service is defined

        if($matches[0] && $matches[0] =~ /^!/) {
            $bandwidth = 0;
            if($hibernating) {
                $icon = "<acronym title=\"hibernating\"><img $P_FLAGS src=\"$URL_ICONS/$ICON_HN\" alt=\"hn\"></acronym>";
                ($service and not $b) ? $num{"vhi"}++ : $num{"uhi"}++;
                $bw{$router} = -1;
            } else {
                $icon = "<acronym title=\"unresponsive\"><img $P_FLAGS src=\"$URL_ICONS/$ICON_UR\" alt=\"ur\"></acronym>";
                ($service and not $b) ? $num{"vur"}++ : $num{"uur"}++;
                $bw{$router} = -2;
            }
            $service ? $oses{$system}[0]++ : $oses{$system}[1]++;
            $service = undef;
        } else {
            my $tooslow = undef;
            $bw{$router} = $bandwidth;
            if($bandwidth >= $V3_MINBW*1000) {
                $icon = "<img $P_FLAGS src=\"$URL_ICONS/$ICON_V3\" alt=\"v3\">";
                ($service and not $b) ? $num{"vv3"}++ : $num{"uv3"}++;
            } elsif($bandwidth >= $V2_MINBW*1000) {
                $icon = "<img $P_FLAGS src=\"$URL_ICONS/$ICON_V2\" alt=\"v2\">";
                ($service and not $b) ? $num{"vv2"}++ : $num{"uv2"}++;
            } elsif(($bandwidth >= $V1_MINBW*1000)
                    and not ($BLOSSOM and ($bandwidth == $V1_MINBW*1000))) {
                $icon = "<img $P_FLAGS src=\"$URL_ICONS/$ICON_V1\" alt=\"v1\">";
                ($service and not $b) ? $num{"vv1"}++ : $num{"uv1"}++;
            } else {
                ($service and not $b) ? $num{"vv0"}++ : $num{"uv0"}++;
                $tooslow = 1;
            }
            $icon = "<acronym title=\"$bandwidth B/s\">$icon</acronym>";
            ($service and not $b) ? $oses{$system}[0]++ : $oses{$system}[1]++;
            $service = undef if $tooslow and ($BLOSSOM == 0);
        }

        # determine the network name from WHOIS results

        $netname = parsewhois("netname", "", \@lines);
        $netname = $addr if length($netname) > $MAXHOSTLENGTH - 16;

        # determine the country (and correct network name if necessary)

        $t = parsewhois("country", undef, \@lines);

        # RFC 1918

        if($addrbytes[0] == 10
                or ($addrbytes[0] == 172
                    and $addrbytes[1] > 15
                    and $addrbytes[1] < 32)
                or ($addrbytes[0] == 192
                    and $addrbytes[1] == 168)) {
            $t = "19";
        }

        # RFC 3330

        if($addrbytes[0] == 0
                or $addrbytes[0] == 127
                or ($addrbytes[0] == 169
                    and $addrbytes[1] == 254)) {
            $t = "33";
        }

        unless($t) {
            $t = "~~";

            # Exception: Brazil
            if(parsewhois("% Copyright registro.br", undef, \@lines)) {
                $t = "BR";
                $netname = parsewhois("aut", "", \@lines);
            }

            # Exception: Japan
            if(parsewhois("\\\[ JPNIC database", undef, \@lines)) {
                $t = "JP";
                $netname = parsewhois("b. \\\[Network Name\\\]", "", \@lines);
            }

            # Exception: Korea
            if(parsewhois("# KOREAN", undef, \@lines)) {
                $t = "KR";
                $netname = parsewhois("Service Name", "", \@lines);
            }
        }
        ($cc = $t) =~ y/a-z/A-Z/;

        $netname = $addr if $netname eq "";

        # generate the wrapper for the host information column

        $t = "";
        if($SORTBW) {
            my $days = int ($uptime{$router}/86400);
            $days = "err" if $days > 999;

            $slen = 1;
            # $t = sprintf "%7s B/s %3sd ", $bandwidth, $days;
            $t = sprintf "%4s %4s %4s ",
                    int($bw{$router}/1000), int($hr{$router}/1000), int($hw{$router}/1000);
            $t = " err  err  err " if length $t > 15;
            my $tt = sprintf "%4s ", int($uptime{$router}/86400);
            if(length $tt > 5) {
                $t .= " err ";
            } else {
                $t .= $tt;
            }
            $wrapper = $t;
            $wrapper =~ s/ /&nbsp;/g if not $TEXTONLY;
            $host = $wrapper . $host;
            if($DISPLAY_ADDR) {
                $host .= " $version";
                $host =~ s/ /&nbsp;/g if not $TEXTONLY;
            }
        } elsif(not $TEXTONLY) {
            $slen = 3;
            $t = $netname;
            $wrapper = "&nbsp;[<a class=\"$atag\" href=\"$WHOIS_SCRIPT?q=$addr\">$t</a>]";
            $host .= $wrapper;
        }
        $length = $slen + (length $host)-(length $wrapper)+(length $t);

        # format the host information to satisfy length constraints

        if(($length > $MAXHOSTLENGTH) && (not $DISPLAY_ADDR) && (not $TEXTONLY)) {
            if($SORTBW) {
                (my $name = $host) =~ s/^.*;//g;
                $host = substr $name, $length-$MAXHOSTLENGTH;
                $host =~ s/^(\S+?)\./\*\./;
                ($host = $t . $host) =~ s/ /&nbsp;/g;
            } else {
                $host = substr $host, $length-$MAXHOSTLENGTH;
                $host =~ s/^(\S+?)\./\*\./;
            }
        }
        if($DISPLAY_ADDR) {
            if($SORTBW) {
                $length = $slen + 36 + (length $version);
            } else {
                $length = $slen + 16 + (length $t);
            }
        } else {
            $length = $slen + (length $host)-(length $wrapper)+(length $t);
        }

        $maxlength = $length if $maxlength < $length;

        $p_router = substr $p_router, 0, $MAXNICKLENGTH if length $router > $MAXNICKLENGTH;
        if($BLOSSOM) {
            if($b) {
                my $b_port = ($b == $DEFAULT_PORT) ? "" : ":$b";
                my $uri_redirect = add_field($uri_blossom, "blossom=$router$b_port");
                $router_td = "<a class=\"$atag\" href=\"?$uri_redirect\">$p_router</a>";
            } else {
                $router_td = "<a class=\"$atag\" href=\"$DESC_SCRIPT?q=$router&amp;blossom=$DESC_DIR\">$p_router</a>";
            }
        } else {
            $router_td = "<a class=\"$atag\" href=\"$DESC_SCRIPT?q=$router\">$p_router</a>";
        }
        $maxname = length $p_router if $maxname < length $p_router;

        if($SORTBW) {
            $router_td = sprintf "%s&nbsp;%s", make_flag($cc), $router_td;
        } else {
            if($cc =~ /US|CA/) {
                $t = parsewhois("stateprov", "&nbsp;&nbsp;", \@lines);
                $t = "~~" unless $t =~ /^[A-Z][A-Z]$/;
                $router_td = "$t&nbsp;$router_td&nbsp;";
            } else {
                $router_td = "&nbsp;&nbsp;&nbsp;$router_td&nbsp;";
            }
        }
        $cc_matches{$cc} = 0 if not defined $cc_matches{$cc};

        # ----- END ROUTER PROCESSING SECTION -----

        my %accept   = ();

        # format the output for this router

        if($TEXTONLY) {
            my $format = "%2s %-${MAXNICKLENGTH}s ";

            $p_router = substr $p_router, 0, $MAXNICKLENGTH;
            if($DISPLAY_ADDR and not $SORTBW) {
                my $tformat = "%7s B/s %-15s %-${MAXNETLENGTH}s";
                $netname = substr $netname, 0, $MAXNETLENGTH;
                $host = sprintf $tformat, $bandwidth, $host, $netname;
                $format .= "%s";
            } else {
                $host = substr $host, 0, $MAXHOSTLENGTH;
                $format .= "%-${MAXHOSTLENGTH}s";
            }
            ${$lines{$cc}}{$router} = sprintf $format, $cc, $p_router, $host;
        } else {
            ${$lines{$cc}}{$router} = "<$class><tt>$router_td</tt></td><$class><tt>$icon&nbsp;$host</tt></td>\n";
        }

        # parse exit policy

        foreach my $PORT (@portslist) {
            for(my $x = 0; $x <= $#policy; $x++) {
                if($policy[$x] =~ /^(\S+) \*:([0-9]+)-([0-9]+)$/) {
                    if ($2 <= $PORT && $3 >= $PORT) {
                        $accept{$PORT} = 1 if $1 eq "accept";
                        last;
                    }
                } elsif($policy[$x] =~ /^(\S+) \*:$PORT$/) {
                    $accept{$PORT} = 1 if $1 eq "accept";
                    last;
                } elsif($policy[$x] =~ /^(\S+) \*:\*$/) {
                    $accept{$PORT} = 1 if $1 eq "accept";
                    last;
                }
            }
        }

        unless($TEXTONLY) {
            ${$lines{$cc}}{$router} .= "    <td class=\"centered\"><acronym title=\"$platformline\"><img $P_ICONS src=\"$URL_OSICONS/$system.png\" alt=\"*\"></acronym></td>\n";
        }

        # compose exit policy output

        my $f = undef;

        if($TEXTONLY and $TEXTONLY eq "fingerprint") {
            ${$lines{$cc}}{$router} .= " $fingerprint";
        } else {
            foreach my $PORT (@portslist) {
                if($TEXTONLY) {
                    if(defined $accept{$PORT}) {
                        ${$lines{$cc}}{$router} .= sprintf "%5s", $PORT;
                        $f = 1;
                    } else {
                        ${$lines{$cc}}{$router} .= "    -";
                    }
                } else {
                    if(defined $accept{$PORT}) {
                        if($service) {
                            ${$lines{$cc}}{$router} .= "    <td class=\"entry\"><tt>$PORT</tt></td>\n";
                        } else {
                            ${$lines{$cc}}{$router} .= "    <td class=\"dimentry\"><tt>$PORT</tt></td>\n";
                        }
                    } else {
                        ${$lines{$cc}}{$router} .= sprintf "    %s\n", padded_cell(4);
                    }
                }
            }
        }
        ${$lines{$cc}}{$router} .= "\n" if defined $TEXTONLY;
        delete ${$lines{"~~"}}{$router} if ${$lines{"~~"}}{$router};
        delete $lines{"~~"} unless (keys %{$lines{"~~"}});
        $hops{$router} = -1;
        $cc_matches{$cc}++ if $f;

        # display Blossom summaries

        if($summary{$router}) {
            foreach my $elt (split /,/, $summary{$router}) {
                my $num_hops = "1";
                my $router_elt = $router;
                if($elt =~ /^(\S+)=([0-9]+)$/) {
                    $router_elt = $1;
                    $num_hops = $2;
                }

                next if $router_elt eq $router;

                @matches = grep /^!?$router_elt$/, @running_routers;
                if(defined $matches[0]) {
                    $icon = "<img $P_FLAGS src=\"$URL_ICONS/$ICON_S1\" alt=\"s1\">";
                } else {
                    $icon = "<img $P_FLAGS src=\"$URL_ICONS/$ICON_S0\" alt=\"s0\">";
                }
                if((not $hops{$router_elt}) or $hops{$router_elt} > int $num_hops) {

                    $hops{$router_elt} = int $num_hops;
                    %{$lines{"~~"}} = () unless $lines{"~~"};

                    if($TEXTONLY) {
                        ${$lines{"~~"}}{$router_elt} = "        $router_elt\n";
                    } else {
                        ${$lines{"~~"}}{$router_elt} = "    <td><tt>&nbsp;&nbsp;&nbsp;$router_elt&nbsp;</tt></td>\n";
                        ${$lines{"~~"}}{$router_elt} .= "    <td><tt>$icon&nbsp;$num_hops via $router</tt></td>\n";
                    }

                }
            }
        }

        # reset the control variables for the next router

        reset_globals();
    }
}
close W;

# compose the table of results

my $f;
foreach $cc (sort keys %lines) {
    if($cc !~ /^$/) {
        my $flag = make_flag($cc);
        my $nodes = scalar keys %{$lines{$cc}};

        my $upnodes = 0;
        foreach $router (sort keys %{$lines{$cc}}) {
            if(${$lines{$cc}}{$router} !~ /hibernating/
                    and ${$lines{$cc}}{$router} !~ /unresponsive/) {
                $upnodes++
            }
        }

        if($SORTBW) {
            foreach $router (sort keys %{$lines{$cc}}) {
                if(${$lines{$cc}}{$router} =~ /unresponsive/) {
                    $all_u{$router} = ${$lines{$cc}}{$router};
                } else {
                    $all_r{$router} = ${$lines{$cc}}{$router};
                }
            }
        } else {

            if(defined $f) {
                if(not defined $TEXTONLY) {
                    $response .= sprintf "\n<tr>%s</tr>\n", padded_cell(1);
                }
            } else {
                $f = 1;
            }

            if(defined $TEXTONLY) {
                $response .= "\n$cc [$nodes] " . $cc_matches{$cc} . "\n";
            } else {
                $response .= "<tr>\n";
                $response .= "    <td class=\"heading\"><tt>$cc&nbsp;$flag&nbsp;$upnodes/$nodes</tt></td>\n";
                $response .= sprintf "    %s\n", padded_cell($maxlength + 4, "heading");
                $response .= sprintf "    %s\n", padded_cell(2);
                foreach my $PORT (@portslist) {
                    $response .= sprintf "    %s\n", padded_cell(4);
                }
                $response .= "</tr>\n";
            }
            $response .= addrouters(\%{$lines{$cc}});
        }
    }
}

if($SORTBW) {
    $response .= addrouters(\%all_r);

    # add a blank line between responsive and unresponsive routers

    unless($TEXTONLY) {
        $response .= "<tr>\n";
        $response .= sprintf "    %s\n", padded_cell($maxname+5);
        $response .= sprintf "    %s\n", padded_cell($maxlength+4);
        $response .= sprintf "    %s\n", padded_cell(2);
        foreach my $PORT (@portslist) {
            $response .= sprintf "    %s\n", padded_cell(4);
        }
        $response .= "</tr>\n";
    }

    $response .= addrouters(\%all_u);
}


# perform final formatting operations

$num{"v"} = $num{"vur"}+$num{"vhi"}+$num{"vv0"}+$num{"vv1"}+$num{"vv2"}+$num{"vv3"};
$num{"u"} = $num{"uur"}+$num{"uhi"}+$num{"uv0"}+$num{"uv1"}+$num{"uv2"}+$num{"uv3"};

foreach my $number (sort keys %num) {
    $num{$number} = sprintf "%4s", $num{$number};
    $num{$number} =~ s/ /&nbsp;/g;
}

if($uri ne "") {
    $uri = "%3F$uri";
    $uri =~ s/&/%26/g;
    $uri =~ s/=/%3D/g;
}

# compose the legend and footer

if(not defined $TEXTONLY) {
    my @bwheader = {"", "", "", ""};
    if($BLOSSOM) {
        $bwheader[0] = "zero throughput";
        $bwheader[1] = "marginal throughput";
    } else {
        $bwheader[0] = "zero or marginal throughput";
        $bwheader[1] = "throughput &gt;= $V1_MINBW kB/s";
    }
    $bwheader[2] = "throughput &gt;= $V2_MINBW kB/s";
    $bwheader[3] = "throughput &gt;= $V3_MINBW kB/s";
    $response .= <<EOF

</table>

<p></p>

<table id=legend>
    <tr>
        <td><tt><img $P_FLAGS src="$URL_ICONS/$ICON_UR" alt="ur"> = unresponsive node</tt></td>
        <td class="number"><tt>${num{vur}}</tt></td>
        <td class="unverifiednumber"><tt>${num{uur}}</tt></td>
    </tr><tr>
        <td><tt><img $P_FLAGS src="$URL_ICONS/$ICON_HN" alt="hn"> = hibernating node</tt></td>
        <td class="number"><tt>${num{vhi}}</tt></td>
        <td class="unverifiednumber"><tt>${num{uhi}}</tt></td>
    </tr><tr>
        <td><tt><img $P_FLAGS src="$URL_ICONS/$ICON_V0" alt="v0"> = $bwheader[0]</tt></td>
        <td class="number"><tt>${num{vv0}}</tt></td>
        <td class="unverifiednumber"><tt>${num{uv0}}</tt></td>
    </tr><tr>
        <td><tt><img $P_FLAGS src="$URL_ICONS/$ICON_V1" alt="v1"> = $bwheader[1]</tt></td>
        <td class="number"><tt>${num{vv1}}</tt></td>
        <td class="unverifiednumber"><tt>${num{uv1}}</tt></td>
    </tr><tr>
        <td><tt><img $P_FLAGS src="$URL_ICONS/$ICON_V2" alt="v2"> = $bwheader[2]</tt></td>
        <td class="number"><tt>${num{vv2}}</tt></td>
        <td class="unverifiednumber"><tt>${num{uv2}}</tt></td>
    </tr><tr>
        <td><tt><img $P_FLAGS src="$URL_ICONS/$ICON_V3" alt="v3"> = $bwheader[3]</tt></td>
        <td class="number"><tt>$num{vv3}</tt></td>
        <td class="unverifiednumber"><tt>$num{uv3}</tt></td>
    </tr>
    <tr><td><tt>&nbsp;</tt></td></tr>
EOF
;

    # provide OS statistics

    foreach my $os (reverse sort by_totals keys %oses) {
        my $vn = sprintf "%4s", $oses{$os}[0];
        my $un = sprintf "%4s", $oses{$os}[1];
        my $f_os = $os;
        $f_os =~ s/Windows/Windows /;
        $f_os =~ s/Linux64/Linux 64/;

        $vn =~ s/ /&nbsp;/g;
        $un =~ s/ /&nbsp;/g;

        $response .= <<EOF
    <tr>
        <td><tt>os&nbsp;<img $P_ICONS src="$URL_OSICONS/$os.png" alt="*">&nbsp;$f_os</tt></td>
        <td class="number"><tt>$vn</tt></td>
        <td class="unverifiednumber"><tt>$un</tt></td>
    </tr>
EOF
;
    }

    $response .= <<EOF
    <tr>
        <td class="unverified"><tt>* = $UV_TEXT</tt></td>
    </tr><tr>
        <td><tt>total nodes</tt></td>
        <td class="number"><tt>${num{v}}</tt></td>
        <td class="unverifiednumber"><tt>${num{u}}</tt></td>
    </tr><tr>
        <td><tt>directory&nbsp;signature&nbsp;$dsignature</tt></td>
    </tr><tr>
        <td><tt>$dpublished</tt></td>
        <td><tt>&nbsp;UTC</tt></td>
        <td><tt>&nbsp;&nbsp;&nbsp;&nbsp;</tt></td>
    </tr><tr>
        <td><tt>$spublished</tt></td>
        <td><tt>&nbsp;UTC</tt></td>
        <td><tt>&nbsp;&nbsp;&nbsp;&nbsp;</tt></td>
    <tr><td><tt><a href="$URL_SOURCE">source code</a>&nbsp;[<a href="$URL_HOME">official $SYS website</a>]</tt></td></tr>
</table>

<p><a href="http://validator.w3.org/check?uri=http%3A%2F%2Fserifos.eecs.harvard.edu%2Fcgi-bin%2Fexit.pl$uri"><img src="http://validator.w3.org/images/vh401.gif" alt="valid HTML 4.01"/></a></p>

<p><a href="http://jigsaw.w3.org/css-validator/validator?uri=http%3A%2F%2Fserifos.eecs.harvard.edu%2Fcgi-bin%2Fexit.pl"><img src="http://jigsaw.w3.org/css-validator/images/vcss" alt="valid CSS"/></a></p>

</body></html>

EOF
;
}

# cache the result

if($cachefile and $success) {
    open C, ">$CACHE/$cachefile" || die;
    print C $response;
    close C;
}

# output the result

print $response;
exit 0;

