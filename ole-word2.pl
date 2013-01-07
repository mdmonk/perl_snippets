#! perl -w
    use strict;
    use Win32::OLE;
    use Win32::OLE::Const 'Microsoft Word';
    ### open Word application and add an empty document
    ### (will die if Word not installed on your machine)
    my $word = Win32::OLE->new('Word.Application', 'Quit') or die;
    $word->{Visible} = 1;
    my $doc = $word->Documents->Add();
    my $range = $doc->{Content};

    ### insert some text into the document
    $range->{Text} = 'Hello World from Monastery.';
    $range->InsertParagraphAfter();
    $range->InsertAfter('Bye for now.');

    ### read text from the document and print to the console
    my $paras = $doc->Paragraphs;
    foreach my $para (in $paras) {
        print ">> " . $para->Range->{Text};
    }

    ### close the document and the application
    $doc->SaveAs(FileName => "c:\\temp\\temp.txt", FileFormat => wdFormatDocument);
    $doc->Close();
$word->Quit();
