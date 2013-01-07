#!/usr/bin/env perl
#
# Searches for hidden processes on Linux 2.4/2.6 kernels, Solaris
# 2.5-11, and MacOS 10.[45]. You do NOT need to be root to search for
# hidden processes (unlike the shell script previously posted).
#
# Jens-S. Vöckler <jens at isi dot edu>
#
# The software is provided "as is" and its author and his contributors
# disclaim all warranties with regard to this software including all
# implied warranties of merchantability and fitness. In no event shall
# the author or his contributors be liable for any special, direct,
# indirect, or consequential damages or any damages whatsoever resulting
# from loss of use, data or profits, whether in an action of contract,
# negligence or other tortious action, arising out of or in connection
# with the use or performance of this software.
#
use 5.005;			# relaxed
use strict;

# My philosophy: The less modules, the better the portability.
use Errno qw(EPERM ESRCH); 	# std module
use POSIX qw(uname _exit strftime); # std module
use File::Spec; 		# std module
use Fcntl;			# std module: import O_* constants

BEGIN {
    # attempt load non-standard modules in a fail-safe fashion, e.g. 
    # DO NOT fail here nor now, if the module cannot be found.
    eval "require Digest::MD5;"; 
    unless ( $@ ) {
	$main::has{'Digest::MD5'} = 1; 
	Digest::MD5->import() if Digest::MD5->can('import');
    }

    eval "require 'syscall.ph';"; 
    if ( $@ ) { 
	eval "require 'sys/syscall.ph';";
	if ( $@ ) { 
	    my $suggest = 'cd /usr/include && sudo h2ph '; 
	    $suggest .= ( lc($^O) eq 'linux' ? '-r -l .' : 
			  '* sys/* arpa/* netinet/*' );
	    die( "\nYour Perl installation is incomplete. Please run the ",
		 "following commands,\nwhich will typically require ",
		 "superuser privileges:\n\n\t$suggest\n\n", 
		 "Most recent problem:\n$@\n" ); 
	} else {
	    $main::has{'syscall'} = 1;
	}
    } else {
	$main::has{'syscall'} = 1; 
    }
}

our $VERSION = v0.8.9;
# 0.8.8 -> 0.8.9: 2009-10-09
# - crk dies on MacOS X (Darwin), fixing. Making syscall() more
#   friendly on Linux. For now, excluding Solaris from getsid checks. 
# - added static check for /usr/lib/?????.p2 directories (11 mio!). 
#   Due to slowness, only activated in "force force" mode. 
# - added sanity to session and process group id during crowdout. 
#
# 0.8.7 -> 0.8.8: ???
# - someone added getsid() checks via syscall() since getsid() is not 
#   part of Perl's POSIX module.
#
# 0.8.6 -> 0.8.7: 2008-08-20
# - bug report about zombies causing premature death
# - added trigger file check to tickle p-kit 
# - warn about possibility of false positives on busy systems
# - inform that you don't have to be root to run this script
# - added summary at end to let user know what this means
# - added exitcode to indicate good or bad. 
# - percentage progress bar during crowding now marked as comment
#
# 0.8.5 -> 0.8.6:
# - bug fix for broken atime information

sub unsupported(@) {
    die "Sorry, @_ is not supported.\n"; 
}

sub max {
    # purpose: find largest in arbitrary array of numbers
    # returns: the max
    #
    my $max = -1; 
    foreach my $n ( @_ ) {
	$max = $n if $n > $max;
    }
    $max;
}

sub busybox($) {
    # purpose: check load average on system
    # paramtr: $system (IN): system identifier
    # returns: 5 minute load average
    # 
    my $system = shift;
    local(*W); 

    my $loadavg = 0; 
    local $ENV{PATH} = '/bin:/usr/bin'; # temporarily safe PATH
    if ( open( W, "w|" ) ) {
	$_ = <W>;
	close W; 
	$loadavg = $1 if /load average: (\S+)/;
    }
    
    $loadavg;
}

sub linux_zombies {
    # purpose: collect all zombie processes, as old 2.6.9 kernels make problems
    # returns: list of zombie pids, possibly empty
    # systems: Linux, though any system that would support BSD-style ps commands
    #
    my @result = ();
    local(*PS); 

    local $ENV{PATH} = '/bin:/usr/bin'; # temporarily safe PATH
    if ( open( PS, "ps axo pid,stat|" ) ) {
	scalar <PS>;		# skip header
	while ( <PS> ) {
	    my ($pid,$state) = split ; 
	    push( @result, $pid ) if index($state,'Z') >= 0; 
	}
	close PS; 
    }

    @result;
}

