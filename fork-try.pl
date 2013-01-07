### Win32 alternatives to fork
################################################

$cmd = "notepad.exe";
#$args = "C:\\ERROR.TXT";
$args = "C:\\PROSR1.TXT";

### Win32::Spawn
# use Win32::Process;

$command = "C:\\WINNT\\system32\\$cmd"; # full path
Win32::Spawn($command, "$cmd $args", $pid) or die $!;
print "[$pid $command $cmd $args]\n";

### system("start ...") (no pid)

$res = system("start $cmd $args");
print "res: $res\n";

### Win32::CreateProcess (no pid)

if ($^O eq "MSWin32") {
    use Win32::Process;
    use Win32;
    sub ErrorReport{
	print Win32::FormatMessage( Win32::GetLastError() );
    }
}

if ($^O eq "MSWin32") {
  $daemon_loc =~ s/\//\\/g;
  my $perlpath =
     "D:\\Apps\\Perl\\5.005\\bin\\MSWin32-x86-object\\perl.exe";
  my $perlline = "perl $cmdline";
  Win32::Process::Create($ProcessObj,
 	      $perlpath,
		   $perlline,
		   0,
		   NORMAL_PRIORITY_CLASS,
		   $daemon_loc); 
#|| die ErrorReport();
  $ProcessObj->Suspend();
  $ProcessObj->Resume();
  $ProcessObj->Wait(INFINITE);
}

