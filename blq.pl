#!/usr/bin/env perl -w --
# $Id: blq,v 1.23 2002/11/13 19:16:03 chip Exp $
#
# blq - block list query
#
# See <http://www.unicom.com/sw/blq/> for latest version.
#
# Chip Rosenthal
# <chip@unicom.com>
#
# Perl POD documentation at the end.
#

$0 =~ s!.*/!!;

use strict;
use Getopt::Std;
use Net::hostent;
use Socket;
use vars qw($Usage %ZoneTags $DefaultId $ShowAddrFlag $NoRevLookup $GetTxtInfo);

%ZoneTags = (

	###
	#
	# The "default" tag is used if no other is given.  Originally,
	# the default query was to "rbl".  That's been deprecated since
	# the MAPS RBL is no longer public.  I've selected a small number
	# of lists to use as the default.  Of course, you are free to
	# change it if you don't like my selection.
	#
	#"default"	=> "rbl",
	"default"	=> [qw(sbl rsl pdl opm relays)],

	###
	#
	# Spamhaus Block List <http://www.spamhaus.org/SBL/>
	#
	"sbl"		=> "sbl.spamhaus.org",

	###
	#
	# Relay Stop List <http://relays.visi.com/>
	#
	"rsl"		=> "relays.visi.com",

	###
	#
	# Pan-American Dailup List <http://www.pan-am.ca/pdl/>
	#
	"pdl"		=> "dialups.visi.com",

	###
	#
	# Open Relay Database <http://www.ordb.org/>
	#
	"ordb"		=> "relays.ordb.org",

	###
	#
	# Not Just Another Bogus List <http://njabl.org/>
	#
	"njabl"		=> "dnsbl.njabl.org",

	###
	#
	# Extreme Spam Blocking List <http://www.selwerd.cx/xbl/>
	#
	"xbl"		=> "xbl.selwerd.cx",

	###
	#
	# <http://www.five-ten-sg.com/blackhole.php>
	"fiveten"	=> "blackholes.five-ten-sg.com",

	###
	#
	# SpamCop Block List <http://spamcop.net/bl.shtml>
	#
	"spamcop"	=> "bl.spamcop.net",

	###
	#
	# Habeas Infringers List <http://www.habeas.com/services/infringers.htm>
	#
	"hil"		=> "hil.habeas.com",

	###
	#
	# RFC-Ignorant ipwhois list  <http://www.rfc-ignorant.org/policy-ipwhois.php>
	#
	"rfci"		=> "ipwhois.rfc-ignorant.org",

	###
	#
	# Open Proxy Monitor List <http://www.blitzed.org/opm/>
	#
	"opm-wingate"	=> "wingate.opm.blitzed.org",
	"opm-socks"	=> "socks.opm.blitzed.org",
	"opm-http"	=> "http.opm.blitzed.org",
	"opm"		=> "opm.blitzed.org",
	"opm-all"	=> [qw(opm opm-wingate opm-socks opm-http)],

	###
	#
	# IDs for zones hosted by osirusoft.com
	#
	"relays"	=> "relays.osirusoft.com",
	"dialups"	=> "dialups.relays.osirusoft.com",
	"spamsites"	=> "spamsites.relays.osirusoft.com",
	"spamhaus"	=> "spamhaus.relays.osirusoft.com",
	"spews"		=> "spews.relays.osirusoft.com",
	"blocktest"	=> "blocktest.relays.osirusoft.com",
	"outputs"	=> "outputs.relays.osirusoft.com",

	# aggregate of all osirusoft.com zones ... except:
	# "blocktest" excluded ... it's not supposed to be used for filtering
	"osirusoft"	=> [qw(relays dialups spamsites
				spamhaus spews outputs)],

	# same as above ... for use in "all" aggregate ... except:
	# "spamhaus" excluded ... it's just an alternate feed of SBL
	# "blocktest" included ...
	"osirusoft-all"	=> [qw(relays dialups spamsites
				spews blocktest outputs)],

	###
	#
	# Distributed Server Boycott List <http://dsbl.org/>
	#
	"dsbl-list"	=> "list.dsbl.org",
	"dsbl-multihop"	=> "multihop.dsbl.org",
	"dsbl-unconfirmed" => "unconfirmed.dsbl.org",
	"dsbl"		=> [qw(dsbl-list dsbl-multihop dsbl-unconfirmed)],

	###
	#
	# IDs for zones hosted by mail-abuse.org (MAPS)
	#
	"rbl+"		=> "rbl-plus.mail-abuse.org",
	"rbl"		=> "blackholes.mail-abuse.org",
	"dul"		=> "dialups.mail-abuse.org",
	"rss"		=> "relays.mail-abuse.org",

	# alias for back-compatibility with original name
	# *** this tag deprecated as of 24-Feb-2002
	"rrss"		=> "rss",

	# aggregate of all MAPS zones
	"maps"		=> [qw(rbl dul rss)],

	###
	#
	# "all" aggregate - query all lists.
	#
	"all" => [qw(sbl rsl pdl ordb njabl xbl fiveten spamcop hil rfci
		opm-all osirusoft-all dsbl maps)]

);

