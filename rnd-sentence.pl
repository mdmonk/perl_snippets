#!/usr/bin/perl -w
use strict;
$|++;

use Parse::RecDescent 1.65;
use Getopt::Long;

GetOptions(
           "start=s" => \ (my $START = "START"),
          ) or die "see code for usage\n";

## define the grammar of the spew grammar:

(my $parser = Parse::RecDescent->new(<<'END_OF_GRAMMAR')) or die "bad!";

## return hashref
## { ident => {
##     is => [
##       [weight => item, item, item, ...],
##       [weight => item, item, item, ...], ...
##     ],
##     defined => { line-number => times }
##     used => { line-number => times }
##   }, ...
## }
## item is " literal" or ident
## ident is C-symbol or number (internal for nested rules)

{ my %grammar; my $internal = 0; }

grammar: rule(s) /\Z/ { \%grammar; }

## rule returns identifier (not used)
rule: identifier ":" defn {
                push @{$grammar{$item[1]}{is}}, @{$item[3]};
                $grammar{$item[1]}{defined}{$itempos[1]{line}{to}}++;
                $item[1];
        }
        | <error>

## defn returns listref of choices
defn: <leftop: choice "|" choice>

## choice returns a listref of [weight => @items]
choice: weight unweightedchoice { [ $item[1] => @{$item[2]} ] }

## weight returns weight if present, 1 if not
weight: /\d+(\.\d+)?/ <commit> /\@/ { $item[1] } | { 1 }

## unweightedchoice returns a listref of @items
unweightedchoice: item(s)

## item returns " literal text" or "identifier"
item:
        { $_ = extract_quotelike($text) and " " . eval }
        | identifier <commit> ...!/:/ { # must not be followed by colon!
                $grammar{$item[1]}{used}{$itempos[1]{line}{to}}++;
                $item[1]; # non-leading space flags an identifier
        }
        | "(" defn ")" { # parens for recursion, gensym an internal
                ++$internal;
                push @{$grammar{$internal}{is}}, @{$item[2]};
                $internal;
        }
        | <error>

identifier: /[^\W\d]\w*/

END_OF_GRAMMAR

my @data = <>;
for (@data) {
  s/^\s*#.*//;
}

(my $parsed = $parser->grammar(join '', @data)) or die "bad parse";

for my $id (sort keys %$parsed) {
  next if $id =~ /^\d+$/;       # skip internals
  my $id_ref = $parsed->{$id};
  unless (exists $id_ref->{defined}) {
    print "$id used in @{[sort keys %{$id_ref->{used}}]} but not defined - FATAL\n";
  }
  unless (exists $id_ref->{used} or $id eq $START) {
    print "$id defined in @{[sort keys %{$id_ref->{defined}}]} but not used - WARNING\n";
  }
}    

#DEBUGGING:# use Data::Dumper; print Dumper($parsed);
show($START);

sub show {
  my $defn = shift;
  die "missing defn for $defn" unless exists $parsed->{$defn};

  my @choices = @{$parsed->{$defn}{is}};
  my $weight = 0;
  my @keeper = ();
  while (@choices) {
    my ($thisweight, @thisitem) = @{pop @choices};
    $thisweight = 0 if $thisweight < 0; # no funny stuff
    $weight += $thisweight;
    @keeper = @thisitem if rand($weight) < $thisweight;
  }
  for (@keeper) {
    ## should be a list of ids or defns
    die "huh $_ in $defn" if ref $defn;
    if (/^ (.*)/s) {
      print $1;
    } elsif (/^(\w+)$/) {
      show($1);
    } else {
      die "Can't show $_ in $defn\n";
    }
  }
}
#### LISTING TWO ####
## Our challenge is to effectively reverse-engineer the output of:
## http://www.dilbert.com/comics/dilbert/career/bin/ms2.cgi
## as well as dynamically provide interactive feedback. :-)

START: missions

missions: mission "\n\n" mission "\n\n" mission "\n\n" mission "\n"

mission:
  Our_job_is_to " " do_goals "." |
  2 @ Our_job_is_to " " do_goals " " because "."

