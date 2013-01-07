#!/usr/bin/perl

=head1 NAME
 
MSS - the Meta Source System

=head1 DESCRIPTION
 
MSS is a CVS-like script for maintaining a "ghost" source
tree based on a source tree and patch set.
 
=cut

$|++;

use strict;
#use diagnostics;
#use warnings;

use POSIX;

use Cwd qw(abs_path);
use Digest::MD5;
use File::Basename;
use File::Find;
use Getopt::Long;
use IO::Handle;
use IPC::Open3;
use MLDBM qw(DB_File Storable);

use vars qw(
	$VERBOSE
	$DRY_RUN
	$OPTIONS_FILE

	$DIR_FROM
	$DIR_PATCH
	$DIR_TO
	$DIR_ME

	@IGNORE_DIRS

	$COLUMNS
	$COMMAND
	$TIME
	$FROM_COUNT
	$PATCH_COUNT
	$TO_COUNT
	$NEW_CHECKOUT
	$SEARCHING

	%STATE_FILE
	$STATE_PREVIOUS
	$STATE_CURRENT
);

$TIME         = time();
$FROM_COUNT   = 0;
$PATCH_COUNT  = 0;
$TO_COUNT     = 0;
$NEW_CHECKOUT = 0;
$COLUMNS      = exists $ENV{COLUMNS}? ($ENV{COLUMNS} - 2):78;

# command-line parsing
my @args = parse_command_line(@ARGV);

$DIR_FROM  = $ENV{BUILD_FROM}  if (defined $ENV{BUILD_FROM}  and not defined $DIR_FROM);
$DIR_PATCH = $ENV{BUILD_PATCH} if (defined $ENV{BUILD_PATCH} and not defined $DIR_PATCH);
$DIR_TO    = $ENV{BUILD_TO}    if (defined $ENV{BUILD_TO}    and not defined $DIR_TO);
$DIR_ME    = abs_path($ENV{PWD});

if ($args[0] !~ /^(create|co|checkout)$/i) {
	$DIR_FROM  = abs_path($ENV{PWD}) . "/.opennms-all"  unless (defined $DIR_FROM);
	$DIR_PATCH = abs_path($ENV{PWD}) . "/.oculan-patch" unless (defined $DIR_PATCH);
	$DIR_TO    = abs_path($ENV{PWD}) . "/oculan-all"    unless (defined $DIR_TO);

	load_options(find_mssrc($ENV{PWD}, $ENV{HOME}));

	print_help("no source directory defined!")      unless (defined $DIR_FROM);
	print_help("no patch directory defined!")       unless (defined $DIR_PATCH);
	print_help("no destination directory defined!") unless (defined $DIR_TO);

	$DIR_FROM  =~ s#/+$##g;
	$DIR_PATCH =~ s#/+$##g;
	$DIR_TO    =~ s#/+$##g;
}

{
	my ($ROOT_INSTALL, $ROOT_BUILD);
	for my $file ("$DIR_FROM/build.properties", "$ENV{HOME}/.bb-global.properties",
		"$ENV{HOME}/.opennms-global.properties") {

		if (open (FILEIN, $file)) {
			while (<FILEIN>) {
				if (/^\s*root\.install\s*=\s*(.+?)\s*$/) {
					$ROOT_INSTALL = $1;
				}
				if (/^\s*root\.build\s*=\s(.+?)\s*$/) {
					$ROOT_BUILD = $1;
				}
			}
			close(FILEIN);
		}
	}

	$ROOT_INSTALL =~ s#\$\{root\.source\}##;
	$ROOT_INSTALL =~ s#${DIR_FROM}##;
	$ROOT_INSTALL =~ s#^/##;
	$ROOT_INSTALL =~ s#/$##;

	$ROOT_BUILD   =~ s#\$\{root\.source\}##;
	$ROOT_BUILD   =~ s#${DIR_FROM}##;
	$ROOT_BUILD   =~ s#^/##;
	$ROOT_BUILD   =~ s#/$##;

	push(@IGNORE_DIRS, $ROOT_INSTALL, $ROOT_BUILD);
}

# Possible States
#
# S: Same	 (file is unchanged)
# C: Changed      (file has changed)
# N: New	  (file is new)
# R: Removed      (file has been removed)
# X: Non-Existant (file doesn't exist and didn't exist)

# the state machine (everything that isn't an "unhandled state")
my $state = {
	'S' => {
		'S' => {
			'S' => \&do_nothing,
			'C' => \&do_patch,
			'X' => [ \&do_diff_warn, "files are not new, but patch is missing" ],
		},
		'C' => {
			'S' => \&do_patch,
			'C' => \&do_scc,
		},
		'R' => {
			'S' => \&do_srs,
			'R' => [ \&do_delete, 1 ],  # 1 = delete from CVS as well
		},
		'X' => {
			'S' => \&do_nothing,
			'C' => \&do_patch,
			'R' => \&do_sxr,
		},
	},
	'C' => {
		'S' => {
			'S' => \&do_diff,
		},
		'C' => {
			'S' => \&do_diff_check,
			'C' => \&do_diff_check,
		},
		'X' => {
			'S' => \&do_create,
			'C' => \&do_cxc,
			'N' => [ \&do_bomb, "the destination directory has changed *and* there is a new .create file!" ],
			'R' => [ \&do_create_warn, ".create may have been deleted, recreating" ],
			'X' => [ \&do_create_warn, ".create may have been deleted, recreating" ],
		},
	},
	'N' => {
		'S' => {
			'N' => \&do_nothing,
		},
		'N' => {
			'N' => \&do_diff_check,
			'X' => \&do_diff,
		},
		'X' => {
			'X' => \&do_create,
		},
	},
	'R' => {
		'S' => {
			'C' => {
				'update' => \&do_patch,
			},
		},
		'C' => {
			'S' => {
				'update' => \&do_patch,
				'create' => \&do_patch,
			},
			'C' => {
				'update' => \&do_patch,
			},
		},
		'R' => {
			'S' => \&do_delete,
			'R' => \&do_nothing,
		},
		'X' => {
			'S' => \&do_rxs,
			'R' => \&do_nothing,
			'X' => \&do_nothing,
		},
		'S' => {
			'S' => \&do_rss,
		},
	},
	'X' => {
		'S' => {
			'S' => \&do_patch,
		},
		'N' => {
			'N' => \&do_patch,
			'X' => [ \&do_copy, "U" ],
		},
		'R' => {
			'R' => [ \&do_nothing_warn, "source file and patch removed" ],
		},
		'X' => {
			'S' => \&do_xxs,
			'N' => \&do_patch,
			'R' => \&do_remove_state,
			'X' => \&do_remove_state,
		},
	},
};

