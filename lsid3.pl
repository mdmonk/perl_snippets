#!/usr/bin/perl
# lsid3 (LiSt ID3 info)
# by Leif Josson (lejon@ju-jutsu.com)
#
# Please send bug reports to lejon@ju-jutsu.com
#
# http://www.ju-jutsu.com/smartid3/
# http://www.ju-jutsu.com/smartid3/lsid3.pl

#This is just using Neon Goats and Chris Nandor MP3 modules
# I have just pasted their code into this script and 
#combining them to do what I wanted.

use vars qw($opt_i $opt_r $opt_h);
use Getopt::Std;
use File::Basename;
use IO::File;

my $version = "0.1.0";
my $dir = '.';
my $new_file = "%f";
$version = "1.0";

getopts('irh');

if (defined($opt_h) && $opt_h) 
{ 
    usage();
}

sub usage {

    print STDERR <<USAGE;

lsid3 (LiSt ID3 info) v$version

Usage: lsid3.pl [-ih]

   -i  take the filenames from the commandline
   -h  this help text

EXAMPLES

     perl lsid3.pl

     perl lsid3.pl -i Three\ Wishes\ -\ *

AUTHOR
       Written by Leif Jonsson (lejon\@ju-jutsu.com).

LOCATION

       http://www.ju-jutsu.com/smartid3/

USAGE

exit;
}



if($opt_i)
{
    @mp3s = @ARGV;
}
else
{
    @mp3s = get_mp3s($dir, $opt_r);
}
my @suffix = ('\.mp3','\.MP3');


foreach my $orig_file (@mp3s){
    
    my $id3 = get_id3_info($orig_file);
    my $mp3info = get_mp3info($orig_file);

    my $fsize = (stat($orig_file))[7];

    $fsize= $fsize/1024/1024;

    print(("File [" . sprintf("%.2f MB",$fsize) . "]: " . $orig_file. "\n")) unless not defined $orig_file;
    print(("--------------------------------------------------------------\n"));
    if ($id3->got_tag()) 
    {
	$orig_file =~ s/\.\///;
	print(("  ID3 Artist  : " . $id3->get_artist() . "\n")) unless not defined $id3->get_artist();
	print(("  ID3 Album   : " . $id3->get_album() . "\n")) unless not defined $id3->get_album(); 
	print(("  ID3 Title   : " . $id3->get_title() . "\n")) unless not defined $id3->get_title();
	print(("  ID3 Track   : " . $id3->get_track() . "\n")) unless not defined $id3->get_track();
	print(("  ID3 Comment : " . $id3->get_comment() . "\n")) unless not defined $id3->get_comment();
	print(("  ID3 Year    : " . $id3->get_year() . "\n")) unless not defined $id3->get_year();
	print(("  ID3 Genre   : " . $id3->get_genre() . "\n")) unless not defined $id3->get_genre();
    }
    else
    {
	print(("  No ID3 info.\n\n"));
    }

    if($mp3info)
    {
	print(("  MP3 length  : " . sprintf("%02u:%02u", $mp3info->{MM}, $mp3info->{SS}) . "\n")) unless not (defined $mp3info->{MM} && defined $mp3info->{SS});
	print(("  MP3 bitrate : " . $mp3info->{BITRATE} . "\n")) unless not defined $mp3info->{BITRATE};
	print(("  MP3 Freq    : " . $mp3info->{FREQUENCY} . "\n")) unless not defined $mp3info->{FREQUENCY};
	print(("  MP3 Version : " . $mp3info->{VERSION} . "\n")) unless not defined $mp3info->{VERSION};;
	print(("  MP3 Stereo  : " . ($mp3info->{STEREO} ? Stereo : Mono) . "\n")) unless not defined $mp3info->{STEREO}; 
	print(("  MP3 Layer   : " . $mp3info->{LAYER} . "\n")) unless not defined $mp3info->{LAYER};
	print(("  MP3 VBR     : " . ($mp3info->{VBR} ? VBR : '') . "\n")) unless not defined $mp3info->{VBR};
	print(("  MP3 Mode    : " . $mp3info->{MODE} . "\n")) unless not defined $mp3info->{MODE};
	print(("  MP3 Cpy     : " . ($mp3info->{COPYRIGHT} ? Copyrighted : 'Not copyrighted') . "\n\n")) unless not defined $mp3info->{COPYRIGHT};
    }
    else
    {
	print(("  No MP3 info.\n"));
    }

}

sub get_id3_info {
	my($mp3_file,$readonly) = @_;
	my $self = {};
	$readonly = 1 unless defined($readonly);
	$self->{FileHandle} = new IO::File;
	if( -w $mp3_file || !$readonly)	{
		$self->{FileHandle}->open("+<${mp3_file}") or (warn("Can't open ${mp3_file}: $!") and return undef);
		$self->{readonly} = 0;
	} else {
		$self->{FileHandle}->open("<${mp3_file}") or (warn("Can't open ${mp3_file}: $!") and return undef);
		$self->{readonly} = 1;
	}
	$self->{filename} = $mp3_file;
	$self->{tag} = ();

	bless($self, "main");

	
	my $initialized = $self->init();
	
	return $self;
}

## Some generic initialization
## Find the headers and be ready for questions.
sub init {
	my($self) = @_;
	my $bytestring ="";
	$bytestring = $self->find_tag_id3v1();
	if(!defined($bytestring)) {
		return 0;
	} else {
		$self->decode_tag_id3v11($bytestring);
	}
	return 1;
}

