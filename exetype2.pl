#!perl
############################ exetype.pl ############################
# Description:
# The standard perl.exe is a console based application, this is
# the right thing usually, but sometimes it might be tedious. 
# Imagine you have a Tk or Win32::GUI based script, you start
# it by a doubleclick on an icon and an ugly empty useless console
# appears and stays on screen until you close the script.
#
# OK, so what is the best solution? 
# The best solution I found to date (I don't think there can be
# any better) is to prepare a guiperl.exe. Something that's
# basically the same as perl.exe, but is a windows application,
# not console based. You will then use a different extension for
# the GUI based scripts and interpret them by guiperl.exe instead
# of perl.exe. 
#
# This may sound hard at first, but actually it's pretty trivial.
# All you have to do is to copy c:\perl\bin\perl.exe to
# c:\perl\bin\guiperl.exe and run this : 
# c:\> EDITBIN.EXE /subsystem:windows c:\perl\bin\guiperl.exe 
#
# I'm using extension .gpl for the scripts that are to be run
# by guiperl, but this is up to you. 
#####################################################################
# Usage:
#  exetype c:\perl\bin\guiperl.exe WINDOWS
# 
#  see Jenda's web page regarding this:
#    http://jenda.krynicky.cz/perl/GUIscripts.html
#
#########
# e.g.
#    copy c:\perl\bin\perl.exe c:\perl\bin\guiperl.exe
#    exetype c:\perl\bin\guiperl.exe WINDOWS
#    assoc .ptk=PerlTk
#    ftype PerlTk=i:\perl\bin\guiperl.exe %%1 %%*
#
# It's better to use this script. It handles everything for you:
#   http://jenda.krynicky.cz/perl/makeGUIperl.pl.txt
####
use strict; unless (@ARGV == 2) {
    print "Usage: $0 exefile [CONSOLE|WINDOWS]\n";     exit; }
unless ($ARGV[1] =~ /^(console|windows)$/i) {
    print "Invalid subsystem $ARGV[1], please use CONSOLE or WINDOWS\n";
    exit; } my ($record,$magic,$offset,$size);
open EXE, "+< $ARGV[0]" or die "Cannot open $ARGV[0]: $!"; binmode EXE;
read EXE, $record, 32*4; ($magic,$offset) = unpack "Sx58L", $record;
die "Not an MSDOS executable file" unless $magic == 0x5a4d;
seek EXE, $offset, 0; read EXE, $record, 24;
($magic,$size) = unpack "Lx16S", $record;
die "PE header not found" unless $magic == 0x4550;
die "Optional header not in NT32 format" unless $size == 224;
seek EXE, $offset+24+68, 0;
print EXE pack "S", uc($ARGV[1]) eq 'CONSOLE' ? 3 : 2; close EXE;
