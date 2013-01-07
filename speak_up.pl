#!/usr/bin/perl

# speak_up by Ryan Wyler <ryan at wyler.net>
#
# Purpose:  Have your Mac with OSX read the news to you
#
# Background: I have been playing with XML lately and had an XML writer I wrote.
#             I started looking for a creative alarm clock and I remembered playing
#             around with wget and apple's speak engine not too long ago so I thought
#             they'd be a perfect match made in heaven.  wget + xml + say = not much
#
# Requirements: o You need wget on your system.  Update the $wget variable with the
#                 correct path if it's not /usr/local/bin/wget
#                 You can get WGET from here: http://fink.sourceforge.net/pdb/package.php/wget
#                 Or you can get WGET from here: http://www.gnu.org/software/wget/wget.html
#               o You need the XML::Simple perl module installed
#                 To do this type the following commands
#                 sudo perl -MCPAN -eshell # (this will give you a "cpan>" prompt)
#                 install Bundle::CPAN
#                 reload cpan
#                 install XML::SAX
#                 install XML::Simple
#             
#
# INSTALLATION: o Once you have wget installed you pretty much just fire up this script,
#                 but you should continue reading the installation cause it might give
#                 you some ideas for you to try.
#               o You should go into the 'speech' section in System Preferences to
#                 pick a voice that better suites you.
#               o Since I was looking for an alarm clock when I wrote this script
#                 I played around with thowing this script in cron to kick off at
#                 7:15 in the morning monday - friday.  To do that type 'crontab -e'
#                 in the terminal and put this line in there:
#
#                 15 7 * * 1,2,3,4,5 /Users/ryan/speak_up >/dev/null 2>&1
#
#                 The only problem with doing this is the only way I could quit the
#                 script if it was buggin me was to be awake enough to kill the pid
#                 of the perl script running.  So I wrote it so you can exit the
#                 script by touching a file:  $ touch /tmp/speak_up.exit
#                 You touch that file and the script will exit once it's done saying
#                 the current line.
#
#                 I also wrote a way to pause the reading incase the phone rang or whatever.
#                 just touch the file /tmp/speak_up.pause and it'll pause reading.
#
#               o You can also have different news sites kick off at different times
#                 using 'crontab -e' again with the following examples.
#
#  # kick off slashdot at 8am
#  0 8 * * 1,2,3,4,5 /Users/ryan/speak_up http://slashdot.org/slashdot.rss >/dev/null 2>&1
#  # kick off yahoo top stories at 9am
#  0 9 * * 1,2,3,4,5 /Users/ryan/speak_up http://rss.news.yahoo.com/rss/topstories >/dev/null 2>&1
#  # kick off macosxhints once you're more awake
#  0 15 * * 1,2,3,4,5 /Users/ryan/speak_up http://www.macosxhints.com/backend/geeklog.rdf >/dev/null 2>&1
#

use strict;
use XML::Simple;

my ($ref, $wget, $rss, $temp_xml, $exit_file, $pause_file, $say);
my (@speak_tags, %speak_elements);

# PUT your correct path to WGET here
$wget = "/usr/local/bin/wget";

# Here you put what RSS feed you want to read
# you can get a list of the yahoo RSS feeds here:
# http://rss.news.yahoo.com/rss
# $rss = "http://rss.news.yahoo.com/rss/topstories";
# $rss = "http://rss.news.yahoo.com/rss/tech";
# $rss = "http://www.macosxhints.com/backend/geeklog.rdf";
$rss = "http://slashdot.org/slashdot.rss";

if ($ARGV[0] ne "") {
	if ($ARGV[0] =~ m/^http:\/\//i) {
		$rss = $ARGV[0];
	} else {
		print "usage: $0 [url to rss feed optional]\n";
		clean_temp_file();
		exit(1);
	}
}

# Here you need to put which elements in the XML you want to speak.
# I have it speaking the TITLE and DESCRIPTION of the yahoo rss xml feeds
# You can change this all you want but you need to have
# TWO elements for each tag you want it to speak
# the TAG and what the voice says before it speaks that section.

# for example .... 
# push (@speak_tags,"XMLTAG","What the voice says, ");

push (@speak_tags,"title","The headline, ");
push (@speak_tags,"description","Description, ");

# In the yahoo RSS feeds you pretty much just want to speak things
# which are in the item tags.  You can configure that by adding
# more things to this hash.
$speak_elements{item} = {};

