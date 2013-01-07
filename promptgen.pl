#!/usr/bin/perl
# promptmaker .001 (c) 1998 dirt (dirt@u.washington.edu)
# Let it be known that this is my first real perl thing, aside from
# a rudimentary guestbook... you have been warned.
# It's all GPL, all the time. Especially the big fat "as is, no warranty" part


die "You need something Bourne-ish, otherwise I don't know\n" 
        unless($ENV{'SHELL'} =~ m#/bash$# || $ENV{'SHELL'} =~ m#/sh$#);

        # bright:
$bBLACK         = "\033[1;30m";
$bRED           = "\033[1;31m";
$bGREEN         = "\033[1;32m";
$bYELLOW        = "\033[1;33m";
$bBLUE          = "\033[1;34m";
$bMAGENTA       = "\033[1;35m";
$bCYAN          = "\033[1;36m";
$bWHITE         = "\033[1;37m";
        # not bright:
$BLACK          = "\033[0;30m";
$RED            = "\033[0;31m";
$GREEN          = "\033[0;32m";
$YELLOW         = "\033[0;33m";
$BLUE           = "\033[0;34m";
$MAGENTA        = "\033[0;35m";
$CYAN           = "\033[0;36m";
$WHITE          = "\033[0;37m";

################### Bash function definitions: ############################
# Note: These screw up bash's positioning ability if done all on one line,
# and tend to be slower than crap. But they can be pretty. 

# list of functions here
my @funclist= qw(
        gradient
        );

# how the function should go in the prompt (eval'd in create_function())
# the text to work on will be stuck in the variable 
#                               >"$text"<
my %funcsetup= (
        gradient => '{
                my ($color,$width) = (0,0);
                my $function = "";
                print "${bYELLOW}What color (0-9, default: 2)?$WHITE ";
                $color = <>;
                chomp $color;
                print "${bYELLOW}Width (number, default: 1/3 width)?$WHITE ";
                $width = <>;
                chomp $width;
                $function = "\$(gradient $text $color $width)";
                print "\noutput: $function: \n";
                return $function;
                }'
        );

# what bash sees (interpolated at every prompt)
my %funcdef= (
        gradient =>'
                gradient() { perl -e \'
                my $text = $ARGV[0];
                die "no text given" unless($text);
                my $color = $ARGV[1] ? $ARGV[1] : 2;
                my $tmp = 0;
                my $width = $ARGV[2] ? $ARGV[2] : 
                        (($tmp=length($text))/3?$tmp/3:1);
                my @reply = split "", $text;
                my $i = 0;
                $reply[$i] = "\033[1;" . ($color + 30) ."m" . $reply[$i];
                $i += $width;
                $reply[$i] = "\033[0;". ($color + 30) . "m" . $reply[$i];
                $i += $width;
                $reply[$i] = "\033[1;30m" . $reply[$i];
                print @reply;\' $*
                }'
        );

############### end functions ######################

#
# stuff
#

my @current_prompt = init();

for(;;) {
        draw_main_ui(@current_prompt);
        $_ = <>;

        if (/q/) {
                exit 1;
        } elsif(/^1$/) {
                change_text(\@current_prompt);
        } elsif(/^2$/) {
                edit_colors(\@current_prompt);
        } elsif(/^3$/) {
                preview(\@current_prompt);
        } elsif(/^4$/) {
                my $tmp = undef;
                foreach $loc(0..$#current_prompt) {
                        $tmp = $current_prompt[$loc]->{text};
                        # replace whitespace with a dot (\376)
                        $tmp =~ s/\s/\376/g;
                        print "loc: $loc value =",
                                "$current_prompt[$loc]->{ansi}$tmp\n";
                }
                print "\npaused...";
                $_ = <>;
        } elsif(/^5$/) {
                save_prompt(\@current_prompt);
        }
        
}

