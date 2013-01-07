#!/usr/bin/perl

$|++;

use lib "/home/ranger/cvs/Radio";
use Radio;

my $station = Radio->new(
  password     => 'dip0903',
  description  => 'Defiance Radio at http://defiance.dyndns.org/mp3s/',
  port         => '8004',
  icy_password => 'M0nkey',
  name         => 'Defiance Radio',
  url          => 'http://defiance.dyndns.org/mp3s/',
  icy_compat   => 0,
);

$station->connect(24, '24kbps') or die "could not connect.\n";
$station->connect(96, '96kbps') or die "could not connect.\n";

my $count = 0;

while (my $song = $station->next() and $count < 5) {

  print "-" x 78, "\n";

  $station->open($song);
  my $now = time;

  while (not $station->finished()) {
    my $secs    = time - $now;
    my $percent = ($secs / $song->{length} * 100);

    if ($percent < 100) {
      print "\rPlaying $song->{song_name} (", $station->format_length($song->{length}), ")... ";
      printf("%2.2f%%", $percent);
    }
  }

  print "Song done.\n";

  $station->close();

  $count++;
}

$station->disconnect('96kbps');
$station->disconnect('24kbps');

# all done
