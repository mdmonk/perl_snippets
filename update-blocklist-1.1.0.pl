#!/usr/bin/perl -wT
#
# ----------------------------------------------------------------------
# update-blocklist
#
# Written by George A. Theall, theall@tifaware.com
#
# Copyright (c) 2003-2005, George A. Theall. All rights reserved.
#
# This module is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# $Id: update-blocklist 163 2005-04-12 03:15:14Z theall $
# ----------------------------------------------------------------------


=head1 NAME

update-blocklist - Updates firewall blocklist.


=head1 SYNOPSIS

  # updates firewall blocklist.
  update-blocklist

  # displays commands used to update firewall blocklist without actually
  #   doing so.
  update-blocklist -d

  # updates firewall blocklist using only static rules. NB: this 
  #   causes any dynamic rules to be removed.
  update-blocklist -s

  # updates firewall blocklist but doesn't retrieve new copies of
  #   dynamic lists.
  update-blocklist -n


=head1 DESCRIPTION

This script updates rules used by an iptables-based firewall to block
inbound traffic.  You can use it to filter incoming traffic based on a
static list maintained locally or one or more dynamic lists available on
the web, such as DShield.org's Block List and The Spamhaus Don't Route
Or Peer List.  The static list allows you to tailor rules to individual
machines while dynamic lists help you stay up-to-date with current
threats. 

Each time you run it, B<update-blocklist> flushes and then repopulates
the firewall blocklist (a special user-defined chain through which
inbound traffic passes).  If a dynamic list is retrieved and,
optionally, verified successfully, a copy will be saved for review and
re-use.  It will be re-used in the event the option C<--no-gets> is
given or a current copy can not be retrieved or verified. 

Optional behaviour can be selected using one or more variables or
commandline arguments:

    Variable            Commandline         Purpose
    $DEBUG              -d|--debug          Turn on debugging. NB: leaves
                                                blocklist unchanged.
    n/a                 -n|--no-gets        Update the blocklist but don't
                                                retrieve new copies of
                                                dynamic lists.
    n/a                 -s|--static-only    Update the blocklist using only
                                                the static list.
    $proxy              n/a                 HTTP proxy (if needed).

B<update-blocklist> is written in Perl.  It should work on any Linux
system with Perl 5 and iptables.  In addition, it can be configured to
use GNU Privacy Guard or C<md5sum>to verify the contents of a dynamic
blocklist so you may need to have working that as well.  Finally, it
requires the following Perl modules:

    o Carp
    o File::Copy
    o File::Temp
    o Getopt::Long
    o LWP::Debug
    o LWP::UserAgent
    o Net::IP

