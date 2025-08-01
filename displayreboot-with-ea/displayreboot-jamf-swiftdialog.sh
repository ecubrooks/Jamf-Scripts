#!/bin/bash

# ------------------------------------------------------------------------------
# Script: displayreboot-jamf-swiftdialog.sh
# Creator: Brooks Person
# Date Created: 2023-08-16 (Original)
# Updated: 2025-05-03/23, 2025-07-29
# Description:
#  Prompts users to restart their macOS device if uptime exceeds a threshold.
#  Uses SwiftDialog or Jamf Helper, depending on availability.
#  Parameter support added for broader Jamf use.
#  Requires: Jamf Pro SmartGroup (Last Reboot Days) and Policy to deploy script.
# ------------------------------------------------------------------------------

# ---------------------------
# Parameters (from Jamf Pro)
# ---------------------------
icon="${4:-https://via.placeholder.com/image}"       # Parameter 4: SwiftDialog icon URL or Image
localIcon="${5:-/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns}"  # Parameter 5: Local icon
orgdeptName="${6:-IT Support}"                         # Parameter 6: Institution name
DEBUG="${7:-true}"                                       # Parameter 7: Debug enabled if set to true

# ---------------------------
# Logging for script
# ---------------------------
log(){
    [[ "$DEBUG" == "true" ]] && echo "[DEBUG] $1"
}

# ---------------------------
# Get uptime in days
# ---------------------------
time_up=$(uptime | grep "days" | awk '{print $3}')
# Local Override for testing
#time_up="7"

if [ -z "$time_up" ]; then
    echo "Computer has rebooted recently."
    exit 0
fi

# ---------------------------
# Get the currently logged-in user
# ---------------------------
loggedinuser=$(stat -f %Su /dev/console)
loggedinuid=$(id -u "$loggedinuser" 2>/dev/null || echo "")
log "Logged-in user: $loggedinuser | UID: $loggedinuid"
if [[ $loggedinuser == *"_"* ]] || [[ $loggedinuser == "root" ]] || [[ -z "$loggedinuser" ]] || [[ -z "$loggedinuid" ]]; then
    echo "No standard user logged in. Exiting."
    exit 0
fi

# ---------------------------
# Check if screen saver is active
# ---------------------------
screenSaverCount=$(pgrep -x -U "$loggedinuid" ScreenSaverEngine | wc -l)
if [[ "$screenSaverCount" -ge 1 ]]; then
    log "Screen saver is running."
    echo "Screen saver is running. Exiting."
    exit 0
fi

# ---------------------------
# SwiftDialog prompt
# ---------------------------
swiftprompt(){
    # Show initial prompt asking user if they want to restart now or cancel
    userSelection=$($dialogCommandFile \
        --title "Reboot Needed" \
        --icon "$icon" \
        --message "Your computer has not been restarted for $time_up days.\n\nWould you like to restart now?" \
        --button1text "Cancel" \
        --button2text "Now" \
        --timer 1800 \
        --hidetimerbar \
        --ontop \
        --mini \
        --position topright \
        --moveable)
            
    userSelection=$? # Capture the exit code from the selection prompt
    log "Swift initial prompt code: $userSelection"

    # Check if the user clicked "Now" (exit code 2)
    if [[ $userSelection -eq 2 ]]; then
        delaySelection=$($dialogCommandFile \
            --title "Reboot?" \
            --icon "$icon" \
            --message "Make sure all data is saved.\n\nSelect a delay (0, 1, 3, 5 minutes):" \
            --selecttitle "Delay (minutes)",required \
            --selectvalues "0,1,3,5" \
            --button1text "Restart" \
            --button2text "Cancel" \
            --small \
            --position topright \
            --ontop)

        delayExit=$? # Capture the exit code from the delay prompt
        # Parse the user's selected delay in minutes and validate
        selectedDelay=$(echo "$delaySelection" | awk -F ": " '/SelectedOption/ {print $2}' | tr -d '"')
        
        # Make sure it's numeric before continuing
        if [[ ! "$selectedDelay" =~ ^[0-9]+$ ]]; then
            echo "Invalid delay value: '$selectedDelay'"
            exit
        fi
        
        # If user clicked "Restart"
        if [[ $delayExit -eq 0 ]]; then
            # If delay is 0, restart immediately
            if [[ "$selectedDelay" == "0" ]]; then 
                log "User selected restart now"
                #shutdown -r now
            else
                # Calculate minutes from seconds & show countdown dialog with restart timer
                timersec=$(($selectedDelay * 60))
                timein="minutes"
                [[ "$selectedDelay" == "1" ]] && timemin="minute"
                $dialogCommandFile \
                    --title "Restarting in $selectedDelay $timein" \
                    --icon "$icon" \
                    --message "System will restart in $selectedDelay $timein. Save your work." \
                    --timer "$timersec" \
                    --mini --ontop --position topright \
                    --button1text "OK"
                # Uncomment the shutdown following lines to actually trigger delayed restart
                exitCode=$?
                log "Dialog exit code: $exitCode"
                
                if [[ $exitCode -eq 4 ]]; then
                    log "Timer expired, dialog closed as expected."
                    echo "Timer expired, dialog closed as expected."
                    # shutdown -r now
                    exit 0
                else
                    log "User exited dialog. $exitCode"
                    echo "User exited dialog."
                    # shutdown -r +$selectedDelay
                    exit 0
                fi
            fi
        else
            # User clicked Cancel during delay prompt
            $dialogCommandFile --title "Restart Cancelled" \
            --icon "$icon" \
            --message "Please restart your computer at your earliest convenience.<br><br>Thank you, ${orgdeptName}" \
            --messagealigmment "centre" \
            --button1text "OK" --timer 20 --hidetimerbar --mini --ontop --position topright

            exitCode=$?
            log "SwiftDialog exited with code: $exitCode"
            
            if [[ $exitCode -eq 4 ]]; then
                log "Dialog timed out — proceeding as expected"
            else
                log "Dialog exited with user input"
            fi
            
            # Prevent error by exiting cleanly
            exit 0
        fi
    else
        # User clicked Cancel in the first prompt
        $dialogCommandFile --title "Restart Cancelled" \
        --icon "$icon" \
        --message "Please restart your computer at your earliest convenience.<br><br>Thank you, ${orgdeptName}" \
        --messagealigmment "centre" \
        --button1text "OK" --timer 20 --hidetimerbar --mini --ontop --position topright
            
        exitCode=$?
        log "SwiftDialog exited with code: $exitCode"
        
        if [[ $exitCode -eq 4 ]]; then
            log "Dialog timed out — proceeding as expected"
        else
            log "Dialog exited with user input"
        fi
        
        # Prevent error by exiting cleanly
        exit 0
    fi
}