##### CALL THE COMMAND GIVEN ON THE COMMAND-LINE #####

my $shortcuts = {
	'checkout'	=> 'create',
	'co'		=> 'create',
	'up'		=> 'update',
};

if (exists &{'cmd_'.$args[0]}) {
	no strict 'refs';
	$COMMAND = shift @args;
	verbose("calling cmd_$COMMAND('" . join("', '", @args) . "')");
	&{'cmd_'.$COMMAND}(@args);
} elsif (exists &{'cmd_'.$shortcuts->{$args[0]}}) {
	no strict 'refs';
	$COMMAND = $shortcuts->{shift @args};
	verbose("calling cmd_$COMMAND('" . join("', '", @args) . "')");
	&{'cmd_'.$COMMAND}(@args);
} else {
	error("command '$args[0]' not found");
}

=head1 COMMAND-LINE OPTIONS

=head2 * add

  mss add [options] <files>

Where [options] is from the following:

=over 4

=item * -f

Force creation of a new patch, even if it exists.

=back

=cut

sub cmd_add {
	my @args = @_;

	my $warnings = 0;
	my $FORCE;

	{
		my @new_args;
		while (1) {
			my $arg = shift @args or last;

			if ($arg eq "-f") {
				$FORCE = 1;
				next;
			}
			push(@new_args, $arg);
		}
		@args = @new_args;
	}

	if (@args == 0) {
		error("you must give at least one file to add!");
	}

	if (not defined $OPTIONS_FILE or $OPTIONS_FILE eq "") {
		my $mssrc = find_mssrc($ENV{PWD});
		load_options($mssrc);
	}

	parse_state();
	for my $key (@args) {
		next if (-d "${DIR_FROM}/${key}" or (not -f "${DIR_FROM}/${key}" and -d "${DIR_TO}/${key}"));
		if (patch_exists($key) and not $FORCE) {
			verbose("C $key exists in the patch tree!");
		} else {
			if (-f "${DIR_FROM}/${key}") {
				do_diff('N:A:S', $key, 'A');
			} else {
				do_create('N:A:X', $key, 'A');
			}
		}
	}

	notice("=" x $COLUMNS);

	my $return;
	$ENV{CVS_RSH} = 'ssh';

	notice("add: entering $DIR_PATCH");
	chdir($DIR_PATCH);

	$return = system('cvs', 'add', map {
		my $file = $_;
		if (-d "${DIR_TO}/$file") {
			$_ = $file;
		} else {
			$file = patch_exists($file);
			$file =~ s#^$DIR_PATCH/##;
			$_ = $file;
		}
	} @args);
	if (($? >> 8) > 0) {
		error("add: CVS add in oculan-patch failed");
		exit 1;
	}
	chdir($DIR_ME);
	close_state();

}

=head2 * commit

  mss commit [files]

Check for changes in the destination tree and
apply them to the CVS source.

=cut

sub cmd_commit {
	my @args = @_;

	my $warnings = 0;

	if (not defined $OPTIONS_FILE or $OPTIONS_FILE eq "") {
		my $mssrc = find_mssrc($ENV{PWD});
		load_options($mssrc);
	}

	my $return;
	$ENV{CVS_RSH} = 'ssh';

	notice("commit: entering $DIR_FROM");
	chdir($DIR_FROM);
	$return = system('cvs', 'up', @args);
	if (($? >> 8) > 0) {
		error("commit: CVS update of opennms-all failed");
		exit 1;
	}
	chdir($DIR_ME);

	my @patch_args;
	for my $arg (@args) {
		my $file = patch_exists($arg) or next;
		$file =~ s#^$DIR_PATCH/##;
		push(@patch_args, $file);
	}
	notice("commit: entering $DIR_PATCH");
	chdir($DIR_PATCH);
	$return = system('cvs', 'up', @patch_args);
	if (($? >> 8) > 0) {
		error("commit: CVS update of oculan-patch failed");
		exit 1;
	}
	chdir($DIR_ME);

	notice("=" x $COLUMNS);
	parse_state();
	do_parse(@args);
	close_state();

	chdir($DIR_PATCH);
	$return = system('cvs', 'commit', @patch_args);
	if (($? >> 8) > 0) {
		error("commit: CVS commit of oculan-patch failed");
		exit 1;
	}
	chdir($DIR_ME);

}

=head2 * create

  mss create [options] [files]

Where [options] is from the following:

=over 4

=item * -s [source directory]

The directory to check the source tree out to.

=item * -p [patch directory]

The directory to check the intermediate files out to.

=item * -d [destination directory]

The directory to put the generated tree into.

=back

=cut

