#!/usr/bin/perl -wT
#
# ----------------------------------------------------------------------
# sd2nbe
#
# Written by George A. Theall, theall@tifaware.com
#
# Copyright (c) 2004, George A. Theall. All rights reserved.
#
# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# $Id: sd2nbe 17 2004-10-18 15:55:35Z theall $
# ----------------------------------------------------------------------


=head1 NAME

sd2nbe - convert Nessus session data to NBE format.


=head1 SYNOPSIS

  # Convert a session from user 'theall' run on Jan 11 at 16:50 to NBE.
  sd2nbe /usr/local/var/nessus/users/theall/sessions/20040111-165004-data > session.nbe

  # Convert the same session and display debugging messages.
  sd2nbe -d /usr/local/var/nessus/users/theall/sessions/20040111-165004-data > session.nbe


=head1 DESCRIPTION

Nessus offers a optional feature known as session saving (see
L<http://www.nessus.org/doc/session_saving.html>).  It's intended as a
means to recover results of interrupted scans (for example, due to a
power outage or client machine crash), although it can also be used as a
more general way of saving results.  Provided that the server was
configured to support session saving and that the user elected to save
the session when submitting a scan, session data will be saved in the
directory C<${prefix}/var/nessus/users/${user}/sessions>. 

To recover results, a user connects to the Nessus server and restores
the session.  The server then replays the session, scanning any hosts
that were missed or unfinished from before, and displays the results. 
One drawback to restoring a session, though, is the length of time the
client takes to replay it.  Even if the scan was not interrupted,
replaying the session may approach the time it took to do the scan
originally. 

B<sd2nbe> takes an alternative approach -- it reads session data
directly and outputs results in a format known as C<NBE> (C<Nessus
BackEnd>).  While the format may not be especially readable, its use
offers several attractive features:

  o It can be fed into the unix-based nessus client and converted 
    to a variety of other formats; eg, HTML, text, XML, etc. 

  o It can be easily filtered so as to limit reports, for example,
    to certain hosts or plugins.

  o It can be merged with other NBE output simply by concatenating 
    the sources.

B<sd2nbe> is written in Perl.  It should work on any system with Perl 5
or better.  It also requires the Perl modules C<Carp> and
C<Getopt::Long>.  If your system does not have these modules installed
already, visit CPAN (L<http://search.cpan.org/>) for help. 


=head1 KNOWN BUGS AND CAVEATS

Currently, I am not aware of any bugs in this script. 

Don't convert at the same time multiple session data files that reflect
scans of the same host(s). 

Warnings are issued for hosts that were not scanned completely. 
However, the script does not check whether the scan itself is complete
(ie, all targets were tested). 


=head1 DIAGNOSTICS

If an input can not be parsed properly, a warning message is generated
and the line is skipped. 

Warnings are issued for hosts that were not scanned completely. 


=head1 SEE ALSO

L<nessus(1)>, 
L<http://www.nessus.org/doc/session_saving.html>,
C<nessus-core/doc/nbe_file_format.txt>,
L<http://www.tifaware.com/perl/sd2nbe/>

=cut


############################################################################
# Make sure we have access to the required modules.
use 5;
use strict;
use Carp;
use Getopt::Long;


############################################################################
# Initialize variables.
$| = 1;
my $DEBUG = 0;
my %msg_types = (
    'NOTE' => 'Security Note',
    'INFO' => 'Security Warning',
    'HOLE' => 'Security Hole',
);


############################################################################
# Process commandline arguments.
my %options = (
    'debug'       => \$DEBUG,
);
GetOptions(
    \%options,
    'debug|d!',
    'help|h|?!',
) or $options{help} = 1;
$0 =~ s/^.+\///;
if ($options{help}) {
    warn "\n",
        "Usage: $0 [options] [session-data-file]\n",
        "\n",
        "Options:\n",
        "  -?, -h, --help             Display this help and exit.\n",
        "  -d, --debug                Display copious debugging messages while\n",
        "                               converting session data.\n";
    exit(9);
}


############################################################################
warn "debug: reading session data.\n" if $DEBUG;
my(@hosts, $line, %scans);
while (<>) {
    chomp;
    ++$line;
    warn "debug:   reading >>$_<<.\n" if $DEBUG;

    # Extract fields in messages from the server and limit attention
    # to a few message types.
    #
    # nb: session data is basically a collection of NTP messages.
    next unless (/^SERVER <\|> (.+) <\|> SERVER$/);
    my($type, @fields) = split(/ <\|> /, $1);
    warn "debug:     message type '$type'.\n" if $DEBUG;
    next unless (grep($type eq $_, ('TIME', 'PORT', 'NOTE', 'INFO', 'HOLE')));

    # Parse and convert messages to category|subnet|host|info
    # fields used w/ NBE.
    #
    my($category, $subnet, $host, $info);
    if ($type eq 'TIME') {
        $category = 'timestamps';
        my($action, $time);
        unless ($action = shift(@fields) and $time = pop(@fields)) {
            warn "NTP error in line $line - not enough fields!\n";
            next;
        }
        $action = lc($action);
        warn "debug:       action '$action'.\n" if $DEBUG;
        if ($action eq 'host_start' or $action eq 'host_end') {
            unless ($host = shift(@fields)) {
                warn "NTP error in line $line - no host field!\n";
                next;
            }
            if ($action eq 'host_start') {
                $scans{$host}++;
                push(@hosts, $host);
            }
            else {
                $scans{$host}--;
            }
        }
        $info = join('|', $action, $time);
    }
    else {
        $category = 'results';
        unless ($host = shift(@fields)) {
            warn "NTP error in line $line - no host field!\n";
            next;
        }
        # Determine "subnet".
        if ($host =~ /^([0-9a-f]{2}(\.|$)){6}$/i) {         # MAC address (w/ '.' as delimiter)
            # nb: use first three bytes (manufacturer id).
            $subnet = substr($host, 0, 8);
        }
        elsif ($host =~ /^((\d{1,3})(\.|$)){4}$/) {         # IP address
            # nb: assume /24.
            ($subnet = $host) =~ s/\.\d{1,3}\.?$//;
        }
        else {                                              # fqdn
            # nb: generally this yields a subdomain / domain.
            ($subnet = $host) =~ s/^[^.]+\.//;
        }

        my $port;
        unless ($port = shift(@fields)) {
            warn "NTP error in line $line - no port field!\n";
            next;
        }

        if ($type eq 'PORT') {
            $info = $port;
        }
        else {
            my($plugin, $report);
            unless ($plugin = pop(@fields) and $report = shift(@fields)) {
                warn "NTP error in line $line - not enough fields!\n";
                next;
            }
            $info = join('|', $port, $plugin, $msg_types{$type}, $report);
        }
    }

    # Print line in NBE format.
    print join('|', $category, ($subnet || ''), $host, $info), "\n";
}


# Warn about unscanned hosts.
if (grep($scans{$_}, @hosts)) {
    warn "\n" .
         "*** Scans of the Following Hosts are Incomplete: ***\n";
    foreach (@hosts) {
        warn "    $_\n" if $scans{$_};
    }
}