$Usage = "usage: $0 [-ant] [list-id-or-zone[,...]] host-name-or-address\n"
	. "  (known list-ids = " . join(", ", keys %ZoneTags) . ")\n";

#
# Grab command line arguments.
#
my %opts;
getopts('ant', \%opts) or die $Usage;
$ShowAddrFlag = $opts{'a'};
$NoRevLookup = $opts{'n'};
$GetTxtInfo = $opts{'t'};
my @server_list = munge_server_spec((@ARGV > 1) ? shift(@ARGV) : "default");
if (@ARGV != 1) {
	die $Usage
}
my @query_list = canonicalize_query(shift(@ARGV));

#
# Pull in Net::DNS only if we are going to be doing TXT lookups.
# That way we can leave it optional for basic functionality.
#
eval 'use Net::DNS'
	if ($GetTxtInfo);

#
# Iterate through the list of servers, performing the requested queries.
#
my($zone, $query, $qtarget, $h, @result, @txtinfo, $ex);
$ex = 0;
foreach $zone (@server_list) {
	foreach $query (@query_list) {

		# output format is:
		#   206.47.217.48 : spews.relays.osirusoft.com : BLOCKED

		undef(@txtinfo);
		undef(@result);
		push(@result, $query->{ADDR});
		if (defined($query->{NAME})) {
			push(@result, $query->{NAME});
		}
		push(@result, ":", $zone, ":");

		$qtarget = calculate_query_target($query->{ADDR}, $zone);
		$h = gethostbyname($qtarget);
		if (defined($h)) {
			push(@result, "BLOCKED");
			if ($ShowAddrFlag) {
				$_ = inet_ntoa(@{$h->addr_list}[0]);
				push(@result, "($_)");
			}
			if ($GetTxtInfo) {
				@txtinfo = query_txt($qtarget);
			}
			$ex = 2
		} else {
			push(@result, "ok");
		}

		print join(" ", @result), "\n";
		print "\t", join("\n\t", @txtinfo), "\n"
			if (@txtinfo);
	}
}
exit($ex);


#
# munge_server_spec - given a list of block list server zones and IDs
# ($server_spec), generate an array containing the block list server zones
# to query (@server_list).
#
sub munge_server_spec
{
	die q[usage: munge_server_spec($server_spec)]
		unless (@_ == 1);
	my $server_spec = shift;
	my @server_list_result = ( );
	my @spec_queue;
	my %did_server;
	my $t;

	@spec_queue = split(/[\s,]+/, $server_spec);
	while (@spec_queue > 0) {

		# grab next entry from the specification
		$_ = shift(@spec_queue);

		# if it might be a DNS zone then add it to our list
		if (/\./) {
			push(@server_list_result, $_)
				if (! $did_server{$_}++);
			next;
		}

		# see if it is a tag we recognize
		$t = $ZoneTags{$_}
			or die "$0: unknown block list \"$_\"\n", $Usage;

		# tags may refer to a single entry or an aggregate of entries
		if (ref($t) eq "ARRAY") {
			unshift(@spec_queue, @{$t});
		} else {
			unshift(@spec_queue, $t);
		}

	}

	return @server_list_result;
}



#
# canonicalize_query() - Given a $query of some form (either a hostname
# or hostaddr) produce a list of ($hostname, $hostaddr) pairs.  The list
# typically will have only a single entry.  The exception is if a hostname
# resolves to multiple addresses.
#
sub canonicalize_query
{
	die q[usage: canonicalize_query($query)]
		unless (@_ == 1);
	my $query = shift;
	my($addr, $name, $h);
	my @ret = ();

	if ($query =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
		# query specified as an address
		$addr = $query;
		if ($NoRevLookup) {
			$name = undef;
		} else {
			$h = gethostbyaddr(inet_aton($addr));
			$name = ($h ? $h->name : undef);
		}
		push(@ret, {'NAME' => $name, 'ADDR' => $addr});
	} else {
		# query specified as a hostname
		$name = $query;
		$h = gethostbyname($name)
			or die "$0: gethostbyname($name) failed\n";
		foreach $addr (@{$h->addr_list}) {
			push(@ret, {'NAME' => $name, 'ADDR' => inet_ntoa($addr)});
		}
	}

	return @ret;
}


#
# calculate_query_target() - Determine DNS query value to locate $addr
# within the block list published at $zone.
#
sub calculate_query_target
{
	die q[usage: calculate_query_target($addr, $zone)]
		unless (@_ == 2);
	my($addr, $zone) = @_;

	# put dot on end to avoid searchlist
	$zone .= "."
		unless ($zone =~ /\.$/);

	$addr =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/
		or die "$0: bad address \"$addr\"\n";

	return "$4.$3.$2.$1.$zone";
}


#
# query_txt() - Query for TXT information associated with $v.
#
sub query_txt
{
	die q[usage: query_txt($v)]
		unless (@_ == 1);
	my($v) = @_;

	my $res = new Net::DNS::Resolver;
	my $query = $res->query($v, "TXT")
		or die("$0: resolver->query($v, \"TXT\") failed: $!\n");

	my @result = ( );
	foreach my $rr ($query->answer) {
		if ($rr->type eq "TXT") {
			$_ = $rr->rdatastr;
			s/^"//;
			s/"$//;
			push(@result, $_);
		}
	}

	undef $res;
	return @result;
}