sub find_tag_id3v1 {
	my($self) = @_;
	my($bytes,$line);
	$self->{FileHandle}->seek(-128,SEEK_END); # Find the last 128 bytes
	while($line = $self->{FileHandle}->getline()) { $bytes .= $line; }
	return undef if $bytes !~ /^TAG/; # Must have Tag Ident to be valid.
	return $bytes;
}

## Decode the ID3v1.1 Tag into useful tidbits.
sub decode_tag_id3v11 {
	my($self,$buffer) = @_;
	## Unpack the Audio ID3v1
	(undef, @{$self->{tag}}{qw/title artist album year comment zero track genre_num/}) =
		unpack('a3a30a30a30a4a28a1C1C1', $buffer);
		#unpack('a3a30a30a30a4a30C1', $buffer);
	
	## Clean em up a bit
	foreach (sort keys %{$self->{tag}}) {
		if(defined($self->{tag}{$_})) {
			$self->{tag}{$_} =~ s/\s+$//;
			$self->{tag}{$_} =~ s/\0.*$//;
			$self->debug(sprintf("ID3v11: %s = ", $_ ) . $self->{tag}{$_});
		}
	}

	if (hex($self->{tag}{'track'}) >= 50) {
		$self->{tag}{'track'} = ''; 
	} 
		
	$self->{tag}{'genre'} = $mp3_genres[$self->{tag}{'genre_num'}];
}

sub get_title {
  my($self) = @_;
  return $self->{tag}{'title'};
}

sub get_artist {
  my($self) = @_;
  return $self->{tag}{'artist'};
}

sub get_album {
  my($self) = @_;
  return $self->{tag}{'album'};
}

sub get_year {
  my($self) = @_;
  return $self->{tag}{'year'};
}

sub get_comment {
  my($self) = @_;
  return $self->{tag}{'comment'};
}

sub get_genre {
  my($self) = @_;
  return $self->{tag}{'genre'};
}

sub get_genre_num {
  my($self) = @_;
  return $self->{tag}{'genre_num'};
}

sub get_track {
  my($self) = @_;
  return $self->{tag}{'track'};
}

sub print_tag {
  my($self) = @_;

  if(defined($self->{tag})) {
    foreach (sort keys %{$self->{tag}}) {
      print(sprintf("%-10s = ",$_ ) . $self->{tag}{$_} . "\n");
    }
  } else {
    print "No ID3v1 Tag Found\n";
  }
}

sub got_tag {
  my($self) = @_;
  return ($self->find_tag_id3v1())?1:0;
}

sub debug {
    $DEBUG = 0;
	my($self,$message) = @_;
	print STDERR "$message\n" if $DEBUG;
}

sub get_mp3s {
	my ($dir, $recursive) = @_;

	my $path;
	my @files;

	unless (opendir(DIR, $dir)) {
		warn "Can't open $dir\n";
		closedir(DIR);
		return;
	}
	foreach (readdir(DIR)) {
		next if $_ eq '.' || $_ eq '..';
		$path = "$dir/$_";
		next if (-l $path);
		if (-d $path) {		# a directory
			if (defined ($recursive) && $recursive == 1) {
				push(@files, get_mp3s($path, $recursive));
			}
		} elsif (-f _) {	# a plain file
			if (/\.mp3$/i) {
				push(@files,$path); 
			}
		}
	}
	closedir(DIR);

	return @files;
}



#package MP3::Info;
use strict;
use Carp;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION
	@mp3_genres %mp3_genres @winamp_genres %winamp_genres $try_harder
	@t_bitrate @t_sampling_freq @frequency_tbl %v1_tag_fields
	@v1_tag_names %v2_tag_names %v2_to_v1_names);
@ISA = 'Exporter';
@EXPORT = qw(set_mp3tag get_mp3tag get_mp3info remove_mp3tag use_winamp_genres);
@EXPORT_OK = qw(@mp3_genres %mp3_genres);
%EXPORT_TAGS = (
	genres	=> [qw(@mp3_genres %mp3_genres)],
	all		=> [@EXPORT, @EXPORT_OK]
);
$VERSION = '0.80';

{
	my $c = -1;
	# set all lower-case and regular-cased versions of genres as keys
	# with index as value of each key
	%mp3_genres = map {($_, ++$c, lc, $c)} @mp3_genres;

	# do it again for winamp genres
	$c = -1;
	%winamp_genres = map {($_, ++$c, lc, $c)} @winamp_genres;
}

=pod

=head1 NAME

MP3::Info - Manipulate / fetch info from MP3 audio files

=head1 SYNOPSIS

	#!perl -w
	use MP3::Info;
	my $file = 'Pearls_Before_Swine.mp3';
	set_mp3tag($file, 'Pearls Before Swine', q"77's",
		'Sticks and Stones', '1990', q"(c) 1990 77's LTD.", 'rock & roll');

	my $tag = get_mp3tag($file) or die "No TAG info";
	$tag->{GENRE} = 'rock';
	set_mp3tag($file, $tag);

	my $info = get_mp3info($file);
	printf "$file length is %d:%d", $info->{MM}, $info->{SS};

=head1 DESCRIPTION

=over 4

=item use_winamp_genres()

Puts WinAmp genres into C<@mp3_genres> and C<%mp3_genres>.

You can import the data structures with one of:

	use MP3::Info qw(:genres);
	use MP3::Info qw(:DEFAULT :genres);
	use MP3::Info qw(:all);

=cut