sub cmd_create {
	my @args = @_;

	my $warnings = 0;

	while (1) {
		my $arg = shift @args or last;

		if ($arg eq "-d") {
			$DIR_TO = shift @args;
			next;
		}
		if ($arg eq "-p") {
			$DIR_PATCH = shift @args;
			next;
		}
		if ($arg eq "-s") {
			$DIR_FROM = shift @args;
			next;
		}
		&warn("create: unknown option '$arg'");
		$warnings++;
	}

	$DIR_FROM  = abs_path($ENV{PWD}) . "/.opennms-all"  unless (defined $DIR_FROM);
	$DIR_PATCH = abs_path($ENV{PWD}) . "/.oculan-patch" unless (defined $DIR_PATCH);
	$DIR_TO    = abs_path($ENV{PWD}) . "/oculan-all"    unless (defined $DIR_TO);

	for ($DIR_TO, $DIR_PATCH, $DIR_FROM) {
		if (-d $_) {
			&warn("everything in $_ could be deleted or changed");
			$warnings++;
		}
	}

	if ($warnings) {
		print "        : Are you sure you want to continue? [Y/n] ";
		my $input = <STDIN>;
		unless ($input =~ /^[Yy]{0,1}$/ or $input =~ /^y(es|up)$/i) {
			print "exiting\n";
			exit 1;
		}
	}

	# everything is go

	for my $dir (\$DIR_FROM, \$DIR_PATCH, \$DIR_TO) {
		unlink($$dir) if (-f $$dir);
		mkdir($$dir);
		$$dir = abs_path($$dir);
		rmdir($$dir);
	}

	$ENV{CVS_RSH} = 'ssh';
	my ($checkout_dir, $basename_dir, $return);

	notice("create: checking out 'from' tree to $DIR_FROM");
	$checkout_dir = dirname($DIR_FROM);
	$basename_dir = basename($DIR_FROM);
	chdir($checkout_dir);
	$return = system('cvs', '-d', ":ext:$ENV{USER}\@cvs.internal.opennms.org:/opt/cvs-experimental",
		'co', '-d', $basename_dir, 'opennms-all');

	if (($? >> 8) > 0) {
		error("create: CVS checkout of opennms-all failed");
		exit 1;
	}

	chdir($DIR_ME);

	notice("create: checking out patch tree to $DIR_PATCH");
	$checkout_dir = dirname($DIR_PATCH);
	$basename_dir = basename($DIR_PATCH);
	chdir($checkout_dir);
	$return = system('cvs', '-d', ":ext:$ENV{USER}\@cvs.internal.opennms.org:/opt/cvs-experimental",
		'co', '-d', $basename_dir, 'oculan-patch');

	if (($? >> 8) > 0) {
		error("create: CVS checkout of oculan-patch failed");
		exit 1;
	}

	notice("=" x $COLUMNS);

	# parse through and generate the initial state (overriding if necessary)
	unlink("${DIR_TO}/filedata.db");

	parse_state();
	for my $key (sort(keys %{$STATE_CURRENT}, keys %{$STATE_PREVIOUS})) {
		my ($oc_state, $op_state, $pa_state) = get_state($key);
		my $state = "${oc_state}:${op_state}:${pa_state}";
		if ($pa_state eq "N") {
			do_patch($state, $key, 'create');
		} elsif ($state eq "X:N:X") {
			&warn("$key exists in source tree, but not in patch tree.  creating.");
			touch("${DIR_PATCH}/${key}.patch");
			do_patch($state, $key);
		} elsif ($state eq "N:N:X") {
			# forced create from do_patch()
			do_diff($state, $key);
		} else {
			error("$key: unknown state $state for a create!");
		}
#		print "$state / $key\n";
	}
	close_state();
	save_options("${DIR_TO}/.mssrc");
}

=head2 * diff

  mss diff [options] [files]

Where [options] is from the following:

=over 4

=item * -d

The person running diff is a (d)ork.

=back

=cut

sub cmd_diff {
	my @args = @_;

	my $warnings = 0;
	my $FORCE;

	{
		my @new_args;
		while (1) {
			my $arg = shift @args or last;

			if ($arg eq "-f") {
				$FORCE = 1;
				next;
			}
			push(@new_args, $arg);
		}
		@args = @new_args;
	}

	if (not defined $OPTIONS_FILE or $OPTIONS_FILE eq "") {
		my $mssrc = find_mssrc($ENV{PWD});
		load_options($mssrc);
	}

}

=head2 * remove

  mss remove [options] <files>

Where [options] is from the following:

=over 4

=item * -f

Force removal of a file from the destination tree as well
as the patch tree.

=back

=cut

sub cmd_remove {
	my @args = @_;

	my $warnings = 0;
	my $FORCE;

	{
		my @new_args;
		while (1) {
			my $arg = shift @args or last;

			if ($arg eq "-f") {
				$FORCE = 1;
				next;
			}
			push(@new_args, $arg);
		}
		@args = @new_args;
	}

	if (@args == 0) {
		error("you must give at least one file to remove!");
	}

	if (not defined $OPTIONS_FILE or $OPTIONS_FILE eq "") {
		my $mssrc = find_mssrc($ENV{PWD});
		load_options($mssrc);
	}

	my @removeme;

	notice("=" x $COLUMNS);
	parse_state();
	for my $key (@args) {

		my $patch = patch_exists($key);
		push(@removeme, $patch) unless ($patch =~ /\.remove$/);

		unlink("${DIR_TO}/${key}") if ($FORCE);
		unlink($patch);

		if (-f "${DIR_FROM}/${key}") {
			&warn("$key still exists in the source directory");
			notice("R $key [R:R:S]");
			touch("${DIR_PATCH}/${key}.remove");
		} else {
			notice("R $key [R:R:X]");
		}

	}

	notice("=" x $COLUMNS);

	my $return;
	$ENV{CVS_RSH} = 'ssh';

	notice("remove: entering $DIR_PATCH");
	chdir($DIR_PATCH);
	$return = system('cvs', 'remove', map {
		my $patch = $_;
		$patch =~ s#^$DIR_PATCH/##;
		$_ = $patch  } @args);
	if (($? >> 8) > 0) {
		error("add: CVS remove in oculan-patch failed");
		exit 1;
	}
	chdir($DIR_ME);
	close_state();

}

=head2 * update

  mss update [files]

Get changes from CVS and apply to the destination tree.

=cut

sub cmd_update {
	my @args = @_;

	my $warnings = 0;

	if (not defined $OPTIONS_FILE or $OPTIONS_FILE eq "") {
		my $mssrc = find_mssrc($ENV{PWD});
		load_options($mssrc);
	}

	my $return;
	$ENV{CVS_RSH} = 'ssh';

	notice("update: entering $DIR_FROM");
	chdir($DIR_FROM);
	$return = system('cvs', 'up', @args);
	if (($? >> 8) > 0) {
		error("update: CVS update of opennms-all failed");
		exit 1;
	}
	chdir($DIR_ME);

	my @patch_args;
	for my $arg (@args) {
		my $file = patch_exists($arg) or next;
		$file =~ s#^$DIR_PATCH/##;
		push(@patch_args, $file);
	}
	notice("update: entering $DIR_PATCH");
	chdir($DIR_PATCH);
	$return = system('cvs', 'up', @patch_args);
	if (($? >> 8) > 0) {
		error("update: CVS update of oculan-patch failed");
		exit 1;
	}
	chdir($DIR_ME);

	notice("=" x $COLUMNS);
	parse_state();
	do_parse(@args);
	close_state();
}

# return the state for a given key (to, from, patch)

