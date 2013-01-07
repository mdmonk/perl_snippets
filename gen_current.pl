<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD>
<META content="text/html; charset=windows-1252" http-equiv=Content-Type></HEAD>
<BODY><XMP>#!/usr/bin/perl

$|++;

use vars qw(
  $currentAge
  $lastAge
  $currentHour
  $lastHour

  $id3file
  $id3info

  $current
  $playing
  $played
  $mp3stat

  $font
  $hr
);

use Memoize;
memoize('parse_file');

$id3file = "/home/ftp/pub/Music/id3info.txt";

$current = "/home/ftp/pub/Music/current.html";
$playing = "/home/ftp/pub/Music/playing.html";
$played  = "http://defiance.bennet:8000/played.html";
$mp3stat = "/usr/local/bin/mp3stat";

$font    = "font face=\"Tahoma, Verdana, Arial, sans-serif\"";
$hr      = "hr noshade size=\"1\" color=\"#006363\"";

while (1) {
  my $entry;
  my $buffer;

  (undef, undef, $currentHour) = localtime(time);
  if ($currentHour != $lastHour or $lastHour eq "") {
    $id3info = get_id3s($id3file);
    $lastHour = $currentHour;
  }

  $currentAge = -M $playing;
  next if ($currentAge == $lastAge);

  # playing.html is updated, build a new file.
  $lastAge = $currentAge;

  # read in playing.html and parse for artist and title, and then populate $entry
  open (PLAYING, $playing) or warn "WARNING: unable to open playing.html for reading: $!\n";
  while (<PLAYING>) {
    if (/^.*?<\!-- BEGIN -->(.*?) - (.*)<\!-- END -->\r?\n?$/) {
      $entry = get_song($1, $2);
    }
  }

  $buffer = <<END;
<html>
 <head>
  <title>
   Alloy - MP3, RealAudio, and Module Music
  </title>
  <meta name="description" content="MP3, RealAudio, and module music by Alloy.">
  <meta name="keywords" content="mp3, real, audio, ra, stream, module, it, alloy, music, audio, ranger rick">
  <meta http-equiv="Refresh" content="300">
  <SCRIPT LANGUAGE="JavaScript" SRC="http://www.live365.com/scripts/listen.js"></SCRIPT>
 </head>
 <body bgcolor="#000000" text="#ffffff" link="#66ffff" vlink="#22ffff" alink="#ffffff">
  <base href="http://defiance.dyndns.org/">
  <table width="100%" border="0" cellpadding="2" cellspacing="0">
   <tr bgcolor="#006363">
    <td align="left" valign="middle">
     <a href="/"><img src="pics/alloy.gif" alt="MP3, RealAudio, and module music by Alloy" border="0"></a>
     <br>
     <$font color="#ffffff">
      View the <a href="faq.html">IAQBRRIALANOVHS</a>.
      <br>
     </font>
    </td>
    <td align="right" valign="middle">
     <!-- BEGIN LINKEXCHANGE CODE --> 
      <center><iframe src="http://leader.linkexchange.com/3/X16758/showiframe?" width=468 height=60 marginwidth=0 marginheight=0 hspace=0 vspace=0 frameborder=0 scrolling=no>
      <a href="http://leader.linkexchange.com/3/X16758/clickle" target="_top"><img width=468 height=60 border=0 ismap alt="" src="http://leader.linkexchange.com/3/X16758/showle?"></a></iframe><br><a href="http://leader.linkexchange.com/3/X16758/clicklogo" target="_top"><img src="http://leader.linkexchange.com/3/X16758/showlogo?" width=468 height=16 border=0 ismap alt=""></a><br></center>
     <!-- END LINKEXCHANGE CODE -->
    </td>
   </tr>
  </table>
  <p>
  <$font size="2">
   <center>
    - page refreshes every 5 minutes, content is updated every 20 seconds - less funky at 800x600 or higher :) -
   </center>
   <br>
   <table align="right" border="0" cellpadding="3" cellspacing="1" bgcolor="#338888" width="300">
    <tr>
     <td colspan="2" align="center">
      <b>Last 10 Songs Played</b>
     </td>
    </tr>
