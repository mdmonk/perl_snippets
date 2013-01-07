#!/usr/bin/perl -wT


=head1 NAME

log-guardian - Monitors one or more logfiles continuously.


=head1 SYNOPSIS

  # monitors logfiles.
  log-guardian

  # same as above but with copious debugging messages.
  log-guardian -d

  # monitors logfiles using settings in /etc/log-guardian/weblogs.
  log-guardian /etc/log-guardian/weblogs


=head1 DESCRIPTION

This script lets you monitor one or more log files in an endless loop,
I<a la> C<tail -f>.  As lines are added to the files, they are compared
to one or more patterns specified as Perl regular expressions.  And as
matches are found, the script reacts by running a block of Perl code. 
Thus, for example, you could use B<log-guardian> to monitor web logs for
problematic behaviour and add troublesome hosts to a blocklist
dynamically.  You could even use it as a port knocking server
(L<http://slashdot.org/articles/04/02/05/1834228.shtml>)!

B<log-guardian> is not a general-purpose log analyzer, though, since it
looks at lines only as they are added to logs, not at whole log files
themselves.  It's intended simply to allow you to react to issues as
they arise. 

By virtue of its use of the Perl module C<File::Tail>, B<log-guardian>
offers a number of advantages.  For one, it's unaffected by log file
rotation -- if a file does not appear to have input for a period of
time, C<File::Tail> will quietly re-open the file and continue reading. 
For another, it does not spend excessive time checking log files with
little or no traffic since C<File::Tail> adjusts how frequently it polls
for input based on past history. 

You control what is monitored and how by modifying the scalar
C<$monitors>, either in the script itself or in a separate config file. 
The scalar should be defined as a hash.  Each key is a log file to
monitor while the value is an array of hashes specifying what to look
for in the log file and how to react.  Keys in these secondary hashes
should be either C<label>, C<pattern>, or C<action>, corresponding to
values representing respectively a descriptive label of the monitor, a
Perl regular expression to use as a pattern, and an anonymous subroutine
to be run if a match occurs.  C<pattern> is required while the other two
key / value pairs are optional.  If C<action> is not present, the
default action in C<$default_action> will be used instead. 

B<log-guardian> is written in Perl.  It should work on any unix-like
system with Perl 5.003 or later.  It also requires the following Perl
modules:

    o Carp
    o Getopt::Long
    o File::Tail
    o Safe

If your system does not have these modules installed already, visit CPAN
(L<http://search.cpan.org/>).  Note that C<File::Tail> must be at least
version 0.90 and C<Safe> at least version 2.0 (thus, it will not work
with versions of Perl older than 5.003).  Note also that C<File::Tail>
is not included in the default Perl distribution so you may need to
install it yourself. 


=head1 KNOWN BUGS AND CAVEATS

Currently, I am not aware of any bugs in this script. 

Understand that actions undertaken by B<log-guardian> are arbitrary Perl
code.  Be careful to control on one hand access to that code and on the
other the content of that code. 

If you encounter an error saying something like C<Can't parse 'file' -
'function' trapped by operation mask>, you will need to adjust the list
of operators permitted by C<Safe>.  Look for the line with
C<$sandbox-E<gt>permit_only> and refer to the manpage for C<Opcode> for
possible operators. 

You must include a pathname when specifying a separate configuration
file; otherwise, it will be silently ignored.

When making changes to C<$monitors>, you would be wise to redirect the
script's output to a file for a period of time.  This will help diagnose
problems in the patterns and / or actions. 


=head1 DIAGNOSTICS

Warnings and errors will be reported to stderr. 

Missing log files will be reported and skipped but will otherwise not
affect monitoring.  A missing pattern, though, will cause the program
to abort.


=head1 SEE ALSO

L<http://www.tifaware.com/perl/log-guardian>.


=head1 AUTHOR

George A. Theall, E<lt>theall@tifaware.comE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (c) 2004, George A. Theall.
All rights reserved.

This script is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 


=head1 HISTORY

17-May-2004, v1.01, George A. Theall
    o Added a configuration variable ($max_interval) to control the
      maximum number of seconds to sleep between checks of logs.
    o Changed $select_timeout to have global scope and lowered its
      default value.

04-May-2004, v1.00, George A. Theall
    o Initial version.

=cut


############################################################################
# Make sure we have access to the required modules.
use 5.003;
use strict;
use Carp;
use Getopt::Long;
use File::Tail 0.90;
use Safe 2.0;


############################################################################
# Initialize variables.
#
# nb: global variables (declared with "our") in this section may also be
#     defined in a separate configuration file.
$| = 1;
delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};   # Make %ENV safer
$ENV{PATH} = '/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
our $DEBUG = 0;                         # debugging messages
our $default_action = sub {             # used if a monitor lacks action.
    my($log, $line, $label, $pattern, @matches) = @_;
    print "*** Match found ***\n",
          "    $line\n";
};
our $max_interval = 5;                  # max interval between checks.
our $monitors = {                       # what to monitor.
#    '/var/log/mail.log' => [
#        {
#            # Monitor sendmail log file relaying attempts.
#            label   => 'Failed Attempt to Relay Mail',
#            pattern => qr/relay=[^,\[]*\[([\d\.]+)\], reject=5\d\d .+ Relaying denied/,
#            action  => sub {
#                my $ip = $_[4];
#                our %attempts;          # nb: this must have global scope!
#                # Three strikes and they're out -- we drop any further 
#                # packets from them!
#                if (++$attempts{$ip} > 2) {
#                    # nb: this is Linux specific; adjust to taste.
#                    system 'logger', '-i', '-t', 'log-guardian', "blocking $ip after 3 attempts to relay mail.";
#                    system 'iptables', split(/ /, "-I INPUT -s $ip -j DROP");
#                }
#            },
#        },
#    ],
#    '/var/log/messages' => [
#        {
#            # A simple port knocking server - SPT=DPT=1, 2, 3.
#            # 
#            # nb: please don't implement this as-is - it's too simplistic!
#            label   => 'Port Knocker',
#            pattern => qr/IN=eth0 .+ SRC=(\S+) .+ SPT=(1|2|3) DPT=\2/,
#            action  => sub {
#                my $ip = $_[4];
#                my $port = $_[5];
#                our %attempts;          # nb: this must have global scope!
#                if ($port == 1 and ! exists $attempts{$ip}) {
#                    ++$attempts{$ip};
#                }
#                elsif ($port == 2 and $attempts{$ip} == 1) {
#                    ++$attempts{$ip};
#                }
#                elsif ($port == 3 and $attempts{$ip} == 2) {
#                    # nb: this is Linux specific; adjust to taste.
#                    system 'logger', '-i', '-t', 'log-guardian', "enabling SSH access for $ip.";
#                    system 'iptables', split(/ /, "-I INPUT -m tcp -p tcp -s $ip --dport 22 -j ACCEPT");
#                }
#                else {
#                    delete $attempts{$ip};
#                }
#            },
#        },
#    ],
};
our $select_timeout = 5;                # timeout for select.


############################################################################
# Process commandline arguments.
$0 =~ s/^.+\///;
my %options = (
    'debug'  => \$DEBUG,
);
Getopt::Long::Configure('bundling');
GetOptions(
    \%options,
    "debug|d!",
    "help|h|?!",
) or $options{help} = 1;
my $cf = shift || '';
$options{help} = 1 if (scalar(@ARGV));
if ($options{help}) {
    print STDERR "\n",
        "Usage: $0 [options] [config_file]\n",
        "\n",
       "Options:\n",
        "  -?, -h, --help             Display this help and exit.\n",
        "  -d, --debug                Display copious debugging messages while\n",
        "                               monitoring log(s).\n";
    exit(9);
}


############################################################################
# Process configuration file, if specified.
if ($cf) {
    # Untaint $cf; it must consist only of alphanumerics, '-', '.', or '/'.
    if ($cf =~ /^([\w\-\.\/]+)$/) {
        $cf = $1;
    }
    else {
        croak "Can't untaint '$cf'!\n";
    }
    croak "Can't read '$cf'!\n" unless (-r $cf);

    # nb: processing is done in a sandbox with the Safe module that 
    #     restricts code in the config file to basically just defining
    #     variables. Further, values are brought back into the main
    #     namespace only for the configurable variables above.
    warn "debug: processing '$cf'.\n" if $DEBUG;
    my $sandbox = new Safe;
    # nb: you may need to adjust this depending on the actions you 
    #     select; "man Opcode" for details.
    $sandbox->permit_only(':default', ':subprocess', ':ownprocess');
    $sandbox->rdo($cf);
    croak "Can't parse '$cf' - $@!\n" if ($@);

    no strict 'vars', 'refs';
    # Bring back values for these scalars.
    foreach my $var (
        'DEBUG',
        'default_action',
        'monitors',
    ) {
        warn "debug:   handling '$var'.\n" if $DEBUG;
        local *symname = $sandbox->varglob($var);

        # Skip unless $var is defined in the config file.
        next unless (defined $symname);

        # Skip if values are the same in the script and the config file.
        next if (defined ${$var} and ${$var} eq $symname);

        if ($DEBUG) {
            warn "debug:   updating '\$$var'.\n";
            warn "debug:     old value: '", ${$var} || '', "'\n";
        }
        ${$var} = $symname;
        if ($DEBUG) {
            warn "debug:     new value: '", ${$var} || '', "'\n";
        }
    }
    use strict 'refs', 'vars';
}


############################################################################
# Validate monitors.
croak "Nothing to monitor!\n" unless (scalar(keys %$monitors));
foreach my $log (keys %$monitors) {
    unless (-r $log) {
        warn "'$log' doesn't exist or is unreadable; skipped!\n";
        delete $monitors->{$log};
        next;
    }
    foreach my $monitor (@{$monitors->{$log}}) {
        my $label = $monitor->{label} || $monitor->{pattern} || 'unknown label';
        unless (exists $monitor->{pattern}) {
            croak "No pattern for '$log' / '$label'!\n";
        }
        if (exists $monitor->{action} and ref($monitor->{action}) ne 'CODE') {
            croak "'action' for '$log' / '$label' is not a code reference!\n";
        }
    }
}


############################################################################
# Monitor logs in an endless loop.
my @logs;
warn "debug: logs to monitor:\n" if $DEBUG;
foreach (keys %$monitors) {
    warn "debug:   $_\n" if $DEBUG;
    push(@logs, File::Tail->new(name=>$_, maxinterval=>$max_interval));
}

warn "debug: starting to monitor.\n" if $DEBUG;
while (1) {
    # Wait for input from one of the logs.
    my($nfound, undef, @pending) = File::Tail::select(
        undef,
        undef,
        undef,
        $select_timeout,
        @logs
    );
    next unless ($nfound);

    # Check one line from each log with input.
    foreach my $fh (@pending) {
        my $log = $fh->{'input'};
        warn "debug: $log has been updated.\n" if $DEBUG;
        my $line = $fh->read;
        chomp $line;
        warn "debug:   read '$line'.\n" if $DEBUG;

        # Attempt to match against each pattern for the log.
        foreach my $monitor (@{$monitors->{$log}}) {
            my $pattern = $monitor->{pattern};
            my $label = $monitor->{label} || $pattern;
            warn "debug:     checking $label.\n" if $DEBUG;
            my @matches = ($line =~ $pattern);
            next unless (@matches);

            # Take action since a match was found.
            warn "debug:     match found; taking " . 
                (exists $monitor->{action} ? '' : 'default ') .
                "action.\n" if $DEBUG;
            my $sub = $monitor->{action} || $default_action;
            &{$sub}($log, $line, $label, $pattern, @matches);
        }
    }
}
