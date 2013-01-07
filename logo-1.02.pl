#!/usr/bin/perl -w

#	Copyright (C) 2002 Derek Pope

#	This program is free software; you can redistribute it and/or
#	modify it under the terms of the GNU General Public License
#	as published by the Free Software Foundation; either version 2
#	of the License, or (at your option) any later version.

#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.

#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

# ------------------------------------------------------------------
#	Suite
#		logo
#
#	Filename
#		logo.pl
#
#	Purpose
#		To enhance my Perl skills, learn about the toolkit package and at the same time,
#		produce something which may prove entertaining to children
#
#	Usage
#		logo.pl
#
#	Related Files
#		[none]
#
#	Author
#               Derek Pope, 22 Jan 2002
#
#	Amendments
#		1.01, Derek Pope, 15th Apr 2002
#			Tidied up the POD controls. Made some changes to the make(), move() etc coding;
#			this mainly reduced the checks being done on the existence or otherwise of objects
#			during code checking.
#		1.02, Derek Pope, 23th Apr 2002
#			Put in code to default to the users 'home' directory in file dialogues on Unix systems
#			since the getOpenFile and getSaveFile seemed to default to the root directory. Allowed
#			for a title to be passed for the 'inform' dialog box.
#
#	Notes
#		The movement implemented is such that a heading of 0 degrees has the pointer facing up the screen,
#		although it would be easier (Tk::canvas has 0,0 as the top left of the screen) to point down.
#		It was felt that 'up' was the more natural direction for this program, this has an effect on lines
#		we draw in subroutine 'forward', and the arrow on the head of the pointer.
#
#		There are some rather arbitary limits to line lengths and solid object sizes but they are designed
#		to keep things within reasonable bounds related to the present canvas size, in a future version
#		it may be possible to override these limits from the command line
#
#		In parsing keyed input, each separate command is stored as one list in an array together
#		with its related parameters, thus a command like 'box 50 100' is stored as the anonymous array
#		[box 50 100] within the array of commands. Where a command such as repeat expects a bracketed subset
#		of commands, the bracketed set of commands is stored as an array of lists of commands. These will
#		inevitably be nested to whatever level is required by what was input.
#
#		The same process is applied to the storage of user functions, each command within the function
#		is stored as an anonymous list in an array of such commands, a reference to the array being stored
#		in the hash of user functions. You don't need to know any of this unless you try to make significant
#		changes to the program code.
#
#		I did make an attempt at allowing the canvas to be resized by dragging the window, and also attaching
#		scrollbars, but the scrolling didn't work too well, and sometimes the scrollbars just disappeared
#
#	Known problems
#		1. Parameter checking is still done in the subroutines, it should be done before we get there which
#		would reduce the cpu cost of checking parameters before we run the commands. If we added the check
#		definitions to the entry subroutine, this would allow us to common up the fwd/back code and the
#		left/right code, etc.
#		2. Need to tidy up the checking for names of things, this is done in a number of places with
#		differring checks for name format and against varying name spaces.
#		3. Should we keep a current heading with each object we 'make' to give move more control? In fact
#		if we kept a heading and x and y it would allow the user good control of the object.
#		4. If we kept heading, x, y with each object we could extend many commands by adding an object name,
#		these include "heading, setx, sety, setxy", also maybe "hide and show".
#		5. The error handling is being done at least two different ways, needs to be tidied up.
#

# ------------------------------------------------------------------
#	Perldoc documentation for CPAN

=head1 NAME

logo (turtle graphics) program.

=head1 DESCRIPTION

This is a reasonably full implementation of the logo graphics facilities
using many of the capabilities of the Tk toolkit. It caters for simple
logic, user defined variables and user defined functions. The program
incorporates a user function editor with save and load capabilites.

=head1 README

This script implements the 'logo' turtle graphics language using
the Tk toolkit. It incorporates a user function editor.

=head1 PREREQUISITES

This script requires the following modules.
C<strict>
C<Tk>
C<Tk::Dialog>
C<Tk::NoteBook>
C<Text::ParseWords>

=head1 OSNAMES

any

=head1 SCRIPT CATEGORIES

Educational/ComputerScience

=cut

# ------------------------------------------------------------------
#	The packages used by this script

use strict;
use Tk;
use Tk::Dialog;
use Tk::NoteBook;
use Text::ParseWords;

# ------------------------------------------------------------------
#	Global Variables, names are all capitals

#	Set the version number, versions below 1.0 are test versions.

our $VERSION="1.02";

#	Set the script name so I can use it elsewhere

our $SCRIPTNAME="logo.pl";

#	Indicate that by default we are not in debug mode

our $DEBUG=0;

#	Place to note the home directory on Unix machine

our $HOME=undef;

#	Define variables for the main window, the canvas and the command entry area

our $WINDOW=0;
our $CANVAS=0;
our $ENTRY=0;

#	Current pointer tag and direction, tag is set in initialisation, heading points up the screen, 
#	The physical pointer is a circle, it's head is an arrow.

our $POINTER=0;
our $ARROW=0;
our $HEADING=0;

#	$POINTER_STATE is either normal or hidden depending whether we are showing or hiding the cursor

our $POINTER_STATE="normal";

#	We also keep the heading as radians so we don't need to recalculate every time we use it

our $RADIANS=0;

#	Maximum screen x and y values

our $MAXX=600;
our $MAXY=400;

#	Default (home) location, normally the middle of the screen

our $HOMEX=int($MAXX/2);
our $HOMEY=int($MAXY/2);

#	Current location, start at home

our $X=$HOMEX;
our $Y=$HOMEY;

#	Displayed information, these are rounded to the nearest whole number for display

our $SHOWX=$X;
our $SHOWY=$Y;
our $SHOWHEADING=$HEADING;

#	Places to retain the paper ink, turtle and fill colours and the pen state
#	pen state starts "down" ie, it writes.

our $PAPER=undef;
our $INK='black';
our $TURTLE='red';
our $FILL=undef;
our $PEN='down';

#	Place to display the chosen colour from so the user can use it again

our $COLOUR='[none]';

#	Remember the line width, initially 1

our $WIDTH=1;

#	Flag to show whether we are running fast or slow (display each element as it's drawn)

our $SLOW=1;

#	Flag to indicate whether we are logging, and a pointer to the button

our $LOG=0;
our $LOG_BUTTON;

#	Flag to show if we are just checking before storing or loading a function
#	this is tested in subroutine 'more' which is used in every user callable subroutine

our $CHECKING=0;

#	Place to hold the pointer to the [GO] button

our $GO=0;

#	Flag to indicate the user wants us to stop the current processing

our $STOP=0;

#	Place to hold the currently executing command for use in error messages etc

our $CURRENT=undef;

#	Create a hash of compass headings

our %COMPASS=(n=>0, nne=>22.5, ne=>45, ene=>67.5,
	e=>90, ese=>112.5, se=>135, sse=>157.5,
	s=>180, ssw=>202.5, sw=>225, wsw=>247.5,
	w=>270, wnw=>292.5, nw=>315, nnw=>337.5);

#	This flag is used to give tags to canvas items being created under the 'make' command

our $MAKE="";

#	Create an array of the complex commands, those which use [] to test against

our @COMPLEX_COMMANDS=('if','for','repeat','make');

#	Place to remember which help page the user looked at last
#	so we can redisplay it automatically next time they ask for help

our $HELP=undef;

#	Remember whether we have an editor window open, to prevent us opening a second

our $EDITOR=0;

#	Define the hash which is central to the processing, this will
#	contain command names and the reference to the related subroutine
#	it also contains many aliases to the commands

our %COMMAND=();

#	Define the hash which will hold the user defined functions

our %FUNCTION=();

#	Define the hash which will hold user defined variables

our %VARIABLE=();

#	Define the holding array for error messages back to the user

our @ERROR=();

#	This array holds the names of the currently executing user functions
#	it is used in sub 'run' to detect any recursive loops. Since we don't
#	provide conventional program logic, this would be impossible for the user to stop

our @EXECUTING=();

#	This variable holds the recursion level we permit, zero means no recursion

our $RECURSION=0;

#	This variable counts how many times we hit the recursion limit

our $LIMIT=0;

#	Below is the text used in the help displays

our $COMMANDS="# comments		Comments are best enclosed in quotes so commands within the comment are ignored
alias word 'command'	Define an abbreviation for a command word, note that the command MUST be in quotes
arc width height start angle	Draw an arc of a disk, see complex commands for more information
backward distance	Like 'forward' but moves backwards instead
box width height	Draw a box of the given dimensions centred on the present position, uses fill colour if set.
clear			Clears the screen but does not home the cursor. Same as hitting the [clear] key
disk width height	Draw a disk within a box of the given dimensions centred on the present position, uses fill.
fast			Don't update the display until all of the changes have been made
fill colour		Sets the fill colour used when filling a box or disk, can be 'off' to not fill
find object		Indicates where the named object has been moved to
for variable start end step [ commands ]
forward distance	Moves the cursor forward the given number of pixels, draws ink color if pen is down
heading angle		Sets the drawing direction, 0 is up, 90 is right etc.
heading compass-point	Can also be specified as a compass point N, SE etc.
hide			Makes the cursor invisible
home			Sends the cursor to the middle of the screen, heading up. Same as hitting the [home] key
if value [ commands ] else [ commands ]
ink colour		Sets the ink colour of the pen
left angle		Turns the cursor left by the number of degrees requested
make object [ commands ] Create a named object which can then be moved using the move command
move object distance	Moves the named object in the direction of the current heading
paper colour		Sets the background colour of the page
pendown			When the pen is down, movement draws lines in the 'ink' colour
penup			When the pen is up, movements (forward and backward) do not draw lines, other commands do
pie width height start angle	Draw a pie slice of a disk, see complex commands for more information, uses fill
polygon sides length	Draw a polygon, with the first side going from x, y at the current heading, uses fill
recursion level		Allow recursive calls of functions to level, default is zero, no recursion
remove object 		Removes the named object from the canvas
repeat count [ commands ]
right angle		Like 'left' but turns right
set variable value	(re)Define a numeric variable and set it to value,
setx position		Set the position on the X axis (x is across) zero is left
setxy xpos ypos		Set the X and Y positions
sety position		Set the position on the Y axis (y is up) zero is bottom
show			Makes the cursor visible
size width height	Change the size of the drawing area
slice width height start angle	Draw a slice of a dis, uses fill
slow			Update the display at every change, this is the default
text \"text\"		Display the text on the canvas, centred on the cursor position
title \"text\"		Change the title in the main window
turtle colour		Sets the colour of the turtle (circle and arrow pointer) on the screen
unset variable		Delete the named variable, free up the name for (say) a function definition
width thickness		Set the line thickness and outline thickness for box, disk etc, default is 1";

our $COMPLEX="Further expanation of the more complex commands

set variable value
(re)Define a numeric variable and set it to value, you can then use the variable wherever a number is needed.  The value can be any numeric expression, including other variables which have already been defined.  As an example, 'set x x+4' is fine.  There are some standard perl mathematical functions which you can use with set, including abs, atan2, cos, int, not, rand, sin, sqrt.  The rand function can be used for setting random numbers, rand(12) will give a random fractional number between 0 and (not quite) 12.
			
for variable start-value end-value step-value [ commands ]
Repeats the given commands and adjusts the value of the variable from the start value up to and including the end value, incrementing by the step value each time. Step-value defaults to 1 if end-value is greater than start value, to -1 if end-value is greater than start-value.
			
repeat count [ commands ]
Repeats the given commands 'count' number of times '[' and ']' must be used and must be separated by spaces.  Repeats can be nested provided appropriate brackets are used.  Repeats cannot be stacked in one command.
			
if value [ commands ] else [ alternate-commands ]
Provides a simple logic mechanism, commands will be run if the value is not zero.  If there is an 'else' and commands then they will only be run if the value is zero.  The \"else [ commands ]\" section is optional, it\' OK to just say \"if x [ commands ]\".
			
pie width height start angle
Draw a pie slice of a disk. The disk is bounded by a box of the given width and height centred on the current position. The left edge of the pie slice is defined by the start angle (0 is up) and the pie slice is the angular size given by the angle.  Thus \"pie 100 200 45 90\" should give a slice of an ellipse who's point is at the present position, the slice would fan outwards to the east (right) and would be a quarter slice of the pie. Compass headings can be used instead of angles.
			
slice width height start angle
slice is similar to pie except that the shape is bounded by the generated arc and a line which joins it's two ends, it should look like a slice of apple.
			
arc width height start angle
arc is similar to pie and slice but it is just the arc, without any additional lines.

make object [ ]
make allows you to give a name to the items you create on the canvas with the commands which you place in the brackets. Once you have created an object, you can move it about the screen with the 'move' command. Note that the 'move' command does not alter the current X and Y position where the next item will be drawn on the canvas. Objects are removed when you clear the canvas or use the 'remove' command";

our $ALIASES="These are aliases for the commands shown, more can be added using alias statements from the entry line.

b		backward
back		backward
background	paper
bg		paper
down		pendown
f		forward
fg		ink
foreground	ink
fwd		forward
i		ink
l		left
p		paper
r		right
rep		repeat
up		penup";

our $COLOURS="You have control over the paper, ink, fill and turtle colours from the Entry line.

You can also specify the foreground and background colours for the overall application display (buttons, all of the widgets in the window etc) by using the -- option on the command line, use the -h command line option when starting the program for more information.

You can set colours by typing in the colour name on the entry line 'paper yellow' or 'ink dark red' or by using a number. If you enter a single number, (say 5123) it is divided by 8 and the remainder is used to select one of the old 'Spectrum' standard colours which were 'black, blue, red, magenta, green, cyan, yellow and white'. This makes it easy to get colours changing in a 'for' loop or with 'set mycol rand(8)'.

