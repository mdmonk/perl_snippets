#!/usr/bin/perl -w
#
# pdfdecrypt.pl
#
# Decrypt a PDF file.
# Usage: pdfdecrypt.pl file.pdf >newFile.pdf
#
# This is a quick hack to make a point.  You really want to parse the
# PDF file properly.  Perl regexps are nifty, but this code will screw
# up in weird cases (e.g., if encrypted stream data happens to include
# the nine bytes "endstream").
#
# This code doesn't bother decrypting strings.
#

use strict;
use MD5;

# change this to set a non-empty user password
my $userPW = "";

my $padBytes = pack("H*", "28BF4E5E4E758A4164004E56FFFA01082E2E00B6D0683E802F0CA9FE6453697A");

#----- Read the entire file into a string.
my $oldIRS = $/;
undef $/;
my $file = <>;
$/ = $oldIRS;

#----- Grab trailer, extract Encrypt and ID.
if (!($file =~ /\btrailer\s*<<(.*)>>/s)) {
    die("Doesn't look like a PDF file - couldn't find trailer\n");
}
my $trailer = $1;
if (!($trailer =~ /\/Encrypt\s+(\d+)\s+(\d+)\s+R/)) {
    die("Not encrypted - couldn't find Encrypt dict ref\n");
}
my $encDictNum = $1;
my $encDictGen = $2;
if (!($trailer =~ /\/ID\s*\[\s*<([\dA-Fa-f]+)>/)) {
    die("Couldn't find document ID\n");
}
my $id = pack("H*", $1);

#----- Grab the Encrypt dict.
if (!($file =~ /\b$encDictNum\s+$encDictGen\s+obj\s*<<((?:.(?!<<))*)>>/s)) {
    die("Couldn't find Encrypt dict\n");
}
my $encDict = $1;
$encDict =~ s/\\n/\n/;
$encDict =~ s/\\r/\r/;
$encDict =~ s/\\t/\t/;
$encDict =~ s/\\b/\x08/;
$encDict =~ s/\\f/\f/;
$encDict =~ s/\\\(/\(/;
$encDict =~ s/\\\)/\)/;
$encDict =~ s/\\\\/\\/;
if (!($encDict =~ /\/Filter\s*\/(\w+)/s)) {
    die("Couldn't find Filter in Encrypt dict\n");
}
if ($1 ne "Standard") {
    die("Unknown filter '$1'\n");
}
if (!($encDict =~ /\/V\s*(\d+)/s)) {
    die("Couldn't find V in Encrypt dict\n");
}
if ($1 ne "1") {
    die("Unknown algorithm '$1'\n");
}
if (!($encDict =~ /\/R\s*(\d+)/s)) {
    die("Couldn't find R in Encrypt dict\n");
}
if ($1 ne "2") {
    die("Unknown revision '$1'\n");
}
if (!($encDict =~ /\/O\s*\((.{32})\)/s)) {
    die("Couldn't find O in Encrypt dict\n");
}
my $ownerHash = $1;
if (!($encDict =~ /\/U\s*\((.{32})\)/s)) {
    die("Couldn't find U in Encrypt dict\n");
}
my $userHash = $1;
if (!($encDict =~ /\/P\s+(-?\d+)/s)) {
    die("Couldn't find P in Encrypt dict\n");
}
my $perm = $1 & 0xffffffff;

#----- generate the file key
my $md5 = new MD5();
$md5->add(substr($userPW . $padBytes, 0, 32));
$md5->add($ownerHash);
$md5->add(pack("V", $perm));
$md5->add($id);
my $fileKey = substr($md5->digest(), 0, 5);


#----- check user password
my $check = new RC4($fileKey);
my $userTest = $check->encrypt($userHash);
if ($userTest ne $padBytes) {
    die("Wrong user password\n");
}

#----- scan through the PDF file, decrypting streams
my (@a) = split(/((?:\bstream\r?\n?)|(?:\r?\n?endstream))/, $file);
# now we have:
#   a[0] = (whatever)
#   a[1] = "stream"
#   a[2] = (stream contents)
#   a[3] = "endstream"
#   a[4] = (whatever)
#   ...
for (my $i = 0; $i + 3 < scalar(@a); $i += 4) {
    if ($a[$i] =~ /^(.*)(\/Encrypt\s+\d+\s+\d+\s+R)(.*)$/s) {
	printf("%s%s%s", $1, " " x length($2), $3);
    } else {
	print($a[$i]);
    }
    print($a[$i+1]);
    if (!($a[$i] =~ /\b(\d+)\s+(\d+)\s+obj\s*<<(?:.(?!\bobj\b))*>>\s*$/s)) {
	die("Couldn't find object number for stream\n");
    }
    print(decryptStream($a[$i+2], $1, $2));
    print($a[$i+3]);
}
for (my $i = scalar(@a) & ~3; $i < scalar(@a); ++$i) {
    if ($a[$i] =~ /^(.*)(\/Encrypt\s+\d+\s+\d+\s+R)(.*)$/s) {
	printf("%s%s%s", $1, " " x length($2), $3);
    } else {
	print($a[$i]);
    }
}

sub decryptStream {
    my ($data, $num, $gen) = @_;
    my $md5 = new MD5();
    $md5->add($fileKey);
    $md5->add(substr(pack("V", $num), 0, 3));
    $md5->add(substr(pack("V", $gen), 0, 2));
    my $key = substr($md5->digest(), 0, 10);
    my $rc4 = new RC4($key);
    return $rc4->encrypt($data);
}

#------------------------------------------------------------------------

package RC4;

sub new {
    my ($class, $key) = @_;
    my @key = unpack("C*", $key);
    my $keyLen = scalar(@key);
    my $self = {};
    bless($self, $class);
    $self->{state} = [];
    for (my $i = 0; $i < 256; ++$i) {
	$self->{state}->[$i] = $i;
    }
    my $idx1 = 0;
    my $idx2 = 0;
    my $t;
    for (my $i = 0; $i < 256; ++$i) {
	$idx2 = ($key[$idx1] + $self->{state}->[$i] + $idx2) & 0xff;
	($self->{state}->[$i], $self->{state}->[$idx2]) =
	    ($self->{state}->[$idx2], $self->{state}->[$i]);
	$idx1 = ($idx1 + 1) % $keyLen;
    }
    $self->{x} = 0;
    $self->{y} = 0;
    return $self;
}

# Encrypt and decrypt are identical.
sub encrypt {
    my ($self, $in) = @_;
    my (@in) = unpack("C*", $in);
    my (@out);
    my $x = $self->{x};
    my $y = $self->{y};
    my ($tx, $ty);
    for my $c (@in) {
	$x = ($x + 1) & 0xff;
	$y = ($self->{state}->[$x] + $y) & 0xff;
	$tx = $self->{state}->[$x];
	$ty = $self->{state}->[$y];
	$self->{state}->[$x] = $ty;
	$self->{state}->[$y] = $tx;
	push(@out, $c ^ $self->{state}->[($tx + $ty) & 0xff]);
    }
    $self->{x} = $x;
    $self->{y} = $y;
    return pack("C*", @out);
}




