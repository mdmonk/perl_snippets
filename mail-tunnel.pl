#!/usr/bin/perl

use IPC::Open3;

use vars qw(
	$open_pid
	$read
	$write
	$error
	@accounts
);

# Change this for every system you want to create an
# SSH tunnel to.

@accounts = (
	# ssh user, mail server,          local forwarded port
	[ 'ben',    'mail.opennms.org',   '1143' ],
	[ 'ranger', 'mail.scenespot.org', '1144' ],
);

sub handler {
	my ($signal) = @_;
	close (FILEOUT);
	close ($open_pid);
	close ($write);
	close ($read);
	close ($error);
	exit 0;
}

for my $sig ('HUP', 'INT', 'QUIT', 'ILL', 'ABRT', 'KILL', 'SEGV', 'PIPE', 'TERM', 'STOP', 'CONT', '__WARN__', '__DIE__') {
  $SIG{$sig} = \&handler;
}
$SIG{'CHLD'} = 'IGNORE';

for my $tunnel (@accounts) {

	if (my $pid = fork) {
		# do nothing
	} else {
		die unless defined $pid;
		my $in;

		open (FILEOUT, ">/tmp/tunnel.log");

		$open_pid = open3($write, $read, $error,
			'ssh',
			'-C',
			'-l',
			$tunnel->[0],
			'-L',
			$tunnel->[2].':localhost:143',
			$tunnel->[1],
			'sleep 30',
		) or die "failed running open3: $!\n";;

		while ($in = <$read> or $in = <$error>) {
			print FILEOUT $in;
			$in = undef;
			sleep 5;
		}
		exit 0;
	}

}

sleep 2;
