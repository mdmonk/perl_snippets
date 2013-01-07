#!/usr/bin/perl

use strict;
use Digest::MD5 qw(md5_hex);
use Getopt::Long;



my $header=
q{#!/usr/bin/perl
use File::Spec::Functions;

sub d{%d=(map{($_,chr$_)}0..255);$n=256;($p,@c)=$_[1]->($_[0]);
$r=$d{$p};for(@c){if(exists $d{$_}){$r.=$d{$_};$d{$n++}=$d{$p}.substr$d{$_},
0,1;}else{$x=$d{$p};$n++;$r.=($d{$_}=$x.substr$x,0,1);}$p=$_;}$r;}
@u=(sub{shift},sub{d(shift,sub{$c=shift;@c=();push @c,(vec($c,3*$_,4)<<8)|
(vec($c,3*$_+1,4)<<4)|(vec($c,3*$_+2,4))for(0..2*length($c)/3-1);@c})},
sub{d(shift,sub{unpack 'n*',shift})});sub e{print "$_[0]\n";exit 1}
print "Content-Type: text/plain\n\n" if $ENV{GATEWAY_INTERFACE};
print "Unpacking files...\n";binmode DATA;while(<DATA>){chomp;
@p=split/\//;$f=catfile(@p);print "* $f: ";-e or mkdir $_ or
e("Couldn't create directory \"$_\".") for(map catfile(@p[0..$_]),(0..$#p-1));
read DATA,$b,5;($t,$l)=unpack("CN",$b);read DATA,$b,$l;
open F,">$f" or e("Couldn't create file.");binmode F;
print F $u[$t]->($b) or e("Couldn't write to file");close F;print"OK\n";}
print "Done!\n";
};



my @exec=();
my $delete=0;
GetOptions("exec=s"=>\@exec,"delete"=>\$delete);

my $output=shift @ARGV;

die "File \"$output\" alread exists" if -e $output;

open OUT,">$output" or die("Couldn't create file \"$output\"");
print OUT $header;
print OUT "unlink \$0 or e(\"Couldn't delete archive.\");\n" if $delete;
print OUT join "",map { (open EXEC,$_ and join "",<EXEC>) or "" } map { split /,/ } @exec;
print OUT "\n__END__\n";
print OUT join "",map "$_\n".load_file($_),map find_files($_),map { s/[\/\\]$//; $_ } @ARGV;
close OUT;



sub find_files($)
{
	my $filename=shift;

	if(!-e $filename) { return () }
	elsif(-d $filename) { return map find_files($_),grep !/^\.{1,2}$/,glob("$filename/*") }
	else { return ($filename) }
}

sub load_file($)
{
	my $filename=shift;
	my $contents="";

	print STDERR "Adding $filename... ";

	open FILE,$filename;
	binmode FILE;
	$contents.=$_ while(<FILE>);
	close FILE;

	my ($compressed,$bits)=compress($contents);
	if($compressed and length($compressed)<length($contents))
	{
		print STDERR "LZW$bits\n";
		return pack("C N a*",$bits==12?1:2,length $compressed,$compressed);
	}

	print STDERR "No compression\n";
	return pack("C N a*",0,length $contents,$contents);
}

sub compress($)
{
	my ($str)=@_;

	my $p=''; 
	my %d=map{(chr $_,$_)} 0..255;
	my @o=();
	my $ncw=256;
	
	for(split '',$str)
	{
		if(exists $d{$p.$_}) { $p.=$_; }
		else
		{
			push @o,$d{$p};
			$d{$p.$_}=$ncw++;
			$p=$_;
		}
	}
	push @o,$d{$p};
	
	if($ncw<1<<12)
	{
		my $v = '';
		for my $i (0..$#o)
		{
			vec($v, 3*$i, 4) = $o[$i]/256;
			vec($v, 3*$i+1, 4) = ($o[$i]/16)%16;
			vec($v, 3*$i+2, 4) = $o[$i]%16;
		}
		return ($v,12);
	}
	elsif($ncw<1<<16)
	{
		return (pack('n*',@o),16);
	}
	else { return undef }
}