# ---------------------------
# Jamf Helper prompt
# ---------------------------
jamfprompt(){
    
    # Set path to jamfHelper binary and configure window type and location
    jamf_helper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
    windowlocation="-windowType utility -windowPosition ur"
    
    # Initial prompt asking if user wants to restart now or cancel
    jamfselection=$("$jamf_helper" \
        $windowlocation -icon "$localIcon" -title "Reboot Needed" \
        -description "Your computer has not been restarted in $time_up days. Restart now?" \
        -button2 "Now" -button1 "Cancel" -cancelButton "1")
    
    log "Jamfhelper initial prompt exit code: $jamfselection"

    # If user chooses "Now" (button2), show delay options
    if [[ "$jamfselection" == "2" ]]; then
        # Show delay prompt with selectable restart times (in seconds)
        delayPrompt=$(sudo -u $(ls -l /dev/console | awk '{print $3}') "$jamf_helper" \
            $windowlocation -icon "$localIcon" -title "Reboot?" \
            -description "Please, make sure all data is saved.  Would you like to restart now or delay?

Select a delay: Now, 1, 3, or 5 minutes." \
            -button2 "Restart" -showDelayOptions "0, 60, 180, 300" -button1 "Cancel" -cancelButton 1)

        # Get numeric value representing delay time 
        timeChosen="${delayPrompt%?}"
        log "Jamf prompt exit code: $timeChosen"
        
        case "$delayPrompt" in
            *2) # If "Restart" was selected
                if [[ "$timeChosen" == "0" ]]; then
                    shutdown -r now
                else
                    # Calculate minutes from seconds & show countdown dialog with restart timer
                    mins=$((timeChosen / 60))
                    minlabel="minutes"
                    [[ "$mins" == "1" ]] && minlabel="minute"
                    "$jamf_helper" \
                    $windowlocation -icon "$localIcon" -title "Restart in $mins $minlabel" \
                    -description "System will restart in $mins $minlabel." \
                    -countdown -timeout "$timeChosen" -alignCountdown center -button1 "OK"
                    # Uncomment the following line to actually trigger delayed restart
                    #shutdown -r +$mins
                fi
                ;;
            *) # User clicked Cancel during delay prompt
                "$jamf_helper" \
                    $windowlocation -icon "$localIcon" -title "Restart Cancelled" \
                    -description "Please restart at your earliest convenience. 

Thank you, 
${orgdeptName}" -button1 "OK"
                ;;
        esac
    else
        # User clicked Cancel in the first prompt
        "$jamf_helper" $windowlocation -icon "$localIcon" -title "Restart Cancelled" \
        -alignDescription left -description "Please, restart your computer at earliest convenience.

Thank You,
${orgdeptName}" -button1 "OK" -cancelButton "1" 
    fi
}

# ---------------------------
# MAIN: Use SwiftDialog if available, otherwise Jamf Helper
# ---------------------------
dialogCommandFile="/usr/local/bin/dialog"
if [[ -x "$dialogCommandFile" ]]; then
    log "Display reboot using Swift Dialog"
    echo "Display reboot using Swift Dialog"
    swiftprompt
else
    log "Display reboot using Jamf Helper"
    echo "Display reboot using Jamf Helper"
    jamfprompt
fi
            