sub get_state {
	my $key = shift;

	my ($op_state, $pa_state, $oc_state);
	my ($c_op_age, $c_op_md5, $c_pa_age, $c_pa_md5, $c_oc_age, $c_oc_md5);
	my ($p_op_age, $p_op_md5, $p_pa_age, $p_pa_md5, $p_oc_age, $p_oc_md5);

	if (exists $STATE_CURRENT->{$key}) {
		($c_oc_age, $c_oc_md5, $c_op_age, $c_op_md5, $c_pa_age, $c_pa_md5) = @{$STATE_CURRENT->{$key}};
	}
	if (exists $STATE_PREVIOUS->{$key}) {
		($p_oc_age, $p_oc_md5, $p_op_age, $p_op_md5, $p_pa_age, $p_pa_md5) = @{$STATE_PREVIOUS->{$key}};
	}

	return (
		do_compare($p_oc_age, $p_oc_md5, $c_oc_age, $c_oc_md5),
		do_compare($p_op_age, $p_op_md5, $c_op_age, $c_op_md5),
		do_compare($p_pa_age, $p_pa_md5, $c_pa_age, $c_pa_md5),
	);
}

# fills $STATE_PREVIOUS and $STATE_CURRENT
sub parse_state {

	makedir($DIR_TO);
	tie %STATE_FILE, 'MLDBM', "$DIR_TO/filedata.db",
	        O_CREAT|O_RDWR, 0644 or error("unable to open $DIR_TO/filedata.db for reading: $!");
	(tied %STATE_FILE)->DumpMeth('portable');

	%{$STATE_PREVIOUS} = %STATE_FILE;

	# fill $STATE_CURRENT -- scan each of the source directories
	get_current_state($DIR_TO,    0);
	get_current_state($DIR_FROM,  1);
	get_current_state($DIR_PATCH, 2);

}

# on a successful run, we set the state tree for next time by taking
# current and forcing it to write to the DBM
sub close_state {

	%STATE_FILE = %{$STATE_CURRENT};
	untie %STATE_FILE;

}

# populate the state information for a directory
sub get_current_state {
	my $directory = shift;
	my $offset    = shift;

	verbose("get_state: scanning directory $directory");
	$SEARCHING = [ $directory, $offset ];
	return find(\&find_files, $directory);
}

# iterate through every filename, generate a comparison of
# it's current and previous state, and act if necessary
sub do_parse {
	my @keys = sort(@_);
	my $last_key;

	@keys = sort(keys %{$STATE_CURRENT}, keys %{$STATE_PREVIOUS})
		unless (@keys > 0);

	for my $key (@keys) {
		next if (defined $last_key and $key eq $last_key);

		my ($op_state, $pa_state, $oc_state);
		my ($c_op_age, $c_op_md5, $c_pa_age, $c_pa_md5, $c_oc_age, $c_oc_md5);
		my ($p_op_age, $p_op_md5, $p_pa_age, $p_pa_md5, $p_oc_age, $p_oc_md5);

		if (exists $STATE_CURRENT->{$key}) {
			($c_oc_age, $c_oc_md5, $c_op_age, $c_op_md5, $c_pa_age, $c_pa_md5) = @{$STATE_CURRENT->{$key}};
		}
		if (exists $STATE_PREVIOUS->{$key}) {
			($p_oc_age, $p_oc_md5, $p_op_age, $p_op_md5, $p_pa_age, $p_pa_md5) = @{$STATE_PREVIOUS->{$key}};
		}

		$oc_state = do_compare($p_oc_age, $p_oc_md5, $c_oc_age, $c_oc_md5);
		$op_state = do_compare($p_op_age, $p_op_md5, $c_op_age, $c_op_md5);
		$pa_state = do_compare($p_pa_age, $p_pa_md5, $c_pa_age, $c_pa_md5);

		# this is a bit ugly; what it does is call the code reference
		# from the state table above
		if (exists $state->{$oc_state}->{$op_state}->{$pa_state}) {
			verbose("* state $oc_state:$op_state:$pa_state exists, calling on key $key");
			if (ref $state->{$oc_state}->{$op_state}->{$pa_state} eq "CODE") {
				&{$state->{$oc_state}->{$op_state}->{$pa_state}}("$oc_state:$op_state:$pa_state", $key)
					or do_bomb("$oc_state:$op_state:$pa_state", $key, "unknown problem occurred for state $oc_state:$op_state:$pa_state on file $key");
			} elsif (ref $state->{$oc_state}->{$op_state}->{$pa_state} eq "HASH") {
				if (exists $state->{$oc_state}->{$op_state}->{$pa_state}->{$COMMAND}) {
					&{$state->{$oc_state}->{$op_state}->{$pa_state}->{$COMMAND}}("$oc_state:$op_state:$pa_state", $key)
					or do_bomb("$oc_state:$op_state:$pa_state", $key, "unknown problem occurred for state $oc_state:$op_state:$pa_state on file $key");
				} else {
					do_bomb("$oc_state:$op_state:$pa_state", $key, "unknown problem occurred for state $oc_state:$op_state:$pa_state on file $key");
				}
			} else {
				my ($sub, @options) = @{$state->{$oc_state}->{$op_state}->{$pa_state}};
				&{$sub}("$oc_state:$op_state:$pa_state", $key, @options)
					or do_bomb("$oc_state:$op_state:$pa_state", $key, "unknown problem occurred for state $oc_state:$op_state:$pa_state on file $key");
			}
		} else {
			do_bomb("$oc_state:$op_state:$pa_state", $key, "unhandled state: $oc_state:$op_state:$pa_state on file $key");
		}

		$last_key = $key;
	}
}

##### GENERIC CASES #####

# the default subrouting for bombing out
sub do_bomb {
	my $state = shift;
	my $key   = shift;
	error(@_);
}

# copy a new source file to the destination and warn
sub do_copy_warn {
	my $state = shift;
	my $key   = shift;

	my $return = do_copy($state, $key);
	&warn("$key: ", @_);
	return $return;
}

# copy a new source file to the destination
sub do_copy {
	my $state = shift;
	my $key   = shift;
	my $noticetype = shift || "U";

	notice("$noticetype $key [$state]");
	makedir(dirname("${DIR_TO}/${key}"));
	makedir(dirname("${DIR_PATCH}/${key}"));
	open (FILEIN, "${DIR_FROM}/${key}") or error("do_copy: unable to open ${DIR_FROM}/${key} for reading: $!");
	open (FILEOUT, ">${DIR_TO}/${key}") or error("do_copy: unable to open ${DIR_TO}/${key} for writing: $!");
	print FILEOUT while (<FILEIN>);
	close (FILEOUT);
	close (FILEIN);
	touch("${DIR_PATCH}/${key}.patch");

	return 1;
}

