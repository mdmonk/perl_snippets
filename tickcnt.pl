	$result = &Win32::GetTickCount ();
	sleep 1;
	$diff = &Win32::GetTickCount ();
	printf "Result1: $result\n";
	printf "Result2: $diff\n";
	printf "%.3f seconds\n", ($diff - $result) / 1000;