sub use_winamp_genres {
	%mp3_genres = %winamp_genres;
	@mp3_genres = @winamp_genres;
	1;
}

=pod

=item remove_mp3tag (FILE)

Removes last 128 bytes from file if those last 128 bytes begin with the
text `TAG'.  File will be 128 bytes shorter.  Returns undef if no existing
TAG found, 1 on successful removal of TAG.

=cut

sub remove_mp3tag {
	my $file = $_[0];

	croak 'No file specified' unless $file;

	local *FILE;
	open FILE, "+< $file\0" or croak "Can't open '$file': $!";
	binmode FILE;
	seek FILE, -128, 2;
	my $tell = tell FILE;
	return unless <FILE> =~ /^TAG/;
	truncate FILE, $tell or carp "Can't truncate '$file': $!";
	close FILE or carp "Problem closing '$file': $!";
	1;
}


=pod

=item set_mp3tag (FILE, TITLE, ARTIST, ALBUM, YEAR, COMMENT, GENRE [, TRACKNUM])

=item set_mp3tag (FILE, $HASHREF)

Adds/changes tag information in an MP3 audio file.  Will clobber
any existing information in file.

Fields are TITLE, ARTIST, ALBUM, YEAR, COMMENT, GENRE.  All fields have
a 30-byte limit, except for YEAR, which has a four-byte limit, and GENRE,
which is one byte in the file.  The GENRE passed in the function is a
case-insensitive text string representing a genre found in C<@mp3_genres>.

Will accept either a list of values, or a hashref of the type
returned by C<get_mp3tag>.

If TRACKNUM is present (for ID3v1.1), then the COMMENT field can only be
28 bytes.

ID3v2 support will come eventually.

=cut

sub set_mp3tag {
	my($file, $title, $artist, $album, $year, $comment, $genre,
		$tracknum) = @_;
	my(%info, $oldfh);
	local %v1_tag_fields = %v1_tag_fields;

	# set each to '' if undef
	for ($title, $artist, $album, $year, $comment, $tracknum, $genre,
		(@info{@v1_tag_names}))
		{$_ = defined() ? $_ : ''}

	# populate data to hashref if hashref is not passed
	if (!ref $title) {
		(@info{@v1_tag_names}) =
			($title, $artist, $album, $year, $comment, $tracknum, $genre);

	# put data from hashref into hashref if hashref is passed
	} elsif (ref $title eq 'HASH') {
		%info = %$title;

	# return otherwise
	} else {
		croak <<'EOT';
Usage: set_mp3tag (FILE, TITLE, ARTIST, ALBUM, YEAR, COMMENT, GENRE [, TRACKNUM]),
		set_mp3tag (FILE, $HASHREF)
EOT
	}

	croak 'No file specified' unless $file;

	# comment field length 28 if ID3v1.1
	$v1_tag_fields{COMMENT} = 28 if $info{TRACKNUM};


	# only if -w is on
	if ($^W) {
		# warn if fields too long
		foreach my $field (keys %v1_tag_fields) {
			if (length($info{$field}) > $v1_tag_fields{$field}) {
				carp "Data too long for field $field: truncated to ".
					 "$v1_tag_fields{$field}";
			}
		}

		if ($info{GENRE}) {
			carp "Genre `$info{GENRE}' does not exist\n"
				unless exists $mp3_genres{$info{GENRE}};
		}
	}

	if ($info{TRACKNUM}) {
		unless ($info{TRACKNUM} =~ /^\d+$/ &&
			$info{TRACKNUM} > 0 && $info{TRACKNUM} < 256) {
			carp "Tracknum `$info{TRACKNUM}' must be an integer " .
				"from 1 and 255\n" if $^W;
			$info{TRACKNUM} = '';
		}
	}


	local *FILE;
	open FILE, "+< $file\0" or croak "Can't open '$file': $!";
	binmode FILE;
	$oldfh = select FILE;
	seek FILE, -128, 2;
	# go to end of file if no tag, beginning of file if tag
	seek FILE, (<FILE> =~ /^TAG/ ? -128 : 0), 2;

	# get genre value
	$info{GENRE} = exists $mp3_genres{$info{GENRE}} ?
		$mp3_genres{$info{GENRE}} : 255;  # some default genre

	# print TAG to file
	if ($info{TRACKNUM}) {
		print pack "a3a30a30a30a4a28xCC", 'TAG', @info{@v1_tag_names};
	} else {
		print pack "a3a30a30a30a4a30C", 'TAG', @info{@v1_tag_names[0..4, 6]};
	}

	select $oldfh;
	close FILE or carp "Problem closing '$file': $!";
	1;
}

=pod

=item get_mp3tag (FILE [, VERSION, RAW_V2])

Returns hash reference containing tag information in MP3 file.  Same
info as described in C<set_mp3tag>.

If VERSION is C<1>, the information is taken from the ID3v1 tag (if present).
If VERSION is C<2>, the information is taken from the ID3v2 tag (if present).
If VERSION is not supplied, the ID3v1 tag is read if present, and then, if present,
the ID3v2 tag information will override any existing ID3v1 tag info.

If the ID3v2 version is older than ID3v2.3.0, it will not be read (and
a warning will be issued if B<-w> is on).

If RAW_V2 is false or not supplied and VERSION is C<2>, only the tags
corresponding to ID3v1 tags are returned, with the same keys in the returned
hashref.