# make a .create file (exists in destination, not in source) and warn
sub do_create_warn {
	my $state = shift;
	my $key   = shift;

	my $return = do_create($state, $key);
	&warn("$key: ", @_);
	return $return;
}

# make a .create file (exists in destination, not in source)
sub do_create {
	my $state = shift;
	my $key   = shift;
	my $noticetype = shift || "M";

	notice("$noticetype $key [$state]");
	my $mode = sprintf('%lo', (stat("${DIR_TO}/${key}"))[2] & 07777);

	makedir(dirname("${DIR_PATCH}/${key}"));
	open (FILEIN, "${DIR_TO}/${key}") or error("do_create: unable to open ${DIR_TO}/${key} for reading: $!");
	open (FILEOUT, ">${DIR_PATCH}/${key}.create") or error("do_create: unable to open ${DIR_PATCH}/${key} for writing: $!");
	print FILEOUT while (<FILEIN>);
	close (FILEOUT);
	close (FILEIN);
	chmod(oct("0$mode"), "${DIR_PATCH}/${key}.create");

	# update the patch status
	$STATE_CURRENT->{$key}->[4] = get_time(patch_exists($key)) or die;
	$STATE_CURRENT->{$key}->[5] = get_md5(patch_exists($key)) or die;

	return 1;
}

# delete a file from all trees and warn
sub do_delete_warn {
	my $state = shift;
	my $key   = shift;

	my $return = do_delete($state, $key);
	&warn("$key: ", @_);
	return $return;
}

# delete a file from all trees
sub do_delete {
	my $state      = shift;
	my $key        = shift;
	my $delete_cvs = shift;

	verbose("R:R:R deleting ${key} from all trees!");
	if (-f "${DIR_FROM}/${key}") {
		unlink("${DIR_FROM}/${key}") or error("unable to delete ${DIR_FROM}/${key}: $!");
	}
	if ($delete_cvs) {
		while (my $patch = patch_exists($key)) {
			$patch =~ s#^$DIR_PATCH/##;

			chdir($DIR_PATCH);
			system('cvs', 'remove', $patch);
			if (($? >> 8) > 0) {
				error("do_delete: CVS remove of $patch in oculan-patch failed");
				exit 1;
			}
			chdir($DIR_ME);
		}
	} else {
		while (patch_exists($key)) {
			unlink(patch_exists($key)) or error("unable to delete ".patch_exists($key).": $!");
		}
	}
	if (-f "${DIR_TO}/${key}") {
		unlink("${DIR_TO}/${key}") or error("unable to delete ${DIR_TO}/${key}: $!");
	}
	return 1;
}

# make a diff (exists in both destination and source) and warn
sub do_diff_warn {
	my $state = shift;
	my $key   = shift;

	my $return = do_diff($state, $key);
	&warn("$key: ", @_);
	return $return;
}

# make a diff (exists in both destination and source)
sub do_diff {
	my $state = shift;
	my $key   = shift;
	my $noticetype = shift || "M";
	my $patch;

	my $mode = sprintf('%lo', (stat("${DIR_FROM}/${key}"))[2] & 07777);

#	my $mm   = File::MMagic->new();
#	my $type = $mm->checktype_filename("${DIR_TO}/${key}");

	$patch = `diff -uNPd '$DIR_FROM/$key' '$DIR_TO/$key' 2>&1`;
	if (($? >> 8) > 1) {
		error(join("\n", map { $_ = "do_diff: " . $_ } split(/[\r\n]+/, $patch)));
	}

	if ($patch =~ /^Binary files/) {
		return do_create($state, $key, $noticetype);
	}

	notice("$noticetype $key [$state]");
	if ($DRY_RUN) {
		print $patch if (defined $patch);
	} else {
		makedir(dirname("${DIR_PATCH}/${key}"));
		open (FILEOUT, ">${DIR_PATCH}/${key}.patch")
			or error("cannot open ${DIR_PATCH}/${key}.patch for writing: $!");
		print FILEOUT $patch if (defined $patch);
		close (FILEOUT);
		chmod(oct("0$mode"), "${DIR_PATCH}/${key}.patch");
		print $patch if (defined $patch and $VERBOSE);
	}

	# update the patch status
	$STATE_CURRENT->{$key}->[4] = get_time(patch_exists($key)) or die;
	$STATE_CURRENT->{$key}->[5] = get_md5(patch_exists($key)) or die;

	return 1;
}

sub do_diff_check {
	my $state = shift;
	my $key   = shift;
	my ($patch, $current_contents);

	if (-f "$DIR_FROM/$key" and -f "$DIR_TO/$key") {
		$patch = `diff -uNPd '$DIR_FROM/$key' '$DIR_TO/$key' 2>&1`;
		if (($? >> 8) > 1) {
			error(join("\n", map { $_ = "do_diff: " . $_ } split(/[\r\n]+/, $patch)));
		}
	} else {
		error("$DIR_FROM/$key went away") if (! -f "$DIR_FROM/$key");
		error("$DIR_TO/$key went away") if (! -f "$DIR_TO/$key");
	}

	if (-f "${DIR_PATCH}/${key}.patch") {
		local $/ = '';
		if (open (FILEIN, "${DIR_PATCH}/${key}.patch")) {
			$current_contents = <FILEIN>;
			close (FILEIN);
		} else {
			error("unable to read from ${DIR_PATCH}/${key}.patch: $!");
		}
	}

	my ($old_patch, $new_patch);
	for my $line (split(/\r?\n/, $patch)) {
		$new_patch .= $line . "\n" if ($line !~ /^(\+\+\+|---)/);
	}
	for my $line (split(/\r?\n/, $current_contents)) {
		$old_patch .= $line . "\n" if ($line !~ /^(\+\+\+|---)/);
	}

	if ($patch =~ /^[\s\r\n]*$/ or $old_patch eq $new_patch) {
		$STATE_CURRENT->{$key}->[4] = get_time(patch_exists($key)) or die;
		$STATE_CURRENT->{$key}->[5] = get_md5(patch_exists($key)) or die;
		return 1;
	} else {
		error("$state CONFLICT: $key");
	}
	return;
}

