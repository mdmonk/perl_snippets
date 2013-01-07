#!/usr/bin/env perl

#
#
###############################################################
#
# $Id: dssh,v 1.15 2003/06/05 04:30:48 wehowk1 Exp $
#
#	dssh - Distributed ssh client
#
# Author:	Mark Curtis
# Date:		6/6/2002
#
# Runs specified comand on the hosts in the workgroup or listed on the
# command line.
#
###############################################################
#
# $Log: dssh,v $
# Revision 1.15  2003/06/05 04:30:48  wehowk1
# Changed so that Term::ReadKey is no longer required.
# If it is present, it will be used.
#
# Revision 1.14  2003/04/01 23:51:25  wecurm
# Modified -v to apply to -o, on localhost, now cd's to $HOME.
#
# Revision 1.13  2003/02/18 00:41:59  wecurm
# Added the -Q option to list known groups.
#
# Revision 1.12  2003/02/17 04:35:44  wecurm
# Changed the Environment variable used to log user command.
#
# Revision 1.11  2002/11/29 03:13:00  wecurm
# Fixed sub-group parsing and now prompt when no hosts are listed to run the command on.
#
# Revision 1.10  2002/11/14 05:33:00  wecurm
# Fixed the group file being referenced.
#
# Revision 1.9  2002/10/04 03:50:20  wecurm
# Cleaned up man page.
#
# Revision 1.8  2002/10/03 07:29:04  wecurm
# Fixed groups in groups to work properly... Ooops.
#
# Revision 1.7  2002/10/03 06:46:01  wecurm
# New group model...
#
# Revision 1.6  2002/10/02 06:48:46  wecurm
# Fixed up some typos....
#
# Revision 1.5  2002/10/02 06:46:04  wecurm
# Nicer format for verbose messges during condensed output.
#
# Revision 1.4  2002/09/30 05:35:49  wecurm
# Better sorting mechanism for condensed output, help options updated and now works running commands on the host it is run on.
#
#	

use strict;
use Getopt::Long;
use POSIX qw(:signal_h setsid WNOHANG);
use Pod::Usage;
use IO::Poll qw(POLLIN POLLOUT POLLERR POLLHUP);
use Errno qw(EWOULDBLOCK);
use vars qw(%CHILDREN $poll %output);
use Sys::Syslog qw(:DEFAULT setlogsock);
use Sys::Hostname;

# If we have Term::ReadKey use it
my $readKeyInstalled;
BEGIN {
	if (eval "require Term::ReadKey") {
		$readKeyInstalled = 1;
		Term::ReadKey->import();
	} else {
		$readKeyInstalled = 0;
	}
	
}

# Declare some constants...
my @command = ('/usr/bin/ssh', '-x', '-o', 'BatchMode=yes');
my $group_file = "/tmp/dssh_groups";
my $list_file = "/tmp/mark_host_list";

# Variables for condensed output
my (%comp_out);

# Logging the command...
my $log_command;
foreach (@ARGV) {
	$log_command .=  " " . $_;
}

#
# This section handles options...
#

# Declare variables...
my (%hosts, $query, $man, $help, $command, $output, $condensed, $verbose, $gquery);
my $remote_user = $ENV{"USER"};
if (!defined($remote_user)) {
	$remote_user = $ENV{'LOGNAME'};
}
my $threads = 8;
my %group_hosts;

read_groups();

# Handle options...
Getopt::Long::Configure("no_ignore_case", "require_order");
GetOptions (
	"Without-host=s" => sub {foreach (split(/,/,$_[1])) {delete $hosts{$_} }},
	"with-host=s" => sub {foreach (split(/,/,$_[1])) {$hosts{$_} = 1 }},
	"group=s" => \&group_option,
	"Group=s" => \&group_option,
	"remote-user=s" => \$remote_user,
	"condensed" => \$condensed,
	"query" => \$query,
	"Query-groups" => \$gquery,
	"verbose" => \$verbose,
	"help|?" => \$help,
	"man" => \$man,
	"output=s" => \$output,
	"threads=i" => \$threads
) or pod2usage(1);

pod2usage(1) if $help;
pod2usage(-verbose => 2) if $man;

# Instantiate our signal handlers...
$SIG{CHLD} = \&reaper;
$SIG{PIPE} = 'IGNORE';

# print the list of groups if required...
if (defined($gquery)) {
	print "Groups known are:\n";
	foreach (sort keys %group_hosts) {
		print "\t$_\n";
	}
	exit(0);
}

# Print the list of hosts if requested...
if (defined($query)) {
	print "Hosts in the list are:\n";
	foreach (sort keys %hosts) {
		print "\t$_\n";
	}
	exit(0);
}

# Check we have a command to run...
pod2usage(1) unless defined($ARGV[0]);

