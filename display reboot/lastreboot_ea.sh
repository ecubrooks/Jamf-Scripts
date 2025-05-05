#!/bin/bash

# ------------------------------------------------------------------------------
# Script: lastreboot_ea.sh
# Description:
#  Last Reboot EA. This will output it in a date format that can be used 
#  in a "Date format" Extension Attribute the way Jamf expects it to be. 
#  So you could use a search like "Before" or "After" a certain date, 
#  or more/less than "In the last X days" and it should work.
# Jamf EA: Data Type Date (YYYY-MM-DD hh:mm:ss)
# ------------------------------------------------------------------------------

lastReboot=`who -b | awk '{print $3" "$4}'`

echo "<result>$(date -jf "%s" "$(sysctl kern.boottime | awk -F'[= |,]' '{print $6}')" +"%Y-%m-%d %T")</result>"

exit 0