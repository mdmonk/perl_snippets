sub ParseHTML
{
# pass in an HTML string to be parsed and a boolean indicating if
whitespace between elements should be trimmed;
# returns a dictionary with the elements in the string
 my ($html, $trim) = @_;
 my $i, $element, $dict;
 $dict = $Server->CreateObject("Scripting.Dictionary");

 foreach $element ($html =~
/(.*?)(<(?:(?:!--.*?--)|(?:\/?[a-z0-9_:.-]+(?:\s+[a-z0-9_:.-]+(?:=(?:[
^> '"\t\n]+|(?:'.*?')|(?:".*?")))?)*))\s*\/?\s*>)/isg)
 {
  $element = TrimWS($element) if $trim;
  $dict->Add($i++, ParseTag($element, $trim)) if length $element;
 }
 return $dict;
}