# We now check that we have hosts to run commands on.
if (!%hosts) {
	print "You have not provided any hosts to run the command on.\nI am going to assume you wanted \'-g all\'.\nIs this correct? (y/N) ";

	# If readkey is installed just accept the first character.
	my $key;
	if ($readKeyInstalled) {
		ReadMode('cbreak');
		$key = ReadKey(0);
		ReadMode('normal');
		print "$key\n";
	} else {
		$key = <STDIN>;
		chomp $key;
	}
	if ($key !~ m/y/i) {
		print "Exiting because there are no hosts to run the command on.\n";
		exit(1);
	}
	group_option('g', "all");
}

# Log command to syslog in case of catastrophic failure
#setlogsock('unix');
#openlog('dssh', 'ndelay', 'user');
#syslog('notice', "user: " . $ENV{'LOGNAME'} . " options: " . $log_command );
#closelog();

#
# This next section forks the processes and execs ssh
#

# Arrays for the pipes and counters, etc...
my (%pids, $num_threads, $host);

# Create the poll object...
$poll = new IO::Poll or die "Can't create IO:Poll object\n";

foreach $host (sort keys %hosts) {
	# Turn off stirct refs...
	no strict 'refs';

	# Create the pipe ends...
	my $reader = *{$host};
	my $writer = *{"WRITE_" . $host};

	# Open the pipes...
	pipe($reader, $writer) or die "Couldn't open pipe!\n";

	# Block signals during fork...
	my $signals = POSIX::SigSet->new(SIGINT,SIGCHLD,SIGTERM,SIGHUP);
	sigprocmask(SIG_BLOCK, $signals);
	
	my $child;
	die "Cannot fork!: $!\n" unless defined ($child = fork);

	if ($child) {
		# parent code...
		# Acknowledge signals...
		sigprocmask(SIG_UNBLOCK, $signals);
	
		# close unneeded ends of pipe...
		close($writer);

		$poll->mask($reader => POLLIN);
		$reader =~ s/^[^:]*:://;
		$output{$reader} = '';

		# check we haven't hit threads...
		if (++$num_threads >= $threads) {
			read_handles();
			$num_threads--;
		}
	} else {
		# child code...
		# Acknowledge signals...
		$SIG{CHLD} = 'DEFAULT';
		sigprocmask(SIG_UNBLOCK, $signals);
	
		# close uneeded end of pipes...
		close($reader);

		open(STDOUT, ">&$writer") or die "Cannot redirect STDOUT: $!\n";
		open(STDERR, ">&$writer") or die "Cannot redirect STDOUT: $!\n";
		open(STDIN, "< /dev/null") or die "Cannot redirect STDIN: $!\n";

		# Stop as much bufferring if we can...
		select(STDOUT); $| = 1;

		if (hostname() eq $host) {
			chdir($ENV{'HOME'}) or die "$0:localhost: cd $ENV{'HOME'} failed: $!\n";
			exec(@ARGV) or die "$0:localhost: @ARGV: $!\n";
		} else {
			exec(@command, '-l', $remote_user, $host, @ARGV) or die "$0:rssh: $host @ARGV: $!\n";
		}
	} 
}
while ($num_threads > 0) {
	read_handles();
	$num_threads--;
}

if ($condensed) {
	print_comp();
}

#
# This section reads the input from filehandles 
# and outputs the data when one closes.
# At this point it also returns to the calling 
# function for it to fork another process...
#

sub read_handles {
	# Turn off stirct refs...
	no strict 'refs';

	my $host;
	my $num_handles = $poll->handles();
	
	do {
		$poll->poll(undef);
		for my $handle ($poll->handles(POLLIN|POLLHUP|POLLERR)) {
			($host = $handle) =~ s/^[^:]*:://;
			my $rc = sysread(*$handle, $output{$host}, 2048, length($output{$host}));
			if (defined $rc)  {
				if ($rc == 0) {
					#End of socket...
					$poll->remove(*$handle);
					close(*$handle);
					last;
				}
			} else {
				# unexpected error...
				$poll->remove(*$handle);
				close(*$handle);
				$output{$host} .= "\n$0:ssh: $!\n";
				last;
			}
		}
	} until ($num_handles > $poll->handles());
	
	# Now we output the data...
	if (defined($output)) {
		open (OUTPUT, "> $output.$host") or die "Cannot open file $output.$host for writing: $!\n";
	}

	# Print verbose information if requested...
	if (defined($verbose) && (defined($output) || defined($condensed))) {
		printf STDERR "%-39.38s complete\n", $host if ($verbose);
	}

	# Now we check to see if we condense the output...
	if (!defined($output) && $condensed) {
		push(@{$comp_out{$output{$host}}}, $host);
		delete $output{$host};
		return;
	}
	my $index = -1;
	my $end_index = index($output{$host},"\n",$index+1);
	my $string;
	while ($end_index != -1) {
		$string = substr($output{$host}, $index+1, $end_index - $index);
		if (defined($output)) {
			print OUTPUT "$string";
		} else {
			print "$host: $string";
		}
		$index = $end_index;
		$end_index = index($output{$host},"\n",$index+1);
	}
	if ($index + 1 < length $output{$host}) {
		$string = substr($output{$host}, $index+1);
		if (defined($output)) {
			print OUTPUT "$string\n";
		} else {
			print "$host: $string\n";
		}
	}
	delete $output{$host};
}

