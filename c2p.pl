#!/usr/bin/perl

use Config;

die "usage: $0 <header file>\n" unless @ARGV == 1;

%chars = (
	'char' => (1 * 1),
	'double' => ($Config{doublesize} * 1),
	'int' => ($Config{intsize} * 1),
	'long' => ($Config{longsize} * 1),
	'short' => ($Config{shortsize} * 1),
	'long double' => ($Config{longdblsize} * 1),
	'long long' => ($Config{longlongsize} * 1),
	'ptr' => ($Config{ptrsize} * 1),
	'__uint8_t' => (1 * 1),
	'__uint16_t' => (2 * 1),
	'__uint32_t' => (4 * 1),
	'__uint64_t' => (8 * 1),
	'int8_t' => (1 * 1),
	'int16_t' => (2 * 1),
	'int32_t' => (4 * 1),
	'int64_t' => (8 * 1),
	'pid_t' => (4 * 1),
	'caddr_t' => (4 * 1),
	'sa_family_t' => (1 * 1),
	'void' => (1 * 1),
);

%chars = (
	%chars,
	'unsigned int' => $chars{int},
	'unsigned char' => $chars{char},
	'unsigned long' => $chars{long},
	'unsigned short' => $chars{short},
);

open(TMP, "</usr/include/sys/types.h");
while (<TMP>) {
 if (/typedef\s+(.+)\s+(\S+);/) {
  ($ele, $key) = ($1, $2);
  if ($ele =~ /struct/) {
   $ele =~ s/\s+/ /g;
   $chars{$key} = \$sizeof{$ele} unless $chars{$key};
  }
  else {
   $chars{$key} = $chars{$ele} unless $chars{$key};
  }
 }
}
close(TMP);

open(FH, "<$ARGV[0]") or die "Can't open file $file: $!\n";
@tmp = <FH>;
$file = join('', @tmp);
foreach (@tmp) {
 if (/typedef\s+(.+)\s+(\S+);/) {
  ($ele, $key) = ($1, $2);
  if ($ele =~ /struct/) {
   $ele =~ s/\s+/ /g;
   $chars{$key} = \$sizeof{$ele} unless $chars{$key};
  }
  else {
   $chars{$key} = $chars{$ele} unless $chars{$key};
  }
 }
 elsif (/include\s+(\S+)/) {
  if ($1 =~ /^<(.*?)>/) {
   open(TMP, "</usr/include/$1");
   while (<TMP>) {
    push(@tmp, $_);
   }
   close(TMP);
  }
  elsif ($1 =~ /^(?:"|')(.*?)(?:"|')/) {
   open(TMP, "</usr/include/$1");
   while (<TMP>) {
    push(@tmp, $_);
   }
   close(TMP);
  }
 }
}

while ($file =~ s/(struct\s+(\S+)\s*{[^}]+})//) {
 my %tmph;
 ($tmp, $struct) = ($1, $2);
 $tmp =~ s/\/\*.*?\*\///g;
 while ($tmp =~ s/\n\s*(.+\S+)\s+(\S+);//) {
  my $tmpr;
  ($str, $val) = ($2, $1);
  if ($val =~ /struct/) {
   $val =~ s/\s+/ /g;
   $val =~ s/^(.*?)$/\$sizeof\{'$1'\}/;
  }
  $str =~ s/\[(\d+)\]//;
  $tmpr = $1;
  $str =~ s/\s+.*?$//g;
  $str =~ s/\W+//g;
  unless ($tmpr =~ /^\d+$/) {
   $tmpr = 1;
  }
  $structs{$struct}{$str} = $val . "[$tmpr]";
 }
}

foreach $struct (keys(%structs)) {
 my $size;
 foreach $val (keys(%{$structs{$struct}})) {
  $tmp = $structs{$struct}{$val};
  ($vl, $ts) = $tmp =~ /^(.*?)\[(\d+)\]/;
  $size = ($size + ($chars{$vl} * $ts));
 }
 $sizeof{"struct $struct"} = $size;
}

foreach $struct (keys(%structs)) {
 my $size;
 foreach $val (keys(%{$structs{$struct}})) {
  if ($structs{$struct}{$val} =~ /struct/) {
   $tmp = $structs{$struct}{$val};
   $tmp =~ s/\$sizeof{'(.*?)'}/$1/g;
   ($vl, $ts) = $tmp =~ /^(.*?)\[(\d+)\]$/;
   $size = ($size + ($sizeof{$vl} * $ts));
  }
  else {
   $tmp = $structs{$struct}{$val};
   ($vl, $ts) = $tmp =~ /^(.*?)\[(\d+)\]$/;
   $size = ($size + ($chars{$vl} * $ts));
  }
 }
}

foreach $struct (reverse(keys(%structs))) {
 my $size;
 foreach $val (keys(%{$structs{$struct}})) {
  if ($structs{$struct}{$val} =~ /struct/) {
   $tmp = $structs{$struct}{$val};
   $tmp =~ s/\$sizeof{'(.*?)'}/$1/g;
   ($vl, $ts) = $tmp =~ /^(.*?)\[(\d+)\]$/;
   $size = ($size + ($sizeof{$vl} * $ts));
  }
  else {
   $tmp = $structs{$struct}{$val};
   ($vl, $ts) = $tmp =~ /^(.*?)\[(\d+)\]$/;
   $size = ($size + ($chars{$vl} * $ts));
  }
 }
 print "\$sizeof{'struct $struct'} = $size;\n";
}