Colours can also be set by specifying a hexadecimal string preceded by a hash (#) symbol, but it's best to use the [Colour] button to help you do this. Once you have used the colour picker, it displays the value you chose in the status line so you can take a note if you want to use exactly the same colour again.

The Toolkit knows a host of colour names, they are listed in the file 'Colours.txt' which I intend to distribute with this program. It is possible that on some systems, not all of them may work, sorry but I don't have too much control over that!";

our $NOTES="Introduction
The initial screen has a row of buttons at the top, below that is a large grey area (the canvas) containing a (turtle) pointer. Below the canvas is a status line showing the present heading (0 is up), the X (across) and Y (up/down) position of the turtle on the screen, the pen status and the last colour chosen with the colour picker dialog. The heading, x and y values are rounded to integers for display, they are updated after each entry line has been run and also every time a 'sleep' is invoked, even if the sleep time is zero. Below the status line is a single line input window into which you can type any of the commands shown in the [Commands] help. The input line can consist of one or more commands or user functions (see below). After typing in your command, hit the [Return] key on your keyboard, or the [GO] button. The command you entered will be executed on the canvas. If the turtle goes off the canvas, you will not be able to see the result of your commands, use the [Home] button to bring it back to the centre of the screen. While a command is running, the [GO] button changes to [Stop] and may be used to stop the running command, this is normally only relevant with long 'for' or 'repeat' commands or user functions.

Buttons
[Exit] terminates the program.
[Print] does not actually print in this version, it creates a postscript file containing a representation of the canvas. If you have a utility to process postscript files, you can view or print from that.
[Clear] clears the screen but does not change the position of the turtle.
[Home] moves the turtle to the middle of the canvas and sets the heading to 0 degrees (up).
[Colour] pops up a dialogue allowing you to directly select the paper, ink or fill colour.
[Log] allows you to log your commands to a file, so that you can review which commands you used to create a particular display on the canvas. Once you start a log, the button changes to [Close Log].
[Editor] takes you into a function editor which allows you to add your own composite commands to the program.
[Help] displays the help window which provides a number of help panels (including this one).

Input Line
If an input line is rejected, it remains in the entry field. If a line is accepted and processed, it is put onto the clipboard so that it can be pasted back into the entry area for review or reuse.

Editor
Allows you to store a set of commands as a new function. Functions can contain calls to other functions as long as they already exist. Functions can include 'repeat', 'for' and 'if' if appropriate brackets [] are used. When you use the [Store] button in the editor, any aliases are converted into the actual commands, the function is then available for use from the main window. From within the editor you can also [Save] your functions to an external file, or [Load] functions in from an external file. The [Store], [Edit] and [Delete] buttons only operate on functions in memory. The [Dismiss] button closes the editor window.

Recursion
When a function calls itself, that is a recursive call, similarly if a function calls another which calls the first function, that (and variations on the theme) is also a recursive call. Some quite interesting things can be done with recursive calls but with the limited logic options in this program it is difficult to control them. There is a recursion option which lets you set recursion level above its initial value of zero (no recursion). The way this works is that recursive calls are allowed but recursion past the current level is prevented, though the function is allowed to continue running. Once the recursive function finishes running, you are told how many excess recursions were invoked. If you want to write a recursive function use the editor, store the function and then insert the recursive call into the function and store it again before you run it. You may get problems trying to load recursive functions into the editor, to overcome this, create a simple function of the same name and then allow it to be overwritten during the load.";

our $ABOUT="
Perl Logo Version $VERSION Copyright 2002 Derek Pope. e-mail derek.pope\@tesco.net

Perl Logo is an implementation of turtle graphics from the 'logo' language defined by Seymour Papert in the late 1960's, early 1970's.

This implementation uses the perl scripting language enhanced by the Tk toolkit. Although I have tried to compile the program so that I can provide an executable for those without perl on their system, apparent problems in Tk prevent it compiling on my system. Consequently you will need to install Perl to run the program.

You can download Perl from http://www.activestate.com where you select 'downloads' from the [Resources] block and then ActivePerl 'download' from the [Available Downloads] block. I use ActiveState perl on my systems. If anyone manages to compile the program with perlcc, please let me know.

The initial window colours are the Toolkit defaults, if you have colour vision issues they may be changed using options on the command line, use the -h option on the command line for details. Unfortunately the initial turtle and ink colours in the canvas needed to be set, or nothing would display; but they can be changed through the entry line.

If you find problems with Perl Logo or would like to see enhancements made, the source is freely available, modifications and comments on Perl Logo can be sent to the author and may be implemented into later versions. My coding style is fairly basic but if you want to make changes and have problems understanding an area of code, mail me and I'll try to get back to you with an explanation.

If you decide you would like to contribute to the continued development of this program, send me an e-mail and I'll gladly give you an address to send minimal contributions.

Perl Logo comes with ABSOLUTELY NO WARRANTY; for details click on the 'GNU' tab.
";

our $IDEAS="
Ok, so you\'ve got the program, what are you going to do with it?

The best thing to do is to play with the commands to understand what they do. Try this and see what you get, press [enter] or hit the [GO] button after each line:-

	forward 50
	left 90
	backward 50
	clear
	box 100 100
	paper black
	paper yellow
	ink red
	disk 100 50
	clear
	repeat 3 [ forward 20 left 120 ]
	clear
	for x 25 3 [ fill x polygon x 50 ]

Did you understand why the screen went all black when you first set the paper colour? The ink you were using until then was black as well, if you have black ink on black paper, what do you expect to see?

From here on out, you are on your own :o)
";

our $GNU="
This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
";

our $FUTURE="
I have some ideas of how to further enhance this program, but I'm happy to hear other people's views on this.

1).	Break the program into smaller modules and perhaps use the autoloader.
2).	Provide for alternate language versions by moving all text into a separate module.
3).	Improve the error handling, it's messy at present with a mixture of ERROR and returned strings.
4).	Allow simple expressions (without whitespace) anywhere a number is allowed.
5).	Provide an undo button for everything except a cleared screen.
6).	Improve the speed and font of pop-up dialogs on some versions.
7).	Allow limits to be set from the command line.
8).	Enhance the colour entry options to allow full RGB numbers to be input or generated.
9).	Implement conventional menus in place of all the buttons.
10).	Tidy up the help text!

";

our $TOOLKIT="
The toolkit 'Tk' is central to the operation of this program, it provides the GUI facilites which are the user interface and also the drawing 'canvas' and related display tools.

When I started to develop the program, the toolkit was not part of the Perl (5.003?) distribution which I was using. If you do not have Perl Tk then you should consider getting the latest distribution from CPAN or ActiveState. 

The Toolkit gives the ability to reconfigure each object which it draws, and although this program does not use the facility, there is a cost in memory since the configuration details of each line, box and disk are retained by the toolkit. Presently the program writes each line as a single object so a decagon (which has ten sides) causes 10 objects to be stored.

Although this should not be a problem on modern machines with oodles of memory, if you repetitively draw lots of complex shapes, without clearing the screen between, it is possible you could run out of memory. If anyone ever gets to this state, please let the author know and some changes to the coding will be considered.
";

our $DISMISS="
The [X] to close the window doesn't work in this help dialog.

Hit the [Close] button at the bottom of the page,
or just hit the [return] key to dismiss it.";

# ------------------------------------------------------------------
#	List of subroutines, these also serve as subroutine prototypes

sub parameters;
sub initialise;
sub debug($);
sub adjustHeading($$);
sub pointer;
sub help;
sub printit;	# at present it just produces a postscript file
sub clear;	# can also be called by the user
sub home;	# can also be called by the user
sub picker;
sub log;
sub editor;	# the following indented subroutines are within the same scope as editor
	sub store;
	sub edit;
	sub list($$$);
	sub delete;
	sub save;
	sub load;
	sub stash($$);
	sub dismiss;
	sub changed;
sub enter;
sub entry();
sub inform($$;$);
sub ask($$);
sub parseline($);
sub parse($$;$);
sub error($);
sub more;
sub tokenise($);
sub alias($$);	# the following subroutine is in the same scope as alias
	sub aliaserror($);	

#	These are validation etc routines called from 'entry'

sub number($$$$);
sub colour($);
sub angle($$);
sub run($);

#	The following subroutines are more or less direct calls from the user

sub comment($);
sub forward($);
sub backward($);
sub left($);
sub right($);
sub paper($);
sub ink($);
sub turtle($);
sub fill($);
sub penup;
sub pendown;
sub hide;
sub show;
sub heading($);
sub setx($);
sub sety($);
sub setxy($$);
sub box($$);
sub disk($$);
sub polygon($$);
sub recursion($);
sub slow;
sub fast;
sub arc($$$$);
sub slice($$$$);
sub pie($$$$;$);
sub size($$);
sub title($);
sub text($);
sub set($$);
sub unset($);
sub width($);
sub sleep($);
sub if($);
sub repeat($);
sub make($);
sub move($);
sub remove($);
sub find($);
sub for($$$$$);

#	The following lines enter the commands names into the command hash

$COMMAND{"#"}=\&comment;
$COMMAND{"alias"}=\&alias;
$COMMAND{"clear"}=\&clear;
$COMMAND{"home"}=\&home;
$COMMAND{"forward"}=\&forward;
$COMMAND{"backward"}=\&backward;
$COMMAND{"left"}=\&left;
$COMMAND{"right"}=\&right;
$COMMAND{"paper"}=\&paper;
$COMMAND{"ink"}=\&ink;
$COMMAND{"turtle"}=\&turtle;
$COMMAND{"fill"}=\&fill;
$COMMAND{"penup"}=\&penup;
$COMMAND{"pendown"}=\&pendown;
$COMMAND{"hide"}=\&hide;
$COMMAND{"show"}=\&show;
$COMMAND{"heading"}=\&heading;
$COMMAND{"setx"}=\&setx;
$COMMAND{"sety"}=\&sety;
$COMMAND{"setxy"}=\&setxy;
$COMMAND{"box"}=\&box;
$COMMAND{"disk"}=\&disk;
$COMMAND{"arc"}=\&arc;
$COMMAND{"polygon"}=\&polygon;
$COMMAND{"recursion"}=\&recursion;
$COMMAND{"fast"}=\&fast;
$COMMAND{"slow"}=\&slow;
$COMMAND{"slice"}=\&slice;
$COMMAND{"pie"}=\&pie;
$COMMAND{"size"}=\&size;
$COMMAND{"title"}=\&title;
$COMMAND{"text"}=\&text;
$COMMAND{"set"}=\&set;
$COMMAND{"unset"}=\&unset;
$COMMAND{"width"}=\&width;
$COMMAND{"sleep"}=\&sleep;
$COMMAND{"if"}=\&if;
$COMMAND{"repeat"}=\&repeat;
$COMMAND{"for"}=\&for;
$COMMAND{"make"}=\&make;
$COMMAND{"move"}=\&move;
$COMMAND{"remove"}=\&remove;
$COMMAND{"find"}=\&find;

#	These lines define the command aliases

alias("cls", "clear");
alias("fwd", "forward");
alias("f", "forward");
alias("back", "backward");
alias("b", "backward");
alias("l", "left");
alias("r", "right");
alias("background", "paper");
alias("bg", "paper");
alias("p", "paper");
alias("foreground", "ink");
alias("fg", "ink");
alias("i", "ink");
alias("up", "penup");
alias("down", "pendown");
alias("rep", "repeat");

# ------------------------------------------------------------------
#	Subroutine
#		parameters;
#	Purpose
#		process command line parameters
#		I tried to implement this as a BEGIN block but the
#		need to use $SCRIPTNAME and $VERSION made that difficult
#

sub parameters
{
	#	Create an exit flag and one to show if we need help

	my $exit=0;
	my $help=0;

	#	Variable to hold a date/time string

	my $time=localtime(time);
	
	#	Now read each argument from the input line

	while ($_=shift @ARGV)
	{
		#	If its a "-h" help request, it will happen at the end

		if ($_ eq "-h")
		{
			$help=1;
			$exit=1;
			next;
		}
		#	If its a "-v" version request, tell them

		if ($_ eq "-v")
		{
			print "This is $SCRIPTNAME version $VERSION\n";
			$exit=1;
			next;
		}
		
		#	If its a "-D" to say produce DEBUG output, take note

		if ($_ eq "-d")
		{
			print "Debugging output started from $SCRIPTNAME - $time\n", '=' x 64, "\n\n";
			$DEBUG=1;
			next;
		}

		#	If its a "--" version request, process no further

		last if ($_ eq "--");

		#	If we get here, there was a bad parameter

		$exit=1;
		$help=1;
	}
	
	#	This serves as help text and as a bad parameter response

	if ($help)
	{
		print "\nUSAGE: $0 [switches]\n";
		print "\t-h\tThis help text\n";
		print "\t-d\tWrite debugging information to standard output\n";
		print "\t-v\tPrint the current version\n";
		print "\t--\tAllow x defaults to be passed to overide colours\n";
		print "\t\tfollow -- with:-\n";
		print "\t\t\t-fg colour To change the foreground colour\n";
		print "\t\t\t-bg colour To change the background colour\n";
		print "\t\t\t-motif To prevent the buttons changing colour\n";
		print "\t\t\t-iconic To start the program minimized\n\n";
		exit;
	}

	#	If we need to quit, do so

	exit if ($exit);
}

# ------------------------------------------------------------------
#	Subroutine
#		initialise;
#	Purpose
#		create a window, exit button, canvas drawing area etc
#