sub linux_pids($$\$) {
    # purpose: collect all visible pids on sane Linux systems
    # paramtr: $system (IN): system identifier
    # paramtr: $release (IN): kernel version number
    # paramtr: $maxpid (IO): maximum process number
    # returns: array with known (visible) ids (process, clone, task)
    #
    my $system = shift;
    my $release = shift; 
    my $maxref = shift; 
    local(*DIR,*D);

    my %result = ();
    if ( substr($release,0,4) eq '2.6.' ) {
	# 2.6.* kernels only 
	my %zombies = map { $_ => 1 } linux_zombies();
	opendir( DIR, "/proc" ) || die "FATAL: opendir /proc: $!\n"; 
	foreach my $pid ( grep { /^\d+$/ } readdir(DIR) ) {
	    if ( opendir( D, "/proc/$pid/task" ) ) {
		foreach my $task ( grep { /^\d+$/ } readdir(D) ) {
		    $result{$task} = 1;
		}
		closedir D; 
	    } else {
		my $error = "$!"; 
		if ( -d "/proc/$pid/task" ) {
		    # bug fix for 2.6.9 kernels
		    warn "Warning: Reading /proc/$pid/task: $error (assuming zombie)\n"
			unless exists $zombies{$pid}; 
		    # FIXME: May this miss threads from the zombie?
		    $result{$pid} = 1; 
		} else {
		    die "FATAL: Reading /proc/$pid/task: $error\n"; 
		}
	    }
	}
	closedir DIR; 
    } elsif ( substr($release,0,4) eq '2.4.' ) {
	# 2.4.* kernels only -- clone-IDs as dot-PID
	opendir( DIR, "/proc" ) || die "FATAL: opendir /proc: $!\n"; 
	while ( defined ($_ = readdir(DIR)) ) {
	    $result{$1} = 1 if /^\.?(\d+)$/;
	}
	closedir DIR; 
    } else {
	unsupported($system,$release);
    }

    if ( open( PROC, "</proc/sys/kernel/pid_max" ) ) {
	chomp( $$maxref = <PROC> );
	close PROC;
	$$maxref = 65536 if ( ! $$maxref || $$maxref < 32768 ); 
    }

    %result;
}

sub solaris_pids($$\$) {
    # purpose: collect all visible pids on sane Solaris systems
    # paramtr: $system (IN): system identifier
    # paramtr: $release (IN): kernel version number
    # paramtr: $maxpid (IO): maximum process number
    # returns: array with known (visible) pids
    #
    my $system = shift;
    my $release = shift;
    my $maxref = shift; 
    local(*DIR); 

    my %result = ();
    if ( substr($release,0,2) eq '5.' &&
	 substr($release,2) > 4 && 
	 substr($release,2) <= 11 ) {
	# Solaris 2.5 .. Solaris 11
	opendir( DIR, "/proc" ) || die "FATAL: opendir /proc: $!\n"; 
	%result = map { $_ => 1 } grep { /^\d+$/ } readdir(DIR);
	closedir DIR; 
    } else {
	unsupported($system,$release);
    }

    $$maxref = max( 30000, max(keys %result) );	# hmmmm
    %result;
}

sub bsdish_pids($$\$) {
    # purpose: collect all visible pids on BSD-like systems (e.g. MacOS X)
    # paramtr: $system (IN): system identifier
    # paramtr: $release (IN): kernel version number
    # paramtr: $maxpid (IO): maximum process number
    # returns: array with known (visible) pids
    #
    my $system = shift;
    my $release = shift; 
    my $maxref = shift; 
    local(*PS); 

    my %result = ();
    local $ENV{PATH} = '/bin:/usr/bin'; # temporarily safe PATH
    if ( open( PS, "ps ax|" ) ) {
	scalar <PS>;		# skip header
	while ( <PS> ) {
	    $result{$1} = 1 if /^\s*(\d+)\s/; 
	}
	close PS; 
    } else {
	unsupported($system,$release);
    }

    $$maxref = max( 32768, max(keys %result) );	# for now
    $$maxref = max( $$maxref, 99999 ) if $system eq 'darwin'; # is that true?
    %result;
}