If RAW_V2 is true and VERSION is C<2>, C<get_mp3tag> will return a hash
of tag four-character IDs and their data.  Tag IDs and their meanings
are in the global hash (not exported) C<%v2_tag_names>.

	my $tag = get_mp3tag('mysong.mp3', 2, 1);   # ID3v2, raw ID3v2 tags
	for (keys %$tag) {
		printf "%s => %s\n", $MP3::Info::v2_tag_names{$_}, $tag->{$_};
	}

=cut

sub get_mp3tag {
	my($file, $ver, $raw_v2, $tag, $v1, $v2, %info, @array) = (@_[0 .. 2]);
	$ver ||= 0;

	croak 'No file specified' unless $file;

	local *FILE;
	open FILE, "< $file\0" or croak "Can't open '$file': $!";
	binmode FILE;

	if ($ver < 2) {
		seek FILE, -128, 2;
		while(defined(my $line = <FILE>)) { $tag .= $line }

		if ($tag =~ /^TAG/) {
			$v1 = 1;
			if (substr($tag, -3, 2) =~ /\000[^\000]/) {
				(undef, @info{@v1_tag_names}) = 
					(unpack('a3a30a30a30a4a28', $tag),
					ord(substr($tag, -2, 1)),
					$mp3_genres[ord(substr $tag, -1)]);
			} else {
				(undef, @info{@v1_tag_names[0..4, 6]}) = 
					(unpack('a3a30a30a30a4a30', $tag),
					$mp3_genres[ord(substr $tag, -1)]);
			}
		}
	}

	$v2 = _get_v2tag(\*FILE);
	return unless $v1 || $v2;

	if (($ver == 0 || $ver == 2) && $v2) {
		if ($raw_v2) {
			%info = %$v2;
		} else {
			for (keys %v2_to_v1_names) {
				if (exists $v2->{$_}) {
					if ($_ eq 'TCON' && $v2->{$_} =~ /^\((\d+)\)/) {
						$info{$v2_to_v1_names{$_}} = $mp3_genres[$1];
					} else {
						$info{$v2_to_v1_names{$_}} = $v2->{$_};
					}
				}
			}
		}
	}

	foreach my $key (keys %info) {
		if (defined $info{$key}) {
			$info{$key} =~ s/\s+$//;
			$info{$key} =~ s/\000.*//g;
		}
	}
	close FILE or carp "Problem closing '$file': $!";
	return {%info};
}

sub _get_v2tag {
	my($fh, $off, $myseek, $v2, $h) = ($_[0]);
	
	$myseek = sub {
		seek $fh, $off, 0;
		read $fh, my($bytes), 10;
		return unless $bytes =~ /^(\w{4})/;
		my($id, $size) = ($1, 10);
		my @bytes = reverse unpack 'C4', substr($bytes, 4, 4);
		for my $i (0 .. 3) {
			$size += $bytes[$i] * 256 ** $i;
		}
		return($id, $size);
	};

	$v2 = _get_v2head($fh) or return;
	if ($v2->{major_version} < 3) {
		warn "This is $v2->{version}; " .
			 "ID3v2 versions older than ID3v2.3.0 not supported\n"
			  if $^W;
		return;
	}

	$off = $v2->{ext_header_size} + 10;

	while ($off < $v2->{tag_size}) {
		my($id, $size) = &$myseek or last;
		seek $fh, $off + 10, 0;
		read $fh, my($bytes), $size - 10;
		$bytes =~ s/\000//g;  # necessary?
		if (exists $h->{$id}) {
			if (ref $h->{$id} eq 'ARRAY') {
				push @{$h->{$id}}, $bytes;
			} else {
				$h->{$id} = [$h->{$id}, $bytes];
			}
		} else {
			$h->{$id} = $bytes;
		}
		$off += $size;
	}

	return $h;
}


=pod

=item get_mp3info (FILE)

Returns hash reference containing file information for MP3 file.
This data cannot be changed.  Returned data includes MP3 version
(VERSION), total time in minutes (MM) and seconds (SS), boolean
for STEREO, MPEG layer (LAYER), BITRATE, MODE, boolean
for COPYRIGHT, and FREQUENCY.

Variable bitrates not yet supported.  See L<"TODO">.

=cut

sub get_mp3info {
	my($file, $off, $myseek, $byte, $eof, $h, $i, $tot) = ($_[0], 0);

	$tot = 4096;
	local *FILE;
	$myseek = sub {
		seek FILE, $off, 0;
		read FILE, $byte, 4;
	};

	open FILE, "< $file\0" or croak "Can't open '$file': $!";
	binmode FILE;
	&$myseek;

	if ($off == 0) {
		if (my $id3v2 = _get_v2head(\*FILE)) {
			$tot += $off += $id3v2->{tag_size};
			&$myseek;
		}
	}

	$h = _get_head($byte);
	until (_is_mp3($h)) {
		$off++;
		&$myseek;
		$h = _get_head($byte);
		return if $off > $tot && !$try_harder;
	}

	my $vbr = _get_vbr(*FILE, $h, \$off);

	seek FILE, 0, 2;
	$eof = tell FILE;
	seek FILE, -128, 2;
	$off += 128 if <FILE> =~ /^TAG/ ? 1 : 0;
	close FILE;

	if ($vbr) {
		$h->{bitrate} = 
			(($vbr->{bytes} != 0 ? $vbr->{bytes} : ($eof - $off))
				/ $vbr->{frames}) * $h->{fs} / 144000;
	}

	$h->{'length'}	= $h->{bitrate} == 0 ? 0 : (($eof - $off) * 8) / $h->{bitrate} / 10;
	$h->{secs}		= $h->{'length'} / 100;
	$h->{freq_idx}	= 3 * $h->{ID} + $h->{sampling_freq};

	$i->{LAYER}		= $h->{layer} <= 0 ? '' : $h->{layer} == 3
			? 1 : $h->{layer} == 1 ? 3 : $h->{layer};
	$i->{VERSION}	= $h->{IDR} == 2 ? 2 : $h->{IDR} == 3
			? 1	: $h->{IDR} == 0 ? 2.5 : 0;
	$i->{VBR}		= $vbr ? 1 : 0;
	$i->{MM}		= int $h->{secs} / 60;
	$i->{SS}		= int $h->{secs} % 60;  # ? ceil() ?  leftover seconds?
	$i->{STEREO}	= $h->{mode} == 3 ? 0 : 1;
	$i->{MODE}		= $h->{mode};
	$i->{COPYRIGHT}	= $h->{copyright};
	$i->{BITRATE}	= $h->{bitrate} >= 0 ? int $h->{bitrate} : '';
	$i->{FREQUENCY}	= $h->{freq_idx} >= 0 ? $frequency_tbl[$h->{freq_idx}] : '';

	return $i;
}