#
# This is the SIGCHLD handler...
#

sub reaper {
	while ((my $child = waitpid(-1, WNOHANG)) > 0) {
		delete $CHILDREN{$child};
	}
}

#
# Print comp output
#
sub print_comp {
	my ($compress_output, $node_host);
	foreach $compress_output (sort keys %comp_out) {
		@{$comp_out{$compress_output}} = sort(@{$comp_out{$compress_output}});
		print "\nHosts -------------------------------------------------------------------------\n";
		my $count = 0;
		foreach $node_host (@{$comp_out{$compress_output}}) {
			$count++;
			printf STDOUT "%-19.18s", $node_host;
			print "\n" if (($count % 4) == 0);
		}
		print "\n" if (($count % 4) != 0);
		print "-------------------------------------------------------------------------------\n";
		print $compress_output;
	}
}

#
# Handles host options...
#
sub read_list {
    open (LIST, "< $list_file") or die "Cannot open the list file: $!\n";
    while (<LIST>) {
        my ($host, $options) = split(/[\s]/,$_,2);
        next if $host =~ m/^#/;
        chomp($options);
        $hosts{$host} = $options;
    }
    close(LIST);
}  

sub read_groups {
	open (GROUPS, "< $group_file") or die "Cannot open the group file: $!\n";
	while (<GROUPS>) {
		my ($group, $group_contains) = split(/:/);
		$group = uc($group);
		next if $group =~ m/^#/;
		foreach (split(/[,\s]/, $group_contains)) {
			push(@{$group_hosts{$group}}, $_);
		}
	}
	close(GROUPS);
}

sub group_list {
	my ($string) = @_;
	$string = uc($string);
	my (%temp_hosts, $nextgroup);
	if (!defined($group_hosts{$string})) {
		printf STDERR "The group %s cannot be found in the groups file.\n", $string;
		return;
	}
	foreach (@{$group_hosts{$string}}) {
		next if $_ =~ m/^$/;
		if ( $_ =~ m/^@/) {
			($nextgroup = $_) =~ s/^@//;
			foreach $host (group_list($nextgroup)) {
				$temp_hosts{$host} = 1;
			}
		} else {
			$temp_hosts{$_} = 1;
		}
	}
	return keys %temp_hosts;
}

sub group_option {
	my ($option, $string) = @_;
	my $group;
	foreach $group (split(/,/, $string)) {
		if ($option =~ m/g/) {
			foreach $host (group_list($group)) {
				$hosts{$host} = 1;
			}
		} elsif ($option =~ m/G/) {
			foreach $host (group_list($group)) {
				delete $hosts{$host};
			}
		} else {
			print "Something is really wrong! Bailing out!\n";
			exit 1;
		}
	}
}

__END__

=head1 NAME

dssh - Distributed ssh client

=head1 SYNOPSIS

dssh [options] command

=head1 OPTIONS

=over 2

=item B<-w host1[,host2,host3]>

Adds separate hosts to the current wrokgroup.

=item B<-W workgroup[,workgroup2,workgroup3]>

Removes the hosts from the current workgroup.

=item B<-g group1[,group2,group3]>

Adds the group to the current workgroup.  The group is worked out from the fan-groups file.

=item B<-G group1[,group2,group3]>

Removes the group from the current workgroup.

=item B<-remote-user username>

Sets the username used when connecting to remote hosts.

=item B<-q>

Prints out the hosts the command would be run on.

=item B<-Q>

Prints out the groups that are listed in the groups file.

=item B<-o filename>

The output is redirected to a series of files called filename.hostname

=item B<-c>

Condense the output by combining hosts that produce exactly the same output for the command.
Note output is printed only when all hosts are completed.

=item B<-v>

Prints message as each host completes (For use with -c and -o).

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Print the manual page and exits.

=item B<--threads num>

Sets the maximum number of threads that will be running at the same time.

=back

=head1 DESCRIPTION

C<dssh> will run the specified command on the given hosts and hosts in the workgroups listed.
The command cannot have any interactive component and the results from each host are returned in a block of text.

The command run and all the options used when invoking the command will also be logged to syslog in the event that something goes astray.

Quoting is handled in a deterministic way, such that the command is interpretted twice.  What this means is that the command should have single quotes ('), around the entire command and double quotes ("), should be used around strings, etc.  Dollar signs also need to be escaped once.  So a sample command would look like:

dssh -g all 'awk "{print \$1}" /etc/passwd'

=cut