# the temp files speak_up uses
$temp_xml = "/tmp/speak_up.xml";
$exit_file = "/tmp/speak_up.exit";
$pause_file = "/tmp/speak_up.pause";

# SAY should be in /usr/bin/say
$say = "/usr/bin/say";

sub get_attributes {
	my ($ref) = @_;
	my ($return);

	if (ref($ref) eq "HASH") {
		my ($key);
		foreach $key (keys(%{$ref})) {
			unless(ref($ref->{$key})) {
				$return->{$key} = $ref->{$key};
			}
		}
	}
	return($return);
}

sub get_arrays {
	my ($ref) = @_;
	my ($return);

	if (ref($ref) eq "HASH") {
		my ($key);
		foreach $key (keys(%{$ref})) {
			if (ref($ref->{$key}) eq "ARRAY") {
				$return->{$key} = $ref->{$key};
			} elsif (ref($ref->{$key}) eq "HASH") {
				$return->{$key} = $ref->{$key};
			}
		}
	}
	return($return);
}

sub clean_xml {
	my ($text);
	$text = $_[0];
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/&/&amp;/g;
	$text =~ s/"/&quot;/g;
	$text =~ s/'/&apos;/g;
	return($text);
}

sub check_status {
	if (-f $exit_file) {
		print "Exit file found, exiting\n";
		clean_temp_file();
		exit(1);
	}
	while(-f $pause_file) {
		print "Pause file found, waiting\n";
		sleep 10;
	}
}

# I've never actually done this before, but I think it's right
sub by_title_then_description {
	$b cmp $a;
}

sub speak_xml {
	my ($ref,$tag,%read_lines,@send_read_lines);
	$ref = $_[0];
	shift (@_);

	while(@_) {
		$read_lines{$_[0]} = $_[1];
		push(@send_read_lines,$_[0],$_[1]);
		shift @_;
		shift @_;
	}

	foreach $tag (keys(%{$ref})) {
		check_status();
		if (ref($ref->{$tag}) eq "HASH") {
			my ($attributes, $attribute);
			my ($arrays, $hashs);
			$attributes = get_attributes($ref->{$tag});
			$arrays = get_arrays($ref->{$tag});
			foreach $attribute (sort by_title_then_description(keys(%{$attributes}))) {
				check_status();
				if (defined($read_lines{$attribute})) {
					if (defined($speak_elements{$tag})) {
						print "$read_lines{$attribute} $attributes->{$attribute}\n";
						open(SAY,"| $say");
						print SAY "$read_lines{$attribute} $attributes->{$attribute}\n";
						close(SAY);
					}
				}
			}
			if($arrays) {
				speak_xml($arrays,@send_read_lines);
			}
		} elsif (ref($ref->{$tag}) eq "ARRAY") {
			my ($element);
			foreach $element (@{$ref->{$tag}}) {
				check_status();
				if (ref($element) eq "HASH") {
					my ($attributes, $attribute);
					my ($arrays);
					$attributes = get_attributes($element);
					$arrays = get_arrays($element);
					foreach $attribute (sort by_title_then_description(keys(%{$attributes}))) {
						check_status();
						if (defined($read_lines{$attribute})) {
							if (defined($speak_elements{$tag})) {
								print "$read_lines{$attribute} $attributes->{$attribute}\n";
								open(SAY,"| $say");
								print SAY "$read_lines{$attribute} $attributes->{$attribute}\n";
								close(SAY);
							}
						}
					}
					if($arrays) {
						speak_xml($arrays,@send_read_lines);
					}
				}
			}
		}
	}
}


sub clean_temp_file {
	if (-f $temp_xml)  {
		unlink ($temp_xml);
		print "Removed: $temp_xml\n";
	}
	if (-f $exit_file) {
		unlink($exit_file);
		print "Removed: $exit_file\n";
	}
	if (-f $pause_file) {
		unlink($pause_file);
		print "Removed: $pause_file\n";
	}
}

clean_temp_file();

my ($done, $tries);
while(($done ne "0") and ($tries < 20)) {
	print "Retrieving: $rss\n";
	$done = system("${wget} -q --output-document=$temp_xml -U Mozilla '$rss'");
	# just incase we get stuck in a loop where the site is down or something
	# try only 20 times then exit
	$tries++;
}

$ref = XMLin("$temp_xml");

speak_xml($ref,@speak_tags);

clean_temp_file();