sub _get_head {
	my($byte, $bytes, $h) = $_[0];
	$bytes = unpack('l', pack('L', unpack('N', $byte)));
	@$h{qw(IDR ID layer protection_bit
		bitrate_index sampling_freq padding_bit private_bit
		mode mode_extension copyright original
		emphasis version_index bytes)} = (
		($bytes>>19)&3, ($bytes>>19)&1, ($bytes>>17)&3, ($bytes>>16)&1,
		($bytes>>12)&15, ($bytes>>10)&3, ($bytes>>9)&1, ($bytes>>8)&1,
		($bytes>>6)&3, ($bytes>>4)&3, ($bytes>>3)&1, ($bytes>>2)&1,
		$bytes&3, ($bytes>>19)&3, $bytes
	);

	$h->{bitrate} = $t_bitrate[$h->{ID}][3 - $h->{layer}][$h->{bitrate_index}];
	$h->{fs} = $t_sampling_freq[$h->{ID}][$h->{sampling_freq}];

	return $h;
}

sub _is_mp3 {
	my $h = $_[0] or return;
	return ! (
			 $h->{bitrate_index} == 0
					||
			 $h->{version_index} == 1
					||
			($h->{bytes} & 0xFFE00000) != 0xFFE00000
					||
			!$h->{fs}
					||
			!$h->{bitrate}
					||
			 $h->{bitrate_index} == 15
					||
			!$h->{layer}
					||
			 $h->{sampling_freq} == 3
					||
			 $h->{emphasis} == 2
					||
			!$h->{bitrate_index}
					||
			($h->{bytes} & 0xFFFF0000) == 0xFFFE0000
					||
			($h->{ID} == 1 && $h->{layer} == 3 && $h->{protection_bit} == 1)
					||
			($h->{mode_extension} != 0 && $h->{mode} != 1)
	);
}

sub _get_vbr {
	my($fh, $h, $roff) = @_;
	my($off, $bytes, @bytes, $myseek, $myunpack, %vbr);

	$off = $$roff;
	@_ = ();	# closure confused if we don't do this

	$myseek = sub {
		my $n = $_[0] || 4;
		seek $fh, $off, 0;
		read $fh, $bytes, $n;
		$off += $n;
	};

	$myunpack = sub {
		unpack('l', pack('L', unpack('N', $_[0])));
	};

	$off += 4;

	if ($h->{ID}) {  # MPEG1
		$off += $h->{mode} == 3 ? 17 : 32;
	} else {		 # MPEG2
		$off += $h->{mode} == 3 ? 9 : 17;
	}

	&$myseek;
	return unless $bytes eq 'Xing';

	&$myseek;
	$vbr{flags} = $myunpack->($bytes);

	if ($vbr{flags} & 1) {
		&$myseek;
		$vbr{frames} = $myunpack->($bytes);
	}

	if ($vbr{flags} & 2) {
		&$myseek;
		$vbr{bytes} = $myunpack->($bytes);
	}

	if ($vbr{flags} & 4) {
		$myseek->(100);
		$vbr{toc} = $myunpack->($bytes);
	}

	if ($vbr{flags} & 8) {
		&$myseek;
		$vbr{scale} = $myunpack->($bytes);
	} else {
		$vbr{scale} = -1;
	}

	$$roff = $off;
	return \%vbr;
}

sub _get_v2head {
	my $fh = $_[0] or return;
	my($h, $bytes, @bytes);

	# check first three bytes for 'ID3'
	seek $fh, 0, 0;
	read $fh, $bytes, 3;
	return unless $bytes eq 'ID3';

	# get version
	read $fh, $bytes, 2;
	$h->{version} = sprintf "ID3v2.%d.%d",
		@$h{qw[major_version minor_version]} =
			unpack 'c2', $bytes;

	# get flags
	read $fh, $bytes, 1;
	@$h{qw[unsync ext_header experimental]} =
		(unpack 'b8', $bytes)[7, 6, 5];

	# get ID3v2 tag length from bytes 7-10
	$h->{tag_size} = 10;	# include ID3v2 header size
	read $fh, $bytes, 4;
	@bytes = reverse unpack 'C4', $bytes;
	foreach my $i (0..3) {
		# whoaaaaaa nellllllyyyyyy!
		$h->{tag_size} += $bytes[$i] * 128 ** $i;
	}

	# get extended header size
	$h->{ext_header_size} = 0;
	if ($h->{ext_header}) {
		$h->{ext_header_size} += 10;
		read $fh, $bytes, 4;
		@bytes = reverse unpack 'C4', $bytes;
		for my $i (0..3) {
			$h->{ext_header_size} += $bytes[$i] * 256 ** $i;
		}
	}

	return $h;
}

