#!/bin/bash

############################### Notes ##################################
# This script will flush failed MDM commands via Power Automoate
#
# Script will create script and launch Deamon plist to flush jamf MDM 
# via Microsoft Power Automate
#
# Plist with last run under Shared folder.
#
# Launch Daemon is set to run this once every hour 
#
# Resources
# https://github.com/rtrouton/rtrouton_scripts/tree/main/rtrouton_scripts/Casper_Scripts/clear_failed_Jamf_Pro_mdm_commands
#
########### ISSUES / USAGE #############################################
# Can either be run on workstation directly or via jamf but requires
# Launch Daemon to run on the workstation.
#
# URL must be generated in Power Automate before running.
# The input from Parameter 4 is sent in from jamf for curl but 
# can be added manually in script to run locally.  Exits if missing. 																
#   
########################################################################

launchDaemonPath="/Library/LaunchDaemons/[INSERT_LAUNCHDAEMON_PLIST]"  # create a launch deamon plist name
label=$(basename $launchDaemonPath | sed 's/.plist//')

scriptPath="/Library/Scripts/.[INSERT_SCRIPT_NAME.SH]" # create a script name (hidden)

if [[ -f "$scriptPath" ]]; then
	rm $scriptPath
else
	touch $scriptPath
fi

tee "$scriptPath" << "EndOfScript"
#!/bin/bash
#shellcheck shell=bash
#set -x

############################### Notes ##################################
# This script will flush failed MDM commands via Power Automate
#
# Script will send a curl command to Microsoft Power Automate
# and will clear any failed commands if found.
#
# Launch Daemon is created to run Power Automate once a week
#
# Resources
# https://github.com/rtrouton/rtrouton_scripts/tree/main/rtrouton_scripts/Casper_Scripts/clear_failed_Jamf_Pro_mdm_commands
# https://macadmins.slack.com/archives/CGXNNJXJ9/p1709065446522179?thread_ts=1709060576.321669&cid=CGXNNJXJ9
#
########### ISSUES / USAGE #############################################
# Can either be run on workstation directly or via jamf but requires
# Launch Daemon to run on the workstation.
#
# URL must be generated in Power Automate before running.
# The input from Parameter 4 is sent in from jamf for curl but 
# can be added manually in script to run locally.  Exits if missing. 
#   
########################################################################


flushMDM(){
	######################################
	# For Sending Information to PA URL  #
	######################################
	consoleUser() {
		scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/  { print $3 }'
	}
	DisplayName=$(scutil --get ComputerName)

	# This plist can be created via: 
	# https://derflounder.wordpress.com/2023/02/25/providing-jamf-pro-computer-inventory-information-via-macos-configuration-profile/
	serialnumber=$(defaults read /Library/Managed\ Preferences/info.plist "Computer Serial Number")
	user=$(consoleUser)
	email=""
	comjssid=$(defaults read /Library/Managed\ Preferences/info.plist "Computer Jamf Pro ID Number")
	
	# Power Automate URL passed in via Parameter 4
	paurl="$4"

	########################################
	# Curl Computer Content                #
	########################################
	
	content=$(cat <<EOF
			
{
"deviceName": "${DisplayName}",
"username": "${user}",
"serialNumber": "${serialnumber}",
"emailaddress": "${email}",
"justification": "${response}",
"jssid": "${comjssid}"
}
EOF
)
	
	echo "$content" | curl "$paurl" -X POST -H 'Content-Type: application/json' -d @-

}


########################################
# Check Last Run                       #
########################################
pBuddy="/usr/libexec/PlistBuddy"

# The file which will keep the date of the last run
flagFile="/Users/Shared/.failedmdm.lastRun.plist"
########################################
# The # of days to wait between runs   #
########################################
delayDays=7

########################################
# If we can't read the date of the     #
# last run, delete the flag file and   #
# recreate it with zeros               #
########################################
if ! "$pBuddy" -c "Print LastRunSeconds" "$flagFile"  > /dev/null 2>&1; then
	rm -rf "$flagFile" > /dev/null 2>&1
	"$pBuddy" -c "Add LastRunSeconds string 0" "$flagFile" > /dev/null 2>&1
	"$pBuddy" -c "Add LastRunReadable string never" "$flagFile" > /dev/null 2>&1
fi

########################################
# Get the date of the last time        #
# the script ran                       #
########################################
lastRun=$("$pBuddy" -c "Print LastRunSeconds" "$flagFile")
########################################
# Get the current time                 #
########################################
currentRunTime=$(date +%s)
########################################
# Get the date X days after the last run
########################################
sevenDaysAfterLastRun=$(date -j -v +${delayDays}d -f "%s" "$lastRun" +%s)

########################################
# If the current time is greater than  #
# X days after the last run, then we   #
# continue. Otherwise, exit.           #
########################################
if [[ "$currentRunTime" -gt "$sevenDaysAfterLastRun" ]]; then
	echo "More than $delayDays days since last run"
	flushMDM
else
	echo "Less than $delayDays days since last run"
	exit 0
fi

########################################
# DO STUFF HERE                        #
# Script complete. Set new "last run"  #
# values in the flag file              #
########################################

"$pBuddy" -c "Set LastRunSeconds $currentRunTime" "$flagFile"
"$pBuddy" -c "Set LastRunReadable $(date)" "$flagFile"

EndOfScript

chown root:wheel "$scriptPath"
chmod 700 "$scriptPath"

if [[ -f "$launchDaemonPath" ]]; then
	launchctl bootout system "$launchDaemonPath"
fi

tee "$launchDaemonPath" << EndOfLaunchAgent
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>Label</key>
		<string>$label</string>
		<key>ProgramArguments</key>
		<array>
			<string>/bin/bash</string>
			<string>$scriptPath</string>
		</array>
		<key>RunAtLoad</key>
		<true/>
		<key>StartInterval</key>
		<integer>3600</integer>
	</dict>
</plist>
EndOfLaunchAgent

#Set permissions to the correct ownership and file mode (root:wheel, 644)
chown root:wheel "$launchDaemonPath"
chmod 644 "$launchDaemonPath"
	
launchctl bootstrap system "$launchDaemonPath"
