###########################################################
# Speed.pl
#
###########################################################
use Win32;
use Win32::API;
use Benchmark;
use Win32::NetAdmin;

$GetTickCount =
  new Win32::API(
		 'KERNEL32',
		 'GetTickCount',
		 [],
		 'N'
		);

$GetShortPathName =
  new Win32::API(
		 'KERNEL32',
		 'GetShortPathName',
		 [qw/P P N/],
		 'N'
		);

$NetGetDCName =
  new Win32::API(
		 Win32::IsWinNT() ? 'NETAPI32' : 'RADMIN32',
		 'NetGetDCName',
		 [qw(P P P)],
		 'N'
		);

$NetApiBufferFree =
  new Win32::API(
		 Win32::IsWinNT() ? 'NETAPI32' : 'RADMIN32',
		 'NetApiBufferFree',
		 ['N'],
		 'N'
		);

$lpWideCharToMultiByte =
  new Win32::API(
		 "kernel32",
		 "WideCharToMultiByte",
		 # CodePage, dwFlags = 0, lpWideCharStr, cchWideChar = -1, 
		 # lpMultiByteStr, cchMultiByte, lpDefaultChar = 0, lpUsedDefaultChar = 0
		 [qw(N N N N P N P P)],
		 # Note the 'N' for lpWideCharStr 
		 # (this is used for pointers alloced by previous calls)
		 'N'
		);

$MultiByteToWideChar =
  new Win32::API(
		 "kernel32",
		 "MultiByteToWideChar",
		 # CodePage = CP_OEMCP, dwFlags = 0, lpMultiByteStr, cbMultiByte,
		 # lpWideCharStr, cchWideChar
		 [qw(N N P N P N)],
		 'N'
		);

$LongName = 'C:\Program Files';
$ShortName = ' ' x 128;

print 'NetGetDCName' . '-' x 50 . "\n";
timethese(1000,
	  {
	   'Win32::NetAdmin (GetDomainController)' => 'Win32::NetAdmin::GetDomainController(q(), q(CISCO_MAIN), $name)',
	   'Win32::API (NetGetDCName)' => 'GetDCName(q(), q(CISCO_MAIN))',
	  }
	 );

print "\nGetShortPathName" . '-' x 50 . "\n";
timethese(50000,
	  {
	   'Win32 (GetShortPathName)' => 'Win32::GetShortPathName($LongName)',
	   'Win32::API (GetShortPathName)' => '$GetShortPathName->Call($LongName, $ShortName, 128)',
	  }
	 );

print "\nGetTickCount" . '-' x 50 . "\n";
timethese(2000000,
	  {
	   'Win32 (GetTickCount)' => 'Win32::GetTickCount()',
	   'Win32::API (GetTickCount)' => '$GetTickCount->Call()'
	  }
	 );


sub GetDCName ($$) {
  my $server = _string_to_unicode("$_[0]\0");
  my $domain = _string_to_unicode("$_[1]\0");
  my $ptr_dc = DWORD;

  my $Error = $NetGetDCName->Call(
    $server,
    $domain,
    $ptr_dc
  );
  $Error and return $! = $^E;

  $ptr_dc = unpack 'L', $ptr_dc;
  my $dc = _unicodeptr_to_string($ptr_dc);
  $NetApiBufferFree->Call($ptr_dc);

  return $dc;
}

sub _ptr_to_string ($;$) {
  my $format = @_ == 2 ? "P$_[1]" : "p";
  return unpack($format, pack("L", shift));
}

sub _unicodeptr_to_string {
  my $UnicodePtr = shift;
  my $BufferSize = 1; # 1 byte for the null
  my $ptrTemp    = $UnicodePtr;

  while (_ptr_to_string($ptrTemp, 2) ne "\0\0") {
    $ptrTemp += 2;
    $BufferSize += 2;
  }
  my $Buffer = "\0" x $BufferSize;

  my $Length = $lpWideCharToMultiByte->Call(
    CP_OEMCP,
    0,
    $UnicodePtr,
    -1,
    $Buffer,
    $BufferSize,
    0,
    0
  );
  return substr($Buffer, 0, $Length - 1);
}

sub _string_to_unicode {
  my $String = shift;
  my $Buffer = " " x (2 * length($String));

  $MultiByteToWideChar->Call(
    CP_OEMCP,
    0,
    $String,
    length($String),
    $Buffer,
    length($Buffer)
  );
  return $Buffer;
}
