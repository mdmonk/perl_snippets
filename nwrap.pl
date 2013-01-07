#! /usr/bin/perl

# Nmap wrapper for OPRP data.
# (C) Simon Biles
# http://www.isecom.org

# Version 0.04
$version = "0.04";

# History - 0.01 Working version.
#           0.02 Changed use of ``s for output to opening a pipe.
#           0.03 Use the OPRP database dump directly, not through
#                pre-parsed file
#           0.04 Included output switches and file writing stuff


# Read in from the OPRP data file created earlier.
# and fill in an internal table.

# Give us a little credit :) and show that it is running ...

print "\n#########################################\n";
print "#  nwrap.pl - Nmap and OPRP combined !  #\n"; 
print "#   (C) Simon Biles CSO Ltd. '04        #\n";
print "#       http://www.isecom.org           #\n";
print "# http://www.computersecurityonline.com #\n";
print "#########################################\n\n";

%services=();

open (DATA, "< oprp_services_dump");

while (<DATA>){
# This line removes the SQL, parentheses and inverted commas from the data.
    $_ =~ s/(^INSERT INTO protocoldb VALUES \()||(\)\;)||(\')//g; 
 # Split the data at comma separations
    ($ref_no,$port_no,$port_type,$name,$reference,$description,$some_number) = split(/,/, $_);
 # Swap underscores for spaces in the names
    $name =~ s/\s+/_/g;
  if ($port_type =~ /^UDP/){
      $port_prot = $port_no."/udp";
      push( @{$services{$port_prot}},$name);
  }
  elsif ($port_type =~ /^TCP UDP/){
      $port_prot = $port_no."/tcp";
      push( @{$services{$port_prot}},$name);
      $port_prot = $port_no."/udp";
      push( @{$services{$port_prot}},$name);
  }
  elsif ($port_type =~ /^TCP$/){
      $port_prot = $port_no."/tcp";
      push( @{$services{$port_prot}},$name);
  }
  elsif ($port_type =~ ""){
      $port_prot = $port_no."/unknown";
      push( @{$services{$port_prot}},$name);
  }
}

# Just to keep things tidy !

close DATA;

# There are some output to file arguments that I hadn't thought about !
# Check for them here and set up some variables ...
# They then are pulled from the arguments so that we can do the output ...
# If more than one output option is specified ( which I'm not sure is legal anyway )
# the final switch will take priority

for($i = 0;$i < @ARGV;$i++){
    if (@ARGV[$i] =~ m/-o/){
	if (@ARGV[$i] =~ m/-oN/){$out_normal = 1; $out_xml = 0; $out_grep = 0; $arguments = $arguments." -oN - "; $i++; $filename = @ARGV[$i];}
	if (@ARGV[$i] =~ m/-oX/){$out_xml = 1; $out_normal = 0; $out_grep = 0; $arguments = $arguments." -oX - "; $i++; $filename = @ARGV[$i];}
	if (@ARGV[$i] =~ m/-oG/){$out_grep = 1; $out_xml = 0; $out_normal = 0; $arguments = $arguments." -oG - "; $i++; $filename = @ARGV[$i];}
    } else {
	$arguments = $arguments.@ARGV[$i];
    }
}

# O.k. ... So if there is a file specified, we had better open it to write to ...

if ($out_normal == 1 || $out_xml == 1 || $out_grep == 1){
    open(OUT,"> $filename") or die "Can't open $filename to write to ! $! \n";
}

# Run nmap with the provided command line args.
# doing it this way rather than with backticks, means that the output is "live"

open(NMAP, "nmap $arguments |") or die "Can't run nmap: $!\n";

# If necessary warn the user that they shouldn't expect to see any output ...

if ($out_xml == 1){
    print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
    print "!  Sorry. The XML output option only  !\n";
    print "!  ouputs to the filename specified   !\n";
    print "!         not to the screen.          !\n";
    print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
}

if ($out_grep == 1){
    print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
    print "! Sorry. The Grep output option only  !\n";
    print "!  ouputs to the filename specified   !\n";
    print "!         not to the screen.          !\n";
    print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
}

# Modify the output as required.

while(<NMAP>){
    if ($out_normal == 0 && $out_xml == 0 && $out_grep == 0){
	if ($_ =~ m/(^\d+\/)(tcp|udp)/){
	    ($port,$state,$service)= split (/\s+/, $_);
	    print "$port : $state \n";
	    foreach $service ( sort @{$services{$port}}){
		print "                - $service \n";
	    }
	} else {
	    print $_;
	}
    } elsif ( $out_normal == 1 && $out_xml == 0 && $out_grep == 0){
	if ($_ =~ m/(^\d+\/)(tcp|udp)/){
	    ($port,$state,$service)= split (/\s+/, $_);
	    print "$port : $state \n";
	    foreach $service ( sort @{$services{$port}}){
		print "                - $service \n";
	    }
	    print OUT "$port : $state \n";
	    foreach $service ( sort @{$services{$port}}){
		print OUT "                - $service \n";
	    }
	} else {
	    print $_;
	    print OUT $_;
	}
    } elsif ( $out_xml == 1 && $out_normal == 0 && $out_grep == 0){

	if ($_ =~ /port /){
	    $_ =~ s/\</ /g;
	    $_ =~ s/\>/ /g;
	    $_ =~ s/\"//g;
	    (@array) = split (" ",$_);
	    foreach (@array){

		if ($_ =~ m/portid/){
		    ($a, $port) = split ("=",$_);
		}
		if ($_ =~ m/state/){
		    ($a,$state) = split ("=",$_);
		}
		if ($_ =~ m/protocol/){
		    ($a,$protocol) = split ("=",$_);
		}
		if ($_ =~ m/conf/){
		    ($a,$conf) = split ("=",$_);
		}
		if ($_ =~ m/method/){
		    ($a,$meth) = split ("=",$_);
		}
	    }
	    $port_prot = $port."/".$protocol;
	    foreach $service ( sort @{$services{$port_prot}}){
		print OUT "<port protocol=\"$protocol\" portid=\"$port\"><state state=\"$state\" /><service name=\"$service\" method=\"$meth\" conf=\"$conf\" /\>\</port>\n";
	    }
	} else {
	    print OUT $_;
	}
    } elsif ( $out_grep == 1 && $out_normal == 0 && $out_xml == 0){

# This is all one bloody long line, so this should be fun ...
# Send the comments stright through ...
	if ( $_ =~ /^\#/ ){
	    print OUT $_;
	} else {
	    @array = split(",",$_);
	    for($i=0;$i < @array; $i++){
		if(@array[$i] =~ /Host:/){
		    ($a,$host_ip,$host_name,$b,$remainder)= split(" ",@array[$i]);		    
		    @array[$i] = $remainder;
		}
		if(@array[$i] =~ /Ignored/){
		    ($port_data,@therest)= split(" ",@array[$i]);
		    @array[$i] = $port_data;
		}
	    }
	    print OUT "$a $host_ip $host_name $b ";
	    foreach (@array){
		$_ =~ s/\// /g;
		$_ =~ s/\,//g;
		$_ =~ s/\s+/:/g;
		($nada,$port,$state,$protocol,$name) = split(":",$_);
		$port_prot = $port."/".$protocol;
		foreach $service ( sort @{$services{$port_prot}}){
		    print OUT "$port/$state/$protocol//$service///,";
		} 
	    }
	    print OUT " ".join(" ",@therest)."\n";
	}
    }
}

# Tidy up the open files ... if they exist ...

if ($out_normal == 1 || $out_xml == 1 || $out_grep == 1){
    close OUT;
}

# That's it really !