sub initialise
{
	#	If we are not on a Windows machine, it is useful to define the user's home directory
	#	as the initial directory in file dialogs, so find what it is and specify it.

	unless (uc($) eq 'MSWIN32')
	{
		$HOME=$ENV{'HOME'};
	}

	#	Some Windows machines don't have a 'home' directory defined, Tk grumbles about it

	unless ($ENV{'HOME'} or ($ENV{'HOMEDRIVE'} and $ENV{'HOMEPATH'}))
	{
		print "Setting home directory, Tk needs it set\n";
		$ENV{'HOME'}="C:\\";
	}

	
	#	Create the main window

	$WINDOW = MainWindow->new(-title=>"Perl Logo version $VERSION");

	#	Create a frame to put the buttons into

	my $button_frame=$WINDOW->Frame->pack(-side=>"top");
	
	#	Pack an anonymous exit button into the frame

	$button_frame->Button
	(
		-text=>"Exit",
		-width=>9,
		-command=>sub{exit}
	)
	->pack(-side=>"left");

	#	Pack an anonymous print button into the frame

	$button_frame->Button
	(
		-text=>"Print",
		-width=>9,
		-command=>\&printit
	)
	->pack(-side=>"left");

	#	Pack an anonymous clear button into the frame

	$button_frame->Button
	(
		-text=>"Clear",
		-width =>9,
		-command =>\&clear
	)
	->pack(-side=>"left");
	
	#	Pack an anonymous home button into the frame

	$button_frame->Button
	(
		-text =>"Home",
		-width =>9,
		-command =>\&home
	)
	->pack(-side=>"left");

	#	Pack a log button into the frame
	#	not anonymous so we can change the text

	$LOG_BUTTON=$button_frame->Button
	(
		-text => "Log",
		-width =>9,
		-command => \&log
	)
	->pack(-side=>"left");

	#	Pack an anonymous editor button into the frame

	$button_frame->Button
	(
		-text => "Editor",
		-width =>9,
		-command => \&editor
	)
	->pack(-side=>"left");

	#	Pack an anonymous colour button into the frame

	$button_frame->Button
	(
		-text => "Colour",
		-width =>9,
		-command => \&picker
	)
	->pack(-side=>"left");

	#	Pack an anonymous help button into the frame

	$button_frame->Button
	(
		-text => "Help",
		-width =>9,
		-command => \&help
	)
	->pack(-side=>"left");

	#	Now lets put a canvas we can play in, into the window

	$CANVAS=$WINDOW->Canvas
	(
		height=>$MAXX,
		width=>$MAXY
	)->pack;

	#	The method below was tried and it did get us some scrollbars but they didn't
	#	work too well and sometimes just disappeared.
	#	$CANVAS=$WINDOW->Scrolled ( 'Canvas', -background=>$PAPER, -height=>$MAXX, -width=>$MAXY,
	#	-scrollregion=>[0,0,$MAXX,$MAXY], -confine=>0, -scrollbars=>'osoe') ->pack(-expand=>1, -fill=>'both');

	#	Create a frame to hold the heading, x and y positions

	my $data_frame=$WINDOW->Frame->pack;

	#	Now put in the anonymous label areas to display from

	$data_frame->Label
	(
		-height=>1,
		-width=>7,
		-text=>"Heading:"
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>5,
		-textvariable=>\$SHOWHEADING
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>3,
		-text=>"X:"
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>5,
		-justify=>"left",
		-textvariable=>\$SHOWX
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>3,
		-text=>"Y:"
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>5,
		-justify=>"left",
		-textvariable=>\$SHOWY
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>5,
		-text=>"Pen:"
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>5,
		-justify=>"left",
		-textvariable=>\$PEN
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>8,
		-text=>"Colour:"
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>14,
		-justify=>"left",
		-textvariable=>\$COLOUR
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>10,
		-text=>"Recursion:"
	)
	->pack(-side=>"left");

	$data_frame->Label
	(
		-height=>1,
		-width=>4,
		-justify=>"left",
		-textvariable=>\$RECURSION
	)
	->pack(-side=>"left");
	
	#	Now we create a frame to put in the entry window and go button
	
	my $entry_frame=$WINDOW->Frame->pack;
	
	#	then we pack in an anonymous label

	$entry_frame->Label(-text=>'Entry:')->pack(side=>"left");
	
	#	a text entry area for the commands,
	#	takefocus should give this the keyboard if the user hits tab

	$ENTRY=$entry_frame->Entry
	(
		-takefocus=>1,
		-width=>50,
		-takefocus=>1
	)
	->pack(side=>"left");

	#	Bind the return key [enter] to subroutine enter
	
	$ENTRY->bind("<Key-Return>",\&enter);

	#	Give the entry widget the focus if it's in our window

	$ENTRY->focus;

	#	Create a [go] button which also serves as a [stop]
	
	$GO=$entry_frame->Button
	(
		-text=>'GO',
		-width=>5,
		-height=>1,
		-command=>\&enter
	)
	->pack(side=>"right");
	
	#	Reset the canvas to our starting size, in case the window manager has changed it
	#	then force an update to display it

	$CANVAS->configure(-width=>$MAXX, -height=>$MAXY);
	$CANVAS->update;

	#	Call the subroutine which clears the screen to save us putting the code in twice

	clear;

	#	Also home the cursor

	home;

	#	Finally, send a list of the entries in %COMMAND to the debug log

	my @command_list=sort(keys(%COMMAND));
	my $message="The valid commands are:-";
	foreach (@command_list)
	{
		$message .= "\n\t$_";
	}
	debug $message;
}

# ------------------------------------------------------------------
#	Subroutine
#		debug(<message>);
#			<message> is a text message, complete with trailing newline if required
#
#	Purpose
#		write a debug message to standard output if required
#

sub debug($)
{
	#	If we aren't wanted, return

	return unless ($DEBUG);

	#	Otherwise, output the passed message

	print "DEBUG: $_[0]\n";
}

# ------------------------------------------------------------------
#	Subroutine
#		adjustHeading(<type>,<adjustment>;
#
#	Purpose
#		Adjust the $HEADING value and related $RADIANS according to
#		whether <type> is '=', '-' or '+', adjustment is
#		a positive integer. This puts all of the HEADING changes into
#		one place so it is easier to control if we need any code changes
#

sub adjustHeading($$)
{
	#	Get the parameters

	my ($type, $value, undef)=@_;

	#	Process according to $type

	if ($type eq '='){$HEADING = $value}
	elsif ($type eq '-'){$HEADING -= $value}
	elsif ($type eq '+'){$HEADING += $value}
	else
	{
		print "Type \"$type\" passed to adjustHeading changed to '='";
		$HEADING = $value;
	}

	#	Heading is set, adjust within 0..360

	$HEADING -= 360 while ($HEADING > 360);
	$HEADING += 360 while ($HEADING < 0);

	#	Now set the radians value used in calculating line lengths

	$RADIANS=(3.1415926 * ($HEADING))/180.0;
}

# ------------------------------------------------------------------
#	Subroutine
#		pointer;
#
#	Purpose
#		[re]create the pointer when it's needed
#		otherwise, just redraw it
#

sub pointer
{
	#	These calculations are similar to those in 'forward'

	my $x=8 * sin($RADIANS);
	my $y=8 * cos($RADIANS);

	#	If we don't have a pointer, create one, with it's arrow
	
	unless ($POINTER)
	{
		$POINTER=$CANVAS->create
		(
			'oval', $X-5, $Y-5, $X+5, $Y+5,
			-state=>$POINTER_STATE,
			-outline=>$TURTLE
		);

		#	We need to negate the Y direction as in 'forward'

		$ARROW=$CANVAS->create
		(
			'line',$X, $Y, $X+$x, $Y-$y,
			-state=>$POINTER_STATE,
			-fill=>$TURTLE,
			-arrow=>"last",
			-arrowshape=>'5 4 2'
		);
	}
	else
	{
	#	If we already had a pointer, position it and its arrow and make sure they are visible

		$CANVAS->itemconfigure($POINTER, -state=>$POINTER_STATE);
		$CANVAS->coords($POINTER, $X-5, $Y-5, $X+5, $Y+5);
		$CANVAS->raise($POINTER,'all');
		$CANVAS->itemconfigure($ARROW, -state=>$POINTER_STATE);
		$CANVAS->coords($ARROW, $X, $Y, $X+$x, $Y-$y);
		$CANVAS->raise($ARROW,'all');
	}

	#	Finally, adjust the displayed heading, x and y values

	$SHOWX=int($X+0.499999);
	$SHOWY=int($Y+0.499999);
	$SHOWHEADING=int($HEADING + 0.499999);


}

# ------------------------------------------------------------------
#	Subroutine
#		help;
#
#	Purpose
#		display help for the user
#
sub help
{
	#	Create a dialog box to put the notebook into, this gives us a [close] button
	
	my $help_window = $WINDOW->DialogBox
	(
		-title => "Perl Logo Help",
		-buttons => ["Close"],
		-default_button => "Close"
	);

	#	Now create the notebook in the dialog box

	my $notebook = $help_window->add('NoteBook');

	#	Add the pages we need into the notebook, the first text field in the add parameter list
	#	is the name of the page, which we can select with "raise" or can determine with "raised"

	my $cmd_page = $notebook->add("one", -label => "Commands");
	my $complex_page = $notebook->add("eight", -label => "Complex");
	my $alias_page = $notebook->add("two", -label => "Aliases");
	my $colour_page = $notebook->add("eleven", -label => "Colours");
	my $notes_page = $notebook->add("nine", -label => "Notes");
	my $about_page = $notebook->add("three", -label => "About");
	my $ideas_page = $notebook->add("four", -label => "Ideas");
	my $gnu_page = $notebook->add("five", -label => "GNU");
	my $future_page = $notebook->add("six", -label => "Future");
	my $toolkit_page = $notebook->add("seven", -label => "ToolKit");
	my $dismiss_page = $notebook->add("ten", -label => "DISMISS");

	#	Put the text into each of the notebook pages using a Message display,
	
	$cmd_page->Message
	(
		-textvariable=>\$COMMANDS
	)->pack(-side => "top", -anchor => "nw");
	
	$complex_page->Message
	(
		-textvariable=>\$COMPLEX
	)->pack(-side => "top", -anchor => "nw");

	$alias_page->Message
	(
		-textvariable=>\$ALIASES
	)->pack(-side => "top", -anchor => "nw");

	$colour_page->Message
	(
		-textvariable=>\$COLOURS
	)->pack(-side => "top", -anchor => "nw");

	$notes_page->Message
	(
		-textvariable=>\$NOTES
	)->pack(-side => "top", -anchor => "n");

	$about_page->Message
	(
		-textvariable=>\$ABOUT
	)->pack(-side => "top", -anchor => "ne");

	$ideas_page->Message
	(
		-textvariable=>\$IDEAS
	)->pack(-side => "top", -anchor => "ne");

	$gnu_page->Message
	(
		-textvariable=>\$GNU
	)->pack(-side => "top", -anchor => "ne");

	$future_page->Message
	(
		-textvariable=>\$FUTURE
	)->pack(-side => "top", -anchor => "ne");

	$toolkit_page->Message
	(
		-textvariable=>\$TOOLKIT
	)->pack(-side => "top", -anchor => "ne");

	$dismiss_page->Message
	(
		-textvariable=>\$DISMISS
	)->pack(-side => "top", -anchor => "s");

	#	Now pack the whole notebook into the dialog box we built for it

	$notebook->pack(-expand => "yes",-fill => "both", -padx => 5, -pady => 5, -side => "top");

	#	If the user has called help before, redisplay the last help page they asked for

	$notebook->raise($HELP) if ($HELP);

	#	Now display the help window we just built and wait for the [Close] button
	#	$result contains the button label if we want to test it

	my $result = $help_window->Show;

	#	Save which page the user asked for last, so we can give it to them next time

	$HELP=$notebook->raised();
}

# ------------------------------------------------------------------
#	Subroutine
#		printit;
#
#	Purpose
#		Write the contents of the canvas to a postscript file ready for printing
#

