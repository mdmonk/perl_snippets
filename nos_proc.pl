use Win32::Process;
$i=0;
@pgm_nm=("c:\\windows\\calc.exe", "c:\\windows\\notepad.exe", "c:\\windows\\winipcfg.exe");
while ($i < @pgm_nm) {
   Win32::Process::Create (
      $ProcessObj,
      $pgm_nm[$i],
      "",
      0,
      DETACHED_PROCESS,
      ".") || die "Cannot create the process: $!";

   $ProcessObj->SetPriorityClass (NORMAL_PRIORITY_CLASS) ||
      die "Unable to set priority: $!";
   $i++;
}
# sleep(3);
# $ProcessObj->Wait (INFINITE);
print "calc program exited. Bye!\n\n";

