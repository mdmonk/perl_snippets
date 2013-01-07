#!/usr/bin/perl
# #!perl.exe

use Win32::API;
use Win32::Sound;

cdOpen();

sub cdOpen {
 my $mciSendString = new Win32::API(
  "winmm",
  "mciSendString",
  ['P', 'P', 'N', 'N'], 'N'
 )
 or die "Can't import the mciSendString API:\n$!";

 doMultiMedia("close cdaudio"); # in case someone left it open
 doMultiMedia("open cdaudio shareable");
 doMultiMedia("set cdaudio door open");
 doMultiMedia("close cdaudio");

 sub doMultiMedia {
  my($cmd) = @_;
  my $ret = "\0" x 1025;
  my $rc = $mciSendString->Call($cmd, $ret, 1024, 0);
  if($rc == 0) {
   $ret =~ s/\0*$//;
   return $ret;
  } else {
   return "error '$cmd': $rc";
  }
 }
} # end cdOpen

sub winBeep {

# to "beep" like Windows does, eg. through the soundcard:
 Win32::Sound::Play(1);

# or from the speaker:
 print chr(7);

} # end winBeep