sub printit
{
	#	Remind the user we can only produce a postscript file, they must print it

	inform($CANVAS,"Print can only write a postscript file for you in this version","Please note");

	#	Use the dialog to get the filename to print to

	my $file=$CANVAS->getSaveFile
	(
		-defaultextension=>'ps',
		-filetypes=>[['PostScript files',['.ps']],['All files',['.*','.""']]],
		-initialfile=>"LogoCanvas.ps",
		-initialdir=>$HOME,
		-title=>"Write the canvas to a PostScript file"
	);

	#	Send the output to the file if they want one

	if (defined($file))
	{
		#	Remember whether we are hiding the pointer, then hide it and update the canvas

		my $pointer_state=$POINTER_STATE;
		hide;
		$CANVAS->update;

		#	Produce the output file
		
		$CANVAS->postscript
		(
			-colormode=>'color',
			-file=>$file,
			-rotate=>1
		);

		#	Now restore the pointer state

		$POINTER_STATE=$pointer_state;
	}

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		clear;
#
#	Purpose
#		Clear the canvas and the command area
#

sub clear
{
	#	Check if there are any extraneous parameters

	return if (more(@_));

	#	First, clear the canvas

	$CANVAS->delete("all");

	#	We just got rid of the pointer, clear it

	$POINTER=0;

	#	Clear the entry area

	$ENTRY->delete(0,'end');

	#	Clear any object name we were making with 'make'

	$MAKE="";

	#	Recreate the pointer in case we were called by the button

	pointer;

	#	Return a good response to the caller

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		home;
#
#	Purpose
#		Set the default pointer, direction and location then position the pointer
#

sub home
{
	#	Check if there are any extraneous parameters

	return if (more(@_));

	$X=$HOMEX;
	$Y=$HOMEY;
	adjustHeading('=',0);
	pointer;

	#	do a good return in case we were called from the entry line

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		picker;
#
#	Purpose
#		Allow the user to directly select a colour from the chooseColor dialogue
#

sub picker
{
	#	Find out what the user wants to set the colour for
	
	my $dialog=$WINDOW->Dialog
	(
		-title=>'Colour chooser',
		-text=>'What do you want your colour for?',
		-default_button=>'Yes',
		-buttons=>['Paper','Ink','Fill','Cancel']
	);

	#	Display the message and get the reply

	my $answer=$dialog->Show();

	#	If the reply was cancel, return

	return if ($answer eq 'Cancel');

	#	Get the current colour for what the user wants

	my $colour;

	$colour=$PAPER if ($answer eq 'Paper');
	$colour=$INK if ($answer eq 'Ink');
	$colour=$FILL if ($answer eq 'Fill');

	#	If it's undefined, set it to black

	$colour='black' unless ($colour);

	#	Pop up the colour chooser dialog

	$colour=$WINDOW->chooseColor(-initialcolor=>$colour,-title=>'Choose your colour');

	#	If no colour was chosen, quit

	return unless ($colour);

	#	Now invoke the correct subroutine for the request

	paper($colour) if ($answer eq 'Paper');
	ink($colour) if ($answer eq 'Ink');
	fill($colour) if ($answer eq 'Fill');

	#	Now store the colour chosen

	$COLOUR=$colour;
}

# ------------------------------------------------------------------
#	Subroutine
#		log;
#
#	Purpose
#		Start logging good commands to a file
#		reinvoke it to stop logging
#

sub log
{
	#	If the log is already open, close it
	#	clear the flag and reset the label

	if ($LOG)
	{
		close LOGFILE;
		$LOG=0;
		$LOG_BUTTON->configure(-text=>'Log');
		return;
	}

	#	Use dialog to get the filename to log to

	my $file=$WINDOW->getSaveFile
	(
		-defaultextension=>'log',
		-filetypes=>[['Text files',['.txt','.log']],['All files',['.*','.""']]],
		-initialfile=>"LogoCommands.log",
		-initialdir=>$HOME,
		-title=>"Start logging commands"
	);

	unless (defined($file))
	{
		return;
	}
		
	#	Open the output file

	unless (open(LOGFILE,">$file"))
	{
		inform($WINDOW,"Failed to open $file: $!");
		return;
	}

	#	Flag to show it's open

	$LOG=1;

	#	Print a header for the file

	my $time=localtime(time);
	print LOGFILE "LOGO COMMAND LOG $time\n\n"; 

	#	Change the text on the log button and do a good return

	$LOG_BUTTON->configure(-text=>'Close Log');
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		editor;
#
#	Purpose
#		Allow the user to create/edit/delete their own functions
#	Note
#		The subroutines: store, edit, delete and dismiss are part of this subroutine
#

sub editor
{
	#	Test whether we already have an editor window, if so we
	#	just try to raise that one to the front

	if ($EDITOR)
	{
		$EDITOR->raise if ($EDITOR);
		return;
	}

	#	define the variables which the other subroutines can use

	our $function_name=undef;
	our $function_list=undef;
	our $edit_textbox=undef;
	our $changed=0;

	#	Create a top level editor window for processing user functions

	$EDITOR=$WINDOW->Toplevel(-width=>200,-height=>200,-title=>"User Function Editor");

	#	Now create a frame to put some buttons into

	my $button_frame=$EDITOR->Frame->pack(-side=>"top");
	
	#	Pack an anonymous create button into the frame

	$button_frame->Button
	(
		-text=>"Store",
		-width=>10,
		-command=>\&store
	)
	->pack(-side=>"left");

	#	Pack an anonymous edit button into the frame

	$button_frame->Button
	(
		-text=>"Edit",
		-width=>10,
		-command=>\&edit
	)
	->pack(-side=>"left");

	#	Pack an anonymous delete button into the frame

	$button_frame->Button
	(
		-text=>"Delete",
		-width=>10,
		-command=>\&delete
	)
	->pack(-side=>"left");

	#	Pack an anonymous save button into the frame

	$button_frame->Button
	(
		-text=>"Save",
		-width=>10,
		-command=>\&save
	)
	->pack(-side=>"left");

	#	Pack an anonymous load button into the frame

	$button_frame->Button
	(
		-text=>"Load",
		-width=>10,
		-command=>\&load
	)
	->pack(-side=>"left");

	#	Pack an anonymous dismiss button into the frame

	$button_frame->Button
	(
		-text=>"Dismiss",
		-width=>10,
		-command=>\&dismiss
	)
	->pack(-side=>"left");

	#	Now we create a frame to put the labels into
	
	my $label_frame=$EDITOR->Frame->pack(-side=>'top');

	#	then we pack an anonymous label for the list

	$label_frame->Label(-text=>'Functions',-width=>12)->pack(-side=>"left");

	#	then we pack anonymous labels around a text box for the function name

	$label_frame->Label(-text=>'Edit your function ')->pack(-side=>"left");
	$function_name=$label_frame->Entry
	(
		-width=>12
	)->pack(-side=>'left');
	$label_frame->Label(-text=>' in the box below')->pack(-side=>"left");

	#	Now create a frame to put the function list and edit text area into

	my $text_frame=$EDITOR->Frame->pack(-side=>'top');

	#	Create a scrolled listbox for the function names

	$function_list=$text_frame->Scrolled
	(
		'Listbox',
		-height=>20,
		-width=>12,
		-scrollbars=>'osow',		#	Optional scrollbars, west and south of the listbox
		-selectmode=>'browse'
	)->pack(-side=>'left');

	#	List the current function names - if any

	foreach my $name (sort(keys(%FUNCTION)))
	{
		$function_list->insert('end',$name);
	}

	#	Create a scrolled textbox within which the user can edit the function

	$edit_textbox=$text_frame->Scrolled
	(
		'Text',
		-height=>20,
		-width=>50,
		-scrollbars=>'osoe',		#	Optional scrollbars, east and south of the listbox
		-tabs=>[qw/1c 2c 3c 4c 5c/],
		-wrap=>'word'
	)->pack(-side=>'right',-fill=>'y');

	#	Bind any keypress to an anonymous subroutine so we know if the textbox was changed

	$edit_textbox->bind("<Any-KeyPress>"=>sub{$changed++});

	# ------------------------------------------------------------------
	#	Note that the following subroutines are within the scope of 'editor' and so
	#	can share variables defined within 'editor'

	# ------------------------------------------------------------------
	#	Subroutine
	#		store;
	#
	#	Purpose
	#		store a user function
	#
	
	sub store
	{
		#	Define local variables

		my $name;
		my $text;
		my $word;

		#	Get the function name from the entry box
		
		unless ($name=$function_name->get)
		{
			inform($function_name,"\"store\" needs a function name");
			return;
		}
	
		#	Check it is a reasonable name
	
		unless ($name =~ /^[a-zA-Z][0-9a-zA-Z]*$/)
		{
			inform($function_name,"\"$name\" is not a valid function name");
			return;
		}
		
		#	If there is already a command named the same, reject the request
	
		if ($COMMAND{$name})
		{
			inform($function_name,"\"$name\" is already a command");
			return;
		}
	
		#	If there is already a variable named the same, reject the request
	
		if ($VARIABLE{$name})
		{
			inform($function_name,"\"$name\" is already a user variable");
			return;
		}
	
		#	If there is already a user function with the name, check they want to replace it
	
		if ($FUNCTION{$name})
		{
			my $reply=ask($EDITOR,"Do you want to replace your function \"$name\"?");
			return if ($reply eq 'No');
		}
	
		#	Check whether we got any commands in the function

		$text=$edit_textbox->get('1.0','end');
		if ($text =~ /^\s*$/)
		{
			inform($edit_textbox,"Type the commands for \"$name\" in the text box");
			return;
		}

		#	Organise the whole function into tokens

		my @tokens=parseline($text);

		#	Now convert any command aliases into the actual command itself

		foreach (@tokens)
		{
			if (defined($_) and $word=$COMMAND{$_})
			{
				$_=$word unless (ref($word) eq 'CODE');
			}
		}

		#	Parse the function definition into an array 

		my $r_array=parse($name,\@tokens);

		#	If there were errors, report them relative to the textbox

		return if (error($edit_textbox));

		#	Now set the 'checking' flag and run the commands
		#	checking relies on sub 'more' to not actually execute anything

		$CHECKING=1;
		run($r_array);
		$CHECKING=0;

		#	Again, if there were errors, report them relative to the textbox

		return if (error($edit_textbox));

		#	store a reference to the command array into the command list
		#	this would replace any existing version
	
		$FUNCTION{$name}=$r_array;

		#	Clear the change flag so we don't force the user to save this again

		$changed=0;

		#	Clear the function list

		$function_list->delete(0,'end');

		#	Now redisplay the function list, alphabetically

		foreach $name (sort(keys(%FUNCTION)))
		{
			$function_list->insert('end',$name);
		}
	}
	
	# ------------------------------------------------------------------
	#	Subroutine
	#		edit;
	#
	#	Purpose
	#		edit an existing user function
	#
	
	sub edit
	{
		#	If the text in the main window has changed, suggest the user store it

		return if (changed());

		#	Clear the changed flag

		$changed=0;

		#	Get the currently selected item from the listbox

		my $selection=$function_list->curselection;

		#	Check there is one

		unless (defined($selection))
		{	
			inform($function_list,"Select a function before hitting [Edit]");
			return;
		}

		#	Get the function name from the hash of functions

		my $function=(sort(keys(%FUNCTION)))[$selection];

		#	Clear the function text window

		$edit_textbox->delete('1.0','end');

		#	Get the reference to the function commands

		my $r_function=$FUNCTION{$function};

		#	List the function to the editor list box, with no indentation

		list(0,0,$r_function);

		#	put the function name into the little box

		$function_name->delete(0,'end');

		#	Display the function name

		$function_name->insert('end',$function);
	}
	
	# ------------------------------------------------------------------
	#	Subroutine
	#		list <flag to say list to file> <# of tabs to indent> <function reference>;
	#
	#	Purpose
	#		list the function, formatted in the text window
	#		or the file opened as FUNCTIONS
	#		this calls itself recursively as necessary
	#		if a parameter to a command is a list reference
	#

	sub list($$$)
	{
		#	Get the file flag

		my $file=$_[0];

		#	Get the indentation count

		my $tabs=$_[1];

		#	Get the reference to the array of command lines

		my $r_array=$_[2];

		#	Now process the array, one command line at a time. Remember that each command is actually
		#	a list consisting of the command in the first element and then any parameters in
		#	subsequent elements

		foreach my $r_list (@$r_array)
		{
			#	Before each line, output the requisite number of tabs

			if ($file)
			{
				print FUNCTIONS "\t" x $tabs if ($tabs);
			}
			else
			{
				$edit_textbox->insert('end',"\t" x $tabs) if ($tabs);
			}
			
			foreach my $word (@$r_list)
			{

				#	Each parameter may be a new array (if it's a 'repeat' or 'for')

				if (ref($word) eq 'ARRAY')
				{
					#	If it's an array, start it on a new line, and put in
					#	the brackets before and after we reinvoke to list it
					#	Not forgetting we want one more tab in the indent

					if ($file)
					{
						print FUNCTIONS "\n"."\t" x $tabs."[\n";
					}
					else
					{
						$edit_textbox->insert('end',"\n"."\t" x $tabs."[\n");
					}
					list($file,$tabs+1,$word);
					if ($file) # Put an extra space after the close bracket to separate any 'else'
					{
						print FUNCTIONS "\t" x $tabs."] ";
					}
					else
					{
						$edit_textbox->insert('end',"\t" x $tabs."] ");
					}
				}
				else
				{
					if ($file)
					{
						print FUNCTIONS $word.' ';
					}
					else
					{
						$edit_textbox->insert('end',$word.' ');
					}
				}
			}
			if ($file)
			{
				print FUNCTIONS "\n";
			}
			else
			{
				$edit_textbox->insert('end',"\n");
			}
		}
	}
	
	# ------------------------------------------------------------------
	#	Subroutine
	#		delete;
	#
	#	Purpose
	#		delete and existing user function
	#
	
	sub delete
	{
		#	define variables

		my ($answer, $name, $selection);

		#	If the text in the main window has changed, suggest the user store it

		return if (changed());

		#	Get the currently selected item from the listbox

		$selection=$function_list->curselection;

		#	Check there is one

		unless (defined($selection))
		{	
			inform($function_list,"Select a function before hitting [Delete]");
			return;
		}

		#	Get the function name from the hash of functions

		my $function=(sort(keys(%FUNCTION)))[$selection];

		#	Check this is what they meant to do

		$answer=ask($function_list, "Do you really want to delete function $function?");

		if ($answer eq 'No')
		{
			return;
		}

		#	Delete the function from the hash

		delete $FUNCTION{$function};

		#	Clear the function text window

		$edit_textbox->delete('1.0','end');

		#	similarly, clear the little box

		$function_name->delete(0,'end');

		#	Clear the function list

		$function_list->delete(0,'end');

		#	Now redisplay the function list, alphabetically

		foreach $name (sort(keys(%FUNCTION)))
		{
			$function_list->insert('end',$name);
		}
	}
	
	# ------------------------------------------------------------------
	#	Subroutine
	#		save;
	#
	#	Purpose
	#		save all of the user functions to a file
	#
	
	sub save
	{

		#	Give the option to store the edit window if it has changed

		return if (changed());

		#	Use dialog to get the filename to save as

		my $file=$EDITOR->getSaveFile
		(
			-defaultextension=>'txt',
			-filetypes=>[['Text files',['.txt','.log']],['All files',['.*','.""']]],
			-initialfile=>"LogoFunctions.txt",
			-initialdir=>$HOME,
			-title=>"Save Logo Functions"
		);

		unless (defined($file))
		{
			return;
		}
		
		#	Open the output file

		unless (open(FUNCTIONS,">$file"))
		{
			inform($EDITOR,"Failed to open $file: $!");
			return;
		}

		#	Print a header for the file

		print FUNCTIONS "LOGO VERSION $VERSION\n";

		#	Process through the functions

		foreach my $function (sort(keys(%FUNCTION)))
		{
			#	Print a header for this function

			print FUNCTIONS "FUNCTION $function:\n";

			#	Get the reference to the function

			my $r_function=$FUNCTION{$function};

			#	Now list it to the open file

			list(1,0,$r_function);
		}

		#	Close the file

		close FUNCTIONS;
	}
	
	# ------------------------------------------------------------------
	#	Subroutine
	#		load;
	#
	#	Purpose
	#		load user functions from a file
	#
	
	sub load
	{
		#	Define variables we need

		my ($version, $function, $line, $detail);
		my $count=0;

		#	If the text in the main window has changed, suggest the user store it

		return if (changed());

		#	Use dialog to get the input file name

		my $file=$EDITOR->getOpenFile
		(
			-defaultextension=>'txt',
			-filetypes=>[['Text files',['.txt','.log']],['All files',['.*','.""']]],
			-initialfile=>"*.txt",
			-initialdir=>$HOME,
			-title=>"Load Logo Functions File"
		);

		unless (defined($file))
		{
			return;
		}

		unless (open(FUNCTIONS,"<$file"))
		{
			inform($EDITOR,"Failed to open $file: $!");
			return;
		}

		#	Check the first line to see if it's our file

		$version=<FUNCTIONS>;
		chomp $version;
		unless ($version =~  /^LOGO VERSION (\d\.\d+)$/)
		{
			inform($EDITOR,"This file is not a Logo functions file");
			close FUNCTIONS;
			return;
		}

		#	Now check whether it's a version we can deal with

		unless ($1 >= 0.86)
		{
			inform($EDITOR,"Sorry, this version of functions cannot be processed");
			close FUNCTIONS;
			return;
		}

		#	Now expect to read a "FUNCTION name:" statement followed by the lines of the function

		while ($line=<FUNCTIONS>)
		{
			#	If we have a new function name, extract it to $1 by using ()

			if ($line =~ /^FUNCTION ([a-zA-Z][a-zA-Z0-9]*)\:$/)
			{
				#	Count the functions as we stash them

				$count += stash($function,$detail);

				#	Now clear the detail space and grab the extracted function name
				#	$1 presupposes 'sub stash' doesn't use any () match processing

				$detail="";
				$function=$1;
				
				#	Go read the next line
				next;
			}

			#	For each detail line, concatenate them to the detail string

			$detail .= $line;
		}

		#	Now stash the last (or only) function - if any

		$count += stash($function,$detail);

		#	Inform the user how many functions we read

		inform($EDITOR,"Read in $count functions","Information");

		# And close the file

		close FUNCTIONS;
	}

	# ------------------------------------------------------------------
	#	Subroutine
	#		stash;
	#
	#	Purpose
	#		put functions read by 'load' into the internal functions list
	#
	
	sub stash($$)
	{
		#	Get the function name and text we were passed
		#	If there is no function name, just return 0, this
		#	simplifies the callers code. If we stash a function
		#	return a 1 so it gets counted

		return 0 unless (my $name=$_[0]);
		
		my $text=$_[1];

		#	Check it is a reasonable name
	
		unless ($name =~ /^[a-zA-Z][0-9a-zA-Z]*$/)
		{
			inform($function_name,"\"$name\" is not a valid function name");
			return 0;
		}
		
		#	If there is already a command named the same, reject the request
	
		if ($COMMAND{$name})
		{
			inform($function_name,"\"$name\" is already a command");
			return 0;
		}
	
		#	If there is already a user function with the name, check they want to replace it
	
		if ($FUNCTION{$name})
		{
			my $reply=ask($EDITOR,"Do you want to replace your function \"$name\"?");
			return 0 if ($reply eq 'No');
		}
	
		#	If there is already a variable named the same, reject the request
	
		if ($VARIABLE{$name})
		{
			inform($function_name,"\"$name\" is already a user variable");
			return 0;
		}
	
		#	Check whether we got any commands in the function

		if ($text =~ /^\s*$/)
		{
			inform($EDITOR,"There is no text in function \"$name\"");
			return 0;
		}

		#	Organise the whole function into tokens

		my @tokens=parseline($text);

		#	Parse the function definition into an array 

		my $r_array=parse($name,\@tokens);

		#	If there were errors, report them relative to the textbox

		return 0 if (error($edit_textbox));

		#	Now set the 'checking' flag and run the commands
		#	checking relies on sub 'more' to not actually execute anything

		$CHECKING=1;
		run($r_array);
		$CHECKING=0;

		#	Again, if there were errors, report them relative to the textbox

		return 0 if (error($edit_textbox));
	
		#	store a reference to the function array into the function list
		#	this would replace an existing version
	
		$FUNCTION{$name}=$r_array;

		#	Clear the function list

		$function_list->delete(0,'end');

		#	Now redisplay the function list, alphabetically

		foreach $name (sort(keys(%FUNCTION)))
		{
			$function_list->insert('end',$name);
		}

		#	Return a 1 so the function gets counted

		return 1;
	}

	# ------------------------------------------------------------------
	#	Subroutine
	#		dismiss;
	#
	#	Purpose
	#		dismiss the editor window, the $changed flag dissappears with the window
	#
	
	sub dismiss
	{
		return if (changed());
		$EDITOR->destroy;	

		#	Flag to show we don't have an editor window now

		$EDITOR=0;
	}
	
	# ------------------------------------------------------------------
	#	Subroutine
	#		changed;
	#
	#	Purpose
	#		Check whether the function in the edit window has changed
	#		If it has, suggest the user store it before continuing
	#	Return
	#		zero if the user doesn't care, 1 if the user wants to store
	#	Usage
	#		return if (changed());
	#
	
	sub changed
	{
		#	If the text in the main window has changed, suggest the user store it

		if ($changed)
		{
			my $answer=ask($edit_textbox,
			"The text in the edit window has changed, do you want a chance to store it?");

			return 1 if ($answer eq 'Yes');
		}

		#	User isn't interested, return zero

		return 0;
	}

	# ------------------------------------------------------------------
	#	End the 'editor' subroutine within which the subroutines above are enclosed

}

# ------------------------------------------------------------------
#	Subroutine
#		enter;
#
#	Purpose
#		Wrapper around subroutine [entry] to grab returns

sub enter
{
	#	Change 'go' to 'stop' etc

	$GO->configure(-text=>"Stop",-command=>sub{$STOP=1});

	#	Call the entry subroutine to do the work

	entry;

	#	Change 'stop' to 'go' etc

	$GO->configure(-text=>'GO',-command=>\&enter);
}


# ------------------------------------------------------------------
#	Subroutine
#		entry;
#
#	Purpose
#		process whatever was typed in the entry box
#		or process the command string if we were called internally
#

sub entry()
{
	#	Grab the input in case the user changes it

	my $line=$ENTRY->get;

	#	return if the line is empty

	if ($line =~ /^\s*$/)
	{
		inform($ENTRY,"Type a command in the entry line and hit [GO]");
		return;
	}

	#	break the entry line into an array of tokens
	
	my @tokens=parseline($line);

	#	Now process the tokens into an array of command lists(arrays), eg a command and it's parameters are
	#	each a separate item in an anonymous array referenced by an element of the returned array.
	#	If the parser hits '[' it invokes itself to give a nested array

	my $r_array=parse('',\@tokens);

	#	If there was an error in parsing, send it back to the user relative to the entry window

	return if (error($ENTRY));

	#	Now set the 'checking' flag and run the commands in check mode
	#	checking relies on sub 'more' to not actually execute anything
	#	although this means we do twice the work, it really doesn't
	#	matter too much for stuff from the command line and it's better
	#	than the user getting a partially run set of commands

	$CHECKING=1;
	run($r_array);
	$CHECKING=0;

	#	In case the user hit stop while checking, unset it

	$STOP=0;

	#	If there was an error in checking, send it back to the user relative to the entry window

	return if (error($ENTRY));

	#	Process the array of list references using the 'run' function

	run($r_array);

	#	If the user hit stop while running, unset it

	$STOP=0;

	#	If we hit the recursion limit, tell the user how many times, and clear it

	if ($LIMIT)
	{
		inform($ENTRY,"You hit the recursion limit $LIMIT times","Recursion");
		$LIMIT=0;
	}

	#	If there was an error running, send it back to the user

	return if (error($ENTRY));
	
	#	Otherwise, we processed the input, put it on the clipboard

	$WINDOW->clipboardClear;
	$WINDOW->clipboardAppend(-type=>'STRING','--', $line);

	#	If we have been asked to log, write it to the log file

	print LOGFILE "$line\n" if ($LOG);
	
	#	Clear the command area

	$ENTRY->delete(0,'end');

	#	and reposition the pointer

	pointer;
}

# ------------------------------------------------------------------
#	Subroutine
#		inform <owning window> <message text> [title text];
#
#	Purpose
#		Pop up a dialog box with an error and just an OK button
#

sub inform($$;$)
{
	#	Define variables

	my $title;

	#	Grab the window to relate the message to

	my $window=$_[0];

	#	Grab the message to be displayed

	my $message=$_[1];

	#	Get the title text or set the default value

	unless($title=$_[2])
	{
		$title='Entry error';
	}

	#	Now create the array of buttons

	my @buttons=['OK'];

	#	Create the dialog box based on the ENTRY field

	my $dialog=$window->Dialog(-title=>$title, -text=>$message, -default_button=>'OK', -buttons=>@buttons);

	#	Display the message and get the reply - always 'OK'

	my $answer=$dialog->Show();

	#	Make sure we send back an empty return

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		ask <window> <message text>;
#
#	Purpose
#		Pop up a dialog box relative to the given window with a Y/N question
#

sub ask($$)
{
	#	Grab the window name

	my $window=$_[0];

	#	Grab the message to be displayed

	my $message=$_[1];

	#	Now create the array of buttons

	my @buttons=['Yes', 'No'];

	#	Create the dialog box based on the window

	my $dialog=$window->Dialog(-title=>'Question', -text=>$message, -default_button=>'Yes', -buttons=>@buttons);

	#	Display the message and get the reply

	my $answer=$dialog->Show();

	#	Make sure we send back the answer

	return $answer;
}

# ------------------------------------------------------------------
#	Subroutine
#		parseline(<textline>);
#
#	Purpose
#		Acts as a wrapper for parse_line - part of Text::ParseWords.
#		parse_line has a number of bugs, it returns empty strings
#		as tokens if the original text starts or ends with whitespace.
#		It returns no tokens if a 'word" is wrapped by unmatched quotes.

sub parseline($)
{
	#	Define variables

	my($text, @tokens, @parsed);

	#	Get the text

	$text=$_[0];

	#	Pass the textline to parse_line, ask it to break up
	#	the text by whitespace and leave quotes around strings

	@parsed=parse_line('\s+',1,$text);

	#	Check whether we got an empty array back

	unless (scalar(@parsed))
	{
		#	If we did and there were words in the original, complain

		push (@ERROR,"there are unmatched quotes in the input line") if ($text =~ /\S/);

		#	Otherwise, there was nothing parsed, return the empty array

		return (@parsed);
	}

	#	Now run through each token in turn looking for empty ones

	foreach (@parsed)
	{
		#	If the token is null just ignore it

		next unless (defined($_));

		#	Similarly, if it's complete whitespace, ignore it

		next if (/^\s*$/);

		#	If it looks like a good token, retain it

		push (@tokens,$_);
	}

	#	Return the array of tokens to the caller

	return (@tokens);
}

# ------------------------------------------------------------------
#	Subroutine
#		parse(<function name OR null> <reference to an array of tokens> <optional nest level>);
#
#	Purpose
#		To take an array of tokens and organise them into command lists(arrays), one list per
#		command with it's parameters. References to the lists(arrays) are stored in the array
#		If we got a list of tokens like (fwd 20 left 90 fwd 30), the resulting array would be
#		[\['fwd',20],\['left',90],\['fwd',30]].
#		The nest level allows us to detect whether we got too many closing brackets,
#		we should not be nesting up if we weren't nested down. Starts at an implied 0
#		The function name allows us to accept recursive calls to a new function
#		which is just being built
#
#	Returns
#		Returns a reference to the array, any errors go into $ERROR
#
#	Notes
#		Should be checking the parameters to the commands
#


sub parse($$;$)
{
	#	Reference any function name we were passed

	my $function=shift;

	#	Reference the token array we were passed

	my $r_tokens=shift;

	#	Set the nest level, from the parameters if it's there

	my $nest=shift;
	$nest=0 unless ($nest);

	#	Define an array for the commands which we will build from the tokens

	my @commands=();

	#	Something to hold the current token

	my $token="";

	#	A place to remember the last command we stacked

	my $last_command=undef;

	#	Process one token at a time, tokens can be zero so we can't just do 'while($token=shift...)'

	while(@$r_tokens)
	{
		$token=shift(@$r_tokens);

		# Provided the token doesn't start with a quote, convert it to lower case
		$token=lc($token) unless ($token =~ /^[\'\"]/);

		#	check if it's in the official command hash or the user function list
		#	or its the function name we were passed (a recursive call of this new function)

		if ($COMMAND{$token} or $FUNCTION{$token} or ($function eq $token))
		{
			#	If it is a command then we add a reference to a new anonymous array onto the
			#	end of the command array and put the token into the first element of the array
			#	Save the command name for '[' check below and go for the next token
		
			push(@commands,[$token]);
			$last_command=$token;
			next;
		}

		#	The token wasn't a command so should already have a command to append it to

		unless (@commands)
		{
			#	It looks like a parameter but doesn't have a command to append to
			#	so the user must have entered it as a command

			push(@ERROR,"the command \"$token\" is not known\n");
			return;
		}

		#	If the token is an open bracket, reinvoke ourself with the remaining tokens
		#	which will go until the first close bracket and return us a pointer to an array.
		#	Because the main loop is a while rather than a foreach, this will work OK

		if ($token eq '[')
		{
			#	Check whether it is appropriate for this command to have [

			unless (grep(/^$last_command$/,@COMPLEX_COMMANDS)) 
			{
				push(@ERROR,"$last_command does not use '['");
				return;
			}

			#	Pass an incremented nest level so we can check correctness of ']' 
			#	Also pass the function name we were given to allow recursive checks

			my $r_subcommand=parse($function,$r_tokens,$nest+1);

			#	Ignore any errors, they will be picked up anyway when we return to 'sub entry'.
			#	Store the returned array as a parameter to the command, eg a new item in the
			#	anonymous array which already contains the current command.
			#	If there were any errors, we won't ever process the commands so it doesn't
			#	matter if we got back junk.

			push (@{$commands[$#commands]},$r_subcommand);
			next;
		}

		#	If the token is a close bracket, we should have some commands to pass back
		#	and we should also be nested down at least 1 level, if not we complain

		if ($token eq ']')
		{
			return \@commands if (@commands and $nest);
			push(@ERROR,"misplaced close bracket ']'\n");
			return;
		}

		#	We have a parameter so append it to the command we already have in the list pointed to
		#	by the present entry in the array then go process the next token

		push (@{$commands[$#commands]},$token);
		next;
	}

	#	We should never get here if we are nested down a level

	if ($nest)
	{
		push(@ERROR,"missing close bracket ']'\n");
		return;
	}

	#	The array of tokens was OK, return a reference to the command array

	return \@commands;
}

# ------------------------------------------------------------------
#	Subroutine
#		error <related window>;
#
#	Purpose
#		Output any errors in a user dialogue then clear
#		the @ERROR array and return true if there were
#		errors. The caller can thus do 'return if (error);'
#

sub error($)
{
	#	Get the related window

	my $window=$_[0];

	#	If there are no errors in the array return 'false'

	return unless(@ERROR);

	#	Display the errors to the user

	inform($window,"@ERROR\ncorrect the error(s) and hit [GO]");

	#	Clear the error array

	@ERROR=();

	#	Return a true response

	return 1;
}

# ------------------------------------------------------------------
#	Subroutine
#		more <callers name> <parameters>;
#
#	Purpose
#		Check whether there are parameters, if so
#		they are an error since they were not needed
#		by the subroutine which called us to check.
#		Sub 'more' also checks if we are in checking mode
#		and returns a phantom error to stop the caller command running
#	Return
#		one if there were any extra parameters
#		two if we are in checking mode, zero otherwise
#	Usage
#		return if (more());
#	Note
#		This subroutine is defined without parameters because defining
#		it as 'sub more($)' always gave a parameter whereas defining it
#		without parameters, it doesn't get a parameter unless there is one
#

sub more
{
	#	Grumble if there were any passed parameters

	if (defined($_[0]))
	{
		my $passed=join(' ',@_);

		push(@ERROR,"$CURRENT found these unwanted parameters \"$passed\"");
		return 1;
	}

	#	If we are just in checking mode, return true so the caller doesn't actually
	#	complete the command they were asked to do

	return 2 if ($CHECKING);

	#	Return a good result so the caller carries on executing

	return 0;
}

# ------------------------------------------------------------------
#	Subroutine
#		tokenise <string>;
#
#	Purpose
#		break a string into tokens, returned as a list
#		the Text::ParseWords functions don't do this for parsing a mathematical expression
#

sub tokenise($)
{
	#	Define some variables we need

	my ($string, $error, $nest, $found, @tokens);
	$nest=0;

	#	Get the string we need to process

	$string=shift;

	#	Work our way along the string, extracting tokens which can be mathematical expressions
	#	or parentheses or words or numbers, aBc123 counts as a word, aBc 123 is a word and a number
	#	we do this by replacing any found token with null at the start of the string until there is
	#	nothing left. The () notation around the search strings captures the replaced token into $1.

	while (length($string))
	{
		#	The next line extracts either: whitespace, word, number, symbol, parenthesis, anything else

		unless ($string =~ s/^(\s+)|([a-zA-Z]\w*)|(\d*[\d\.\,]\d*)|([\+\-\/\*\%\!\=]+)|([\(\)])|(.)//)
		{
			return "Problem in subroutine 'tokenise', nothing found in \"$string\"";
		}
		$found="";
		$found.=$1 if ($1);
		$found.=$2 if ($2);
		$found.=$3 if ($3);
		$found.=$4 if ($4);
		$found.=$5 if ($5);
		$found.=$6 if ($6);
		$nest++ if ($found eq '(');
		$nest-- if ($found eq ')');
		push(@tokens,$found);

		#	Do some checks to prevent accidental problems....

		return "can't allow dog-eared quotes \"`\"" if ($found eq '`');
		return "can't allow \"system\"" if ($found eq 'system');
		return "can't allow \"exec\"" if ($found eq 'exec');
		return "can't allow \"kill\"" if ($found eq 'kill');
	}


	#	Grumble about unmatched parentheses if appropriate

	return "unmatched parentheses" unless ($nest == 0);

	#	Return an empty string and the tokenised values

	return "",@tokens;
}

# ------------------------------------------------------------------
#	Subroutine
#		alias <alias name> <command>;
#
#	Purpose
#		Put an alias for the defined command into the command array, this is normally expected to be
#		used within a language definition module and it must be used after the commands have already
#		been defined.
#		To allow for possible end user use, allow for the command in quotes, if the user puts the command
#		without quotes, it never gets passed in as a parameter

sub alias($$)
{
	#	Define the variables we need

	my($alias, $command);

	#	Get the alias name

	unless (defined($alias=shift))
	{
		aliaserror "Alias needs an alias name\n";
		return;
	}
	
	#	check it isn't already a command, function or variable

	if ($COMMAND{$alias})
	{
		aliaserror "There is already a command called \"$alias\"\n";
		return;
	}
	if ($VARIABLE{$alias})
	{
		aliaserror "There is already a variable called \"$alias\"\n";
		return;
	}
	if ($FUNCTION{$alias})
	{
		aliaserror "There is already a function called \"$alias\"\n";
		return;
	}

	#	Get the command name they want to alias this to

	unless (defined($command=shift))
	{
		aliaserror "Alias needs a command to alias, put it in quotes from the entry line\n";
		return;
	}

	#	Remove any quotes

	if ($command =~ s/^[\'\"]//)
	{
		$command =~ s/$&$//;
	}

	#	We can only alias to an existing command

	unless (ref($COMMAND{$command}) eq 'CODE')
	{
		aliaserror "There is not a command \"$command\" to alias\n";
		return;
	}

	#	check if there are any extraneous parameters

	return if (more(@_));

	#	Store the alias into the command hash, it contains the actual command name

	$COMMAND{$alias}=$command;

	#	If this is an alias to a complex command which takes [], add the alias to the list

	push(@COMPLEX_COMMANDS,$alias) if (grep(/^$command$/,@COMPLEX_COMMANDS));

	return;

	# ------------------------------------------------------------------
	#	Subroutine
	#		aliaserror <message>;
	#
	#	Purpose
	#		output message appropriate to whether we were called at initialization or by the user
	#		This sub is within the scope of alias

	sub aliaserror($)
	{
		#	If $WINDOW is defined, we are running for the user

		if ($WINDOW)
		{
			push(@ERROR,$_[0]);
		}
		else
		{
			print($_[0]);
		}
	}
}

# ------------------------------------------------------------------
#	Subroutine
#		number(<minimum>,<maximum>,<name>,<value>);
#
#	Purpose
#		validate an entered number
#		if minimum or maximum is 'none', we don't check it
#		name is the name of the value, used for explanatory messages
#	Return
#		<error message><value>; if error message is undef, value is valid
#

sub number($$$$)
{
	#	Get the minimum and maximum values and the value name

	my $minimum=shift;
	my $maximum=shift;
	my $name=shift;

	#	Return an error if there is no value

	return "no $name specified" unless (defined $_[0]);

	#	Complain if there are too many parameters

	return "too many values" unless (@_==1);

	#	Now get the number
	
	my $number=shift;

	#	Check the number is numeric, if not see if its a user variable
	#	We allow an optional leading sign(+ or -) zero or more leading digits
	#	a decimal point or decimal comma then
	#	zero or more decimal digits but there must be at least one digit before
	#	after any decimal point

	unless ($number =~ /^[+-]?\d*[\d\.\,]\d*$/)
	{
		if (exists $VARIABLE{$number})
		{
			$number=$VARIABLE{$number};
		}
		else
		{
			return "$name \"$number\" is not a number";
		}
	}
	#	The regular expression above doesn't reject '.' or ',' on its own

	return "$name \"$number\" is not a number" if ($number eq '.' or $number eq ',');

	#	Now check if it is in bounds

	unless ($minimum eq 'none')
	{
		return "$name must be at least $minimum" unless ($number >= $minimum);
	}

	unless ($maximum eq 'none')
	{
		return "$name must be at most $maximum" unless ($number <= $maximum);
	}

	#	Checked out OK, return to caller

	return undef,$number;
}

# ------------------------------------------------------------------
#	Subroutine
#		colour([<qualifier>,[<qualifier>,]]<colour>);
#
#	Purpose
#		validate a colour for a calling subroutine
#

sub colour($)
{
	#	If we were given no colour, return

	return "no colour specified" unless (@_);

	#	Get the parameter, there should only be one
	#	but if there are qualifying words put them all into the string
	#	since the colour mechanism is happy with things like dark red
	
	my $colour="";
	my ($temp, @temp);

	while(@_) # allow for a value of zero
	{
		$temp=shift;
		$colour .= $temp.' ';
	}

	#	Remove the trailing space and any quotes

	chop $colour;
	$colour =~ s/["']//g;

	#	If it's a number, convert it to a colour name using the Sinclair
	#	Spectrum colour set, adjusted modulus 8 to give the 0-7 values

	my ($return,$value)=number(0,'none','colour',$colour);
	unless ($return)
	{
		@temp=qw/black blue red magenta green cyan yellow white/;
		$temp = $value % 8;
		$colour = $temp[$temp];
	}

	#	Now check the colour value is valid
	#	the eval gives an error message in $@ if the color is bad
	
	eval {local $SIG{'__DIE__'}; $CANVAS->rgb($colour)};
	return "invalid colour" if ($@ =~ /unknown/);

	#	Otherwise, return an empty error string and the actual colour
	

	return "",$colour;
}

# ------------------------------------------------------------------
#	Subroutine
#		angle <name> <value>;
#
#	Purpose
#		validate a given angle, the name is for error reporting
#

sub angle($$)
{
	#	Get the name

	my $name=shift;

	#	Do the numeric check

	my ($return,$angle)=number(-360,360,$name,$_[0]);

	#	Check whether we got an error

	if ($return)
	{
		#	If the angle is not numeric, see if its a compass heading

		if ($return =~ /not a number/)
		{
			$angle=$COMPASS{lc $_[0]};
			return "$name is neither a number nor a compass heading" unless (defined $angle);
		}
		else
		{
			#	we have another returned message, throw it back

			return $return;
		}
	}

	#	Return no error and the angle

	return undef, $angle;
}

# ------------------------------------------------------------------
#	Subroutine
#		run <\@command lists>
#
#	Purpose
#		Execute the command lists referenced in the passed array
#		errors go into the ERROR array
#

sub run($)
{

	#	Get the pointer to the array of command lists

	my $r_commands=$_[0];

	#	Set up the work variables

	my $command;
	my @parameters;
	my $return;
	my $r_list;

	foreach $r_list (@$r_commands)
	{
		#	Stop working if we get a STOP request from the user

		if ($STOP)
		{
			#	Since we can sometimes get restarted from (say) a repeat, we need
			#	to know if we were already invoked
			
			push(@ERROR,"STOP requested") unless ($STOP++ >1);
			return;
		}

		#	Get the command and parameters from the list, note that we must not
		#	destroy the list in case it is part of a user function or repeat, in
		#	which case it will be needed again!

		($command,@parameters)=@$r_list;

		#	If the command is a user function the reference is an array

		if (my $r_command=$FUNCTION{$command})
		{
			#	Clear a counter for us to use

			my $count=0;

			#	Check that the function isn't already executing too many times at a higher level

			foreach my $function (@EXECUTING)
			{
				$count++ if ($command eq $function);
			}

			#	If we are in checking mode, we don't do recursion, there is no point

			unless ($count and $CHECKING)
			{
				#	If we recursed too far, count it and skip this request

				if ($count>$RECURSION)
				{
					$LIMIT++;
				}
				else
				{
					#	process the array by calling myself again, passing the command array,
					#	also make sure the current command name goes into the EXECUTING array

					push(@EXECUTING,$command);
					$return=run($r_command);
					pop(@EXECUTING);
				}
			}
		}
		#	Otherwise it may be a built in command

		elsif ($r_command=$COMMAND{$command})
		{
			#	grab the subroutine reference for the built in command

			$r_command=$COMMAND{$command};

			#	If the reference actually contains a string, it was an alias, so resolve it

			$r_command=$COMMAND{$r_command} unless (ref($r_command) eq 'CODE');

			#	Set the current command text for error messages etc

			$CURRENT=$command;

			#	call the command with parameters, grab any returned string

			$return=&$r_command(@parameters);

			#	If we are running in slow mode, let the display catch up

			$CANVAS->update if ($SLOW);
		}
		#	Otherwise we *assume* it's a user function being recursively called and ignore it
		else
		{
			$return="Bad command \"$command\" found\n" unless ($CHECKING);
		}

		#	If there was a returned error message add it to the error array

		if (defined($return))
		{
			push(@ERROR,"$command: $return\n");

			#	Return due to the error, unless we are checking

			return unless $CHECKING;
		}
	}
	#	Return an undefined return code to the caller

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		comment <ignored>;
#
#	Purpose
#		To allow the user to use comments in stored functions
#
#	

sub comment($)
{
	#	Comments are ignored

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		forward(<distance>);
#
#	Purpose
#		draw a line in the direction the pointer points
#
#	

sub forward($)
{
	#	Grab the distance

	my $distance=shift;
	
	#	Do the numeric check, return any failure message

	my ($return,$value)=number(-$MAXX-$MAXY,$MAXX+$MAXY,'distance',$distance);
	return $return if $return;

	#	Check if there are further parameters

	return if (more(@_));

	#	Convert the required distance into x and y values
	#	depending on the angle on which we are heading
	
	my $x=$value * sin($RADIANS);
	my $y=$value * cos($RADIANS);

	#	Now draw the line with the current ink color, if the pen is down
	#	remember that directionally down is up and up is down, so we need
	#	to subtract the incremental vertical distance not add it

	$CANVAS->create('line',$X,$Y,$X+$x,$Y-$y,-fill=>$INK,-tags=>[$MAKE],-width=>$WIDTH) if ($PEN eq 'down');

	#	Then move the pointer co-ordinates
	#	remembering that down is up and up is down....

	$X+=$x;
	$Y-=$y;

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		backward(<distance>);
#
#	Purpose
#		draw a line in the opposite direction to which the pointer points
#
#	

sub backward($)
{
	#	Get the distance

	my $distance=shift;

	#	Do the numeric check, return any failure message

	my ($return,$value)=number(-$MAXX-$MAXY,$MAXX+$MAXY,'distance',$distance);
	return $return if $return;

	#	Check for any extra parameters

	return if (more(@_));

	#	Now call "forward" with the negated distance

	forward(-$value);
}

# ------------------------------------------------------------------
#	Subroutine
#		left(<degrees>);
#
#	Purpose
#		move the heading number of degrees left
#

sub left($)
{
	#	Get the angle

	my $angle=shift;
	
	#	Do the numeric check, return any failure message

	my ($return,$value)=number(-360,360,'angle',$angle);
	return $return if $return;

	#	Check extra params

	return if (more(@_));

	#	Change the heading by the given angle and adjust within 0 .. 360

	adjustHeading('-',$value);

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		right(<degrees>);
#
#	Purpose
#		move the heading number of degrees right
#

sub right($)
{
	#	Get the angle

	my $angle=shift;
	
	#	Do the numeric check, return any failure message

	my ($return,$value)=number(-360,360,'angle',$angle);
	return $return if $return;
	
	#	Check extra params

	return if (more(@_));

	#	Change the heading by the given angle and adjust within 0 .. 360

	adjustHeading('+',$value);
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		paper(<optional qualifiers> <colour>);
#
#	Purpose
#		set the paper (background) colour
#	

sub paper($)
{
	#	If we were given no colour, return

	return "no colour specified" unless (@_);

	#	Extract the colour value, or an error message

	(my $error, my $colour)=colour(join(' ',@_));

	#	If we got an error message, return it

	return $error if $error;

	#	Skip if we are just checking

	return if $CHECKING;

	#	Now set the colour
	
	$CANVAS->configure(-background=>$colour);

	#	Retain the value for the future

	$PAPER=$colour;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		ink(<optional qualifiers> <colour>);
#
#	Purpose
#		set the ink (foreground) colour
#	

sub ink($)
{
	#	If we were given no colour, return

	return "no colour specified" unless (@_);

	#	Extract the colour value, or an error message

	(my $error, my $colour)=colour(join(' ',@_));

	#	If we got an error message, return it

	return $error if $error;

	#	Skip if we are just checking

	return if $CHECKING;

	#	Ink colour is used in the drawing routines so just retain the value for the future
	
	$INK=$colour;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		turtle(<optional qualifiers> <colour>);
#
#	Purpose
#		set the turtle (pointer) colour
#	

sub turtle($)
{
	#	If we were given no colour, return

	return "no colour specified" unless (@_);

	#	Extract the colour value, or an error message

	(my $error, my $colour)=colour(join(' ',@_));

	#	If we got an error message, return it

	return $error if $error;

	#	Skip if we are just checking

	return if $CHECKING;

	#	Turtle colour is used in the pointer routine, so just set the value
	
	$TURTLE=$colour;

	#	Now get rid of the pointer and its arrow from the canvas

	$CANVAS->delete($POINTER);
	$CANVAS->delete($ARROW);
	
	#	clear the pointer value so it gets recreated
	
	$POINTER=0;
	$ARROW=0;

	#	And return to the caller

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		fill(<optional qualifiers> <colour>);
#
#	Purpose
#		set the fill colour used in box, disk etc
#	

sub fill($)
{
	#	If we were given no colour, return

	return "no colour specified" unless (@_);

	#	If we only have 'off' as a value, turn fill off

	if ($_[0] eq 'off' and @_ == 1)
	{
		$FILL=undef unless $CHECKING;
		return;
	}

	#	Extract the colour value, or an error message

	(my $error, my $colour)=colour(join(' ',@_));

	#	If we got an error message, return it

	return $error if $error;

	#	Skip if we are just checking

	return if $CHECKING;

	#	Ink colour is used in the drawing routines so just retain the value for the future
	
	$FILL=$colour;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		penup
#
#	Purpose
#		stop the pen from writing, movement commands move but don't write
#	

sub penup
{
	#	Check if we got extra parameters

	return if (more(@_));

	$PEN='up';
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		pendown
#
#	Purpose
#		start the pen writing, movement commands move and write
#	

sub pendown
{
	#	Check if we got extra parameters

	return if (more(@_));

	$PEN='down';
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		hide
#
#	Purpose
#		hide the pointer
#	

sub hide
{
	#	Check if we got extra parameters

	return if (more(@_));

	$POINTER_STATE="hidden";
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		show
#
#	Purpose
#		show the pointer
#	

sub show
{
	#	Check if we got extra parameters

	return if (more(@_));

	$POINTER_STATE="normal";
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		heading(<angle>);
#
#	Purpose
#		set the pointer heading to a new angle
#	

sub heading($)
{
	#	Get the angle

	my $angle=shift;

	#	Check the angle
	
	(my $return, $angle) = angle('heading',$angle);

	#	if we got a returned message, throw it back

	return $return if (defined($return));

	#	Check if we get extra parameters

	return if (more(@_));

	#	Set the new heading and return

	adjustHeading('=',$angle);
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		setx(<x axis value>);
#
#	Purpose
#		set the x value to a new position
#	

sub setx($)
{
	#	Get the value

	my $x=shift;
	
	#	Do the numeric check, return any failure message

	my ($return,$value)=number(0,$MAXX,'x position',$x);
	return $return if $return;

	#	Check extra parameters

	return if (more(@_));

	#	Now set the x value and return

	$X=$value;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		sety(<y axis value>);
#
#	Purpose
#		set the y value to a new position
#	

sub sety($)
{
	#	Get the value

	my $y=shift;
	
	#	Do the numeric check, return any failure message

	my ($return,$value)=number(0,$MAXY,'y position',$y);
	return $return if $return;

	#	Check extra parameters

	return if (more(@_));

	#	Now set the y value and return

	$Y=$value;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		setxy(<x axis value>,<y axis value>);
#
#	Purpose
#		set the x and y values to a new position
#	

sub setxy($$)
{
	#	Define the variables

	my $return;

	#	Check any given X value

	my $x=shift;

	($return,$x)=number(0,$MAXX,'x position',$x);
	return $return if $return;

	#	Check any given Y value

	my $y=shift;

	($return,$y)=number(0,$MAXY,'y position',$y);
	return $return if $return;

	#	Check extra parameters

	return if (more(@_));

	#	Now set the values and return

	$X=$x;
	$Y=$y;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		box(<horizontal size>,<vertical size>);
#
#	Purpose
#		Draw a box centred on the present x, y position
#	

sub box($$)
{
	#	Define the variables

	my $return;

	#	Check the horizontal size

	my $x=shift;
	($return,$x)=number(0,$MAXX,'horizontal size',$x);
	return $return if $return;

	#	Check the vertical size

	my $y=shift;
	($return,$y)=number(0,$MAXY,'vertical size',$y);
	return $return if $return;

	#	Check extra parameters

	return if (more(@_));

	#	Now draw the box and return

	$CANVAS->createRectangle($X-$x/2,$Y-$y/2,$X+$x/2,$Y+$y/2,-fill=>$FILL,-outline=>$INK,-tags=>[$MAKE],-width=>$WIDTH);
	
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		disk(<horizontal size>,<vertical size>);
#
#	Purpose
#		Draw an ellipse centred on the present x, y position
#	

sub disk($$)
{
	#	Define the variables

	my $return;

	#	Check the horizontal size

	my $x=shift;
	($return,$x)=number(0,$MAXX,'horizontal size',$x);
	return $return if $return;

	#	Check the vertical size

	my $y=shift;
	($return,$y)=number(0,$MAXY,'vertical size',$y);
	return $return if $return;

	#	Check extra parameters

	return if (more(@_));

	#	Now draw the ellipse and return

	$CANVAS->createOval($X-$x/2,$Y-$y/2,$X+$x/2,$Y+$y/2,-fill=>$FILL,-outline=>$INK,-tags=>$MAKE,-width=>$WIDTH);
	
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		polygon(<number of sides>,<side length>);
#
#	Purpose
#		Draw a polygon, centred on the current position,
#		the polygon having the number of sides of length as specified
#		the first side is drawn in the direction of the current heading
#	Note
#		This command is only provided because it is impossible to fill
#		lines drawn with 'forward'. We work out the full set of x,y positions
#		and then throw then all into one line drawing command with the fill
#		option set.
#	

sub polygon($$)
{
	#	Define the variables we need

	my($return, $sides, $length, $radians, $angle, $x, $y);
	my(@points, $count, $maxx, $maxy, $minx, $miny, $adjustx, $adjusty);
	$maxx=$maxy=$minx=$miny=0;

	#	Get the number of sides

	$sides=shift;
	($return,$sides)=number(2,1024,'sides',$sides);
	return $return if $return;

	#	Get the required side length

	$length=shift;
	($return,$length)=number(1,($MAXX+$MAXY)/2,'length',$length);
	return $return if $return;

	#	Check extra parameters

	return if (more(@_));

	#	Now calculate the angular change between sides
	#	get the current heading (in radians),
	#	and assume we start with x=0, y=0

	$angle=(2.0 * 3.1415926)/$sides;
	$radians=$RADIANS;
	$x=0;
	$y=0;

	#	Put the current x and y into the points array

	#push(@points, $x, $y);

	#	Now work out and store the point at the end of each line,
	#	work out the max and min x and y values as we go
	#	calculate the new heading at each point,

	for ($count=0; $count<$sides; $count++)
	{
		$x+=$length * sin($radians);
		$y+=$length * cos($radians);
		push(@points, $x, $y);
		$minx=$x if ($minx > $x);
		$miny=$y if ($miny > $y);
		$maxx=$x if ($maxx < $x);
		$maxy=$y if ($maxy < $y);
		$radians+=$angle;
	}

	#	Now calculate the adjustment we need to bring the middle of the figure back over our origin

	$adjustx=$maxx - ($maxx - $minx)/2.0;
	$adjusty=$maxy - ($maxy - $miny)/2.0;

	#	Now adjust each point in the array by the calculated value.
	#	We go one more time than the last loop, because	we already had 0,0 in the array beforehand.

	#for ($count=0; $count<=$sides; $count++)
	for ($count=0; $count<$sides; $count++)
	{

		#	We started from a relative 0,0 so we need to add the ACTUAL $X and $Y.
		#	We have to adjust the maximum span of the figure back by the adjustment

		$points[(2*$count)] = $points[(2*$count)] + $X - $adjustx;
		$points[1+(2*$count)] = $points[1+(2*$count)] + $Y - $adjusty;
	}

	#	Now draw a filled line through all of those points

	$CANVAS->create('polygon',@points,-outline=>$INK,-fill=>$FILL,-tags=>[$MAKE],-width=>$WIDTH);

	#	Set a good response

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		recursion <level>;
#
#	Purpose
#		To set the allowed recursion level, default is zero

sub recursion($)
{
	#	Define variables

	my($return, $level);

	#	Get the recursion level requested

	$level=shift;
	($return,$level)=number(0,1024,'level',$level);
	
	#	Quit if we can't allow the value

	return $return if $return;

	#	Check other parameters

	return if (more(@_));

	#	Set the recursion level

	$RECURSION=$level;

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		slow;
#
#	Purpose
#		Set the display mode iback to slow (the default)

sub slow
{
	#	Check if we got extra parameters

	return if (more(@_));

	$SLOW=1;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		fast
#
#	Purpose
#		Set the display mode to fast

sub fast
{
	#	Check if we got extra parameters

	return if (more(@_));

	$SLOW=0;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		arc(<horizontal size>,<vertical size>, <start angle>, <angle>);
#
#	Purpose
#		Draw an arc of an ellipse centred on the present x, y position
#		the slice starts at the start angle and continues clockwise for angle
#		degrees. 
#	

sub arc($$$$)
{
	#	Pass all of the parameters to pie, flagged for an arc
	#	return any error message we get back

	return &pie(@_,'arc');
}

# ------------------------------------------------------------------
#	Subroutine
#		slice(<horizontal size>,<vertical size>, <start angle>, <angle>);
#
#	Purpose
#		Draw a slice of an ellipse centred on the present x, y position
#		the arc of the slice starts at the start angle and continues clockwise
#		for angle degrees, the slice is bounded by this arc and the straight line
#		which joins its ends
#	

sub slice($$$$)
{
	#	Pass all of the parameters to pie, flagged for a slice
	#	return any error message we get back

	return &pie(@_,'chord');
}

# ------------------------------------------------------------------
#	Subroutine
#		pie(<horizontal size>,<vertical size>, <start angle>, <angle> [,<optional style>]);
#
#	Purpose
#		Draw a pie slice of an ellipse centred on the present x, y position
#		the slice starts at the start angle and continues clockwise for angle
#		degrees. The optional style allows this to be called from 'slice' and
#		arc to carry out those functions of the toolkit 'arc' function.
#	

sub pie($$$$;$)
{
	#	Define the variables

	my($return, $x, $y, $start, $angle, $style);

	#	Check the horizontal size

	$x=shift;
	($return,$x)=number(1,$MAXX+$MAXY,'horizontal size',$x);
	return $return if $return;

	#	Check the vertical size

	$y=shift;
	($return,$y)=number(1,$MAXX+$MAXY,'vertical size',$y);
	return $return if $return;

	#	Check the start angle, which can be a compass heading

	$start=shift;
	($return,$start)=angle('start',$start);
	return $return if $return;

	#	Check the slice angle which must be in degrees

	$angle=shift;
	($return,$angle)=number(0,360,'slice size',$angle);
	return $return if $return;

	#	Get any style we were passed by arc or chord, default to pie

	$style='pie';
	if (defined($_[0]))
	{
		$style=shift;

		#	If the style isn't what we want, put it back and leave it for the extra parameters check

		unshift (@_,$style) unless (($style eq 'arc') or ($style eq 'chord'));
	}

	#	Check for extra parameters

	return if (more(@_));

	#	Now change the start angle to what the arc function needs
	#	it's start is degrees left from 3 o'clock and its
	#	extent is left from that, so we need to start from the
	#	opposite edge, adjust relative to arc's 90 degree start point

	$start=90-($start+$angle);
	$start += 360 if ($start < 0);
	$start -= 360 if ($start > 360);
	
	#	Now draw the pie and return

	$CANVAS->createArc
	(
		$X-$x/2, $Y-$y/2, $X+$x/2, $Y+$y/2,
		-start=>$start,
		-extent=>$angle,
		-style=>$style,
		-fill=>$FILL,
		-outline=>$INK,
		-tags=>[$MAKE],
		-width=>$WIDTH
	);
	
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		size(<horizontal size>,<vertical size>);
#
#	Purpose
#		Change the canvas size to the new values requested
#	

sub size($$)
{
	#	Define the variables

	my($return,$maxx,$maxy,$x,$y);

	#	Get the current screen size

	$maxx=$WINDOW->screenwidth;
	$maxy=$WINDOW->screenheight;

	#	Take off some for the other things in the window
	
	$maxx -= 24;
	$maxy -= 100;

	#	Check the horizontal size

	$x=shift;
	($return,$x)=number(0,$maxx,'horizontal size',$x);
	return $return if $return;

	#	Check the vertical size

	$y=shift;
	($return,$y)=number(0,$maxy,'vertical size',$y);
	return $return if $return;

	#	Now check for extra parameters

	return if (more(@_));

	#	Now store the new maximum and middle values

	$MAXX=$x;
	$MAXY=$y;
	$HOMEX=int($MAXX/2);
	$HOMEY=int($MAXY/2);

	#	Reconfigure the canvas to the new size

	$CANVAS->configure(-width=>$MAXX, -height=>$MAXY);

	#	Return to the caller
	
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		title <quoted title>
#
#	Purpose
#		To allow the user to change the title displayed on the main window
#	

sub title($)
{
	#	Check that we have a title

	return "You need to specify a title string, in \"quotes\"" unless (@_);

	#	Get the parameters all as one string, regardless of how they were entered

	my $title=join ' ', @_;

	#	Remove any starting and ending quotes

	if ($title =~ s/^[\'\"]//)
	{
		$title =~ s/$&$//;
	}

	#	Check that we still have a title to display, it may have just been quotes!

	return "A title string consisting of just quotes is not much use!" unless ($title);

	#	Skip if we are just checking

	return if $CHECKING;

	#	Finally, set the title

	$WINDOW->configure(-title=>$title);

	#	Return a good response

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		text <quoted text>
#
#	Purpose
#		Add text to the display at the current pointer position
#	

sub text($)
{
	#	Check that we have text

	return "Specify the text string, in \"quotes\"" unless (@_);

	#	Get the parameters all as one string, regardless of how they were entered

	my $text=join ' ', @_;

	#	Remove any starting and ending quotes

	if ($text =~ s/^[\'\"]//)
	{
		$text =~ s/$&$//;
	}

	#	Check that we still have text to display, it may have just been quotes!

	return "A text string consisting of just quotes is not much use!" unless ($text);

	#	Skip out if we are checking

	return if $CHECKING;

	#	Finally, display the text

	$CANVAS->createText($X,$Y,
			-anchor=>'center',
			-justify=>'center',
		 	-fill=>$INK,
			-tags=>[$MAKE],
			-text=>$text);

	#	Return a good response

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		set <variable name> <numeric value>
#
#	Purpose
#		Give a variable a numeric value which can be used later
#		This will only deal with numeric values, the name and value will
#		be stored in the %VARIABLES hash. To allow parameters to be passed into
#		user functions, these will use names composed of the function name
#		and the functions own variable name, separated by a colon.
#		'set' will only permit alphanumeric names for varaibles.
#	

sub set($$)
{
	#	declare variables

	my ($return, @tokens);

	#	Check that we have a variable name
	
	return "needs a variable name" unless (my $variable=shift);

	#	Check it is a reasonable name, we won't have got in here if it is already
	#	a command or function name

	return "\"$variable\" is not a valid variable name" unless ($variable =~ /^[a-zA-Z][0-9a-zA-Z]*$/);

	#	Check that we have a value, grab everything left on the line

	return "needs a value for $variable" unless (defined(my $value=join(' ',@_)));

	#	If the 'value' is not a number, we need to evaluate it

	unless ($value =~ /^[+-]?\d*[\d\.\,]\d*$/)
	{
		#	Define some variables we need for this processing

		my($count, $number);

		#	Remove any leading and trailing quote

		if ($value =~ s/^[\"\']//)
		{
			$value =~ s/$&$//;
		}
		
		#	Break the string into tokens, quit if we get a bad return

		($return, @tokens)=tokenise($value);
		return $return if ($return);

		#	Now process each token in the array, turning any variable into its value

		for($count=0; $count<@tokens; $count++)
		{
			if (defined($number=$VARIABLE{lc($tokens[$count])}))
			{
				$tokens[$count]=$number;
			}
		}

		#	Now evaluate the whole array

		unless (defined($value=eval(join(' ',@tokens))))
		{
			if ($@ =~ /Bareword/)
			{
				$@ =~ s/^Bareword//;
				$@ =~ s/not allowed.*$//;
				return "do you need to predefine variable $@?";
			}
			else
			{
				return "could not evaluate the expression \"@tokens\"";
			}
		}
	}

	#	Check that the (resulting) value is numeric

	($return,$value)=number('none','none','value',$value);
	return $return if ($return);

	#	For other commands we skip out here if we are just checking so we don't impact things
	#	but if we do that for 'set' then the checks fail when the value is being used so we
	#	just have to leave things to run. There are two possible impacts, (1) we leave a variable
	#	created which should not have been and (2) that we change the value of a variable.

	#	Store the value in the hash with the given name

	$VARIABLE{$variable}=$value;

	#	Give a good return

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		unset <variable name>
#
#	Purpose
#		delete a variable from the hash, mainly useful when loading a file of functions which clash
#	

sub unset($)
{
	#	declare variables

	my $return;

	#	Check that we have a variable name
	
	return "needs a variable name" unless (my $variable=shift);

	#	Check it is a reasonable name, we won't have got in here if it is already
	#	a command or function name

	return "\"$variable\" is not a valid variable name" unless ($variable =~ /^[a-zA-Z][0-9a-zA-Z]*$/);

	#	Check for any extra parameters

	return if (more(@_));

	#	Delete the variable, we don't really care whether it exists

	delete $VARIABLE{$variable};

	#	Return a good response

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		width(<line width>);
#
#	Purpose
#		set the line width used if forward, back etc and the outline width for box, disk
#	

sub width($)
{
	#	Do the numeric check, return any failure message
	#	allow a maximum line width of 25

	my $width=shift;
	my ($return,$value)=number(0,25,'width',$width);
	return $return if $return;

	#	Check for extra parameters

	return if (more(@_));

	#	Now set the line width value and return

	$WIDTH=$value;
	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		sleep(<how long >);
#
#	Purpose
#		Pause the user commands for a period of time
#	

sub sleep($)
{
	#	Define variables

	my ($time, $return);
	
	#	Do the numeric check, return any failure message
	#	allow a maximum time of 60 seconds

	$time=shift;
	($return,$time)=number(0,60,'time',$time);
	return $return if $return;

	#	Check for extra parameters

	return if (more(@_));

	#	Adjust the displayed heading, x and y values

	$SHOWX=int($X+0.499999);
	$SHOWY=int($Y+0.499999);
	$SHOWHEADING=int($HEADING + 0.499999);

	#	Force the display to update

	$CANVAS->update;

	#	If the value is zero, return

	return unless ($time);

	#	Sleep for the desired time, needed to clarify this
	#	because I called this subroutine 'sleep' as well!

	if ($time >= 1)
	{
		CORE::sleep $time if ($time >= 1);
		return;
	}

	#	On some systems, we can microsleep

	if ($ eq 'linux' and $time < 1)
	{
		$time=int($time*1000);
		return unless($time);
		
		`usleep $time`;		
	}

	#	and return

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		if <value> <\@commands>
#
#	Purpose
#		run the commands, only if the value is not zero
#	

sub if($)
{
	#	Define variables

	my ($initial,$value,$return,$r_if_commands,$else,$r_else_commands);

	#	Get the value
	
	return "if needs a value to test" unless (defined($initial=shift));

	#	Check it is numeric 

	($return,$value)=number('none','none','value',$initial);
	return "value \"$initial\" is not a number" if $return;

	#	Check whether we got any commands to run

	return "no commands to run" unless ($r_if_commands=shift);

	#	Now check that the commands were put into [], and so we have an array

	return "if must have commands in brackets" unless (ref($r_if_commands) eq 'ARRAY');

	#	See if there is an else

	if (defined($else=shift))
	{
		#	Check if it is an 'else'

		return "the only permissible option after an 'if' is 'else'" unless ($else eq 'else');
	
		#	Check whether we got any commands to run

		return "else has no commands to run" unless ($r_else_commands=shift);

		#	Now check that the commands were put into [], and so we have an array

		return "else must have commands in brackets" unless (ref($r_else_commands) eq 'ARRAY');
	}

	#	Check for extraneous parameters

	return if (more(@_) == 1);

	#	Now we are ready to run the commands
	#	If the value is not zero, run the commands and return

	if ($value)
	{
		run($r_if_commands);
		return;
	}

	#	If we got here and we have some else commands, run them

	if (defined($else))
	{
		run($r_else_commands);
	}

	#	Now return, we finished	

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		repeat <count> <\@commands>
#
#	Purpose
#		repeat the commands in the array the given number of times
#	

sub repeat($)
{
	#	Define variables

	my ($count,$repeat,$return);

	#	Get the repeat count
	
	return "repeat needs a repeat count" unless (defined($repeat=shift));

	#	Check it is numeric and within a reasonable range

	($return,$repeat)=number(1,2048,'repeat count',$repeat);
	return "repeat count is not a number or is too large" if $return;

	#	Check whether we got any commands to repeat

	return "no commands to repeat" unless (my $r_commands=shift);

	#	Now check that the commands were put into [], and so we have an array

	return "the repeat loop must have commands in brackets" unless (ref($r_commands) eq 'ARRAY');

	#	Now check for any extra parameters

	return if (more(@_) == 1);

	#	Finally, run the command sequence the requested number of times

	for ($count=0; $count<$repeat; $count++)
	{
		run($r_commands);

		#	We don't want to keep checking the same thing so

		last if ($CHECKING);

		#	If there was an error, we shouldn't continuously reinvoke

		last if(@ERROR);
	}

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		make <name> <\@commands>
#
#	Purpose
#		make an object on screen by tagging the items created in the commands with name
#	

sub make($)
{
	#	Define variables

	my $name;

	#	Get the object name
	
	return "make needs an object name" unless (defined($name=shift));

	#	Check the name is valid, starts with a letter followed by letters and/or digits

	return "\"$name\" is not a valid object name" unless ($name =~ /^[a-zA-Z][0-9a-zA-Z]*$/);

	#	Make sure we aren't already making an object

	return "cannot make $name while you are already making $MAKE" if ($MAKE and not $CHECKING);
	
	#	If there is already a command, etc named the same, reject the request
	
	return "\"$name\" is already a command" if ($COMMAND{$name});
	return "\"$name\" is already a user function" if ($FUNCTION{$name});
	return "\"$name\" is already a user variable" if ($VARIABLE{$name});
	
	#	Check whether we got any commands to make the object

	return "no commands to make object $name" unless (my $r_commands=shift);

	#	Now check that the commands were put into [], and so we have an array

	return "the make object must have commands in brackets" unless (ref($r_commands) eq 'ARRAY');

	#	Now check for any extra parameters

	return if (more(@_) == 1);

	#	Unless we are checking, find out if there is already an object tagged with the same name

	unless($CHECKING)
	{
		return "There is already an object tagged as \"$name\"" if ($CANVAS->find('withtag',$name));
	}

	#	Everything has checked out OK, save the tag name

	$MAKE=$name;

	#	Run the commands the user entered to create the object

	run($r_commands);

	#	Clear the tag name now we finished making it

	$MAKE="";

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		move <object name> <distance>
#
#	Purpose
#		move all objects tagged with the name, toward the current heading
#	

sub move($)
{
	#	Define variables

	my ($name, $distance);

	#	Get the object name
	
	return "move needs an object name" unless (defined($name=shift));

	#	Check the name is valid, starts with a letter followed by letters and/or digits

	return "\"$name\" is not a valid object name" unless ($name =~ /^[a-zA-Z][0-9a-zA-Z]*$/);

	#	Grab the distance

	$distance=shift;
	
	#	Do the numeric check, return any failure message

	my ($return,$value)=number(-$MAXX-$MAXY,$MAXX+$MAXY,'distance',$distance);
	return $return if $return;

	#	Check if there are further parameters

	return if (more(@_));

	#	If we are only checking, we don't really care whether it exists

	return if $CHECKING;

	#	Get the list of objects tagged with this name

	return "There is no object tagged as \"$name\"" unless ($CANVAS->find('withtag',$name));

	#	Convert the required distance into x and y values
	#	depending on the angle on which we are heading
	
	my $x=$value * sin($RADIANS);
	my $y=$value * cos($RADIANS);

	#	Move all of the objects, remembering to negate the y distance, as in forward

	$CANVAS->move($name,$x,-$y);

	#	All done

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		remove <object name>
#
#	Purpose
#		remove from the canvas all objects tagged with the name
#	

sub remove($)
{
	#	Define variables

	my ($name, $tags);

	#	Get the object name
	
	return "remove needs an object name" unless (defined($name=shift));

	#	Check the name is valid, starts with a letter followed by letters and/or digits

	return "\"$name\" is not a valid object name" unless ($name =~ /^[a-zA-Z][0-9a-zA-Z]*$/);

	#	Check if there are further parameters

	return if (more(@_));

	#	In the case where we are still creating this object, it's illogical to remove it

	return "Pointless to remove \"$name\" while we are making it!" if ($MAKE eq $name);

	#	If we are checking, we don't really care if it exists

	return if $CHECKING;

	#	Get the list of objects tagged with this name

	$tags=$CANVAS->find('withtag',$name);
	unless ($tags)
	{
		return "There is no object tagged as \"$name\"";
	}

	#	Delete all of the canvas widgets with this tag

	$CANVAS->delete($name);

	#	All done

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		find <object name>
#
#	Purpose
#		Indicate where the first object with the given tag has been moved to
#	

sub find($)
{
	#	Define variables

	my ($name,@objects,$x1,$x2,$y1,$y2);

	#	Get the object name
	
	return "find needs an object name" unless (defined($name=shift));

	#	Check the name is valid, starts with a letter followed by letters and/or digits

	return "\"$name\" is not a valid object name" unless ($name =~ /^[a-zA-Z][0-9a-zA-Z]*$/);

	#	Check if there are further parameters

	return if (more(@_));

	#	Get the coordinates of the items in the object tagged with this name

	return "There is no object tagged as \"$name\"" unless (@objects=$CANVAS->find('withtag',$name));
	($x1,$y1,$x2,$y2)=$CANVAS->bbox(@objects);
	inform($CANVAS,"Object $name is presently within the box bounded by $x1,$y1 and $x2,$y2");

	#	All done

	return;
}

# ------------------------------------------------------------------
#	Subroutine
#		for <variable> <start value> <end value> <increment> <\@commands>
#
#	Purpose
#		conventional for loop, only works in a positive direction!
#	

sub for($$$$$)
{
	#	Define variables

	my ($variable, $value, $return, $start, $end, $step, $keep);

	#	Check that we have a variable name
	
	return "\"for\" needs a variable name" unless (defined($variable=shift));

	#	Check it is a reasonable name

	return "\"$variable\" is not a valid variable name" unless ($variable =~ /^[a-zA-Z][0-9a-zA-Z]*$/);

	#	Check that we have a start value

	return "\"for\" needs a start value for $variable" unless (defined($start=shift));

	#	Check that the value is numeric

	($return,$start)=number('none','none','start',$start);
	return $return if ($return);

	#	Check that we have an end value

	return "\"for\" needs an end value for $variable" unless (defined($end=shift));

	#	Check that the value is numeric

	($return,$end)=number('none','none','end',$end);
	return $return if ($return);
	
	#	Ensure we have a step value

	if (ref($_[0]) ne 'ARRAY')
	{
		#	Check that the value is numeric and not zero

		$step=shift;
		($return,$step)=number('none','none','step',$step);
		return $return if ($return);
		return "For loop will never complete with a step value of zero" if ($step == 0);
	}
	else
	{
		$step=1;
		$step=-1 if ($end < $start);
	}

	#	Finally, check that the step value goes in the correct direction

	return "step value \"$step\" will never reach \"$end\"" if (($step < 0) and ($end > $start));
	return "step value \"$step\" will never reach \"$end\"" if (($step > 0) and ($end < $start));
	
	#	Check whether we got any commands to repeat

	return "no commands in the for loop" unless (my $r_commands=shift);

	#	Now check that the commands were put into [], and so we have an array

	return "the for loop must have commands in brackets" unless (ref($r_commands) eq 'ARRAY');

	#	Check if there are any extra parameters

	return if (more(@_) == 1);

	#	If we are in checking mode, we really don't want to change any variable's value, so grab it

	$keep=$VARIABLE{$variable};

	#	Finally, run the command sequence the requested number of times
	#	storing the value in the variables hash with the given name each time

	if ($end > $start)
	{
		for ($value=$start; $value<=$end; $value+=$step)
		{
			$VARIABLE{$variable}=$value;
			run($r_commands);

			#	We don't want to keep checking the same thing so

			last if ($CHECKING);

			#	If there was an error, we shouldn't continuously reinvoke

			last if(@ERROR);
		}
	}
	else
	{
		for ($value=$start; $value>=$end; $value+=$step)
		{
			$VARIABLE{$variable}=$value;
			run($r_commands);

			#	We don't want to keep checking the same thing so

			last if ($CHECKING);

			#	If there was an error, we shouldn't continuously reinvoke

			last if(@ERROR);
		}
	}

	#	If we were checking, revert the kept value

	if ($CHECKING)
	{
		if ($keep)
		{
			$VARIABLE{$variable}=$keep;
		}
		else
		{
			delete $VARIABLE{$variable};
		}
	}

	return;
}

#-----------------------------------------------------------------------
#	Main body of script

#	Process any command line parameters

parameters;

#	Create the interactive window

initialise;

#	Invoke the toolkit main loop to do the work
#	this invokes subroutines as they are needed

MainLoop;

#	When you hit the [exit] button on the graphic display the program exits

#-----------------------------------------------------------------------
#	End of Script

