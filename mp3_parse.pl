#!/usr/bin/perl

use MP3::ID3v1Tag;
use MP3::Info qw(:all);
use Term::ReadLine;
use Term::ReadKey;
use Term::ANSIColor qw(:constants);

use vars qw(

  $topDirectory
  $attribs
  $commands
  $term
  $prompt

  $format_album
  $format_artist
  $format_title
  $format_comment
  $format_year
  $format_genre
  $format_filename

);

$Term::ANSIColor::AUTORESET = 1;
#$topDirectory               = 'D:\Data\Music';
$topDirectory               = '/DG/Music/beam-back';

$attribs = {
  'ANSI'      => [0,             "Use ANSI Color? (Yes/No)"],
  'DIRECTORY' => [$topDirectory, 0],
  'LINES'     => [25,            "Number of lines on your screen."],
};

$commands = {
  'QUIT'  => [\&quitApplication, "Exits the application."],
  'EXIT'  => [\&quitApplication, "Alias for 'quit'."],
  'HELP'  => [\&printHelp,       "Shows this message."],
  'LS'    => [\&showDirectory,   "Prints a listing of the current directory."],
  'DIR'   => [\&showDirectory,   "Alias for 'ls'."],
  'CD'    => [\&changeDirectory, "Change the current directory.  (supports partial matches)"],
  'SET'   => [\&setAttribute,    "Change settings."],
  'GET'   => [\&getInfo,         "Get info on an MP3 file."],
  'PUT'   => [\&putInfo,         "Set info on an MP3 file."],
};

$term   = Term::ReadLine->new('Test MP3 Editor');
$prompt = "\n[$attribs->{DIRECTORY}->[0]] ";

$OUT = $term->OUT || STDOUT;
while ( defined (my $line = $term->readline($prompt)) ) {
  $line =~ /^\s*(\S*)\s*(.*)\s*$/;

  my $command = uc($1);
  my @vars    = split(/\s+/, $2);

  if (defined $commands->{$command}) {
    &{$commands->{$command}[0]}(@vars);
  } else {
    print $OUT "$command: Unknown command.\n";
  }

  if ($line =~ /\S/) {
    $term->addhistory($line);
  }

  $prompt = ($attribs->{ANSI}->[0] ? BOLD . BLUE . "\n[$attribs->{DIRECTORY}->[0]] " : "\n[$attribs->{DIRECTORY}->[0]] ");

}

sub quitApplication {
  my @vars = @_;

  exit;

}

sub printHelp {
  my @vars = @_;

  if ($vars[0] ne "" and grep(uc($vars[0]), keys %{$commands})) {

    if ($vars[0] =~ /^set$/i) {
      print $OUT "Set an attribute value.  Valid attributes are:\n\n";

      for my $attribute (sort keys %{$attribs}) {
        if ($attribs->{$attribute}->[1]) {
          print $OUT "  ", substr($attribute . " " x 10, 0, 10), ": ", $attribs->{$attribute}->[1], "\n";
        }
      }
    } else {
      print $OUT uc($vars[0]), ": ", $commands->{uc($vars[0])}->[1], "\n";
    }

  } else {

    print $OUT "These are valid (case-insensitive) commands:\n\n";

    for my $command (sort keys %{$commands}) {
      if ($commands->{$command}->[1]) {
        print $OUT "  ", substr($command . " " x 10, 0, 10), ": ", $commands->{$command}->[1], "\n";
      }
    }
  }

  1;
}

sub showDirectory {
  my @vars = @_;
  my $firstCall = 1;
  my $lineCount = 0;

  (print "Current directory is \"$attribs->{DIRECTORY}->[0]\":\n" and $lineCount++) if ($vars[0] eq "");

  opendir(DIR, $attribs->{DIRECTORY}->[0]) or die "Cannot open $directory for reading: $!\n";
  my @files = readdir(DIR);
  closedir(DIR);

  @files = map { $_->[0] } sort { $b->[1] cmp $a->[1] } map { [ $_, -d $_ ] } sort @files;

  for my $file (@files) {

    if ($lineCount >= ($attribs->{LINES}->[0] - 2)) {
      $lineCount = 0;
      last if more($firstCall);
      $firstCall = 0;
    }

    $dirShow = "[N/A]";
    $dirShow = "[MP3]" if ($file =~ /\.mp3$/i);
    $dirShow = "[DIR]" if (-d $attribs->{DIRECTORY}->[0] . "\\" . $file);

    $file =~ s/_/ /g;

    print $OUT $dirShow, "   ", $file, "\n" and $lineCount++;
  }

  1;
}

