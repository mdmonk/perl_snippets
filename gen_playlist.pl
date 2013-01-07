use MP3::ID3v1Tag;
use File::Find;
use Cwd;

use vars qw(

  $topDirectory
  $playlistDirectory
  $parseDirectory

  $mp3s

  @categories

  $format_album
  $format_artist
  $format_title
  $format_comment
  $format_year
  $format_genre
  $format_filename

);

$|++;

$playlistDirectory = $ARGV[1] || 'D:\Data\Playlists';
$topDirectory      = $ARGV[0] || 'D:\Data\Music';
@categories        = ('Artist', 'Year', 'Genre');
chdir($topDirectory);
$topDirectory = cwd();


find(\&wanted, $topDirectory);
print "\n";

for my $cat (@categories) {
  parse_by_category(lc($cat));
}

sub parse_by_category {
  my $category = shift;

  open (ALL, ">$playlistDirectory\\all.m3u") or die "Cannot open \"$playlistDirectory\\all.m3u\" for writing: $!\n" if ($category eq "artist");
  print ALL "#EXTM3U\n" if ($category eq "artist");

  print "[W] Category \"$category\"\n";

  for my $cat (sort keys %{$mp3s->{$category}}) {

    if ($cat ne "") {

      my $lastCat;
      my $catCount = 1;

      mkdir "$playlistDirectory\\$category";

      $cat   = $mp3s->{$category}->{$cat};
      delete   $mp3s->{$category}->{$cat};

      my @tracks = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, $_->{title} ] } @{$cat};
      undef $cat;

      for my $entry (@tracks) {
        if ($lastCat ne $entry->{$category}) {
          $filename = $entry->{$category};
          close (FILEOUT);
          open (FILEOUT, ">$playlistDirectory\\$category\\$filename\.m3u") or die "Cannot open \"$playlistDirectory\\$category\\$filename.m3u\" for writing: $!\n";
          print FILEOUT "#EXTM3U\n";
          $lastCat = $entry->{$category};
          $catCount = 1;
        }
        $entry->{filename} =~ s/\//\\/g;
        print FILEOUT $entry->{filename}, "\n";
        print ALL     $entry->{filename}, "\n" if ($category eq "artist");
        $catCount++;
      }

      close (FILEOUT);

    }
  }

  close (ALL) if ($category eq "artist");

}
sub wanted {

  if ($File::Find::name =~ /\.mp3$/) {

    my $name   =  $File::Find::name;
    my $file   =  MP3::ID3v1Tag->new($name);
    my $values;

    for ($file->tag) {
      $values->{$_} = $file->tag($_);
      $values->{$_} = "Unknown" if ($file->tag($_) eq "");
    }

    $values->{filename} =  $name;
    $values->{filename} =~ s/ /_/g;

    if ($parseDirectory ne $File::Find::dir) {
      $parseDirectory = $File::Find::dir;
      print "\n", substr("\r[R] " . $File::Find::dir . " " x 50, 0, 50), " ";
    }

    print ".";

    push(@{$mp3s->{title}->{$file->tag('title')}}, $values);
    push(@{$mp3s->{artist}->{$file->tag('artist')}}, $values);
    push(@{$mp3s->{year}->{$file->tag('year')}},   $values);
    push(@{$mp3s->{genre}->{$file->tag('genre')}}, $values);

  }
}