BEGIN { 
	@mp3_genres = (
		'Blues',
		'Classic Rock',
		'Country',
		'Dance',
		'Disco',
		'Funk',
		'Grunge',
		'Hip-Hop',
		'Jazz',
		'Metal',
		'New Age',
		'Oldies',
		'Other',
		'Pop',
		'R&B',
		'Rap',
		'Reggae',
		'Rock',
		'Techno',
		'Industrial',
		'Alternative',
		'Ska',
		'Death Metal',
		'Pranks',
		'Soundtrack',
		'Euro-Techno',
		'Ambient',
		'Trip-Hop',
		'Vocal',
		'Jazz+Funk',
		'Fusion',
		'Trance',
		'Classical',
		'Instrumental',
		'Acid',
		'House',
		'Game',
		'Sound Clip',
		'Gospel',
		'Noise',
		'AlternRock',
		'Bass',
		'Soul',
		'Punk',
		'Space',
		'Meditative',
		'Instrumental Pop',
		'Instrumental Rock',
		'Ethnic',
		'Gothic',
		'Darkwave',
		'Techno-Industrial',
		'Electronic',
		'Pop-Folk',
		'Eurodance',
		'Dream',
		'Southern Rock',
		'Comedy',
		'Cult',
		'Gangsta',
		'Top 40',
		'Christian Rap',
		'Pop/Funk',
		'Jungle',
		'Native American',
		'Cabaret',
		'New Wave',
		'Psychadelic',
		'Rave',
		'Showtunes',
		'Trailer',
		'Lo-Fi',
		'Tribal',
		'Acid Punk',
		'Acid Jazz',
		'Polka',
		'Retro',
		'Musical',
		'Rock & Roll',
		'Hard Rock',
	);

	@winamp_genres = (
		@mp3_genres,
		'Folk',
		'Folk-Rock',
		'National Folk',
		'Swing',
		'Fast Fusion',
		'Bebob',
		'Latin',
		'Revival',
		'Celtic',
		'Bluegrass',
		'Avantgarde',
		'Gothic Rock',
		'Progressive Rock',
		'Psychedelic Rock',
		'Symphonic Rock',
		'Slow Rock',
		'Big Band',
		'Chorus',
		'Easy Listening',
		'Acoustic',
		'Humour',
		'Speech',
		'Chanson',
		'Opera',
		'Chamber Music',
		'Sonata',
		'Symphony',
		'Booty Bass',
		'Primus',
		'Porn Groove',
		'Satire',
		'Slow Jam',
		'Club',
		'Tango',
		'Samba',
		'Folklore',
		'Ballad',
		'Power Ballad',
		'Rhythmic Soul',
		'Freestyle',
		'Duet',
		'Punk Rock',
		'Drum Solo',
		'Acapella',
		'Euro-House',
		'Dance Hall',
	);

	@t_bitrate = ([
		[0, 32, 48, 56,  64,  80,  96, 112, 128, 144, 160, 176, 192, 224, 256],
		[0,  8, 16, 24,  32,  40,  48,  56,  64,  80,  96, 112, 128, 144, 160],
		[0,  8, 16, 24,  32,  40,  48,  56,  64,  80,  96, 112, 128, 144, 160]
	],[
		[0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
		[0, 32, 48, 56,  64,  80,  96, 112, 128, 160, 192, 224, 256, 320, 384],
		[0, 32, 40, 48,  56,  64,  80,  96, 112, 128, 160, 192, 224, 256, 320]
	]);

	@t_sampling_freq = (
		[22050, 24000, 16000],
		[44100, 48000, 32000]
	);

	@frequency_tbl = map {eval"${_}e-3"}
		@{$t_sampling_freq[0]}, @{$t_sampling_freq[1]};

	%v1_tag_fields =
		(TITLE => 30, ARTIST => 30, ALBUM => 30, COMMENT => 30, YEAR => 4);

	@v1_tag_names = qw(TITLE ARTIST ALBUM YEAR COMMENT TRACKNUM GENRE);

	%v2_to_v1_names = (
		'TIT2' => 'TITLE',
		'TPE1' => 'ARTIST',
		'TALB' => 'ALBUM',
		'TYER' => 'YEAR',
		'COMM' => 'COMMENT',
		'TRCK' => 'TRACKNUM',
		'TCON' => 'GENRE',
	);

	%v2_tag_names = (
		'AENC' => 'Audio encryption',
		'APIC' => 'Attached picture',
		'COMM' => 'Comments',
		'COMR' => 'Commercial frame',
		'ENCR' => 'Encryption method registration',
		'EQUA' => 'Equalization',
		'ETCO' => 'Event timing codes',
		'GEOB' => 'General encapsulated object',
		'GRID' => 'Group identification registration',
		'IPLS' => 'Involved people list',
		'LINK' => 'Linked information',
		'MCDI' => 'Music CD identifier',
		'MLLT' => 'MPEG location lookup table',
		'OWNE' => 'Ownership frame',
		'PCNT' => 'Play counter',
		'POPM' => 'Popularimeter',
		'POSS' => 'Position synchronisation frame',
		'PRIV' => 'Private frame',
		'RBUF' => 'Recommended buffer size',
		'RVAD' => 'Relative volume adjustment',
		'RVRB' => 'Reverb',
		'SYLT' => 'Synchronized lyric/text',
		'SYTC' => 'Synchronized tempo codes',
		'TALB' => 'Album/Movie/Show title',
		'TBPM' => 'BPM (beats per minute)',
		'TCOM' => 'Composer',
		'TCON' => 'Content type',
		'TCOP' => 'Copyright message',
		'TDAT' => 'Date',
		'TDLY' => 'Playlist delay',
		'TENC' => 'Encoded by',
		'TEXT' => 'Lyricist/Text writer',
		'TFLT' => 'File type',
		'TIME' => 'Time',
		'TIT1' => 'Content group description',
		'TIT2' => 'Title/songname/content description',
		'TIT3' => 'Subtitle/Description refinement',
		'TKEY' => 'Initial key',
		'TLAN' => 'Language(s)',
		'TLEN' => 'Length',
		'TMED' => 'Media type',
		'TOAL' => 'Original album/movie/show title',
		'TOFN' => 'Original filename',
		'TOLY' => 'Original lyricist(s)/text writer(s)',
		'TOPE' => 'Original artist(s)/performer(s)',
		'TORY' => 'Original release year',
		'TOWN' => 'File owner/licensee',
		'TPE1' => 'Lead performer(s)/Soloist(s)',
		'TPE2' => 'Band/orchestra/accompaniment',
		'TPE3' => 'Conductor/performer refinement',
		'TPE4' => 'Interpreted, remixed, or otherwise modified by',
		'TPOS' => 'Part of a set',
		'TPUB' => 'Publisher',
		'TRCK' => 'Track number/Position in set',
		'TRDA' => 'Recording dates',
		'TRSN' => 'Internet radio station name',
		'TRSO' => 'Internet radio station owner',
		'TSIZ' => 'Size',
		'TSRC' => 'ISRC (international standard recording code)',
		'TSSE' => 'Software/Hardware and settings used for encoding',
		'TXXX' => 'User defined text information frame',
		'TYER' => 'Year',
		'UFID' => 'Unique file identifier',
		'USER' => 'Terms of use',
		'USLT' => 'Unsychronized lyric/text transcription',
		'WCOM' => 'Commercial information',
		'WCOP' => 'Copyright/Legal information',
		'WOAF' => 'Official audio file webpage',
		'WOAR' => 'Official artist/performer webpage',
		'WOAS' => 'Official audio source webpage',
		'WORS' => 'Official internet radio station homepage',
		'WPAY' => 'Payment',
		'WPUB' => 'Publishers official webpage',
		'WXXX' => 'User defined URL link frame',
	);
}


__END__

=pod

=back

=head1 TROUBLESHOOTING

If you find a bug, please send me a patch.  If you cannot figure out
why it does not work for you, please put the MP3 file in a place where
I can get it (preferably via FTP) and send me mail regarding where I
can get the file, with a detailed description of the problem.

If I download the file, after debugging the problem I will not keep the
MP3 file if it is not legal for me to have it.  Just let me know if
it is legal for me ot keep it or not.


=head1 TODO

=over 4

=item ID3v2 Support

First go at adding support for reading ID3v2 tags.  Still need to do
more, such as using Compress::Zlib to decompress compressed tags.
But until I see this in use more, I won't bother.  I might not be able
to support Unicode at all, until Perl supports 16-bit Unicode.
If something does not work properly with reading, follow the
instructions above for troubleshooting.

Still need to add support for writing ID3v2 tags, and work on API
a bit.

=back


=head1 HISTORY

=over 4

=item v0.80, Monday, March 6, 2000

Better stripping of bad data (after nulls) in ID3 tags (Dave O'Neill)

Fixed VERSION in get_mp3info to properly return 2 when appropriate.
(Bogdan Surdu)

Added VBR support.  Average bitrate is returned as BITRATE, and
minutes and seconds (MM and SS) should be accurate.
(Andy Waite for pointer to MP3Ext)

Made time calculation better overall.

Made MP3 header validation routines more comprehensive.
(Matthew Sachs for pointer to xmms source)

Changed name to MP3::Info (with wrapper still named MP3::Info).


=item v0.71, Thursday, July 8, 1999

Several fixes to ID3v2 support unpack unsigned instead
of signed, don't bail out after 4096-byte offsets on long ID3v2 headers.
Thanks much to Matthew Sachs.


=item v0.70, Saturday, July 3, 1999

Added preliminary ID3v2 reading support in C<get_mp3tag>.  Thanks much
to Tom Brown.


=item v0.64, Thursday, July 1, 1999

Found bug in checking TRACKNUM parameter, used \d instead of \d+.
Only gives spurious warnings, doesn't affect anything else.

Cleaned up a bit, prepare for impending ID3v2 support.

NOTE: truncate() broken in some builds of ActivePerl (517, maybe
others).  No changes to module to fix problem.  (Brian Goodwin)


=item v0.63, Friday, April 30, 1999

Added ID3v1.1 support. (Trond Michelsen, Pass F. B. Travis)

Added 255 (\xFF) as default genre. (Andrew Phillips)

I think I fixed bug relating to spaces in ID3v2 headers. (Tom Brown)


=item v0.62, Sunday, March 7, 1999

Doc updates.

Fix small unnoticable bug where ID3v2 offset is tag size plus 10,
not just tag size.

Not publickly released.


=item v0.61, Monday, March 1, 1999

Fixed problem of not removing nulls on return from C<get_mp3tag> (was
using spaces for padding before ... now trailing whitespace and
all nulls are removed before returning tag info).

Made tests more extensive (more for my own sanity when making all
these changes than to make sure it works on other platforms and
machines :).


=item v0.60, Sunday, February 28, 1999

Cleaned up a lot of stuff, added more comments, made C<get_mp3info>
much faster and much more reliable, and added recognition of ID3v2
headers.  (Tom Brown)



=item v0.52, Sunday, February 21, 1999

Fixed problem in C<get_mp3tag> that changed value of C<$_> in caller
(Todd Hanneken).


=item v0.51, Saturday, February 20, 1999

Fixed problem with C<%winamp_genres> having the wrong numbers
(Matthew Sachs).


=item v0.50, Friday, February 19, 1999

Added C<remove_mp3tag>.  Addeed VERSION to the hash returned by 
C<get_mp3info>, and fixed a bug where STEREO was not being set correctly.

Export all genre data structures on request.  Added C<use_winamp_genres>
to use WinAmp genres. (Roland Steinbach)

Added a C<$MPEG::MP3Info::try_harder> (C<$MP3::Info::try_harder>) variable
that will try harder to find the MP3 header in a file.  False by default.
Can take a long time to fail, but should find most headers at any offsets
if set to true.

Thanks to Matthew Sachs for his input and fixes, and for mp3tools.


=item v0.20, Saturday, October 17, 1998

Changed name from C<MPEG::MP3Tag> to C<MPEG::MP3Info>, because it does
more than just TAG stuff now.

Made header stuff even more reliable.  Lots of help and testing from
Meng Weng Wong again.  :-)


=item v0.13, Thursday, October 8, 1998

Had some problems with header verification, got some code from
Predrag Supurovic with his mpgtools.
Great stuff.  Also did some looping to find a header if it is not in the 
"right" place.  I did what I think it is a smart way to do it, since
some files have the header as far down as 2 kbytes into the file.  First,
I look at position 0, then at position 36 (a position where I have found
many headers), then I start at 0 again and jump in 128-byte chunks.
Once I do that a bunch of times, I go back at the beginning and try at 0
and go ahead in 1-byte chunks for a bunch more times.

If you have an MP3 that has the header begin at an odd place like byte
761, then I suggest you strip out the junk before the header begins. :-)