sub sysvish_pids($$\$) {
    # purpose: collect all visible pids on System-V-like systems from ps -ef
    # paramtr: $system (IN): operating system identifier
    # paramtr: $release (IN): kernel version number
    # paramtr: $maxpid (IO): maximum process number
    # returns: array with known (visible) pids
    #
    my $system = shift;
    my $release = shift; 
    my $maxref = shift; 
    local(*PS); 

    my %result = ();
    local $ENV{PATH} = '/bin:/usr/bin'; # temporarily safe PATH
    if ( open( PS, "ps -ef|" ) ) {
	scalar <PS>;		# skip header
	while ( <PS> ) {
	    $result{$1} = 1 if /^\s*\S+\s+(\d+)\s/; 
	}
	close PS; 
    } else {
	unsupported($system,$release);
    }

    $$maxref = max( 32768, max(keys %result) );	# for now
    %result;
}

sub scramble($) {
    # purpose: create a scrambled list of all pids to check. This is in case
    # a smart rootkit feels us "approaching" and decides to hide temporarily. 
    # paramtr: $maxpid (IN): last pid
    # returns: list of pids to check
    #
    my $maxpid = shift; 
    my @result = 1 .. $maxpid; 

    # fisher yates shuffle
    for ( my $i = @result; --$i ; ) {
	my $j = int rand($i+1);
	next if $i == $j;
	@result[$i,$j] = @result[$j,$i];
    }

    @result;
}


sub check_loadavg($\%) {
    # systems: Linux only 
    # purpose: compare known ids to reported ids
    # paramtr: $system (IN): operating system identifier
    # paramtr: $visible (IN): reference to set of known [cpt]id
    # returns: number of instances found, -1 for unknown result 
    # inspired by .security-projects.com
    #
    my $system = shift; 
    my $visref = shift; 
    my $n = scalar( keys %{$visref} ); 
    local(*P);

    my $result = -1; 		# unknown
    if ( open( P, "</proc/loadavg" ) ) { 
	warn "# comparing process count\n"; 
	# OK, we could open loadavg successfully, so this is likely a linux
	my @x = split ' ', <P>;
	close P; 

	@x = split /\//, $x[3]; 
	$result = $x[1] - $n; 
	warn "Warning: There may be $result processes hiding (thumb estimate)\n"
	    if $result; 
    } else {
	# only warn, if this is Linux and the open() above failed
	warn "Warning: While reading /proc/loadavg: $! (strange)\n"
	    if $system eq 'linux';
    }
    $result;
}

sub check_links($) {
    # systems: !MacOS
    # purpose: check the link count on some well-known system directories
    # paramtr: $system (IN): operating system identifier
    # returns: number of instances found. 
    # idea by: CERN CERT
    #
    my $system = shift;
    return -1 if $system eq 'darwin'; 
    local(*DIR); 

    my $result = 0; 
    warn "# compare a few link counts\n"; 

    foreach my $dir ( qw(/ /etc /tmp /var /usr /bin /sbin /var/tmp /dev/shm /usr/share /usr/include /usr/lib ) ) {
	my @stat = lstat($dir); 
	if ( @stat && -d _ && opendir( DIR, $dir ) ) {
	    my @subdir = grep { lstat($_), -d _ } 
	                 map { File::Spec->catdir($dir,$_) } 
	                 readdir(DIR); 
	    closedir DIR; 
	    if ( @subdir != $stat[3] ) {
		warn( "Warning: $dir has mis-matched link count: ",
		      $stat[3], ' != ', scalar(@subdir), "\n" ); 
		# TODO: add more info what mis-match we perceive
		++$result; 
	    }
	}
    }
    $result; 
}

# undef, fifo, char dev, undef, directory, xenix named pipe, block dev, undef
# regular file, undef, symlink, undef, socket, sun door, sun port, undef
my @ifmt_str = qw(? p c ? d X b ?    - ? l ? s D P ?); 