If your system does not have these modules installed already, visit CPAN
(L<http://search.cpan.org/>).  Note that C<LWP::Debug>,
C<LWP::UserAgent>, and C<Net::IP> are not included with the default Perl
distribution so you may need to install them yourself; you can find the
first two as part of the LWP library
(L<http://search.cpan.org/dist/libwww-perl/>). 


=head1 KNOWN BUGS AND CAVEATS

Currently, I am not aware of any bugs in this script.

Rule optimization can slow things down significantly.  Disable it if you
don't mind the inefficiencies that entails or prefer to handle it
manually. 

If you encounter a problem using this script, I encourage you to enable
debug mode (eg, add C<-d> to your commandline) and examine the output it
produces before contacting me.  Often, this will enable you to resolve
the problem yourself.


=head1 DIAGNOSTICS

Warnings and errors will be reported to stderr. 

Failure to retrieve a dynamic blocklist or to verify it, if configured,
will result in a warning and cause the previously saved version to be
used. 


=head1 SEE ALSO

L<iptables(8)>, L<http://www.dshield.org/block_list_info.php>,
L<http://www.spamhaus.org/drop/index.lasso>,
L<http://www.tifaware.com/perl/update-blocklist>. 

=cut


############################################################################
# Make sure we have access to the required modules.
use 5.003;
use strict;
use Carp;
use File::Copy qw/cp mv/;
use File::Temp qw/ :POSIX /;
use Getopt::Long;
use LWP::UserAgent;
use Net::IP;


############################################################################
# Initialize variables.
delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};   # Make %ENV safer
$ENV{PATH} = '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
$| = 1;
my $config = '/usr/local/etc/update-blocklist.conf';    # config file
our $DEBUG = 0;                         # debugging messages / no updates
our @bl_dynamic = ();                   # dynamic blocklist(s).
our $bl_static = '/var/lib/iptables/blocklist.static';  # static blocklist
our $ipt_chain = 'BLOCKLIST';           # iptables chain to use
our $ipt_default_target = 'DROP';       # default target to use for blocking
our $optimize = 1;                      # optimize rulesets (0/1)
our $proxy = '';
my $useragent = 'update-blocklist/1.1.0' .
                    ' (http://www.tifaware.com/perl/update-blocklist/)';
umask 022;


############################################################################
# Read configuration file, if it exists.
#
# nb: any variables defined here will override those defined previously.
require $config;

croak "*** You must set \$ipt_chain! ***\n" unless ($ipt_chain);
croak "*** You must set \$ipt_default_target! ***\n" unless ($ipt_default_target);


############################################################################
# Process commandline arguments.
my %options = (
    'debug'     => \$DEBUG,
    'optimize'  => \$optimize,
);
Getopt::Long::Configure('bundling');
GetOptions(
    \%options,
    "debug|d!",
    "help|h|?!",
    "no-gets|n|",
    "optimize|o|",
    "static-only|s|",
) or $options{help} = 1;
$0 =~ s/^.+\///;
if ($options{help}) {
    warn "\n",
        "Usage: $0 [options]\n",
        "\n",
        "Options:\n",
        "  -?, -h, --help             Display this help and exit.\n",
        "  -d, --debug                Display copious debugging messages but\n",
        "                               don't actually change the blocklist.\n",
        "  -n, --no-gets              Update the blocklist but don't retrieve\n",
        "                               new copies of dynamic blocklists.\n",
        "  -o, --optimize             Optimize the rules by checking for\n",
        "                               overlap.\n",
        "  -s, --static-only          Update the blocklist using only the\n",
        "                               static list.\n";
    exit(9);
}


############################################################################
# Retrieve dynamic blocklists
unless ($options{'no-gets'} or $options{'static-only'}) {
    my $cnt;
    foreach my $bl (@bl_dynamic) {
        ++$cnt;
        my $label = $bl->{label} || "Blocklist #$cnt";
        warn "debug: updating blocklist for '$label'.\n" if $DEBUG;

        # Validate some parameters.
        my $url = $bl->{url};
        if (!$url) {
            warn "*** No URL configured for '$label'; skipped. **\n";
            next;
        }
        my $copy = $bl->{copy};
        if (!$copy) {
            warn "*** No file configured for '$label'; skipped. ***\n";
            next;
        }

        # Actually retrieve the blocklist.
        my $scratch = tmpnam();
        if ($DEBUG) {
            warn "debug: retrieving '$url' as '$scratch'.\n";
            require LWP::Debug; import LWP::Debug qw(+);
        }
        my $ua = LWP::UserAgent->new(
            agent => $useragent,
        );
        if (defined($proxy)) {
            $ua->proxy('http', $proxy);
        }
        my $response = $ua->get(
            $url,
            ':content_file' => $scratch,
        );
        if (!$response->is_success) {
            warn "*** Failed to retrieve '$url' (", $response->status_line, ")! ***\n";
            next;
        }

        # Verify contents if desired.
        if ($bl->{verify}) {
            my $method = $bl->{verify}{method};
            my $vurl = $bl->{verify}{url};
            if ($method) {
                if (grep(/^$method$/, ("gpg", "md5"))) {
                    if (!$vurl) {
                        warn "*** No URL configured for verification for '$label'; skipped. ***\n";
                        next;
                    }
                }
                else {
                    warn "*** Don't know how to handle '$method' verification! ***\n";
                    next;
                }
            }

            warn "debug: retrieving '$vurl' as '$scratch.verify'.\n" if $DEBUG;
            $response = $ua->get(
                $vurl,
                ':content_file' => "$scratch.verify",
            );
            if (!$response->is_success) {
                warn "*** Couldn't retrieve '$vurl' (", $response->status_line, ")! ***\n";
                next;
            }

            warn "debug: verifying contents of blocklist with '$method'.\n" if $DEBUG;
            if ($method eq 'md5') {
                system 'md5sum', '--status', '--check', "$scratch.verify";
                my $rc = $? >> 8;
                unlink "$scratch.verify";
                if ($rc) {
                    warn "*** MD5 checksum verification for '$label' failed ($rc)! ***\n";
                    next;
                }
            }
            elsif ($method eq 'gpg') {
                my $uid;
                # nb: "--logger-fd 1" redirects stderr to stdout.
                open(CMD, '-|', 'gpg', '--logger-fd', '1', '--verify', "$scratch.verify", $scratch) or croak "Can't run 'gpg' - $!\n";
                while (<CMD>) {
                    chomp;
                    warn "debug:   $_\n" if $DEBUG;
                    $uid = $1 if (/Good signature from \"(.+)\"$/i);
                }
                close(CMD);
                my $rc = $? >> 8;
                unlink "$scratch.verify" unless $DEBUG;
                if ($rc) {
                    warn "*** GPG signature verification for '$label' failed ($rc)! ***\n";
                    next;
                }
                elsif (!$uid or ($bl->{verify}{uid} and $uid ne $bl->{verify}{uid})) {
                    warn "*** GPG signature verification for '$label' failed ('$uid' != '", $bl->{verify}{uid}, "')! ***\n";
                    next;
                }
            }
        }

        # Update copy of dynamic blocklist unless debugging.
        if ($DEBUG) {
            warn "debug: would save '$scratch' as '$copy'!\n";
            $bl->{copy} = $scratch;
        }
        else {
            mv $scratch, $copy or croak "*** Move failed - $! ***\n";
        }
    }
}


############################################################################
# Determine rulespecs to apply.
my($rule, %origins, %rules);

# Read static blocks.
my $line;
warn "debug: reading static blocks from '$bl_static'.\n" if $DEBUG;
open(FILE, $bl_static) or croak "Can't read '$bl_static' - $!\n";
while (<FILE>) {
    chomp;
    ++$line;
    warn "debug:   line $line: '$_'.\n" if ($DEBUG);
    s/#.*$//;                               # nb: strip out any comments.
    next if (/^\s*$/);                      # nb: skip empty lines.

    # Parse / untaint data.
    my $rulespec;
    #
    # - a source specification.
    #   nb: this must occur as the first field.
    if (s/^\s*(\!?\s*[\w\.\/]+)\s*//) {
        $rulespec = "-s $1";
    }
    else {
        warn "*** no source specification found in line $line; skipped. ***\n";
        next;
    }
    # - a jump target.
    #   nb: this must occur as the second field, if given.
    if (s/^\s*([^\-\s]+)\s*//) {
        $rulespec .= " -j $1";
    }
    # - anything left on line will be appended to the rule specification.
    #
    #   nb: while this untaints the data, it's not really safe so be 
    #       careful who/what you let write to the static blocklist.
    $rulespec .= " $1" if (/^\s*(\S.*\S)\s*$/);
    # nb: add a jump if there's not one already.
    $rulespec .= " -j $ipt_default_target" unless ($rulespec =~ / -j /);

    ++$rule;
    warn "debug:     rulespec #$rule is '$rulespec'.\n" if ($DEBUG);
    $rules{$rule} = $rulespec;
    $origins{$rule} = "line $line from $bl_static";
}
close(FILE);

# Read dynamic blocks.
unless ($options{'static-only'}) {
    my $cnt;
    foreach my $bl (@bl_dynamic) {
        ++$cnt;
        my $label = $bl->{label} || "Blocklist #$cnt";

        # Validate some parameters.
        my $copy = $bl->{copy};
        if (!$copy) {
            warn "*** No file configured for '$label'; skipped. ***\n";
            next;
        }
        my $parse = $bl->{parse};
        if (!$parse) {
            warn "*** No parsing routine defined for '$label'; skipped. ***\n";
            next;
        }

        warn "debug: reading dynamic blocks from '$copy'.\n" if $DEBUG;
        $line = 0;
        open(FILE, $copy) or croak "Can't read '$copy' - $!\n";
        while (<FILE>) {
            chomp;
            ++$line;
            warn "debug:   line $line: '$_'.\n" if ($DEBUG);
            my $rulespec = &$parse("$_");
            if ($rulespec) {
                ++$rule;
                $rules{$rule} = $rulespec;
                warn "debug:     rulespec #$rule is '$rulespec'.\n" if ($DEBUG);
                $origins{$rule} = "line $line from $copy";
            }
        }
        close(FILE);
    }
}

# Append a rule to allow unmatched traffic to pass.
$rules{++$rule} = "-j RETURN";


############################################################################
# Optimize rules by checking for overlap, if desired.
if ($optimize) {
    warn "debug: optimizing rules.\n" if $DEBUG;
    my(%sources);
    foreach $rule (keys %rules) {
        # Extract the source specification.
        if ($rules{$rule} =~ /-s (\S+)/) {
            # Create a Net::IP object.
            #
            # nb: we don't worry about errors in Net::IP; they just mean
            #     the blocklist won't be as lean as it could be.
            my $new_ip = new Net::IP($1);
            if ($new_ip) {
                my $ignore;
                foreach my $source_rule (keys %sources) {
                    my $ip = $sources{$source_rule};
                    my $overlap = $ip->overlaps($new_ip);
                    if ($overlap == $IP_B_IN_A_OVERLAP or $overlap == $IP_IDENTICAL) {
                        warn "debug:   ignoring rule #$rule ($origins{$rule}) - already covered by rule #$source_rule ($origins{$source_rule}).\n" if $DEBUG;
                        delete $rules{$rule};
                        $ignore = 1;
                        last;
                    }
                    elsif ($overlap == $IP_A_IN_B_OVERLAP) {
                        warn "debug:   ignoring rule #$source_rule ($origins{$source_rule}) - covered by rule #$rule ($origins{$rule}).\n" if $DEBUG;
                        delete $rules{$source_rule};
                        delete $sources{$source_rule};
                        last;
                    }
                }
                # Keep track of this source.
                $sources{$rule} = $new_ip unless ($ignore);
            }
            else {
                # nb: probably arises because the source specification is invalid.
                warn "*** Couldn't create Net::IP object for '$1'! ***\n";
            }
        }
    }
}



############################################################################
# Update iptables.

# Flush or create the chain as necessary.
if ($DEBUG) {
    warn "debug: would issue the following commands:\n",
         "debug    iptables -F $ipt_chain || iptables -N $ipt_chain\n";
}
else {
    # Flush chain.
    system "iptables", "-F", $ipt_chain;
    my $rc = $? >> 8;
    # If that fails, try to create it.
    if ($rc) {
        system "iptables", "-N", $ipt_chain;
        $rc = $? >> 8;
    }
    croak "'iptables -N $ipt_chain' failed with rc $rc!\n" if ($rc);
}

# Append each rule, sorted by its number.
foreach my $rule (sort {$a <=> $b} keys %rules) {
    if ($DEBUG) {
        warn "debug:   iptables -A $ipt_chain ", $rules{$rule}, " (rule #$rule)\n";
    }
    else {
        my @parts = split(/\s+/, $rules{$rule});
        system "iptables", "-A", $ipt_chain, @parts;
        my $rc = $? >> 8;
        croak "'iptables ", join(" ", @parts), "' failed with rc $rc!\n" if ($rc);
    }
}