#
# init parses the prompt, stripping out any extraneous characters
# and seprates the various color fields into elements of @current_prompt
#
sub init {
        my(@tmp_prompt, @retval, $tmp_hash) = ();
        $_ = $ENV{'PS1'};
        # strip out ansi and bash-specific codes
        s/\\\[//g;
        s/\\\]//g;
        s/\\033/\033/g;
        s/\\e/\033/g;
        @tmp_prompt = split(/(?=\033)/, $_); # zero-width lookahead (?)
        foreach $thing(@tmp_prompt) {
                $tmphash = undef;
                $thing =~ /(\033.*?m)(.*)/;
                $tmphash->{ansi} = $1;
                $tmphash->{text} = $2;
                push @retval, $tmphash;
        }
        clean_prompt(\@retval);
        return @retval;
}

#
# This is a very important and heavily used funciton, though a bit slow
# because of the nested loop... not noticably. TODO: speedup
#
sub clean_prompt {
        my $prompt = shift;
        my ($head,$read_ahead) = (0,0);
        my @tmp_prompt = ();


        # first, go through and lump same-colored or ansi-less text together
        $head = 0;
        $read_ahead = 0;
        while($head < $#{$prompt}) {
                # $read_ahead starts 1 element ahead of $head, and keeps 
                # running ahead until there is a difference, in which case 
                # the inner loop stops
                $read_ahead = $head+1;
                while   ($read_ahead <$#{$prompt} && 
                                (
                                        !$prompt->[$read_ahead]->{ansi} || 
                                        $prompt->[$read_ahead]->{ansi} eq 
                                        $prompt->[$head]->{ansi}
                                ) 
                        ) 
                {
                        $prompt->[$head]->{text} .=
                                $prompt->[$read_ahead]->{text};
                        $prompt->[$read_ahead++]->{text} = "";
                }
                $head = $read_ahead; # start where $read_ahead left off
        }

        # finally, get rid of empty elements (i.e. elements with no text,
        # may or may not have ansi strings to worry about)
        $head=0;
        # $read_ahead is the element of the temporary copy location, now
        $read_ahead=0;  
        for $head(0..$#{$prompt}) {
                if(defined $prompt->[$head]->{text} 
                                && $prompt->[$head]->{text} ne "") {
                        $tmp_prompt[$read_ahead++] = $prompt->[$head];
                }
        }
        @$prompt = ();  # clear it
        @$prompt = @tmp_prompt;
}