sub mode_str($) {
    # purpose: transform a file mode into ls-la-like permission string
    # paramtr: $mode (IN): file mode
    # returns: formatted permissions string
    # 
    my $mode = shift;
   
    join( '', 
	  # FIXME: I really shouldn't be hard-coding these constants
	  $ifmt_str[ ( $mode & 0xF000 ) >> 12 ], 
	  $mode & 0400 ? 'r' : '-',
	  $mode & 0200 ? 'w' : '-',
	  $mode & 0100 ? 
	  ( $mode & 04000 ? 's' : 'x' ) : 
	  ( $mode & 04000 ? 'S' : '-' ),

	  $mode & 040 ? 'r' : '-',
	  $mode & 020 ? 'w' : '-',
	  $mode & 010 ? 
	  ( $mode & 02000 ? 's' : 'x' ) :
	  ( $mode & 02000 ? 'S' : '-' ),

	  $mode & 04 ? 'r' : '-',
	  $mode & 02 ? 'w' : '-',
	  $mode & 01 ? 
	  ( $mode & 01000 ? 't' : 'x' ) :
	  ( $mode & 01000 ? 'T' : '-' ) );
}

sub fmt_stat($$@) {
    # purpose: format contents of stat() call
    # paramtr: $fn (IN): file name that was stat() called
    #          $md5sum (IN): hex digest of MD5 sum (of regular), or undef
    #          @stat (IN): result record from stat() call
    # returns: formatted string with contents
    #
    my $fn = shift; 
    my $md5sum = shift; 
    my @stat = @_; 

    # FIXME: I am just assuming that MAJOR/MINOR are at byte boundaries
    my $dev = sprintf "%d:%u", $stat[0]/256, ( abs($stat[0]) & 255 ); 

    my $uid = getpwuid($stat[4]) || sprintf( "uid(%u)", $stat[4]);
    my $gid = getgrgid($stat[5]) || sprintf( "gid(%u)", $stat[5]); 
    my $atime = strftime( "%Y-%m-%dT%H:%M:%SZ", gmtime($stat[8])); 
    my $mtime = strftime( "%Y-%m-%dT%H:%M:%SZ", gmtime($stat[9])); 
    my $ctime = strftime( "%Y-%m-%dT%H:%M:%SZ", gmtime($stat[10])); 
    
    sprintf( '%7s %10u %10s %8s %8s %8u %20s %20s %20s %32s %s',
	     $dev,		    # st_dev
	     $stat[1],		    # st_inode
	     mode_str($stat[2]),    # st_mode
	     $uid, $gid,	    # st_uid st_gid
	     $stat[7],		    # st_size
	     $mtime, $ctime,	    # st_mtime st_ctime
	     $atime,		    # st_atime
	     $md5sum || '',	    # md5sum
	     $fn );
}

sub fmt_title() {
    sprintf( '%7s %10s %10s %8s %8s %8s %20s %20s %20s %32s %s',
	     'DEVICE', 'INODE', 'FILEMODE', 'USER', 'GROUP', 'FILESIZE', 
	     'LAST_MODIFICATION', 'LAST_INODE_CHANGE', 'LAST_ACCESS_TIME', 
	     'MD5SUM', 'LOCATION' );
}

sub check_directory($) {
    # systems: POSIX
    # purpose: look at a single, specific well-known location
    # paramtr: $dir (IN): name of directory to check for
    # returns: 0 if not found, 1 if found
    # idea by: CERN CERT
    #
    my $dir = shift; 
    my $result = 0; 

    my ($base,$fn,$md5sum);
    if ( opendir( DIR, $dir ) ) {
	warn( "Warning: Found well-known location $dir\n" );
	warn( fmt_title(), "\n" );
	++$result;

	while ( defined ($base = readdir(DIR)) ) {
	    next if $base eq '..';
	    $fn = File::Spec->catfile( $dir, $base );
	    undef $md5sum; 
	    my @stat = lstat($fn);

	    if ( -l _ ) {
		$fn .= ' -> ' . readlink($fn);
	    } elsif ( exists $main::has{'Digest::MD5'} &&
		      -f _ && open( F, "<$fn" ) ) {
		my $ctx = Digest::MD5->new; 
		$ctx->addfile(*F); 
		close F; 
		$md5sum = $ctx->hexdigest; 
	    }
		
	    warn( fmt_stat( $fn, $md5sum, @stat ), "\n" );
	}
	closedir DIR; 
    }

    $result;
}