Our_job_is_to:
  ("It is our " | "It's our ") job " to" |
  "Our " job (" is to" | " is to continue to") |
  "The customer can count on us to" |
  ("We continually " | "We ") ("strive" | "envision" | "exist") " to" |
  "We have committed to" |
  "We"

job:
  "business" | "challenge" | "goal" | "job" | "mission" | "responsibility"
  
do_goals:
  goal | goal " " in_order_to " " goal

in_order_to:
  "as well as to" |
  "in order that we may" |
  "in order to" |
  "so that we may endeavor to" |
  "so that we may" |
  "such that we may continue to" |
  "to allow us to" |
  "while continuing to" |
  "and"

because:
  "because that is what the customer expects" |
  "for 100% customer satisfaction" |
  "in order to solve business problems" |
  "to exceed customer expectations" |
  "to meet our customer's needs" |
  "to set us apart from the competition" |
  "to stay competitive in tomorrow's world" |
  "while promoting personal employee growth"

goal: adverbly " " verb " " adjective " " noun

adverbly:
  "quickly" | "proactively" | "efficiently" | "assertively" |
  "interactively" | "professionally" | "authoritatively" |
  "conveniently" | "completely" | "continually" | "dramatically" |
  "enthusiastically" | "collaboratively" | "synergistically" |
  "seamlessly" | "competently" | "globally"


verb:
  "maintain" | "supply" | "provide access to" | "disseminate" |
  "network" | "create" | "engineer" | "integrate" | "leverage other's" |
  "leverage existing" | "coordinate" | "administrate" | "initiate" |
  "facilitate" | "promote" | "restore" | "fashion" | "revolutionize" |
  "build" | "enhance" | "simplify" | "pursue" | "utilize" | "foster" |
  "customize" | "negotiate"

adjective:
  "professional" | "timely" | "effective" | "unique" | "cost-effective" |
  "virtual" | "scalable" | "economically sound" |
  "inexpensive" | "value-added" | "business" | "quality" | "diverse" |
  "high-quality" | "competitive" | "excellent" | "innovative" |
  "corporate" | "high standards in" | "world-class" | "error-free" |
  "performance-based" | "multimedia-based" | "market-driven" |
  "cutting edge" | "high-payoff" | "low-risk high-yield" |
  "long-term high-impact" | "prospective" | "progressive" | "ethical" |
  "enterprise-wide" | "principle-centered" | "mission-critical" |
  "parallel" | "interdependent" | "emerging" |
  "seven-habits-conforming" | "resource-leveling"

noun:
  "content" | "paradigms" | "data" | "opportunities" |
  "information" | "services" | "materials" | "technology" | "benefits" |
  "solutions" | "infrastructures" | "products" | "deliverables" |
  "catalysts for change" | "resources" | "methods of empowerment" |
  "sources" | "leadership skills" | "meta-services" | "intellectual capital"
#### LISTING THREE ####
#!/usr/bin/perl -w
use strict;
$|++;

use Parse::RecDescent;

(my $parser = Parse::RecDescent->new(<<'END_OF_GRAMMAR')) or die "bad!";

start: <leftop: junk rule junk> /\Z/ { 1 }

junk: /[^{}]*/ { 1 }

rule: "{" defining choices "}" { print "$item[2]: $item[3]\n\n" }
  | <error>

defining: symbol ";" <commit> { $item[1] } | symbol

symbol: /^<(\S+)>/ {
  my $x = $1;
  $x =~ s/([^a-zA-Z])/sprintf "_%02x_", ord $1/ge;
  if ($x eq "start") {
    $x = "START";
  }
  ## warn "saw symbol $x\n";
  $x;
}

choices: choice(s) { join " |\n  ", @ {$item[1]} } | { q{""} }

choice: item(s) ";" { join q{ " " }, @ {$item[1]} }
  | <error>

item: symbol | wordlist | <error>

wordlist: word(s) { "q{" . join( " ", @ {$item[1]} ) . "}" }

word: /^"(\S+)"/ <commit> { $1 } | /^[^\s<>{};]+/

END_OF_GRAMMAR

(my $parsed = $parser->start(join '', <>)) or die "bad parse";

## see http://www-cs-faculty.stanford.edu/~zelenski/rsg/grammars/

