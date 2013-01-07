# Copyright 2000 George Shaffer (gshaffer@erols.com)
# Anyone may use or modify this code for any purpose PROVIDED
# that as long as it is recognizably derived from this code,
# that the copyright notice, this comment and the immediately
# following comments on passwords remain intact and unchanged.
# No warrantees of any kind are expressed or implied.

# Please feel free to change anything from this point forward.

# I experimented at considerable length to find seed logic that
# was very random on Windows NT which generates a very small
# universe of process ID numbers ($$) compared to Unix.  
srand(time() ^ ($$ + $$ << 21));

# USER CHANGEABLE CONSTANTS FOLLOW

# Change $howMany to change the number of generated passwords.
$howMany = 10;

# Increase the default 7 to change the generated password size
# and extra letters will be added to the end.  Decrease and
# you'll lose some or all of the second string of letters.
# Depending on the value of $addConsonants the actual 
# password length may range from $siz to $siz + 2.
# Size interacts with other choices.  If $addConsonants is false
# size will be fixed length and is achieved by truncation after
# checking for upper case and digits so short sizes (3 - 5) may
# not have the variability you desire.
$siz = 7;
# A $siz less than 3 creates an endless loop.
$siz = 3 if ($siz < 3);

# Change $addConsonats to 0 to prevent some extra consonants
# from being tacked on to letter sequences.  Leave $addConsonants
# at 1 to sometimes add an extra consonant to letter sequences.
# If left at 1 the password size will vary from $siz to $siz+2.
$addConsonants = 1;

# Change $firstUpper to 0 to prevent the first character of each
# letter sequence from being upper case.  Leave it as 1 if you
# want some of the first characters to be upper case.
$firstUpper = 1;

# Change $mixedCase to 1 to mix the case of all letters.
# $mixedCase is not random as subsequent checks force at
# least one upper and one lower case letter in each password.
# Leave it at 0 so all letters will be lower case or only
# the first or each letter sequence may  be upper case.
$mixedCase = 0;

# By changing $symbolOdds from 0 to 10 you change the likelihood
# of having two numbers or a number and a symbol.  At 0 you will
# always get 2 digits.  At 1 you will usually only get one digit
# but will sometimes get a second digit or a symbol.  At 10 you 
# will always get two numbers or a number and a symbol with the 
# about even chances that one of the two characters will be a 
# symbol.  The odds are affected by what characters are added to 
# or removed from the $sym initialization string.  
# The default is 7.
$symbolOdds = 7;

# Change $across to a 1 to print passwords across the screen.
# Leave $across as a 0 to print a single column down the screen. 
$across = 0;

# Add or remove symbols to make passwords easier or harder
# to type.  Delete the second set of digits to increase
# the relative frequency of symbols and punctuation.
# Add some vowels or consonants to really change the patterns
# but these will also get much harder to remember.
# If you change the symbol list you need to change the matching
# regular expression near the bottom of the program.
$sym = "~`!@#$%^&*()-_+=,.<>";
$numb = "12345678901234567890" . $sym;
$lnumb = length($numb);


# USER CHANGEABLE CONSTANTS END - Changing the constants as
# specified above has been fairly well tested.  Any changes
# below here and you are changing the logic of the program.
# You should be familiar with programming if you make changes
# after this point.

# Unless you plan to change the logic in the loop below,
# leave this next alone and control case with $firstUpper and
# $mixedCase above.  $mixedCase supercedes if both are true.
$upr = "BCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz";
$cons = "bcdfghjklmnpqrstvwxyz";
if ($mixedCase) {
    $vowel = "AEIOUaeiou";
    $cons = $upr;
} else {
    $vowel = "aeiou";
}
$upr = $cons unless ($firstUpper);
$lvowel = length($vowel);
$lcons = length($cons);
$lupr = length($upr);

$realSize = $siz;
$realSize += 2 if ($addConsonants);
($across) ? ($down = "  ") : ($down = "\n");
$linelen = 0;

for ($j=0; $j<=$howMany; $j++) {
   $pass = "";
   $k = 0;
   for ($i=0; $i<=$siz; $i++) {
      # The basic password structure is cvc99cvc.  Depending on
      # how $cons and $upr have been initialized above case will
      # be all lower, first upper or random.
      if ($i==0 or $i==2 or $i==5 or $i==7) {
         if ($i==0 or $i==5) {
            $pass .= substr($upr,int(rand($lupr)),1);
         } else {
            $pass .= substr($cons,int(rand($lcons)),1);
         }
         # The next will conditionally add up to 2 consonants
         # pseudo randomly after the four "standard" consonants.
         if ($addConsonants and (int(rand(4)) == 3) and $k < 2) {
            $pass .= substr($cons,int(rand($lcons)),1);
            $k++;
         }
      }

      # Pad the password with letters if $siz is over 7.
      if ($i > 7) {
          if (int(rand(26)) <= 5) {
             $pass .= substr($vowel,int(rand($lvowel)),1);
          } else {
             $pass .= substr($cons,int(rand($lcons)),1);
          }
      }

      # Put the vowels in cvc99cvc.  Case depends on how $vowel
      # was initialized above.
      $pass .= substr($vowel,int(rand($lvowel)),1) 
         if ($i==1 or $i==6);

      # Change $symbolOdds initialization above to affect the
      # number of numbers and symbols and their ratio.
      if ($i==3 or $i==4) {
         # If $symbolOdds is non zero take any character
         # from the $numb string which has digits, symbols
         # and punctuation.
         if ($symbolOdds) {
            $pass .= substr($numb,int(rand($lnumb)),1) 
               if (int(rand(10)) <= $symbolOdds);
         } else {
            # If $symbolOdds is zero keep trying until a
            # a digit is found.
            $n = "";
            until ($n =~ /[0-9]/) {
               $n = substr($numb,int(rand($lnumb)),1);
            }
            $pass .= $n;
         }
      }
   }

   # Plan to use this password unless . . .
   $skipThisOne = 0;
   # Don't include two consecutive symbols or puntuation.
   $skipThisOne = 1 if ($pass =~ /[~`!@#$%^&*()\-_+=,.<>]{2}/);
   # Include at least one digit.
   $skipThisOne = 1 unless ($pass =~ /[0-9]/);
   # Include at least one lower case letter.
   $skipThisOne = 1 unless ($pass =~ /[a-z]/);
   # Conditionally insure at least one upper case character.
   $skipThisOne = 1 
      if (!($pass =~ /[A-Z]/) and ($firstUpper or $mixedCase));
   # If any test fails get another password.
   if ($skipThisOne) {
      $j--;
      next;
   }

   # Check the password length.
   $pass = substr($pass,0,$realSize) if (length($pass) > $realSize);

   # Print the passwords in a single column or across
   # the screen based on $down which is set based on the
   # the value of $across.
   if ($down ne "\n") {
      # Don't wrap passwords or trailing whitespace.
      if ($linelen + length($pass) + length($down) > 79) {
         print "\n";
         $linelen = 0;
      }
      $linelen += length($pass) + length($down);
   }
   print "$pass$down";
}
# Be sure to end the last line with an end of line.
print "\n" if $down ne "\n";
