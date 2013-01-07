
use Win32::Semaphore;

Win32::Semaphore::Create ($SemaphoreObj, 1, 0, "SemaphoreName") || die "Cannot create semaphore: $!";
#  1,
#  0,
#  "SemaphoreName")  | die "Cannot create semaphore: $!";

if ($SemaphoreObj->Wait (INFINITE)) {

  # Access to the shared resource and do something here

  print ("The semaphore has been taken!\n");
  $SemaphoreObj->Release (1, $LastCount);
  print ("The semaphore has been released.\n");
} else {
  print ("Cannot access the semaphore\n");
}