END

  for my $previous (get_last()) {
    my $spacer = '&nbsp;&nbsp;&nbsp;';
    $buffer .= <<END;
    <tr bgcolor="#006363">
     <td valign="top" align="left">
      <font face="Arial Narrow,sans-serif" size="2">$previous->{timeplayed}</font>
     </td>
     <td valign="top" align="left">
      <font face="Arial Narrow,sans-serif" size="2">
END

    $buffer .= "       <b>$previous->{title}</b>";
    $buffer .= " [$previous->{length}]"               if ($previous->{length} ne "");
    $buffer .= "\n";

    $buffer .= "       <br>\n       $spacer ";
    $buffer .= "<a href=\"$previous->{album_link}\">" if ($previous->{album_link} ne "");
    $buffer .= "$previous->{artist}";
    $buffer .= "</a>"                                 if ($previous->{album_link} ne "");
    $buffer .=        ", $previous->{year}"           if ($previous->{year} != 0);
    $buffer .= "\n       <br>\n";

    $buffer .= "       $spacer $previous->{album}";
    $buffer .= "\n";

    $buffer .= <<END;
       <br>
      </font>
     </td>
    </tr>
END

  }

  $buffer .= <<END;
   </table>
   <br>
   <$font size="+2">
    <b>Welcome to Defiance Radio</b>
   </font>
   <p>
   <font size="+1">
    Tune in now:
    [<a href='javascript:LaunchBroadcast("rangerrick")'>96kbps</a>]
    [<a href='javascript:LaunchBroadcast("rangerrick_low")'>24kbps</a>]
    <p>
    <$hr>
END

  $buffer .= <<END;
    <table>
     <tr>
      <td align="center" valign="top">
END

  $buffer .= "       <a href=\"$entry->{album_link}\">" if ($entry->{album_link} ne "");
  $buffer .= "<img src=\"$entry->{cover}\" alt=\"$entry->{artist} - $entry->{album}\" width=\"170\" height=\"170\" hspace=\"5\" border=\"0\">" if ($entry->{cover} ne "");
  $buffer .= "</a>" if ($entry->{album_link} ne "");
  $buffer .= "\n" if ($entry->{cover} ne "");

  $buffer .= <<END;
       &nbsp;&nbsp;
      </td>
      <td align="left" valign="middle">
       <$font>
        <font size="+1">
         <b>Currently Playing:</b>
        </font>
        <p>
END

  $buffer .= "        $entry->{title}"                      if ($entry->{title}      ne "");
  $buffer .= " [$entry->{length}]"                          if ($entry->{length}     ne "");
  $buffer .= "\n        <br>\n";

  $buffer .= "        By "                                  if ($entry->{artist}     ne "");
  $buffer .= "<a href=\"$entry->{album_link}\">"            if ($entry->{album_link} ne "");
  $buffer .= $entry->{artist}                               if ($entry->{artist}     ne "");
  $buffer .= "</a>"                                         if ($entry->{album_link} ne "");
  $buffer .= "\n"                                           if ($entry->{artist}     ne "");

  $buffer .= "        <br>\n        From '$entry->{album}'" if ($entry->{album}      ne "");
  $buffer .= ", $entry->{year}"                             if ($entry->{year}       != 0);

  $buffer .= <<END;
       </font>
      </td>
     </tr>
    </table>
    <p>
END

  my @songs = (sort keys %{$id3info->{$entry->{artist}}});
  my $count = 0;

  if ($entry->{album} ne "") {
    $buffer .= <<END;
    <$hr>
    <font size="+1">
     <b>Other songs from '$entry->{album}' by '$entry->{artist}' in the archive:</b>
    </font>
    <blockquote>
     <font size="-1">
END

    for my $song (@songs) {
      if ($id3info->{$entry->{artist}}->{$song}->{album} eq $entry->{album} and $id3info->{$entry->{artist}}->{$song}->{title} ne $entry->{title}) {
        $buffer .= "      " . $id3info->{$entry->{artist}}->{$song}->{title} . "<br>\n";
        $count++;
      }
    }

    $buffer .= "     (None Found)<br>\n" if (not $count);

    $buffer .= <<END;
     </font>
    </blockquote>
    <p>
END

  }

  $buffer .= <<END;
    <$hr>
    <font size="+1">
     <b>Other CDs containing the artist '$entry->{artist}' in the archive:</b>
    </font>
    <blockquote>
     <font size="-1">
END

  my $albums;
  for my $song (@songs) {
    $song = $id3info->{$entry->{artist}}->{$song};
    if ($song->{album} ne $entry->{album}) {
      $albums->{$song->{album}}->{tracks}++;
      $albums->{$song->{album}}->{artist} = $song->{artist};
    }
  }

  $count = 0;
  for my $album (sort keys %{$albums}) {
    $buffer .= "      $album ";
    $buffer .= "(by $albums->{$album}->{artist}) " if ($albums->{$album}->{artist} ne $entry->{artist});
    $buffer .= "- $albums->{$album}->{tracks} track(s)<br>\n";
    $count++;
  }

  $buffer .= "     (None Found)<br>\n" if (not $count);

  $buffer .= <<END;
    </font>
   </blockquote>
  </font>
 </body>
