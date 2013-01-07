#!/usr/bin/perl -w
#
# Copyright (C) 2010, Joshua D. Abraham (jabra@spl0it.org)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
# use strict;
#
# proxycrawl.pl - perform web requests using a proxy
#
#
use strict;
use Getopt::Long;
use vars qw( $PROG );
( $PROG = $0 ) =~ s/^.*[\/\\]//;    # Truncate calling path from the prog name
my $AUTH    = 'Joshua "Jabra" Abraham';  # author
my $EMAIL   = 'jabra@spl0it.org';   # email
my $VERSION = '1.00';               # version

my @scheme;
my $proxy=8080;
my %options;
#
# help:
# display help information
#
sub help {
    print "Usage: $PROG [Input Option] [Option]
    -i  --input [file]      Input web applications (default HTTP)
    -s  --ssl               Use HTTPS, instead of HTTP
    -b  --both              Using both HTTP and HTTPS
    -p  --proxy [int]       Proxy port (default 8080)

    -v  --version           Display version
    -h  --help              Display this information
Send Comments to $AUTH ( $EMAIL )\n";
    exit;
}

#
# print_version:
# displays version
#
sub print_version {
    print "$PROG version $VERSION by $AUTH ( $EMAIL )\n";
    exit;
}

if ( @ARGV == 0 ) {
    help;
}
GetOptions(
    \%options,
    'input|i=s', 'both|b', 'ssl|s', 'proxy|p=i',
    'help|h'    => sub { help(); },
    'version|v' => sub { print_version(); },
) or exit 1;

if ( defined( $options{ssl} )  ) {
    push(@scheme, 'https');
}
elsif ( defined( $options{both} ) ) {
    push(@scheme, 'http');
    push(@scheme, 'https');
}
else {
    push(@scheme, 'http');
}
if ( defined( $options{proxy} ) ) {
    $proxy=$options{proxy};
}

if ( defined( $options{input} ) ) {
    open(IN, $options{input}) or die "can't open input file\n";
    my @ary = <IN>;
    use LWP::UserAgent;
    require LWP::UserAgent;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->proxy(['http', 'https'], "http://localhost:$proxy/");
    foreach my $s (@scheme) {
        chomp($s);
        foreach my $i (@ary) {
            chomp($i);
            print "Requesting $s://$i\n";
            my $response = $ua->get("$s://$i");
        }
    }
}
else {
    help();
}