sub check_usr_lib($) {
    # systems: POSIX
    # purpose: look at a single, specific well-known wildcard location
    # paramtr: $system (IN): operating system identifier
    # returns: number of matches found
    # idea by: CERN CERT
    #
    my $system = shift; 

    my $result = 0; 
    warn "# checking for /usr/lib/?????.p2 directories (very slow)\n"; 

    # since the rootkit will most definitely hide itself from dirent calls, 
    # we will have to check 11 million permutations (sigh)
    my (@range,$dir) = ( 'a' .. 'z' ); 
    
    print STDERR "# "; 
    foreach my $i ( @range ) {
	print STDERR "$i"; 
	foreach my $j ( @range ) {
	    foreach my $k ( @range ) {
		foreach my $l ( @range ) {
		    foreach my $m ( @range ) { 
			$dir = '/usr/lib/' . $i . $j . $k . $l . $m . '.pl2'; 
			$result += check_directory($dir); 
		    }
		}
	    }
	}
    }
    print STDERR "\n"; 

    $result; 
}

sub check_known($) {
    # systems: POSIX
    # purpose: look at well-known locations
    # paramtr: $system (IN): operating system identifier
    # returns: number of instances found. 
    # idea by: CERN CERT
    #
    my $system = shift;
    local(*DIR,*F); 

    my $result = 0; 
    warn "# search well-known locations\n"; 

    my ($dir);
    while ( defined ($dir = <DATA>) ) {
	chomp($dir); 

	if ( index($dir,'*') >= 0 || index($dir,'?') >= 0 ) {
	    warn "Warning: asterisk wildcard in \"$dir\" not supported, skipping\n"; 
	    next; 
	}

	$result += check_directory($dir); 
    }

    $result; 
}

sub check_trigger($) {
    # purpose: special check for phalanx rootkit using trigger file
    # paramtr: $system (IN): operating system identifier
    # returns: -1 (unknown), 0 (not found), 1 (found)
    # idea by: CERN CERT
    #
    my $system = shift; 
    local(*F1,*F2,*F3);

    my $result = -1; 
    if ( -d '/dev/shm' ) {
	# only on systems that have a /dev/shm directory
	warn "# search well-known triggers\n"; 
	
	my $trigger = '/dev/shm/....'; 
	if ( ! sysopen( F1, $trigger, O_RDWR ) ) {
	    if ( sysopen( F2, $trigger, ( O_RDWR | O_CREAT | O_TRUNC ), 0600 ) ) {
		if ( open( F3, "</dev/shm/khubd.injected" ) ) {
		    $result = unlink($trigger); 
		    close F3; 
		} else {
		    local(*SHM); 
		    if ( opendir( SHM, "/dev/shm" ) ) {
			$result = 0; 
			foreach my $base ( grep { /\.injected$/ } readdir(SHM) ) {
			    warn( "Warning: Found /dev/shm/$base\n" );
			    ++$result;
			}
			closedir SHM;
		    }

		    unlink($trigger);
		}
		close F2;
	    }
	} else {
	    warn( "Warning: Found $trigger\n" );
	    $result = 1;
	    close F1;
	}

	warn "Warning: Looks like there is a phalanx2 rootkit on your system\n"
	    if $result > 0;
    }

    $result; 
}

sub cmdline($) {
    # purpose: read the output of the cmdline proc file and split
    # paramtr: $fn (IN): which file to read (and split)
    # returns: the output, or a message that the file was not readable
    # systems: Linux only 
    # 
    my $fn = shift;
    local(*F); 
    my $result;

    if ( open( F, "<$fn" ) ) {
	$result = <F>;
	close F; 
	$result =~ tr[\000][ ];	# change all NUL to SPACE
    } else {
	$result = "[open $fn: $!]";
    }
    $result;
}

sub check_signal($\@\%\%) {
    # systems: POSIX
    # purpose: exhaustively search pid space, and determine those pid that 
    #          react to signal, yet which are not conventionally visible.
    # paramtr: $system (IN): operating system identifier
    # paramtr: @pids (IN): scrambled pid space to check
    # paramtr: $visible (IN): reference to set of known [cpt]id
    # paramtr: $blocked (--): reference to set of blocked but empty [cpt]id
    # returns: number of instances found. 
    # idea by: CERN CERT
    #
    my $system = shift;
    my $pidref = shift;		# reference to array
    my $visible = shift; 	# reference to hash
    my $blocked = shift; 	# reference to hash

    my $result = 0; 
    warn "# search using signals\n"; 

    foreach my $pid ( @{$pidref} ) {
	if ( kill( 0, $pid ) == 1 || $!{EPERM} ) {
	    # $pid said "who's there?"
	    unless ( exists $visible->{$pid} ) {
		my $msg = "Warning: pid $pid is hidden";
		$msg .= ': ' . cmdline("/proc/$pid/cmdline")
		    if $system eq 'linux';
		warn( "$msg\n" );
		++$result;
	    }
	} elsif ( $!{ESRCH} ) {
	    # no reaction from $pid -- this is OK
	} else {
	    # what's this?
	    die "FATAL: Unknown problem with pid $pid: $!\n"; 
	}
    }

    $result; 
}


