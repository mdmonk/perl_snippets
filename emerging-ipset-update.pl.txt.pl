#!/usr/bin/perl
#
# Name: emerging-ipset-update.pl
# Shamelessy stolen from Author: Joshua Gimer <jgimer@gmail.com> ;-)
# Last Update: Wed Jan 28 04:45:01 CST 2009 
# Version: 1.0
#
# This will check for an updated FW ruleset based on the revision number from Emerging Threats.
# If the revison number is newer indicating a change, the rules will be flushed and repopulated.
# 

use strict;
use LWP;
use Sys::Syslog;
use Unix::PID;
print "Now backgrounding emerging-ipset process...\n";
fork and exit;

Unix::PID->new()->pid_file('/var/run/emerging-ipset-update.pid') or die 'The PID in /var/run/emerging-ipset-update.pid is still running.';

#use Net::IP::Match::Regexp qw( create_iprange_regexp match_ip );

my $timer='43200'; # The refresh timer in seconds. Default: 43200 (Roughly 2 times a day)

openlog('EMERGING-IPTABLES-BLOCK', 'pid', 'info');

# The location of the Emerging Threats revison number file.
my $emerging_fwrev='http://www.emergingthreats.net/fwrules/FWrev';
# The location of the Emerging Threats ruleset.
my $emerging_fwrules='http://www.emergingthreats.net/fwrules/emerging-Block-IPs.txt';

my $tmp = '/tmp/';			       # The temporary directory you want to use.
my $rules_file=$tmp . 'emerging_iptables.txt'; # The name of the temp rules file.

my $iptables='/sbin/iptables';	     # The location of the IPTables binary.
my $ipset='/usr/sbin/ipset';         # The location of the ipset binary.
my $iptables_att_chain='ATTACKERS';  # The name of the Netfilter attack chain.
my $iptables_drop_chain='ETLOGDROP'; # The name of the Netfilter DROP chain.
my $ipset_botcc='botcc';
my $ipset_botccnet='botccnet';

# Whitelist of ip addresses and ranges that you never want blocked
#my $whitelist = create_iprange_regexp( 
#	qw(127.0.0.0/8 10.0.0.1)
#);

# Get the current IPTables ruleset revison number.
sub get_fw_rev {

	my $browser = LWP::UserAgent->new;
        my $response = $browser->get( "$emerging_fwrev" );
        (syslog("notice", "Can't get $emerging_fwrev:  $response->status_line") && die "Can't get $emerging_fwrev", $response->status_line) unless $response->is_success;

	return $response->content;

}

# Get the current IPTables ruleset.
sub get_fw_rules {

	my $browser = LWP::UserAgent->new;
	my $response = $browser->get( "$emerging_fwrules", ':content_file' => "$rules_file" );
	(syslog("notice", "Can't get $emerging_fwrev:  $response->status_line") && die "Can't get $emerging_fwrev", $response->status_line) unless $response->is_success;

}

my $rev_num = undef;

while () {

	# Place the contents of the current revison number into $old_rev_num and get the new number
	my $old_rev_num = $rev_num;
	$rev_num = &get_fw_rev;

	# Check to see if the number has incremented
	if ($rev_num > $old_rev_num) {

		# Get the new ruleset
		&get_fw_rules;

		open(RULES, "<$rules_file") or (syslog("notice", "Could not open $rules_file") && die "Could not open $rules_file\n");

		# Flush the current attacker chain and remove the attack chain from current chains
		system("$iptables -F $iptables_drop_chain 2>/dev/null 1>/dev/null") == 0
		|| syslog("notice", "Could not flush $iptables_drop_chain");
		system("$iptables -F $iptables_att_chain 2>/dev/null 1>/dev/null") == 0
		|| syslog("notice", "Could not flush $iptables_att_chain");
		system("$iptables -D FORWARD -j $iptables_att_chain 2>/dev/null 1>/dev/null") == 0
		|| syslog("notice", "Could not delete $iptables_att_chain from FORWARD chain");
		system("$iptables -D INPUT -j $iptables_att_chain 2>/dev/null 1>/dev/null") == 0
		|| syslog("notice", "Could not delete $iptables_att_chain from INPUT chain");
                system("$ipset -X botccnet 2>/dev/null 1>/dev/null") == 0
                || syslog("notice", "Could not delete $ipset_botccnet");
                system("$ipset -X botcc 2>/dev/null 1>/dev/null") == 0
                || syslog("notice", "Could not delete $ipset_botcc");


                # Create attacker and drop chains. 
                system("$iptables -N $iptables_att_chain 2>/dev/null 1>/dev/null");
                system("$iptables -I FORWARD 1 -j $iptables_att_chain 2>/dev/null 1>/dev/null") == 0
                || (syslog("notice", "Could not insert $iptables_att_chain chain into FOWARD chain") && die "Could not insert $iptables_att_chain chain into FOWARD chain\n");
                system("$iptables -I INPUT 1 -j $iptables_att_chain 2>/dev/null 1>/dev/null") == 0
                || (syslog("notice", "Could not insert $iptables_att_chain chain into INPUT chain") && die "Could not insert $iptables_att_chain chain into INPUT chain\n");
                system("$iptables -N $iptables_drop_chain 2>/dev/null 1>/dev/null");
                system("$iptables -A $iptables_drop_chain -j LOG --log-level INFO --log-prefix 'ET BLOCK: ' 2>/dev/null 1>/dev/null");
                system("$iptables -A $iptables_drop_chain -j DROP 2>/dev/null 1>/dev/null");
                system("$ipset -N $ipset_botccnet nethash 2>/dev/null 1>/dev/null");
                system("$ipset -N $ipset_botcc iphash 2>/dev/null 1>/dev/null");
    
		syslog("notice", "Starting blocklist population");

		while (<RULES>) {

			chomp($_);

			# Check to see if input looks like an IP
			if ($_ =~ /^(\d{1,3}\.?){4}(\/\d{1,2})?$/) {
                        
                            if($_=~/\/32$/){
                                $_=substr($_, 0, -3);
                                print "scrubbed \/32 to be a host $_\n";
                            }  

                            if($_ =~/\//)
                            {
                                #if (!match_ip("$_", $whitelist)) {    
                                    system("$ipset -A $ipset_botccnet $_ 2>/dev/null 1>/dev/null");
                                #}
                            }else{
                                #if (!match_ip("$_", $whitelist)) {
                                    system("$ipset -A $ipset_botcc $_ 2>/dev/null 1>/dev/null");
                                #}
                             }        
                         }
                }

               system("$iptables -A $iptables_att_chain -p ALL -m set --set $ipset_botcc src,src -j $iptables_drop_chain 2>/dev/null 1>/dev/null");
               system("$iptables -A $iptables_att_chain -p ALL -m set --set $ipset_botccnet src,src -j $iptables_drop_chain 2>/dev/null 1>/dev/null");
               system("$iptables -A $iptables_att_chain -p ALL -m set --set $ipset_botcc dst,dst -j $iptables_drop_chain 2>/dev/null 1>/dev/null");
               system("$iptables -A $iptables_att_chain -p ALL -m set --set $ipset_botccnet dst,dst -j $iptables_drop_chain 2>/dev/null 1>/dev/null");
	}

	sleep $timer;

}