</html>
END

  if ($entry->{title} !~ /^\s*$/ and $entry->{artist} !~ /^\s*$/) {
    date_print("writing file... ");
    open (CURRENT, ">$current") or warn "WARNING: unable to open $current for writing: $!\n";
    print CURRENT $buffer;
    close (CURRENT);
    print "done.\n";
  }

  exit;

  sleep 5;

}

sub get_song {
  my $artist = shift;
  my $song   = shift;
  my $entry;

  if (defined $id3info->{$artist}->{$song}) {
    $entry = $id3info->{$artist}->{$song};
    my $extra = parse_file($entry->{filename});
    for my $key (keys %{$extra}) {
      $entry->{$key} = $extra->{$key};
    }
  } else {
    $entry->{artist} = $artist;
    $entry->{title}  = $song;
  }

#  if ($entry->{filename} ne "") {
#    my $command = "$mp3stat \"/home/ftp$entry->{directory}/$entry->{filename}\"";
#    chomp($entry->{length} = `$command`);
#    my $mins = int($entry->{length} / 60);
#    my $secs = $entry->{length} - ($mins * 60);
#    $entry->{length} = $mins . ":" . sprintf("%02d", $secs);
#  }

  return $entry;
}

sub get_last {
  my $file;
  my @return;

  if (open (LAST, "/usr/bin/lynx -dump -source $played|")) {
    while (<LAST>) {
      $file .= $_;
    }
    close (LAST);
  }

  $file =~ s/<\/tr>/<\/tr>\n/g;
  for my $line (split(/\n/, $file)) {
    next if $line =~ m#<td><b>Current Song</b></td>#;
    if ($line =~ m#<tr><td>(\d+:\d+:\d+)</td><td>(.*?) - (.*)</tr>#) {
      my ($time, $artist, $song) = ($1, $2, $3);
      my $entry = get_song($artist, $song);
      $entry->{timeplayed} = $time;
      push(@return, $entry);
    }
  }

  return @return;
}

sub get_id3s {
  my $id3file = shift;
  my $id3s;

  date_print("scanning id3 tags... ");

  open (FILEIN, $id3file) or die "cannot open id3info.txt for reading: $!\n";
  while (<FILEIN>) {
    chomp;
    my @values = split(/\#\#\#/);
    my $entry;
    for my $key (@values) {
      $key =~ /^(.*?)\:(.*)$/;
      $entry->{$1} = $2;
    }
    $id3s->{$entry->{artist}}->{$entry->{title}} = $entry;
  }

  print "done.\n";

  return $id3s;
}

sub parse_file {
  my $filename = shift;
  #my $cover;
  #my $songnum;
  #my $albumLink;
  #my $lyrics;

  my $return;

  date_print("getting extended info for $filename... ");

  $filename            = "\\pub" . $filename;
  my @directory        = split(/\\/, $filename);
  $return->{filename}  = pop(@directory);
  $return->{directory} = join('/', @directory);

  if (-s "/home/ftp$return->{directory}/cover.jpg") {
    $return->{cover} = "$return->{directory}/cover.jpg";
  }
  if (-s "/home/ftp$return->{directory}/cover.gif") {
    $return->{cover} = "$return->{directory}/cover.gif";
  }

  if (-s "/home/ftp$return->{directory}/tracks.txt") {
    open (TRACKS, "/home/ftp$return->{directory}/tracks.txt") or die "cannot open tracks.txt for reading: $!\n";
    while (my $line = <TRACKS>) {
      chomp;
      my ($num, $songname, $lyr) = split(/\s+/, $line);
      if ($songname eq $filename) {
        $return->{lyrics}  = $lyr;
        $return->{songnum} = $num if ($num != 0);
      }
      if ($line =~ /^\S+$/) {
        $return->{album_link} = $line;
      }
    }
    close (TRACKS);
  }

  for my $key (keys %{$return}) {
    chomp($return->{$key});
  }

  print "done.\n";

  return $return;
}

sub date_print ($) {
  my $printme = shift;
  return print "[" . localtime(time) . "] ", $printme;
}
</XMP></BODY></HTML>
