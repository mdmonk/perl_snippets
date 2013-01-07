#!/usr/bin/perl

#    Copyright 2005, 2005 Piotr Sobolewski
#    contact: piotr_sobolewski@o2.pl
#    contact: http://www.rozrywka.jawsieci.pl/materialy/dane_EN.html
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

# usage: ./look_for_hidden_files filesystem_device directory
# eg.:   ./look_for_hidden_files /dev/hda1 /home/piotr

# VERSION=1.0

sub check_dir {
  my ($dir, $filesys)=(@_);
  open(LS, "ls -f \'$dir\' |");
  open(DEBUGFS, "debugfs $filesys -R \'ls -l \"$dir\"\' 2>/dev/null | ");

  my @files_ls=<LS>;
  my $file_debugfs='';

  foreach $file_debugfs (<DEBUGFS>) {
    chomp($file_debugfs);
    if ($file_debugfs=~m/[a-zA-Z0-9]/) {
      ($file_debugfs_)=($file_debugfs =~ m/[0-9]*[^0-9]*\([0-9]*\)[^0-9]*[0-9]*[^0-9]*[0-9]*[^0-9]*[0-9]*[^0-9]*[0-9a-zA-Z\-]*[^0-9]*[0-9:]*\ *(.*)/);
      my $hidden=1;
      my $file_ls='';
      foreach $file_ls (@files_ls) {
	chomp($file_ls);
	if ($file_ls eq $file_debugfs_) { $hidden=0 }
      }
      if (($hidden==1) && (!($file_debugfs =~ m/^\ *0\ /))) { # files with inode 0 are some sh^H^Hgarbage
        print("$dir: $file_debugfs\n"); 
      }
    }
  }

  close(LS);
  close(DEBUGFS);
}

$filesys=$ARGV[0];
$basedir=$ARGV[1];
open(FIND, "find $basedir -mount -type d |");
@dirs=<FIND>;
foreach $dir_ (@dirs) {
  chomp($dir_);
  if (!($dir_ eq '.')) {
#    print("$dir_\n");
    &check_dir($dir_, $filesys);
  }
}