sub check_getsid($\@\%\%) {
    # systems: POSIX
    # purpose: exhaustively search pid space, and determine those pid that
    #          react to getsid, yet which are not conventionally visible.
    # paramtr: $system (IN): operating system identifier
    # paramtr: @pids (IN): scrambled pid space to check
    # paramtr: $visible (IO): reference to set of known [cpt]id, adds pgrp
    # paramtr: $blocked (IO): reference to set of blocked but empty [cpt]id
    # returns: number of instances found.
    # idea by: .security-projects.com
    #
    my $system = shift;
    my $pidref = shift;         # reference to array
    my $visible = shift;        # reference to hash
    my $blocked = shift; 	# reference to hash

    my $arch = `uname -p 2>> /dev/null`; 
    chomp $arch;

    # FIXME: maybe more verbose since this is the last line of defense? 
    return -1 unless exists $main::has{'syscall'}; 

    # IFF Linux AND syscall number is unknown THEN try to figure it out
    # FIXME: This is admittedly fragile and may not work on old Linuxes. 
    if ( ! defined &SYS_getsid && $system eq 'linux' ) {
	my $fn = ( index($arch,'64') >= 0 ?
		   '/usr/include/asm/unistd_64.h' : 
		   '/usr/include/asm/unistd_32.h' ); 
	if ( open( H, "<$fn" ) ) {
	    while ( <H> ) { 
		next unless /^\#define\s+__NR_getsid\s+(\d+)/; 
		my $syscallnr = $1; 
		eval "sub SYS_getsid () { $syscallnr; }" if $syscallnr > 0;
		last; 
	    }
	    close H; 
	}
    }

    die( "FATAL: Unable to dereference SYS_getsid from your Perl-compiled system\n",
	 "headers. Your admin may have forgotten to translate header files, or\n",
	 "update them to the latest kernel and libc installations. Typically\n",
	 "one needs to run:\n\n",
	 "\tcd /usr/include && sudo h2ph -r -l .\n\n" )
	unless ( defined &SYS_getsid && $system ne 'sunos' ||
		 defined &SYS_pgrpsys && $system eq 'sunos' ); 

    my $result = 0;
    warn "# search using getsid (via syscall)\n";

    foreach my $pid ( @{$pidref} ) {
        # say "gimme your process session id via syscall" to $pid
	# WARNING: Be VERY careful with syscall() on SPARC!
	$pid += 0;
	my $sid = ( $system eq 'sunos' ? 
		    syscall( &SYS_pgrpsys, 2, $pid+0 ) : 
		    syscall( &SYS_getsid, $pid+0 ) );
        if ( $sid >= 1 ) {
            # $pid actually answered
            if ( exists $visible->{$pid} ) {
                # record session id for valid processes
		$blocked->{$sid} = $pid unless exists $visible->{$sid}; 
                $visible->{$pid} = $sid;
            } else {
                my $msg = "Warning: pid $pid is hidden";
		$msg .= ': ' . cmdline("/proc/$pid/cmdline")
		    if $system eq 'linux';
                warn( "$msg\n" );
                ++$result;
            }
        }
    }

    $result;
}

