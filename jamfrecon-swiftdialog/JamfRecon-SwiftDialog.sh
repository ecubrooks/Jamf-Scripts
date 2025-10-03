#!/bin/bash
########################################################################################
#
# SCRIPT NAME: JamfRecon-swiftdialog.sh
#
# DESCRIPTION:
#   Displays a progress window while running Jamf Manage and Jamf Recon.
#   Provides user-facing progress text during inventory submission.
#
# REQUIREMENTS:
#   - Jamf Pro agent installed (/usr/local/bin/jamf)
#   - SwiftDialog installed (/usr/local/bin/dialog)
#   - Policy trigger available to install SwiftDialog if missing
#
# AUTHOR: Brooks Person
# CREATED: 12/16/2022 
# UPDATED: 10/03/2025
#
# CHANGE LOG:
#   1.0 - Intial release with IBM Notifier
#   2.0 - Updated to Run with swiftdialog removed IBM Notifier
#
########################################################################################

# Get current directory and set variables
LOGS="/Library/Logs/JamfReconNotification.log"

# Jamf Parameters and Logs
# $4 - Path to SwiftDialog binary
# $5 - Organization Name
# $6 - Jamf policy trigger for SwiftDialog installation (if missing)

DIALOG=${4:-"/usr/local/bin/dialog"}
orgname=${5:-"IT Department"}
eventtrigger=${6:-"trigger"}

# Temp command file for SwiftDialog
cmdfile="$(/usr/bin/mktemp /var/tmp/jamf_recon.XXXX)"
/bin/chmod 644 "$cmdfile"

# Get Current User
currentUser=$(stat -f %Su /dev/console)

# Checks if SwiftDialog is installed and exits if missing
check_dialog_binary() {
	if [[ ! -x "$DIALOG" ]]; then
		echo "Dialog not found at $DIALOG. Attempting to install via Jamf policy..." 
		/usr/local/bin/jamf policy -event "$eventtrigger" #insert a valid trigger to install Swift
		sleep 3  # Give some time for installation
		if [[ ! -x "$DIALOG" ]]; then
			echo "Dialog binary still not found after Jamf install attempt. Exiting."
			exit 1
		fi
	fi
}

# Checks system hardware for SwiftDialog icon
checkhardware(){
# Grab the "Model Name" from system_profiler
model=$(/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/ {print $2}')
		
# Check for "Book" in the model name (MacBook Air, MacBook Pro, etc.)
if [[ "$model" == *Book* ]]; then
	icon="laptopcomputer.and.arrow.down"
else
	icon="desktopcomputer.and.arrow.down"
fi
}

# Check to make sure dialog binary is valid
# Remove hash to check for valid binary and/or install via jamf
check_dialog_binary

# Check hardware for swiftdialog icon
checkhardware

# Launch a progress window
"$DIALOG" \
--title "$orgname - Computer Check-In" \
--message "Please wait while the computer inventory policy is running..." \
--messagealignment centre \
--position center \
--icon "SF=${icon}" \
--mini \
--progress \
--moveable \
--commandfile "$cmdfile" \
--button1disabled \
--autoquit &

sleep 0.5

########################################################################################
# Main
########################################################################################

echo "=====" 2>&1 | tee -a "$LOGS"
echo "Running Jamf Recon Notification" 2>&1 | tee -a "$LOGS"
echo "=====" 2>&1 | tee -a "$LOGS"

echo "Running Jamf Manage" 2>&1 | tee -a "$LOGS"
echo "progresstext: Collecting system inventory and updating management settings…" >> "$cmdfile"
jamf manage --verbose >> "$LOGS"
sleep 3

echo "Running Jamf Recon" 2>&1 | tee -a "$LOGS"
echo "progresstext: Submitting updated computer record info to Jamf Pro…" >> "$cmdfile"
jamf recon -endUsername "${currentUser}" --verbose >> "$LOGS"
sleep 1

echo "progresstext: Computer successfully checked in with Jamf Pro." >> "$cmdfile"
sleep 3
echo "quit:" >> "$cmdfile"


echo "=====" 2>&1 | tee -a "$LOGS"
echo "Completed Jamf Recon" 2>&1 | tee -a "$LOGS"
echo "=====" 2>&1 | tee -a "$LOGS"

/bin/rm -f "$cmdfile"

exit
