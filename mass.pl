#!/usr/bin/perl

# this is for doing stuff with multiple files when the program doesn't support multiple files
# example:
# if you have 3 .tar's in a dir, you can't do tar -xvf *.tar
# you have to do each one, one by one
# with this, you just do something like: mass 'tar -xvf *.tar' and it will run each one for you
# or maybe mass 'tar -xvf program-0.?.tar' or whatever...
# cp5 owns.you

die "usage: $0 <'program'>\nexample: $0 'tar -xvf *.tar'\n" unless @ARGV == 1;
@args = split(/\s+/, $ARGV[0]);
foreach (@args) {
 unless (/\?|\*/ or $dn) {
  $frst .= "$_ ";
 }
 if ($dn) {
  $last .= "$_ ";
 }
 if (/\?|\*/) {
  $dn++;
  if (/^(.*?\/)([^\/]+)$/) {
   opendir (DIR, $1);
   $file = $2;
  }
  else {
   opendir (DIR, "./");
   $file = $_;
  }
  $file =~ s/\?/.{1}/g;
  $file =~ s/\*/.*?/g;
  @fils = grep { /^$file$/ } readdir(DIR);
 }
}
foreach (@fils) {
 system("$frst $_ $lst");
}
