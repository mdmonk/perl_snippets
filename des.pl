
##############################################
# Author: Amine Moulay Ramdane
# Date: 15 June 1998
#
# A small example that demonstrate the use of
# crypt(),des_ecb_encrypt() and des_ecb_decrypt()
#
#  Enjoy! 
###############################################

use Win32::DES;
use Win32::Console;

sub passwd {
my($password) = shift;
my($username) = "";
print("\nEnter your username: ");
while(1) {
  my($key) = $Console->InputChar(1) || die "Error reading character";
  if ($key ge "!" and $key le "~") { # ! to ~ legal
    $username .= $key;
    print("$key");
  } elsif (($key eq "\t" || $key eq "\r") && length($username) > 0) { #Tab or Enter
    print "\n";
    last;
  } elsif ($key eq "\b") { # ^H/backspace
    print "\b \b";
    chop $username;
  } elsif ($key eq "\cu") { # ^U/clearline
    print "\b \b" x length $username;
    $username = "";
  } elsif ($key eq "\e") { # escape
    exit 0;
  } else {
    ;       
  }
}
$$password = "";
print("Enter your password: ");
while(1) {
  $key = $Console->InputChar(1) || die "Error reading character";
  if ($key ge "!" and $key le "~") { # ! to ~ legal
    $$password .= $key;
    print("*");
  } elsif (($key eq "\t" || $key eq "\r") && length($$password) > 0) { #Tab or Enter
    print "\n";
    last;
  } elsif ($key eq "\b") { # ^H/backspace
    print "\b \b";
    chop $$password;
  } elsif ($key eq "\cu") { # ^U/clearline
    print "\b \b" x length $$password;
    $$password = "";
  } elsif ($key eq "\e") { # escape
    exit 0;
  } else {
    ;       
  }
}
}

$Console =  new Win32::Console(STD_INPUT_HANDLE) || die "Error creating
console";
$Console->Mode(ENABLE_PROCESSED_INPUT) || die "Error setting console mode";
my($pass) = "Perl5";
my($salt) = "?.";
my($key) =pack("C8",0x12,0x23,0x45,0x67,0x89,0xab,0xcd,0xef);
@ks= des_set_key($key);
my($a) = ord('P');
my($b) = ord('e');
my($c) = ord('r');
my($d) = ord('l'); 
my($e) = ord('5');
my($f) = ord(' ');
my($g) = ord(' ');
my($h) = ord(' ');
my($data) = pack("C8",$a,$b,$c,$d,$e,$f,$g,$h);
my($outbytes) = des_ecb_encrypt(*ks,1,$data);
my(@enc) =unpack("C8",$outbytes);
print "\n1) DES ECB mode example:\n";
print "Initial test block is: Perl5   \n";
print "Encrypted text: ";
for($i=0;$i<=7;$i++)
{
  $char = chr($enc[$i]);
  print "$char";
}
print "\n";
my($amine1) = des_ecb_encrypt(*ks,0,$outbytes);
@enc =unpack("C8",$amine1);
print "Decripted text: ";

for($i=0;$i<=7;$i++)
{
 $char = chr($enc[$i]);
 print "$char";
}

my($passwd) = crypt($pass,$r);
my($i) = 3;
my($guess);

print "\n\n2) Crypt() Example,guess the password :)\n";
while()
{
 my($password1);
 &passwd(\$password1);
 $guess = crypt($password1,$salat);
if ($guess eq  $passwd)
{
 print "\nOk!,the password is valid.";
 exit;
}
}

