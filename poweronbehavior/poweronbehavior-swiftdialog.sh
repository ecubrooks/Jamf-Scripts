#!/bin/bash

#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	poweronbehavior-swiftdialog.sh -- Allows user to change startup behavior for macOS
#
# SYNOPSIS
#  ./poweronbehavior-swiftdialog.sh
#   Can run from jamf as a Self Service script, uses Swift Dialog or osascript
#
# AUTHOR
# Brooks Person 03-25-2025
#
####################################################################################################

# Path to Swift Dialog
DIALOG="/usr/local/bin/dialog"

######################################
# For Sending Information to Webhook #
######################################
consoleUser() {
    scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/  { print $3 }'
}
DISPLAYNAME=$(scutil --get ComputerName)
SERIAL_NUMBER=$(system_profiler SPHardwareDataType | grep "Serial Number" | awk '{print $4}')
CURRENT_USER=$(consoleUser)

# Function to display notification using osascript
display_notification_osascript() {
    choice=$(osascript <<EOF
        set options to {"Prevent Both", "Prevent Lid Only", "Prevent Power Only", "Restore Default"}
        set selectedOption to choose from list options with title "Startup Behavior Configuration" with prompt "Choose how your Mac behaves when opening the lid or connecting to power.         
1. Prevent Both - Prevent startup when opening the lid or connecting to power.
2. Prevent Lid Only - Prevent startup only when opening the lid.
3. Prevent Power Only - Prevent startup only when connecting to power.
4. Restore Default - Restored default startup behavior." default items {"Prevent Both"}
        if selectedOption is false then
            return "Cancel"
        else
            return selectedOption
        end if
EOF
    )
    echo "$choice"
}

# Function to display notification using Swift Dialog
display_notification_swift_dialog() {
    selection=$("$DIALOG" \
    --title "Apple Startup Behavior Configuration" \
    --message "From dropdown choose how your Mac behaves when opening the lid or connecting to power.

1. Prevent Both - Prevent startup when opening the lid or connecting to power.
2. Prevent Lid Only - Prevent startup only when opening the lid.
3. Prevent Power Only - Prevent startup only when connecting to power.
4. Restore Default - Restored default startup behavior." \
    --icon "/Library/User Pictures/Account Images/701 ProfileImage1.tif" \
    --infobox "**Computer Name**: $DISPLAYNAME <br>
**Serial Number**: $SERIAL_NUMBER" \
    --selecttitle "Choose how your Mac behaves when opening the lid or connecting to power:" \
    --selectvalues "Prevent Both,Prevent Lid Only,Prevent Power Only,Restore Default" \
    --height 400 \
    --moveable \
    --infobuttontext "Need Help" \
    --infobuttonaction "https://itsupport.url" \
    --button1text "Select" \
    --button2text "Cancel")
    
    # Check if user clicked "Cancel" or Selected Choice
    if [[ $? -ne 0 ]]; then
        echo "Cancel"
    else
        # Extract the selected option
        echo "$selection" | grep '"SelectedOption"' | awk -F ' : ' '{print $2}' | tr -d '"'
    fi

}

# Function to execute the nvram command based on user choice
execute_choice() {
    case "$1" in
        *"Prevent Both"*)
            sudo nvram BootPreference=%00
            echo "Configured to prevent startup when opening the lid or connecting to power."
            ;;
        *"Prevent Lid Only"*)
            sudo nvram BootPreference=%01
            echo "Configured to prevent startup only when opening the lid."
            ;;
        *"Prevent Power Only"*)
            sudo nvram BootPreference=%02
            echo "Configured to prevent startup only when connecting to power."
            ;;
        *"Restore Default"*)
            sudo nvram -d BootPreference
            echo "Restored default startup behavior."
            ;;
        *"Cancel"*)
            echo "No selection made. Exiting."
            ;;
        *)
            echo "Invalid selection. Exiting."
            ;;
    esac
}

# Main script execution
if [ -x "$DIALOG" ]; then
    user_choice=$(display_notification_swift_dialog)
    #echo "DEBUG: Raw user_choice output: $user_choice"
    execute_choice "$user_choice"
else
    echo "Swift Dialog not found."
    user_choice=$(display_notification_osascript)
    #echo "DEBUG: Raw user_choice output: $user_choice"
    execute_choice "$user_choice"
fi
            