__END__

=head1 NAME

blq - Inquire an email block list server.

=head1 SYNOPSIS

B<blq> I<-at> [list-id-or-zone[, ...]] host-name-or-address

=head1 DESCRIPTION

Several organizations publish mail abuse lists via DNS.  B<blq> inquires
those lists to determine if a particular host is present.

The I<list-id-or-zone> selects which list to query.  It may be the
full DNS zone of the block list (such as "blackholes.mail-abuse.org"), one of
a number of pre-defined IDs (see below), or a list (comma or space
delimited) of these items.

As distributed, the pre-defined set of IDs includes:
 
 List-Id	List-Zone
 -------	--------------------

 sbl		sbl.spamhaus.org
 rsl		relays.visi.com
 pdl		dialups.visi.com
 ordb		relays.ordb.org
 njabl		dnsbl.njabl.org
 xbl		xbl.selwerd.cx
 fiveten	blackholes.five-ten-sg.com
 spamcop	bl.spamcop.net
 hil		hil.habeas.com
 
 opm		opm.blitzed.org (combines the following lists)
 opm-wingate	wingate.opm.blitzed.org
 opm-socks	socks.opm.blitzed.org
 opm-http	http.opm.blitzed.org
 opm-all	(all the opm.blitzed.org zones)
 
 relays		relays.osirusoft.com
 dialups	dialups.relays.osirusoft.com
 spamsites	spamsites.relays.osirusoft.com
 spamhaus	spamhaus.relays.osirusoft.com (alternate feed of SBL)
 spews		spews.relays.osirusoft.com
 blocktest	blocktest.relays.osirusoft.com (not for filtering)
 outputs	outputs.relays.osirusoft.com
 osirusoft	(all osirusoft.com zones, except blocktest)

 dsbl-list	list.dsbl.org
 dsbl-multihop	multihop.dsbl.org
 dsbl-unconfirmed unconfirmed.dsbl.org
 dsbl		(all dsbl.org zones)
 
 rbl		blackholes.mail-abuse.org
 dul		dialups.mail-abuse.org
 rss		relays.mail-abuse.org
 maps		(all mail-abuse.org zones)
 
 all		(all the above)
 default	sbl, rsl, pdl, opm and relays
 

If no I<list-id-or-zone> is specified, then B<default> is used.

The I<host-name-or-address> is the query to perform, specified either as
a name or IP address.  All the block lists are indexed by host address,
not name.  Thus, when a host name is given, it must be (and will be)
resolved to an address for the query.

If a name resolves to multiple addresses, they all will be queried.

The output contains three colon-delimited fields, and looks
something like:

 blackholes.mail-abuse.org : 192.168.117.89 relay.spamhausen.com : BLOCKED

The first field lists the zone queried.  The second field lists the query:
the host address followed by the name it resolves to.  The third field
lists the result:  "BLOCKED" if the host is on the list, "ok" if it isn't.

The following options are available:

=over 8

=item B<-a>

Some block lists provide additional information on a listed entry.
This information is encoded as an IP address.  The B<-a> option displays
the address codes encountered for blocked entries.

=item B<-n>

Normally, when the target is specified as an address, a reverse lookup
is performed to determine the hostname.  When B<-n> is specified the
reverse lookup is suppressed, and just the numeric address is displayed.

=item B<-t>

Some block lists provide additional information in TXT records.  If the
B<-t> option is specified, I<blq> will fetch any TXT records associated
with a list entry.  The information found will be printed on subsequent
lines, indented one tabstop.

=back

=head1 SEE ALSO

 dsbl		http://dsbl.org/
 dul		http://mail-abuse.org/dul/
 fiveten	http://www.five-ten-sg.com/blackhole.php
 hil		http://www.habeas.com/services/infringers.htm
 njabl		http://njabl.org/
 opm		http://www.blitzed.org/opm/
 ordb		http://www.ordb.org/
 pdl		http://www.pan-am.ca/pdl/
 rbl		http://mail-abuse.org/rbl/
 rsl		http://relays.visi.com/
 rss		http://mail-abuse.org/rss/
 sbl		http://www.spamhaus.org/SBL/
 spamcop	http://spamcop.net/bl.shtml
 xbl		http://www.selwerd.cx/xbl/

=head1 DIAGNOSTICS

An exit status of zero indicates the host was not listed ("ok").  An exit
status of two indicates that it was listed ("BLOCKED").  Any other
non-zero exit status is an error.

=head1 BUGS

Inclusion of a particular list in this utility should B<not> be
construed as an endorsement by the program author.  I use some of
these lists for email filtering.  I believe some of these lists
are evil.  You should visit their web pages, read their policies,
and decide for yourself.

=head1 AUTHOR

 Chip Rosenthal
 <chip@unicom.com>

 $Id: blq,v 1.23 2002/11/13 19:16:03 chip Exp $
 See http://www.unicom.com/sw/blq/ for latest version.


