use Win32::File;
use Win32::FileSecurity;
use File::Copy;
use File::stat;
use Getopt::Long;

GetOptions(\%options, "RC|r=s", "Help|h=s", "LOG|l=s");
$rc_file = "syncsrv.rc" unless ($rc_file = $options{"RC"});
$interval = 30;
@srvs = ();
$log_level = 2; #1=errors, 2=warnings, intervals 3=everything
read_rc($rc_file, \@srvs);
$log = "syncsrv.log" unless ($log= $options{"LOG"});
open(LOG,">>$log"); 
print LOG "SyncSrv started: " . localtime(time()) . "\n";
print LOG "----------------------------------------------------\n";
while(1)
	{
	foreach $srv(@srvs)
		{
		($src, $dest) = split(/;/, $srv, 2);
		print "syncing: $src to $dest\n";
		print LOG "syncing: $src(". localtime(time). ")\n" 
		if($log_level >= 2);
		sync($src, $dest);
		print ("sleeping...");
		close LOG;
		open(LOG,">>$log"); 
		sleep ($interval);
		print("$interval\n");
		}
	}

sub sync
{
my $size= undef;
my $stat= undef;
my $src = shift;
my $dest= shift;
my $file=undef;
my $dos_src_path = undef;
my $dos_dest_path = undef;
my $attributes=undef;
#print ("src: $src dest: $dest\n");
print LOG "$src(" . localtime(time) . ")\n" if ($log_level >= 3);

if(!opendir(SRC, $src))
	{
 	warn "Can't open Dir: $src: $!";
	print LOG "OPEN DIR FAILURE: $src : $!\n" if ($log_level >= 1);
	return;
	}
my @src=readdir(SRC);
closedir (SRC);
foreach $file(@src)
	{
	next if(($file eq '.') || ($file eq '..'));
	if(!Win32::File::GetAttributes("$src/$file", $attributes))
		{
		warn "failed to stat $src/$file: $!";
		print LOG "STAT FAILED: $src/$file: $!\n" if($log_level >= 1);
		next;
		}
	$size = $stat->size if($stat = stat("$src/$file"));
	if(-d "$src/$file")
		{
		mkdir("$dest/$file", 0777) unless (-d "$dest/$file");
		sleep(3);
		if(!(-d "$dest/$file"))	
			{
			warn "Dest doesn't exist";
			print LOG "NON-EXISTANT: $dest/$file\n" if ($log_level >= 1);
			}
		sync("$src/$file", "$dest/$file");
		}
	elsif(($attributes & ARCHIVE) || !(-e "$dest/$file"))
		{
		print("src: $src/$file($size)....\n");
		if (acl_copy("$src/$file", "$dest/$file"))
			{
			print ("dest: $dest/$file Updated!\n");
			if($attributes & ARCHIVE)
				{
				Win32::File::SetAttributes("$src/$file", ($attributes^ARCHIVE))
				||
				warn "Failed to clear Archive bit for: $src/$file";
				}
			}
		else
			{
			print "dest: $dest/$file FAILED!\n";
			print LOG "dest: $dest/$file FAILED!\n" if ($log_level >= 1);
			}
		print ("sleeping...");	
		sleep(2);
		print ("2\n");	
		}
	}
}


sub read_rc
{
my $rc_file = shift;
my $srvs = shift;
open(RC, $rc_file);
my @entries = <RC>;
my ($e_type, $e_data, $entry)=undef;
close (RC);

foreach $entry (@entries)
	{
	($e_type, $e_data) = split(/=/,$entry, 2);
	if($e_type eq "srv")
		{
		chomp($e_data);
		push(@$srvs, $e_data);
		}
	elsif($e_type eq "log_level")
		{
		$log_level = $e_data;
		}
	elsif($e_type eq "interval")
		{
		$interval = $e_data;
		}
	}
}	
		
	
		
		
sub acl_copy
{
my $src = shift;
my $dest = shift;
my %acl_hash = {};
if(-e $src)
	{
	eval
		{
		Win32::FileSecurity::Get($src, \%acl_hash);
		copy($src, $dest,2048);
		Win32::FileSecurity::Set($dest, \%acl_hash);
		};
	return 1 unless ($@);
	print LOG "ERROR: $@\n";
	return -1;
	}
else{warn "$src doesn't exist!\n"; return -2;}
}
