#! /usr/bin/perl

# Make sure the correct line is uncommented below. If none of the
# descriptions fit, you will need to comment them all out and supply
# a replacement line of your own.

# Use this line if you're using a Linksys WPC54G CardBus card.
$new_device_id = "pci1737,4320";
# Use this line if you're using a Linksys WMP54G PCI card.
#$new_device_id = "pci1737,13";
# Use this line if you're using a Buffalo WLI-CB-G54 CardBus card.
#$new_device_id = "pci1154,324";

# Use this value for 10.2.4 (v3.0.3):
#$patchloc = 0x4b71c;
# Use this value for 10.2.5 (v3.0.4):
#$patchloc = 0x4e954;
# Use this value for the first post- 10.2.5 update (v3.0.4):
$patchloc = 0x4e8ac;

chdir "/System/Library/Extensions/AppleAirPort2.kext/Contents";

if ( -f "MacOS/AppleAirPort2_patched" ) {
  print "I see a MacOS/AppleAirPort2_patched file.\n\n";
  print "This means I may have already been run on this machine.\n";
  print "So I'm not going to do anything.\n";
  exit 1;
}

if ( -f "Info.plist.orig" ) {
  print "I see a Info.plist.orig file.\n\n";
  print "This means I may have already been run on this machine.\n";
  print "So I'm not going to do anything.\n";
  exit 1;
}

system "cp MacOS/AppleAirPort2 MacOS/AppleAirPort2_patched";

open DRIVER, "+<", "MacOS/AppleAirPort2_patched";
sysseek DRIVER, $patchloc, SEEK_SET;
sysread DRIVER, $readstr, 7;

if ($readstr ne "pci106b") {
  close DRIVER;
  unlink "MacOS/AppleAirPort2_patched";
  print "This doesn't appear to be the right version of the driver.\n";
  print "I'm not going to actually do anything.\n";
  exit 1;
}

sysseek DRIVER, $patchloc, SEEK_SET;
syswrite DRIVER, $new_device_id;
syswrite DRIVER, "\0";
close DRIVER;

system "cp -p Info.plist Info.plist.orig";

open PLIST_ORIG, "<", "Info.plist.orig";
open PLIST_NEW, ">", "Info.plist";
$skiplines = 0;

LINE: while (<PLIST_ORIG>) {
	next LINE if $skiplines-- > 0;

	if ( m,<key>CFBundleExecutable</key>, ) {
		print PLIST_NEW $_;
print PLIST_NEW "\t<string>AppleAirPort2_patched</string>\n";
		$skiplines = 1;
		next LINE;
	}

	if ( m,<key>IONameMatch</key>, ) {
		print PLIST_NEW $_;
print PLIST_NEW "\t\t\t<array>\n";
print PLIST_NEW "\t\t\t\t<string>" . $new_device_id . "</string>\n";
print PLIST_NEW "\t\t\t</array>\n";
		$skiplines = 3;
		next LINE;
	}

	print PLIST_NEW $_;
}

close PLIST_NEW;
close PLIST_ORIG;

print "Finished!\n";
print "If you see no other messages, then it probably worked.\n";
print "You can now try kextloading the driver and see if it works.\n";

exit 0;