# do nothing, but warn about it  =)
sub do_nothing_warn {
	my $state = shift;
	my $key   = shift;

	&warn("$key: ", @_);
	return 1;
}

# what to do when you do nothing  ;)
sub do_nothing {
	my $state = shift;
	my $key   = shift;

	verbose("$key is unchanged");
	return 1;
}

# apply a create/diff/patch file
sub do_patch {
	my $state = shift;
	my $key   = shift;

	makedir(dirname("${DIR_TO}/${key}"));
	if (patch_exists($key) =~ /\.create$/) {
		notice("A $key [$state]");
		my $mode = sprintf('%lo', (stat("${DIR_PATCH}/${key}.create"))[2] & 07777);
		open (FILEIN, patch_exists($key)) or error("unable to open ".patch_exists($key)." for reading: $!");
		open (FILEOUT, ">${DIR_TO}/${key}") or error("unable to open ${DIR_TO}/${key} for writing: $!");
		print FILEOUT while (<FILEIN>);
		close (FILEOUT);
		close (FILEIN);
		chmod(oct("0$mode"), "${DIR_TO}/${key}");
		$STATE_CURRENT->{$key}->[0] = get_time("${DIR_TO}/${key}") or die;
		$STATE_CURRENT->{$key}->[1] = get_md5("${DIR_TO}/${key}") or die;
		$STATE_CURRENT->{$key}->[4] = get_time(patch_exists($key)) or die;
		$STATE_CURRENT->{$key}->[5] = get_md5(patch_exists($key)) or die;
		return 1;
	} elsif (patch_exists($key) =~ /\.remove$/) {
		notice("R $key [$state]");
		unlink("${DIR_TO}/${key}");
		return 1;
	} else {
		# don't ask me... modes are *fucked up*
		notice("P $key [$state]");
		my $mode = sprintf('%lo', (stat("${DIR_FROM}/${key}"))[2] & 07777);
		if ((-s "${DIR_PATCH}/${key}.patch") == 0) {
			open (FILEIN, "${DIR_FROM}/${key}") or error("unable to open ${DIR_FROM}/${key} for reading: $!");
			open (FILEOUT, ">${DIR_TO}/${key}") or error("unable to open ${DIR_TO}/${key} for writing: $!");
			print FILEOUT while (<FILEIN>);
			close (FILEOUT);
			close (FILEIN);
			chmod(oct("0$mode"), "${DIR_TO}/${key}");
			$STATE_CURRENT->{$key}->[0] = get_time("${DIR_TO}/${key}") or die;
			$STATE_CURRENT->{$key}->[1] = get_md5("${DIR_TO}/${key}") or die;
			$STATE_CURRENT->{$key}->[4] = get_time(patch_exists($key)) or die;
			$STATE_CURRENT->{$key}->[5] = get_md5(patch_exists($key)) or die;
			return 1;
		}
		
		my $patchargs = "";
		$patchargs = "--dry-run" if ($DRY_RUN);
		local $/ = undef;
		open(PATCH, "patch $patchargs '${DIR_FROM}/${key}' '${DIR_PATCH}/${key}.patch' -o '${DIR_TO}/${key}.patched' |") or die "can't run patch: $!\n";
		my $stdout = <PATCH>;
		my $return = close(PATCH);

		if (not $return) {
			if ($! eq "0") {
				warn("do_patch: ${DIR_TO}/${key}.patch: patch failed");
			} else {
				error("do_patch: an error occurred running patch on ${key}: $!");
			}
		}

		my $output;
		if (open(PATCH, "${DIR_TO}/${key}.patched")) {
			$output = <PATCH>;
			close(PATCH);
		}
		move("${DIR_TO}/${key}.patched", "${DIR_TO}/${key}");
		chmod(oct("0$mode"), "${DIR_TO}/${key}");

		$STATE_CURRENT->{$key}->[0] = get_time("${DIR_TO}/${key}") or die;
		$STATE_CURRENT->{$key}->[1] = get_md5("${DIR_TO}/${key}") or die;
		$STATE_CURRENT->{$key}->[4] = get_time(patch_exists($key)) or die;
		$STATE_CURRENT->{$key}->[5] = get_md5(patch_exists($key)) or die;

		return $return;
	}

	return;
}
 
# remove all memory of a key
sub do_remove_state {
	my $state = shift;
	my $key   = shift;

	delete $STATE_CURRENT->{$key};
	return 1;
}


##### SUPPORT SUBROUTINES #####

# compares the age and MD5s of a set of files to determine if it's changed
sub do_compare {
	my $p_age = shift;
	my $p_md5 = shift;
	my $c_age = shift;
	my $c_md5 = shift;

	#print "age: $p_age/$c_age, md5: $p_md5/$c_md5\n";
	if (defined $p_age and $p_age) {
		if (defined $c_age and $c_age) {
			if (defined $p_md5 and defined $c_md5 and $p_md5 eq $c_md5 and $p_md5 ne "0") {
				return 'S';
			} else {
				return 'C';
			}
		} else {
			return 'R';
		}
	} else {
		if (defined $c_age and $c_age) {
			return 'N';
		} else {
			return 'X';
		}
	}
	return;
}


# do nothing but log if $VERBOSE
sub nothing {
	my $file = shift;
	verbose("$file:\tnothing to be done");
}

# bomb on file $_[0]
sub default_bomb {
	my $file = shift;
}

# apply patch $_[0] to $_[1]
sub default_patch {
	my $patch = shift;
	my $file  = shift;

}

# do a diff between $_[0] and $_[1]
sub default_diff {
	my $from = shift;
	my $to   = shift;
}

# log if verbose
sub verbose {
	return 1 unless ($VERBOSE);
	notice(@_);
}

# print a message
sub notice {
	output("notice", @_);
}

# print a warning
sub warn {
	output("warning", @_);
}

# print an error and die
sub error {
	output("error", @_);
}

# simple text-parsing to prepend a key to a message
sub output {
	my $prefix = shift;
	my $output = join('', @_, "\n");
	$output =~ s#[\r\n]+#\n#g;

	my $printme;
	for my $line (split(/\n/, $output)) {
		next if ($line =~ /^\n?$/);
		if ($prefix eq "notice") {
			$printme .= $line . "\n";
		} else {
			$printme .= sprintf("%8s: %s\n", $prefix, $line);
		}
	}
	if ($prefix eq "error") {
		die $printme if (defined $printme);
		die "an unknown error occurred";
	} else {
		return print $printme;
	}
	return;
}