sub check_getpgid($\@\%\%) {
    # systems: POSIX
    # purpose: exhaustively search pid space, and determine those pid that 
    #          react to getpgid, yet which are not conventionally visible.
    # paramtr: $system (IN): operating system identifier
    # paramtr: @pids (IN): scrambled pid space to check
    # paramtr: $visible (IO): reference to set of known [cpt]id, adds pgrp
    # paramtr: $blocked (IO): reference to set of blocked but empty [cpt]id
    # returns: number of instances found. 
    # idea by: .security-projects.com
    #
    my $system = shift;
    my $pidref = shift;		# reference to array
    my $visible = shift; 	# reference to hash
    my $blocked = shift; 	# reference to hash

    my $result = 0; 
    warn "# search using getpgid\n"; 

    foreach my $pid ( @{$pidref} ) {
	# say "gimme your process group id" to $pid
	my $pgrp = getpgrp($pid); 
	if ( $pgrp >= 1 ) {
	    # $pid actually answered
	    if ( exists $visible->{$pid} ) {
		# record process group id for valid processes
		$blocked->{$pgrp} = $pid unless exists $visible->{$pgrp}; 
		$visible->{$pid} = $pgrp; 
	    } else {
		my $msg = "Warning: pid $pid is hidden";
		$msg .= ': ' . cmdline("/proc/$pid/cmdline")
		    if $system eq 'linux';
		warn( "$msg\n" );
		++$result;
	    }
	}
    }

    $result; 
}

sub check_reading($\@\%\%) {
    # systems: Linux and Solaris only 
    # purpose: try reading a file from the /proc subdir in pid space.
    # paramtr: $system (IN): operating system identifier
    # paramtr: @pids (IN): scrambled pid space to check
    # paramtr: $visible (IN): reference to set of known [cpt]id
    # paramtr: $blocked (--): reference to set of blocked but empty [cpt]id
    # returns: number of instances found. 
    # idea by: mine, I think
    #
    my $system = shift;
    my $pidref = shift;		# reference to array
    my $visible = shift; 	# reference to hash
    my $blocked = shift; 	# reference to hash
    my $result = -1; 		# unknown result

    if ( $system eq 'linux' || $system eq 'sunos' ) {
	$result = 0; 
	local(*P); 
	warn "# search using reading\n"; 

	foreach my $pid ( @{$pidref} ) {
	    # say "tell me who you are" to $pid
	    my $fn = ( $system eq 'linux' ? 
		       "/proc/$pid/cmdline" :
		       "/proc/$pid/psinfo" );
	    if ( open( P, "<$fn" ) ) {
		# $pid actually answered has a file we can read
		close P;
		unless ( exists $visible->{$pid} ) {
		    my $msg = "Warning: pid $pid is hidden"; 
		    $msg .= ': ' . cmdline($fn) if $system eq 'linux';
		    warn( "$msg\n" );
		    ++$result;
		}
	    }
	}
    }

    $result; 
}

sub check_crowdout($$\%\%) {
    # systems: some
    # purpose: exhaustively search pid space by crowding out all pids, hoping to
    #          snare suspicious holes in the id space that appear unattainable.
    # paramtr: $system (IN): operating system identifier
    # paramtr: $maxpid (IN): maximum process number to look for
    # paramtr: $visible (IN): reference to set of known [cpt]id
    # paramtr: $blocked (IN): reference to set of blocked but empty [cpt]id
    # returns: number of instances found. 
    # idea by: .security-projects.com
    #
    my $system = shift;
    my $maxpid = shift;
    my $visible = shift; 	# reference to hash!
    my $blocked = shift; 	# reference to hash
    local (*R); 

    return -1 if $system eq 'darwin'; # does not work on MacOS X

    my $result = 0; 
    warn "# search using crowding (slow and unreliable, but may offer clues)\n"; 

    print STDERR "# "; 
    my %space = (); 
    for ( my $i=scalar(keys %{$visible}); $i < $maxpid; ++$i ) {
	my $pid = fork();	# Dang, I wish I had vfork in Perl
	if ( ! defined $pid ) {
	    warn "\n# seen $!, stopping crowding (this is odd)\n"; 
	    last; 
	} elsif ( $pid ) {
	    # parent
	    my $child = waitpid($pid,0); 
	    $space{$child} = 1 if ( defined $child && $child == $pid );
	    warn "Something odd happened with PID $child\n" 
		unless $? >> 8 == 42; 
	} else {
	    # child
	    POSIX::_exit(42);	# see "man vfork"
	}
	
	unless ( $i & 1023 ) {
	    printf STDERR "%.0f%%.. ", $i * 100.0 / $maxpid;
	}
    }
    print STDERR "100%\n"; 

    # add-on: If a session-id or pgroup-id is not used by a pid of the same 
    # value, this pid slot will still not be allocated to new processes. 
    my %pgrp = map { $_ => 1 } values %{$visible}; 

    # The first 300 pids are never allocated to users on 2.6 kernels?
    my $start = ( $system eq 'linux' ? 300 : 1 );
    for ( my $pid=$start; $pid < $maxpid; ++$pid ) {
	if ( ! exists $space{$pid} && 
	     ! exists $visible->{$pid} && 
	     ! exists $pgrp{$pid} ) {
	    print STDERR "I was unable to obtain pid $pid"; 
	    if ( exists $blocked->{$pid} ) { 
		# A session id and a process group id will block a slot
		# in the process table (when the founder had exited). 
		print STDERR ' (OK; blocked by session or process group id)'; 
	    } else {
		++$result; 
		if ( open( R, "</proc/$pid/cmdline" ) ) {
		    my @x = split( /\000/, scalar <R> ); 
		    close R; 
		    print STDERR ": @x (did you start this later?)"; 
		} else {
		    print STDERR ' (transient process?)'; 
		}
	    }
	    print STDERR "\n"; 
	}
    }

    $result;
}

