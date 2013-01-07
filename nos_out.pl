use Win32;

($login_name) = Win32::LoginName;
&Error;

($perl_version) = Win32::PerlVersion;
&Error;

($fs_type) = Win32::FsType;
&Error;

($string, $major, $minor, $build, $id) = Win32::GetOSVersion;
&Error;

my ($os) = 'unknown';
if ($id == 1) {
  $os = 'Windows 95';
} elsif ($id == 2) {
  $os = 'Windows NT';
} elsif ($id == 0) {
  $os = 'Generic Win32';
}

open (MYFILE, "> output15.log");
&Error;
print MYFILE "Login Name:          $login_name\n";
print MYFILE "Perl Version:        $perl_version\n";
print MYFILE "FS Type:             $fs_type\n";
print MYFILE "Operating System:    $os\n";
print MYFILE "OS Version:          $major.$minor\n";
print MYFILE "OS Build:            $build\n";

close (MYFILE);

print ("\nGo ahead to review the outputs saved in output15.log.\n");
Win32::Spawn ("c:\\windows\\notepad.exe", "notepad output15.log", $pid);
&Error;

sub Error {
  print Win32::FormatMessage (Win32::GetLastError());
}