sub changeDirectory {
  my $dir    =  join(' ', @_);
     $dir    =~ s/ /_/g;
  my $newdir =  $attribs->{DIRECTORY}->[0];

  opendir(DIR, $newdir) or die "Cannot open $newdir for reading: $!\n";
  my @files = grep(/^$dir/i, readdir(DIR));
  closedir(DIR);

  if (@files == 1) {
    $dir = $files[0];
  } elsif (@files > 1 and $dir ne "" and $dir !~ /^\.\.?$/) {
    my $temp =  join("\", \"", @files);
       $temp =~ s/\,\" (.*?)$/\, and $1/;
       $temp =  "\"" . $temp . "\"";
    print $OUT "Ambiguous file name \"$dir\" matches:\n  $temp.\n";
    return;
  }

  if ($dir eq "") {
    print $OUT "Current directory is $newdir\n";
  } else {
    if (-d "$newdir\\$dir") {
      if ($dir eq "..") {
        
        my @parts = split(/\\/, $newdir);
        $newdir = join('\\', @parts[0..$#parts-1]);
      } elsif ($dir eq ".") {
      } else {
        $newdir .= "\\$dir";
      }
    } else {
      print $OUT "$newdir\\$dir does not exist or is not a directory!\n";
    }
    my $temp =  $topDirectory;
       $temp =~ s/([\\\.\:])/\\$1/g;
    if ($newdir =~ /^$temp/) {
      $attribs->{DIRECTORY}->[0] = $newdir;
    } else {
      print $OUT "You cannot change to \"$newdir\"!!\n";
    }
    print $OUT "Current directory is \"$attribs->{DIRECTORY}->[0]\".\n";
  }
  1;
}
sub setAttribute {
  my @vars = @_;
  @vars    = split(/=/, $vars[0]) if (not $vars[1] and $vars[0] =~ /=/);
  $vars[0] = uc($vars[0]);
  $vars[1] = "1" if ($vars[1] =~ /^(true|on|yes)$/i);
  $vars[1] = "0" if ($vars[1] =~ /^(false|off|no)$/i);

  if ($vars[0] ne "") {

    print $OUT "Setting $vars[0] to $vars[1]\n";
    $attribs->{$vars[0]}->[0] = $vars[1];

  } else {

    print $OUT "Current Settings:\n\n";
    for my $attribute (sort keys %{$attribs}) {
      if ($attribs->{$attribute}->[1]) {
        print $OUT "  ", substr($attribute . " " x 10, 0, 10), ": ", $attribs->{$attribute}->[0], "\n";
      }
    }
  }

  1;
}

sub getInfo {
  my $dir       =  join(" ", @_);
  my $firstCall =  1;
  $dir          =~ s/ /_/g;
  $dir          =~ s/\s*\*\s*//g;
  $dir          =~ s/^all$//g;
  my $artist    =  (split(/\\/, $attribs->{DIRECTORY}->[0]))[3];

  opendir(DIR, $attribs->{DIRECTORY}->[0]) or die "Cannot open $newdir for reading: $!\n";
  my @files = grep(!/^\.\.?$/, readdir(DIR));
  my @match = grep(/^($dir|${artist}_\-_$dir)/i, @files);
  closedir(DIR);

  if (@match == 1) {
    $dir = $match[0];
  } elsif (@match > 1 and $dir ne "") {
    print $OUT "Ambiguous query: \"$dir\".\n";
  }

  my $fileName = "$attribs->{DIRECTORY}->[0]\\$dir";

  if (-e $fileName and $dir ne "") {

    my $file = MP3::ID3v1Tag->new($fileName);
    $format_filename = $dir;
    $format_title    = $file->get_title();
    $format_artist   = $file->get_artist();
    $format_album    = $file->get_album();
    $format_year     = $file->get_year();
    $format_genre    = $file->get_genre();
    $format_comment  = $file->get_comment();

    print $OUT <<END;
Filename: $format_filename
Title:    $format_title
Artist:   $format_artist
Album:    $format_album
Year:     $format_year
Genre:    $format_genre
Comment:  $format_comment
END

  } elsif ($dir eq "") {

    my $num = int(int(int($attribs->{LINES}->[0]) - 1) / 5);
    my $lineCount = 0;

    for my $mp3 (@files) {

      if ($lineCount >= $num) {
        $lineCount = 0;
#        last if more($firstCall);
        last if more();
        $firstCall = 0;
      }

      my $file         = MP3::ID3v1Tag->new("$attribs->{DIRECTORY}->[0]\\$mp3");
      $format_filename = $mp3;
      $format_title    = $file->get_title();
      $format_artist   = $file->get_artist();
      $format_album    = $file->get_album();
      $format_year     = $file->get_year();
      $format_genre    = $file->get_genre();
      $format_comment  = $file->get_comment();
      write;
      $lineCount++;
    }

  } else {

    print $OUT "File \"$dir\" does not exist.\n";

  }

  1;
}

sub putInfo {
  my $object       =  join(" ", @_);
  my $firstCall    =  1;
  my $artist       =  (split(/\\/, $attribs->{DIRECTORY}->[0]))[3];

  if ($object      =~ /^\s*(\".+?\"|\S+?)\s+\"?(title|artist|album|year|genre|comment)\"?(?:\s+(\".+?\"|.+?)\s*)?$/i) {

    my $filename   =  lc($1);
    my $keyword    =  lc($2);
    my $value      =  $3;

    $filename      =~ s/^\"(.*)\"$/$1/;
    $keyword       =~ s/^\"(.*)\"$/$1/;
    $value         =~ s/^\"(.*)\"$/$1/;

    $filename =~ s/ /_/g;
    $filename =~ s/^\s*\*\s*$//g;
    $filename =~ s/^all$//g;

    print "\$filename = \"$filename\", \$keyword = \"$keyword\", \$value = \"$value\"\n";

    opendir(DIR, $attribs->{DIRECTORY}->[0]) or die "Cannot open $attribs->{DIRECTORY}->[0] for reading: $!\n";
    my @files = grep(!/^\.\.?$/, readdir(DIR));
    my @match = grep(/^($filename|${artist}_\-_$filename)/i, @files);
    closedir(DIR);

    if (@match == 1) {
      $filename = $match[0];
    } elsif (@match > 1 and $filename ne "") {
      print $OUT "Ambiguous file name: \"$filename\".\n";
    }

    @match = ($filename) if ($filename ne "");
    use_winamp_genres();

    if ($keyword eq "genre" and not -d "$attribs->{DIRECTORY}->[0]\\$match[0]" and $value eq "") {
      my $file = MP3::ID3v1Tag->new("$attribs->{DIRECTORY}->[0]\\$match[0]");
      my $count;

      for my $genre (@mp3_genres) {
        if ($lineCount >= ($attribs->{LINES}->[0] - 1)) {
          $lineCount = 0;
          last if more($firstCall);
          $firstCall = 0;
        }
        print $OUT (substr($count++ . "    ", 0, 3)) . ": $genre\n" and $lineCount++;
      }

#      $file->print_genre_chart();
      print $OUT "Enter genre: ";
      chomp(my $input = <STDIN>);
      print $OUT "\n";
      $keyword = "genre";
      $value   = $input;
#       return;
    }

    $value = $mp3_genres[$value] if ($keyword eq "genre");

    for my $mp3 (@match) {
      my $file = MP3::ID3v1Tag->new("$attribs->{DIRECTORY}->[0]\\$mp3");
      my $currentValue;
      my $return;
      eval("\$currentValue = \$file->get_$keyword(\$value);");
      print $OUT "Changing $keyword on $mp3 from \"$currentValue\" to \"$value\"\n";
      my $tag = get_mp3tag("$attribs->{DIRECTORY}->[0]\\$mp3");
      $tag->{uc($keyword)} = $value;
      $return = set_mp3tag("$attribs->{DIRECTORY}->[0]\\$mp3", $tag);
#      print("\$file->set_$keyword(\$value);\n");
#      eval("\$return = \$file->set_$keyword(\$value);");
#      print "Returned $return.\n";
    }

  } else {
    print $OUT "Unable to parse \"$object\".  No such file name and/or tag found.\n";
    return;
  }


  1;
}

sub more {
  my $firstCall = shift;
  ReadMode 4;
  $key = ReadKey(0) if ($firstCall);
  print $OUT "--MORE--";
  while (not defined ($key = ReadKey(0))) { }
  ReadMode 0;
  print $OUT "\r        \r";
  if ($key =~ /q/i) {
    return 1;
  } else {
    return 0;
  }
  return 0;
}

format STDOUT =
-----------------------------------------------------------------------------
File: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$format_filename
Title: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Year: @<<<< Genre: @<<<<<<<<<<<<<<<<<<
$format_title, $format_year, $format_genre
Artist: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Album: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$format_artist, $format_album
Comment: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$format_comment
.

for my $artist (sort @artists) {
  $displayArtist =  $artist;
  $displayArtist =~ s/_/ /g;

  next if $artist eq "output.txt";
  next if $artist eq "parse.pl";

  opendir(DIR, "$directory\\$artist") or die "Cannot open $directory\\$artist for reading: $!\n";
  my @albums = grep( !/^\.\.?$/, readdir(DIR));
  closedir(DIR);

  for my $album (sort @albums) {
    $displayAlbum =  $album;
    $displayAlbum =~ s/_/ /g;

    opendir(DIR, "$directory\\$artist\\$album") or die "Cannot open $directory\\$artist\\$album for reading: $!\n";
    my @songs = grep ( !/^\.\.?$/, readdir(DIR));
    closedir(DIR);

    print "$displayArtist / $displayAlbum\n";



#    for my $song (sort @songs) {
#    }
  }
}