#
# --- main ------------------------------------------------------
#

# system, kernel version
my ($system,$release);
($system,undef,$release) = map { lc($_) } POSIX::uname();

# some start-up information
my @msg = ( 'Info: Comment lines start with a hash (#) character.' ); 
push( @msg, 'Info: Your systems appears busy, so expect false positives.' )
    if busybox($system) > 0.2;
push( @msg, 'Info: You do not need to be root to run this script.' )
    if $> == 0; 
print STDERR "\n", join("\n",@msg), "\n\n";

# determine all visible thingies that have a pid (processes, clones, tasks).  
my $maxpid = 65536;
my %visible = (); 
my %blocked = (); 
if ( $system eq 'linux' ) {
    %visible = linux_pids($system,$release,$maxpid); 
} elsif ( $system eq 'sunos' ) {
    %visible = solaris_pids($system,$release,$maxpid); 
} elsif ( $system eq 'darwin' ) {
    %visible = bsdish_pids($system,$release,$maxpid); 
} else {
    unsupported($system,$release);
}

# any CLI argument will print this debugging line
warn( "# Found the following visible (unsuspicious) processes: ",
      "@{[sort { $a <=> $b } keys %visible]}\n") if @ARGV; 
my @pidspace = scramble($maxpid); # 1 .. $maxpid

my $sum = 0;
my $rc=check_loadavg($system,%visible);		# Linux
$sum += $rc if $rc > 0;
$rc=check_links($system);			# all
$sum += $rc if $rc > 0;
$rc=check_known($system);			# all
$sum += $rc if $rc > 0;
$rc=check_trigger($system);			# Linux, I think
$sum += $rc if $rc > 0;
$rc=check_signal($system,@pidspace,%visible,%blocked);	# all
$sum += $rc if $rc > 0;
$rc=check_getsid($system,@pidspace,%visible,%blocked);   # not Solaris
$sum += $rc if $rc > 0;
$rc=check_getpgid($system,@pidspace,%visible,%blocked);	# all
$sum += $rc if $rc > 0;
$rc=check_reading($system,@pidspace,%visible,%blocked);	# Linux+Solaris
$sum += $rc if $rc > 0;
if ( $ARGV[0] eq 'force' ) {
    $rc=check_crowdout($system,$maxpid,%visible,%blocked); # !MacOS
    $sum += $rc if $rc > 0;
    if ( $ARGV[1] eq 'force' ) { 
	$rc=check_usr_lib($system);	# all
	$sum += $rc if $rc > 0;
    }
}

print "\nSUMMARY\n"; 
if ( $sum == 0 ) {
    # didn't find anything, but this does not mean anything, either
    print << "EOF";

Good, I did not find anything suspicous. However, please keep in mind
that my set of checks is limited. Other rootkits, or an evolved version,
could be eluding these checks.

EOF
} else {
    # did find something: Either rootkit or false positive
    print << "EOF";

Bad news: $sum suspicious activities. While there is a chance that some of
these activities are false positives, you should investigate each instance. 
Often, re-running will show different pids for false positives whereas 
rootkits tend to keep their pid constant. Additionally, certain session-id
scenarios are a known source of constant pid false positives.

EOF
}

# tell via exit code (e.g. to automatic workflows)
exit( $sum > 0 ? 1 : 0 );

__DATA__
/etc/khubd.p2
/etc/lolzz.p2
/dev/nu11
/tmp/pwned
