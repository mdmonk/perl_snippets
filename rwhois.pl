#!/usr/bin/perl
#
# iswho
# 
# Wrapper around whois so that we can get around this stupid NSI crap of
# indirect queries
#

# Print usage if not the right number of args specified.
die "Usage: iswho user[@<whois.server>]\n" if ($#ARGV != 0);

# Query the whois server
$output = `whois $ARGV[0] 2>&-`;

# Do another query if the whois server is not specified.
if ($ARGV[0] !~ /@/) {
        my ($whois) = ($output =~ /Whois Server:\s+(.*)\n/);    

        $output = `whois $ARGV[0]\@$whois 2>&-`;
}

print $output;