=item v0.12, Friday, October 2, 1998

Added C<get_mp3info>.  Thanks again to F<mp3tool> source from
Johann Lindvall, because I basically stole it straight (after
converting it from C to Perl, of course).

I did everything I could to find the header info, but if 
anyone has valid MP3 files that are not recognized, or has suggestions
for improvement of the algorithms, let me know.


=item v0.04, Tuesday, September 29, 1998

Changed a few things, replaced a regex with an C<unpack>. 
(Meng Weng Wong)


=item v0.03, Tuesday, September 8, 1998

First public release.

=back

=head1 THANKS

Johann Lindvall,
Meng Weng Wong E<lt>mengwong@pobox.comE<gt>,
Predrag Supurovic E<lt>mpgtools@dv.co.yuE<gt>,
Matthew Sachs E<lt>matthewg@zevils.comE<gt>,
Peter Kovacs E<lt>kovacsp@egr.uri.eduE<gt>,
Roland Steinbach E<lt>roland@support-system.comE<gt>,
Todd Hanneken E<lt>thanneken@hds.harvard.eduE<gt>,
Tom Brown E<lt>thecap@usa.netE<gt>,
Andrew Phillips E<lt>asp@wasteland.orgE<gt>,
Trond Michelsen E<lt>mike@crusaders.noE<gt>,
Pass F. B. Travis E<lt>pftravis@bellsouth.netE<gt>,
Vittorio Bertola E<lt>v.bertola@vitaminic.comE<gt>,
Brian Goodwin E<lt>brian@fuddmain.comE<gt>,
Bogdan Surdu E<lt>tim@go.roE<gt>,
Andy Waite E<lt>andy@mailroute.comE<gt>,
Chris Sidi E<lt>sidi@angband.orgE<gt>,
Luke Drumm E<lt>lukedrumm@mypad.comE<gt>,
Dave O'Neill E<lt>dave@nexus.carleton.caE<gt>,
Edward Allen E<lt>allenej@c51844-a.spokn1.wa.home.comE<gt>.


=head1 AUTHOR AND COPYRIGHT

Chris Nandor E<lt>pudge@pobox.comE<gt>, http://pudge.net/

Copyright (c) 2000 Chris Nandor.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the terms
of the Artistic License, distributed with Perl.


=head1 SEE ALSO

=over 4

=item mp3tools

	http://www.zevils.com/linux/mp3tools/

=item mpgtools

	http://www.dv.co.yu/mp3list/mpgtools.htm
	http://www.dv.co.yu/mp3list/mpeghdr.htm

=item mp3tool

	http://www.dtek.chalmers.se/~d2linjo/mp3/mp3tool.html

=item ID3v2

	http://www.id3.org/

=item Xing Variable Bitrate

	http://www.xingtech.com/support/partner_developer/mp3/vbr_sdk/

=item MP3Ext

	http://rupert.informatik.uni-stuttgart.de/~mutschml/MP3ext/

=item Xmms

	http://www.xmms.org/


=back

=head1 VERSION

v0.80, Monday, March 6, 2000

=cut