# recursively make a directory if it doesn't exist
sub makedir {
	my $path = shift;

	verbose("makedir: making directory $path");
 
	my $previous = '';
	my @dirs = grep(!/^$/, split(/\//, $path));
	for my $dir (@dirs) {
		mkdir( $previous.'/'.$dir, 0775 );
		$previous .= '/' . $dir;
	}
	return 1;
}

# create an empty file if it doesn't exist
sub touch {
	for my $file (@_) {
		if (! -f $file) {
			open (FILEOUT, ">$file") or error("touch: unable to create file '$file': $!");
			close (FILEOUT);
		}
	}
	return 1;
}

# move a file to another
sub move {
	my $fromfile = shift;
	my $tofile   = shift;
 
	makedir(dirname($tofile));
	unlink($tofile);
	my (@fileinfo) = stat($fromfile);
	link($fromfile, $tofile) and unlink($fromfile) and return 1;
	return;
}

# abstracts the whole create/remove/patch
sub patch_exists {
	my $key = shift;

	for my $suffix ('create', 'remove', 'patch') {
		return "${DIR_PATCH}/${key}.${suffix}" if (-f "${DIR_PATCH}/${key}.${suffix}");
	}
	return;
}

# this is not called directly, it's called using File::Find
# it fills the hash table of file statuses
sub find_files {
	my $filename = $_;
	my $path     = $File::Find::dir;

	$filename =~ s/[\r\n]+//;
	$path     =~ s/[\r\n]+//;
 
	my $fullpath = "$path/$filename";
	return unless (-f $fullpath);

	# dump ., .., .#*, .*.swp, *~, and CVS/*
	return if ($filename =~ /^\.\.?$/ or $filename =~ /^\.#/);
	return if ($filename =~ /^\..+\.swp$/);
	return if ($filename =~ /~$/);
	return if ($path eq $DIR_TO  and $filename eq "filedata.db");
	return if ($path eq $DIR_TO  and $filename eq ".mssrc");
	return if ($path =~ m#/CVS$# or  (-d $fullpath and $filename eq "CVS"));
	for my $dir (@IGNORE_DIRS) {
		verbose("find_files: ignoring $dir");
		return if ($path =~ m#^${DIR_FROM}/${dir}/#);
		return if ($path =~ m#^${DIR_PATCH}/${dir}/#);
		return if ($path =~ m#^${DIR_TO}/${dir}/#);
	}

	verbose("find_files: scanning $fullpath");

	# SEARCHING = [ prefix, state index ]
	my $chopped_path = $fullpath;
	$chopped_path =~ s#^$SEARCHING->[0]##;
	$chopped_path =~ s#^/##;

	if ( $SEARCHING->[1] == 2 ) {
		my $done = 0;
		$chopped_path =~ s/\.patch$//  and $done = 1 unless ($done);
		$chopped_path =~ s/\.create$// and $done = 1 unless ($done);
		$chopped_path =~ s/\.delete$// and $done = 1 unless ($done);
		$PATCH_COUNT++;
	}

	return if ($filename =~ /^\.?\#/ and $chopped_path =~ /\#$/);

	$TO_COUNT++   if ($SEARCHING->[1] == 0);
	$FROM_COUNT++ if ($SEARCHING->[1] == 1);

	my $offset = ($SEARCHING->[1] * 2);
	# state index   =   0       1       2       3       4       5
	# STATE_CURRENT = [ oc_age, oc_md5, op_age, op_md5, pa_age, pa_md5 ];
	$STATE_CURRENT->{$chopped_path}->[$offset]   = get_time($fullpath);
	$STATE_CURRENT->{$chopped_path}->[$offset+1] = get_md5($fullpath);
}

# gets the absolute age of a file in seconds (-M returns the age in days by default)
sub get_time {
	my $file = shift;

	if ( -e $file ) {
		my $day = 60 * 60 * 24;
		my $age = -M $file;
		return int($TIME - ($age * $day));
	} else {
		return 0;
	}
}

# gets the md5 of a file
sub get_md5 {
	my $filename = shift;
	my $md5;

	if (-e $filename) {
		my $digest = Digest::MD5->new();
		my $file = IO::Handle->new();
		open ($file, $filename) or error("unable to open $filename for reading: $!");
		$digest->addfile($file) or error("unable to md5 $filename: $!");
		$md5 = $digest->b64digest or error("unable to md5 $filename: $!");
		close ($file);
	} else {
		$md5 = 0;
	}

	return $md5;
}

# locate the .mssrc file
sub find_mssrc {
	my @paths = @_;
	my @sub_paths;

	for my $path (@paths) {
		if (opendir(DIR, $path)) {
			for my $sub (grep(!/^\.\.?$/, readdir(DIR))) {
				push(@sub_paths, abs_path($sub)) if (-d $sub);
			}
			closedir(DIR);
		}
	}

	for my $path (@paths, @sub_paths, $ENV{HOME}) {
		my @dirs = split(m#/+#, $path);
		while (@dirs) {
			if (-f join('/', @dirs) . '/.mssrc') {
				return join('/', @dirs) . '/.mssrc';
			} else {
				pop(@dirs);
			}
		}
	}

}

# read the options file
sub load_options {
	$OPTIONS_FILE = find_mssrc(shift);

	if (open (FILEIN, $OPTIONS_FILE)) {
		while (<FILEIN>) {
			next if (/^\s*#/);
			$_ =~ s#^\s*##;
			$_ =~ s#\s*$##;
			my ($key, $value) = split(/\s*=\s*/, $_, 2);
			eval("\$$key = '$value'");
		}
		close (FILEIN);
	}
	return 1;
}

# save the options file
sub save_options {
	my $file = shift;

	open (FILEOUT, ">$file") or error("unable to write to '$file': $!");
	print FILEOUT <<END;
DIR_FROM = $DIR_FROM
DIR_PATCH = $DIR_PATCH
DIR_TO = $DIR_TO
END
	close (FILEOUT);
	return 1;
}

# parse the command-line options
sub parse_command_line {
	my @args = @_;
	my @return;
	my $noparse = 0;

	ARGPARSE: while (my $arg = shift @args) {
		if ($noparse) {
			return (@return, $arg, @args);
		} else {
			# booleans
			do { $VERBOSE=1;             next ARGPARSE } if check_arg($arg, 'v', 'verbose');
			do { $DRY_RUN=1;             next ARGPARSE } if check_arg($arg, 'd', 'dry-run');

			# things that are assignments
			if (my $return = check_arg($arg, 'o', 'options-file')) {
				$DIR_TO    = $return ne "1"? $return:shift @args;
				next ARGPARSE;
			}
			if (my $return = check_arg($arg, 'f', 'from-dir')) {
				$DIR_FROM  = $return ne "1"? $return:shift @args;
				next ARGPARSE;
			}
			if (my $return = check_arg($arg, 'p', 'patch-dir')) {
				$DIR_PATCH = $return ne "1"? $return:shift @args;
				next ARGPARSE;
			}
			if (my $return = check_arg($arg, 't', 'to-dir')) {
				$DIR_TO    = $return ne "1"? $return:shift @args;
				next ARGPARSE;
			}
			do { print_help(); exit } if check_arg($arg, 'h', 'help');

			# misc other args
			if ($arg eq "--") {
				return (@return, @args);
			}
			if ($arg !~ /^-/) {
				return (@return, $arg, @args);
			}

			# otherwise, push onto the return stack
			push(@return, $arg);
		}
	}

	return @return;
}

# check an argument for match, return right side
# if it's --long=[something] or -v[something]
sub check_arg {
	my $arg   = shift;
	my $short = shift;
	my $long  = shift;

	if ($arg eq "-${short}" or $arg eq "-${long}" or $arg eq "--${long}") {
		return 1;
	} elsif ($arg =~ /^-${short}(.+)$/ or $arg =~ /^-?-${long}=(.+)$/) {
		return $1;
	}
	return;
}

# print out help (and maybe exit)
sub print_help {
	my ($handle, $message, $error);
	if (ref $_ eq "GLOB") {
		$handle = shift;
	} else {
		$handle = IO::Handle->new();
		$handle->fdopen(fileno(STDOUT), "w") or die "cannot open STDOUT for writing: $!\n";
	};
	$error    = shift;
	$message  = "Usage: $0 [options] [files_or_directories]\n";
	$message .= "ERROR: " . $error . "\n" if (defined $error);
	$message .= <<END;
	
Options:
  -v, --verbose      extra output
  -d, --dry-run      don't change any files
  -h, --help         this help
  -o, --options-file location of your .mssrc
                     (defaults to "~/.mssrc")

  -f, --from-dir     source directory
  -p, --patch-dir    patch directory
  -t, --to-dir       destination directory

END

	if (defined $error) {
		die $message;
	} else {
		print $handle $message;
	}

	return 1;
}

##### SPECIAL CASES #####

sub do_cxc {
	my $state = shift;
	my $key   = shift;

	if (patch_exists($key) =~ /\.create$/ and -f "${DIR_TO}/${key}") {
		my $patch_md5 = get_md5(patch_exists($key));
		my $to_md5    = get_md5("${DIR_TO}/${key}");

		if ($patch_md5 eq $to_md5) {
			# update the patch/file status
			$STATE_CURRENT->{$key}->[0] = get_time("${DIR_TO}/${key}") or die;
			$STATE_CURRENT->{$key}->[1] = get_md5("${DIR_TO}/${key}") or die;
			$STATE_CURRENT->{$key}->[4] = get_time(patch_exists($key)) or die;
			$STATE_CURRENT->{$key}->[5] = get_md5(patch_exists($key)) or die;
			return 1;
		}
	}
	error("$key: both the patch and destination file have changed for ${key} -- you must delete one or the other to resolve this conflict");
}

sub do_xxs {
	my $state = shift;
	my $key   = shift;

	if (patch_exists($key) =~ /\.create$/) {
		notice(patch_exists($key)." exists, but ${DIR_TO}/${key} does not.  Should I delete it from the patch directory too?");
		print "          `-> [Y/n]: ";
		chomp(my $input = <STDIN>);
		if ($input =~ /^y/i or $input eq "") {
			return &do_delete($state, $key);
		} else {
			notice("Patching ${DIR_TO}/${key}\n");
			return &do_patch($state, $key);
		}
	} else {
		my $file;
		$file = patch_exists($key);
		&warn("${file} is stale and is being deleted");
		return unlink($file);
	}
	return;
}

# to unchanged, from and patch changed
sub do_scc {
	my $state = shift;
	my $key   = shift;

	if ($COMMAND eq "update") {
		notice("$key has changed for FROM and PATCH, regenerating");
		return do_patch($state, $key);
	} else {
		error("do_scc: unhandled state: S:C:C on file $key");
	}
}

# ask a question and then run one sub or the other
# based on the response
sub do_srs {
	my $state = shift;
	my $key   = shift;

	notice("${DIR_FROM}/${key} ($state) has been deleted.  Should I delete it from the destination directory too?");
        print "          `-> [Y/n]: ";
	chomp(my $input = <STDIN>);
	if ($input =~ /^y/i or $input eq "") {
		return &do_delete($state, $key, '1');
	} else {
		return &do_create($state, $key);
	}
	return;
}

sub do_sxr {
	my $state = shift;
	my $key   = shift;

	#FIXME is this right?
	return do_delete($state, $key);
}

sub do_rxs {
	my $state = shift;
	my $key   = shift;

	if ($COMMAND eq "update") {
		return &do_patch($state, $key);
	} else {
		notice("${DIR_TO}/${key} ($state) has been deleted.  Should I delete it from the patch directory too?");
	        print "          `-> [Y/n]: ";
		chomp(my $input = <STDIN>);
		if ($input =~ /^y/i or $input eq "") {
			return &do_delete($state, $key);
		} else {
			return &do_patch($state, $key);
		}
		return;
	}
}

sub do_rss {
	my $state = shift;
	my $key   = shift;

	if ($COMMAND eq "update") {
		return &do_patch($state, $key);
	} else {
		notice("${DIR_TO}/${key} ($state) has been deleted.  Should I delete it from the patch directory too?");
	        print "          `-> [Y/n]: ";
		chomp(my $input = <STDIN>);
		if ($input =~ /^y/i or $input eq "") {
			return &do_delete($state, $key);
		} else {
			return &do_patch($state, $key);
		}
		return;
	}
}



