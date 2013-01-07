use Crypt;

$encrypted_passwd = "Py***********";    # changed value to *'s
$plaintext_passwd = "plaintxt";         # not real value
$result = crypt ($plaintext_passwd, substr ($encrypted_passwd, 0, 2));
print $result, "\n";

