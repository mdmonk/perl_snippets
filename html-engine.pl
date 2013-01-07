#!/usr/bin/perl -w

#######################################################
#
# what is this?
#
# basically, i'm working on a real html parser engine
# for scobra, and well any other type of use
#
# lots of people use code to 'trick' crawlers/bots/etc
# to reading in things that 'good' browsers such as IE
# and netscape don't...the point of this
# engine is to basically be able to 'parse' as much as
# IE is able to without getting tricked
#
# blah blah blah
# 
# if you have any questions/comments,
# email me at commport5@lucidx.com
# -samy kamkar
#######################################################


use strict;
use IO::Socket;

my $sock = IO::Socket::INET->new("cobra.lucidx.com:80");
print $sock "GET /downloads/dev/temp.html HTTP/1.0\nHost: cobra.lucidx.com\n\n";
my $res;
while (<$sock>) {
 $res .= $_;
}
my $tags = &html_parse(\$res);


sub html_parse {
 my $data = $_[0];
 my (%tags);
 while ($$data =~ s/
(?:
 <!\s*-\s*-.*?-\s*-\s*> | # if it's a comment, we don't really care but it's here so others will
                            # know how to implement it if they want
 <([\/a-zA-Z]*)             # opening tag name...e.g., <a, <img, etc.
 (
  (?:
   \s*
   (?:
    '[^']*'     |           # to protect from 'trickyness'
    "[^"]*"     |           # to protect...
    `[^`]*`     |           # to protect...
    [^'"`=\s>]*             # attribute keys...e.g., src, href
   )
   (?:
    \s*=\s*                 # = in between the attribute key and value, if any value
    (?:
     '[^']*'    |           # e.g., 'blah.html'
     "[^"]*"    |           # e.g., "blah.html"
     `[^`]*`    |           # e.g., `blah.html` -- yes, those are backticks...IE parses them, so scobra should too :)
     [^'"\s>]+              # attribute values...e.g., blah.html
    )
   )?
  )+                        # this line is to allow multiple attribute keys+values
 )
 \s*>                       # end...>
)
//xs)
 {
  my ($g, $x) = ($1, $2);
   while ($x =~ s/
(
 '[^']*'     |        # to protect from 'trickyness'
 "[^"]*"     |        # to protect...
 `[^`]*`     |        # to protect...
 [^'"`=\s>]+          # attribute keys...e.g., src, href
)
(?:
 \s*=\s*              # = in between the attribute key and value, if any value
 (
  '[^']*'    |        # e.g., 'blah.html'
  "[^"]*"    |        # e.g., "blah.html"
  `[^`]*`    |        # e.g., `blah.html`
  [^'"\s>]+           # attribute values...e.g., blah.html
 )
)#?
//xs)
   {
    print "$g ___$1---$2___\n";
   }
  }
 return (\%tags);
}


#  while($x=~s/([^'"`=\s>]+|'[^']*'|"[^"]*"|`[^`]*`)\s*=\s*([^'"`\s>]+|'[^']*'|"[^"]*"|`[^`]*`)//xs)
#s/(<[\/a-zA-Z!]*(?:--.*?--|\s+((?:(?:[^'"`=\s>]*|'[^']*'|"[^"]*"|`[^`]*`)\s*=?\s*(?:[^'"`\s>]*|'[^']*'|"[^"]*"|`[^`]*`))+))?\s*>)//xs
