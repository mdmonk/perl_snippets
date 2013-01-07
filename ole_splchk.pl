use Win32::OLE;
use Win32::OLE qw(in);
$Win32::OLE::Warn=2;
$w = Win32::OLE->new('Word.Application.8', sub {$_[0]->Quit;});
$docs = $w->{Documents};
$d = $docs->Add;
$d->Activate;
$d->{Range}->{Text}=<<END_OF_TEXT;
##########################################################################
# INCLUDED LIBRARY FILES
#use strict;

##########################################################################
# FUNCTION DECLARATIONS
# Todo: To provide proper modularity within this program, do everything
#       in functions rather than globally, and declare all functions here.

##########################################################################
# CONSTANTS AND GLOBAL VARIABLES
# Todo: Define your contants here. Don't use global variables if you can
#       stay away from them, but declare them here as well. All variables
#       should be declared as "my" variables and given a default value.

END_OF_TEXT
$range = $d->{Range};
$range->{LanguageID} = 1033; # wdEnglishUS : I use Czech language by default
$range->{GrammarChecked} = 0;		 # to force new spell and grammar checking	
$pr1 = $range->{SpellingErrors};
$sc = $pr1->{Count};
print "Spelling errors: $sc\n\n";
foreach $error (in $pr1) {
	print $error->{Start},": ";
	print $error->{Text},"\n";
}
$d->Close(0); # wdDoNotSaveChanges;
