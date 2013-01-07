#
# Perl version or Richard's test program
@month_tab =
(
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
);

@dow_tab =
(
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday"
);

print_time(986158800);  # Sunday, April 1, 2001
print_time(986655600);  # Saturday, April 7, 2001
print_time(986738400);  # Sunday, April 8, 2001

#
# print_time -- print out a time_t value converted by localtime()
#

sub print_time
{
	 $time_t = shift;
    @tmp = localtime($time_t);
    if( ! @tmp )
    {
        printf("0x%08lX = Invalid time\n", $time_t);
        return;
    }
    if( ($tmp[4] >= 0) && ($tmp[4] <= 11) )
        { $month = $month_tab[$tmp[4]]; }
    else
        { $month = sprintf("BadMonth=%d", $tmp[4]); }
    if( ($tmp[6] >= 0) && ($tmp[6] <= 6) )
        { $dow = $dow_tab[$tmp[6]]; }
    else
        { $month = sprintf("BadDOW=%d", $tmp[6]); }

    printf("0x%08lX = %s, %s %d, %d -- %d:%02d:%02d %s -- DOY=%d\n",
           $time_t, $dow, $month, $tmp[3], $tmp[5] + 1900,
           $tmp[2], $tmp[1], $tmp[0], ($tmp[8]) ? 'Eastern Daylight Time' :
'Eastern Standard Time',
           $tmp[7]);
    return;

}
