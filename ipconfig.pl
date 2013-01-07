###############################################
#--ipcfg.pl-- interface to `IPCONFIG`
#
###############################################

debug_test();

sub debug_test {
	my %ipconfig=();
	my %section=();
	my $name;
	if (GetIPConfig(\%ipconfig)) {
#		PrintAll(\%ipconfig);
		GetConfigHash(\%ipconfig,\%section);
		print "Configuration:\n";
		PrintSectionHash(\%section);
		foreach $name (keys %ipconfig) {
			unless ($name eq "Configuration") {
				GetSectionHash($name, \%ipconfig, \%section);
				print "$name:\n";
				PrintSectionHash(\%section);
				print "IP Addresses:\n";
				@iplist = split /;/,$section{"IP Address"};
				foreach (@iplist) {
					print "\t$_\n";
				}
			}
		}
	}
}

sub GetIPConfig {
	my $hashref = shift;
	my @lines=();
	my %section=();
	my $item;
	my $key;
	my $val;
	@lines = `ipconfig /all`;
	foreach (@lines) {
		s/([\x0d\x0a])//g;			#remove all EOL markers
		next unless $_;				#skip empty lines
		if (/^\w.*\s([^:]*)/) {			#new section?
			if ($item) {			#save last?
				$$hashref{$item}=(join ",", %section);
			}
			undef(%section);
			$item = $1;
		} else {
			if (/:/) {			#new item?
				($key,$val) = /\s([^.]*).*:\W*(.*)/;
			} else {				#another value
				($val) = /\s*(.*)/;
			}
			$key =~ s/(\s*)$//;			#remove trailing space
			$val =~ s/(\s*)$//;			#remove trailing space
			if (exists $section{$key}) {
				$section{$key} .= ";$val"
			} else {
				$section{$key} = $val;
			}
		}
	}
	if ($item) {						#save last?
		$$hashref{$item}=(join ",", %section);
	}
	return (1);
}

# GetConfigHash(\%config, \%section)
sub GetConfigHash {
	GetSectionHash("Configuration", shift, shift)
}

# GetSectionHash($name, \%config, \%section)
sub GetSectionHash {
	my $name = shift;
	my $configref = shift;
	my $sectionref = shift;
	%$sectionref = split /,/,$$configref{$name};
}


# takes a config hash and prints each section's keys and values
sub PrintAll {
	my $hashref = shift;
	my %section=();
	my $item;
	foreach $item (keys %$hashref) {
		print "$item\n";
		%section = split /,/,$$hashref{$item};
		PrintSectionHash(\%section);
	}
}

# takes a section hash and prints the keys and values
sub PrintSectionHash {
	my $hashref = shift;
	foreach (keys %$hashref) {
		print "\t" . $_ . "=" . $$hashref{$_} . "\n";
	}
}

# takes a config hash and prints the Items (section names)
sub PrintItems {
	my $hashref = shift;
	foreach (keys %$hashref) {
		print "$_\n";
	}
}