# TODO: I don't know many ansi codes--background, cursor motion, etc...
sub cmp_ansi {
        my($first, $second) = @_;
        my($highlight,$color,$tmp) = ();
        if($first eq $second) { # first obvious case
                return 1;
        }

        if($first =~ m/\033\[(\d+)\;(\d+)m/) {
                $highlight->{first} = $1;
                $color->{first} = $2;
        } elsif($first =~ m/\033\[(\d+)m/) {
                $color->{first} = $1;
        }

        if($second =~ m/\033\[(\d+)\;(\d+)m/) {
                $highlight->{second} = $1;
                $color->{second} = $2;
        } elsif($first =~ m/\033\[(\d+)m/) {
                $color->{second} = $1;
        }

        return ($highlight->{first} == $highlight->{second} &&
                $color->{first} == $color->{second}); 
}

sub get_joined_prompt{
        my $prompt = "";
        my $i = 0;
        my $tmp;
        foreach $i(0..$#_) {
                $tmp = $_[$i]->{text};
                $tmp =~ s/\s/\376/g;            # whitespace marker
                $prompt .= $_[$i]->{ansi} . $tmp;
        }
        return $prompt;
}

sub draw_main_ui {
        system("clear");
        print "\n\n\t${bGREEN}1.$bBLUE Change text\n";
        print "\t${bGREEN}2.$bBLUE Edit colors\n";
        print "\t${bGREEN}3.$bBLUE Preview\n";
        print "\t${bGREEN}4.$bBLUE Debug\n";
        print "\t${bGREEN}5.$bBLUE Save\n";
        print "\t${bGREEN}(${bCYAN}Q${bGREEN})${bBLUE}uit\n";
        print "${bBLACK}Current prompt:$WHITE ", get_joined_prompt(@_);
        print "\n${bYELLOW}Choice? $WHITE";
}  

sub draw_change_ui {
        system("clear");
        print "\n${bGREEN}Some handy bash prompt variables:";
        print "\n$bRED\t\\d\t-\t${BLUE}Date";
        print "\n$bRED\t\\u\t-\t${BLUE}User";
        print "\n$bRED\t\\w\t-\t${BLUE}Directory";
        print "\n$bRED\t\\W\t-\t${BLUE}Directory basename "
                . "(e.g. /usr/src/)";
        print "\n$bRED\t\\t\t-\t${BLUE}Current 24-hr time";
        print "\n$bRED\t\\\#\t-\t${BLUE}Current command number";
        print "\n$bRED\t\\!\t-\t${BLUE}Current history number";
        print "\n\n${bBLUE}Enter the prompt text, ",
                "or just ${bRED}enter$bBLUE to abort:$WHITE ";
}

#TODO: backgrounds
sub draw_edit_options {
        # top line
        print "$bWHITE(${BLACK}1$bWHITE) " .
                "$bWHITE(${BLUE}2$bWHITE) " .
                "$bWHITE(${GREEN}3$bWHITE) " .
                "$bWHITE(${CYAN}4$bWHITE) " .
                "$bWHITE(${RED}5$bWHITE) " .
                "$bWHITE(${MAGENTA}6$bWHITE) " .
                "$bWHITE(${YELLOW}7$bWHITE) ".
                "$bWHITE(${WHITE}8$bWHITE)\n";
        # bottom line
        print "$bWHITE(${bBLACK}9$bWHITE) " .
                "$bWHITE(${bBLUE}10$bWHITE) " .
                "$bWHITE(${bGREEN}11$bWHITE) " .
                "$bWHITE(${bCYAN}12$bWHITE) " .
                "$bWHITE(${bRED}13$bWHITE) " .
                "$bWHITE(${bMAGENTA}14$bWHITE) " .
                "$bWHITE(${bYELLOW}15$bWHITE) ".
                "${bWHITE}(16)\n";
        print "${bGREEN}F${bWHITE})unction\n";
        print "${bYELLOW}What color/function to apply? $WHITE";
}

# TODO: fix this so the user can actually edit, instead of redoing it
sub change_text {
        my $prompt = shift;
        draw_change_ui();
        $_ = <>;
        chomp;
        return if($_ eq "");            # nothing entered, abort
        @$prompt = ();                  # flush it all away, learn to swim
        $prompt->[0]->{ansi} = "";
        $prompt->[0]->{text} = $_;
}

sub preview {
        my $prompt = shift;
        my $preview_prompt = get_joined_prompt(@$prompt);
        my $cwd = `pwd`;
        chomp($cwd);
        $cwd =~ s/$ENV{'HOME'}/~/g;
        $preview_prompt =~ s/\\u/$ENV{'USER'}/g;
        $preview_prompt =~ s/\\h/$ENV{'HOSTNAME'}/g;
        $preview_prompt =~ s/\\w/$cwd/g;
        $cwd = `basename $cwd`;
        chomp($cwd);
        $preview_prompt =~ s/\\W/$cwd/g;
        $preview_prompt =~ s/\\#/102/g;
        $preview_prompt =~ s/\\!/1052/g;
        $preview_prompt =~ s/\376/ /g;  # note: doesn't do tabs and stuff
        print "\n$preview_prompt";
        $_ = <>;
}


sub edit_colors {
        # reference to the prompt
        my $prompt = shift;
        # length of the plaintext for the ruler
        my $len = get_text_len(@$prompt);
        # the character location where the user wants to start editing
        my $start = 0;
        # the location where the user wants to stop editing
        my $end = 0;
        # the thing displayed to screen--note the clearscreen and newline
        my $pretty_prompt = `clear` . get_joined_prompt(@$prompt) . "\n";
        # the portion of the prompt the user wants modified
        my $edit_block = "";
        # what element in the prompt the new stuff goes
        my $edit_element = 0;
        # where in the element to put the new stuff
        my $edit_pos = 0;
        # function to insert (read below for context, uhh yeah)
        my $function;

        print $pretty_prompt;
        draw_ruler($len);

        print "Enter the starting number: ";
        $start = <>;
        chomp($start);
        if($start < 1 || $start > $len) {
                print "${bRED}Invalid number\n";
                sleep(1);
                return;
        }

        print $pretty_prompt;
        draw_ruler($len, $start);

        print "Enter the ending number: ";
        $end = <>;
        chomp($end);
        if($end < 1 || $end > $len) {
                print "${bRED}Invalid number\n";
                sleep(1);
                return;
        } elsif($start > $end) {
                # swap
                $tmp = $start;
                $start = $end;
                $end = $tmp;
        }

        print $pretty_prompt;
        draw_ruler($len, $start, $end);

        ($edit_block,$edit_element,$edit_pos) = 
                yank_out_block($prompt,$start,$end);
        draw_edit_options();
        $_ = <>;
        if(/^[fF]/) { # function
                $function = create_function($edit_block);
                unless($function) { return; }
                insert_block($prompt,$edit_element,$edit_pos,$function);
        } else {
                insert_block($prompt, $edit_element, $edit_pos, 
                                create_element($edit_block, $_));
        }
        clean_prompt($prompt);
}

sub get_text_len {
        my $len = 0;
        my $i = 0;
        for $i(0..$#_) {
                $len += length $_[$i]->{text};
        }
        return $len;
}

sub draw_ruler {
        my $len = shift(@_);
        my $start = shift(@_);
        my $end = shift(@_);
        my $toggle_draw_bar = 0;
        my $loc = 0;

        # print out the ruler, every 5th is a number with a red bar underneath;
        # green caret at the start, dashes in between, and an ending 
        # caret at the ending location. If $end isn't defined, just draw the 
        # one caret. Blue bars everywhere else

        for($loc=1;$loc <=$len; $loc++) {
                if(defined $start && ($loc == $start || $loc == $end)) {
                        # if $start is the same as $end, we dont draw bars
                        if(defined $end && $start != $end) {
                                $toggle_draw_bar = !$toggle_draw_bar;
                        }
                        print "${bGREEN}^";
                } elsif($toggle_draw_bar) {
                        print "${bGREEN}-";
                } elsif($loc % 5) { # not on a number
                        print "$bBLUE" . "|";
                } else { # on a number, print a red bar
                        print "$bRED" . "|";
                }
        }

        # print out the numbers below
        print "\n$bRED";
        for($loc=1;$loc <=$len; $loc++) {
                if($loc % 5) {
                        print " ";
                } else {
                        print "$loc";
                        $loc++ if($loc > 9);    # number is 2 digits/spaces
                }
        }
        print "\n$bBLACK\376 = whitespace\n$WHITE";
}

#
# The calling function is responsible for valid ranges, lest this whole thing
# goes to hell. Returns what was removed, which element it was removed from,
# and where (position) if it was removed from within one (1, uno) element
# otherwise the position is 0. Will leave gaping empty fields for clean_prompt()
# so user beware (needed if you're going to stick anything back in).
# TODO: rewrite this godawful function
#
sub yank_out_block {
        my($prompt,$start,$end) = @_;
        my($i,$tot_len, $len,$element_num,$edit_element,$edit_pos) = 
                (0,0,0,0,0,0);
        my $yanked = "";
        my $tmp = "";

        # first, find the start
        for $i(0..$#{$prompt}) {
                $element_num = $i;
                $len = length $prompt->[$i]->{text};
                last if($tot_len + $len >= $start); 
                $tot_len += $len;
        }

        # the save the location of the first element (later, whatever was 
        # removed is inserted immediately after this element)
        $edit_element = $element_num;
        
        # test to see if the end is within the current element or not
        if($tot_len + $len >= $end) {
                # note the -1 for offset for 0-based arrays 
                # and the length +1 because the end is *inclusive*
                $edit_pos = ($start - $tot_len) - 1;
                $yanked = substr $prompt->[$element_num]->{text}, 
                        $edit_pos, ($end - $start) + 1; 

                # after copying the substring, remove it from the prompt
                substr($prompt->[$element_num]->{text}, 
                        ($start - $tot_len) - 1, ($end - $start) + 1) = "";

                # if we cleared all of the text out, clear out the ansi too,
                # so it's removed by clean_prompt()
                unless($prompt->[$element_num]->{text}) {
                        $prompt->[$element_num]->{ansi} = "";
                }

                # if $edit_pos is 0, just have it insert the yanked text
                # before the chosen element
                unless($edit_pos) {
                        $edit_element--;
                }
                return wantarray ? ($yanked,$edit_element,$edit_pos) : $yanked;
        } else {
                # copy to the end of the string (offseting for 0-based arrays!)
                $yanked = substr $prompt->[$element_num]->{text},
                        ($start-1)-$tot_len;
                # remove the part copied
                substr($prompt->[$element_num]->{text},($start-1)-$tot_len)="";
                # if we cleared all the text out, clear out the ansi too,
                # so it's removed by clean_prompt()
                # BUG: somethings up with clean_prompt() not joining everything
                unless($prompt->[$element_num]->{text}) {
                        $prompt->[$element_num]->{ansi} = "";
                }
        }

        # move on to the next element
        $tot_len += $len;
        $element_num++;

        # find the end
        for $i($element_num..$#{$prompt}) {
                $element_num = $i;
                $len = length $prompt->[$i]->{text};
                last if($tot_len + $len >= $end);
                $tot_len += $len;       
                # add this element to the string
                $yanked .= $prompt->[$i]->{text};
                # clear it out from the prompt
                $prompt->[$i]->{text}="";
                $prompt->[$i]->{ansi}="";
        }
        # copy what's left
        $yanked .= substr $prompt->[$element_num]->{text}, 0, $end - $tot_len;
        # remove what was copied 
        $prompt->[$element_num]->{text}=substr $prompt->[$element_num]->{text},
                $end - $tot_len;

        # clear the ansi if the text was empty
        unless($prompt->[$element_num]->{text}) {
                $prompt->[$element_num]->{ansi} = "";
        }
        # return 0 as the third element, because the yanked element spanned
        # over 1 element... TODO: make this more consistant
        return wantarray ? ($yanked,$edit_element,0) : $yanked;
}


#
# create_element() takes a block of text, an integer for color (1-14)
# and returns a hash. If the color number is ommited, no ansi is given
#
# TODO: just add the ansi numbers up together in a more efficent algorithm
sub create_element {
        my($text,$color) = @_;
        my $retval = {};

SWITCH: {
                $retval->{ansi} = $BLACK, last SWITCH if($color == 1);
                $retval->{ansi} = $BLUE, last SWITCH if($color == 2);
                $retval->{ansi} = $GREEN, last SWITCH if($color == 3);
                $retval->{ansi} = $CYAN, last SWITCH if($color == 4);
                $retval->{ansi} = $RED, last SWITCH if($color == 5);
                $retval->{ansi} = $MAGENTA, last SWITCH if($color == 6);
                $retval->{ansi} = $YELLOW, last SWITCH if($color == 7);
                $retval->{ansi} = $WHITE, last SWITCH if($color == 8);
                $retval->{ansi} = $bBLACK, last SWITCH if($color == 9);
                $retval->{ansi} = $bBLUE, last SWITCH if($color == 10);
                $retval->{ansi} = $bGREEN, last SWITCH if($color == 11);
                $retval->{ansi} = $bCYAN, last SWITCH if($color == 12);
                $retval->{ansi} = $bRED, last SWITCH if($color == 13);
                $retval->{ansi} = $bMAGENTA, last SWITCH if($color == 14);
                $retval->{ansi} = $bYELLOW, last SWITCH if($color == 15);
                $retval->{ansi} = $bWHITE, last SWITCH if($color == 16);
                $retval->{ansi} = "";
        }

        $retval->{text} = $text;
        return $retval;
}

#
# TODO: more elegant. all functions their own variables, eval'd if
# the user wants to gradient some static text (instead of at every prompt)
#
sub create_function {
        my $text = shift; # eval'd functions will use this
        my $retval = {};
        my $i=0;
        my $reply = "";
        $retval->{ansi} = "";

        print "\nAvailble functions:\n";
        while(defined $funclist[$i]) {
                print "\t$bWHITE$i$bGREEN)$WHITE ",$funclist[$i++],"\n";
        }
        print "$bYELLOW","Selection? ";
        $reply=<>;
        # scold the user if it's not a number or out of range
        if(!($reply =~ /^[0-9]$/) || $reply >= $i) {
                print "$bRED","Invalid option.\n";
                sleep(1);
                return undef;
        }
        
        $retval->{text} = eval $funcsetup{$funclist[$reply]};

        return $retval;
}


#
# this function is so horribly ugly, fragile, and dependant on magic variables
# it's really very sad. TODO: rewrite
#
sub insert_block {
        my ($prompt,$element,$pos,$block) = @_;
        my $i = 0;
        my @tmp_prompt = ();

        # we will insert immediately after $element
        while($i <= $element) {
                $tmp_prompt[$i] = $prompt->[$i];
                $i++;
        }

        # $pos is only set if the block we're inserting was removed
        # from within an element, i.e. we're re-inserting into an element
        if($pos) {
                my $tmp_text = $prompt->[$element]->{text};
                my $tmp_ansi = $prompt->[$element]->{ansi};
                # this is here so follwing colors aren't the same
                $tmp_ansi = $WHITE unless $tmp_ansi;

                $tmp_prompt[$element]->{text} = substr $tmp_text,0,$pos;
                $tmp_prompt[$element]->{ansi} = $tmp_ansi;

                $tmp_prompt[++$element] = $block;

                $tmp_prompt[++$element]->{text} = substr $tmp_text,$pos;
                $tmp_prompt[$element]->{ansi} = $tmp_ansi;
        } else {
                $tmp_prompt[++$element] = $block;
                # this is here so colors following aren't all the same
                unless( $prompt->[$element]->{ansi}) {
                        my $ansi = ($element-2>0) ? 
                                $prompt->[$element-2]->{ansi} : undef;
                        $prompt->[$element]->{ansi} = $ansi ? $ansi : $WHITE;
                }
        }

        # copy the rest over
        while(defined $prompt->[$i]) {
                $tmp_prompt[++$element] = $prompt->[$i++];
        }
        # copy and overwrite
        @$prompt = @tmp_prompt;
}

#
# TODO: dbm database, functions
#
sub save_prompt {
        my $string = &get_bashful_prompt;
        my $outfile;
        my $funcname;
    my $i=0;

        print "${bYELLOW}Save to what file? ";
        $outfile = <>;
        chomp($outfile);

        # TODO: make this go better. Use select() instead?
        # Hmm, a decision as monumental as this cannot be made lightly.
        if(-e $outfile) {
                print "${bYELLOW}File exists, overwrite?$WHITE ";
                $_ = <STDIN>;
                if(/^[yY]/) {
                        unless(open(OUTFILE, ">" . $outfile)) {
                                print "${bRED}Can't open file for writing!\n";
                                sleep(1);
                                return;
                        }
                } else {
                        print "${bRED}Aborted.\n";
                        sleep(1);
                        return;
                }
        }  else { 
                unless(open(OUTFILE, ">" . $outfile)) {
                        print "${bRED}Can't open file for writing!\n";
                        sleep(1);
                        return; 
                }
        }
        print OUTFILE "#!/bin/sh\nexport PS1=\'$string\'\n";
        while(defined ($funcname=$funclist[$i++])) {
                if($string =~ /$funcname/) {
                        print OUTFILE $funcdef{$funcname};
                }
        }
        print "${CYAN}Your prompt as been$bCYAN saved$CYAN. To use it, type:\n";
        print "\t${WHITE}. $outfile$CYAN\nMake sure you use the dot.\n";
        $_ = <>;
}

#
# simple conversions to make anything we've done bash friendly
#
sub get_bashful_prompt {
        my $prompt = shift;
        my @thingy = ();
        my $i = 0;
        while(defined $prompt->[$i]) {
                $thingy[$i] = $prompt->[$i]->{ansi} . $prompt->[$i]->{text};
                $thingy[$i] =~ s/\'/\\\'/g;
                $thingy[$i] =~ s/\033\[(.*?)m/\\[\\033[$1m\\]/g;
        } continue {
                $i++;
        }
        return join "", @thingy;
}

