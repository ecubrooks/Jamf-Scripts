#!/bin/bash

################################################################
# macOS Update Enforcement Script using SwiftDialog + softwareupdate
#
# This script is designed to enforce minor macOS updates 
# (within the same major version) using a deferral system 
# tracked by text file. SwiftDialog is used to present the 
# user with an interactive prompt to update or defer.
#
# Key Features:
# - Supports both Intel and Apple Silicon Macs
# - Version-aware deferral reset (tied to REQUIRED_OS_VERSION)
# - Secure password prompt for Apple Silicon updates
# - Automatic cleanup of deferral tracking files after update
# - SwiftDialog timeout is treated as a deferral
#
# Author: Brooks Person
# Last Updated: 2025-07-10, 2025-09-02
################################################################


################################################################
# Jamf Script Parameters (4–10):
# $4 = Full path to SwiftDialog binary (default: /usr/local/bin/dialog)
# $5 = Max Number of Defferals Allows (default: 3)
# $6 = Deferrals Directory to set enforce.txt file
# $7 = Dialog icon (URL to PNG or SFSymbol)
# $8 = URL for IT support/help documentation
# $9 = Required macOS Version to Check against script
# $10= IT Department organization name
################################################################


# ----- Configurable Variables -----
DIALOG_BIN="${4:-/usr/local/bin/dialog}" # Use Jamf parameter 4 or default path to dialog
MAX_DEFERS="${5:-3}" # Max attempts to before forced
DEFER_DIR="${6:-/Library/Application Support/SWUpdate}"  # Deferral Directory /Library/Application Support/SWUpdate
DEFER_COUNT_FILE="$DEFER_DIR/enforce_count.txt"  # Deferral Directory 
dialogIcon="${7:-https://www.apple.com/ac/structured-data/images/knowledge_graph_logo.png}"  # Icon shown in the dialog
supportURL="${8:-https://support.example.com}" # Link for IT support help site
REQUIRED_OS_VERSION="${9}" # Require macOS Version Number
dept_orgname="${10:-IT SUPPORT}"

######################################
# Collect System Information
######################################
DISPLAYNAME=$(scutil --get ComputerName)
SERIAL_NUMBER=$(system_profiler SPHardwareDataType | awk '/Serial Number/ {print $4}')
MACOS_VERSION=$(sw_vers -productVersion)

# =============================
# SoftwareUpdate Functions 
# =============================

# Function to get current macOS version
get_current_version() {
    sw_vers -productVersion
}

# Function to compare versions
version_greater_equal() {
    [ "$(echo -e "$1\n$2" | sort -V | head -n 1)" == "$2" ]
}

# Function to list available software updates
get_latest_update() {
    # Get the current macOS version
    CURRENT_VERSION=$(get_current_version)
    CURRENT_MAJOR=$(echo "$CURRENT_VERSION" | awk -F'.' '{print $1}')  # Extracts '14' from '14.x.x'
    
    echo "Current macOS Version: $CURRENT_MAJOR"
    
    # Get Current Software Updates Available
    GET_SU=$(softwareupdate --list 2>&1)
    
    # Find only minor updates for the current macOS major version
    LATEST_UPDATE=$(echo "$GET_SU" | grep -E "Title: macOS.*${CURRENT_MAJOR}\.[0-9]+(\.[0-9]+)?" | awk -F '[:,]' '{print $2}' | tail -n 1 | sed 's/^[[:space:]]*//')  # Gets the latest minor update
    LATEST_UPDATE_LABEL=$(echo "$GET_SU" | grep -E "Label: macOS.*${CURRENT_MAJOR}\." | awk -F 'Label: ' '{print $2}' | tail -n 1 | xargs)
    
    if [[ -z "$LATEST_UPDATE" || -z "$LATEST_UPDATE_LABEL" ]]; then
        echo "[ERROR] No matching macOS updates found for version $CURRENT_MAJOR.x. Exiting..."
        exit
    fi

    # Report the Title and Lable from Software Update
    echo "Latest macOS update title: $LATEST_UPDATE"
    echo "Latest macOS update label: $LATEST_UPDATE_LABEL"
    
    # Check for "Deferred: YES" in the block for this label    
    if echo "$GET_SU" | grep -q "Deferred: YES"; then
        echo "[INFO] Latest update is deferred. Exiting."
        exit      
    fi
    
    export LATEST_UPDATE
    export LATEST_UPDATE_LABEL
}

check_dialog_binary() {
    if [[ ! -x "$DIALOG_BIN" ]]; then
        echo "Dialog not found at $DIALOG_BIN. Attempting to install via Jamf policy..."
        /usr/local/bin/jamf policy -event swiftdialoginstaller
        sleep 3  # Give some time for installation
        
        if [[ ! -x "$DIALOG_BIN" ]]; then
            echo "Dialog binary still not found after Jamf install attempt. Exiting."
            exit 1
        fi
    fi
}

test_battery() {

    # Detect if it's a MacBook by checking for a battery
    if pmset -g batt | grep -q "InternalBattery"; then
        # It's a MacBook – get battery percentage
        battery_percent=$(pmset -g batt | grep -Eo "\d+%" | head -n1 | cut -d% -f1)
        
        if [[ $battery_percent -lt 50 ]]; then
            echo "MacBook detected. Battery is under 50% ($battery_percent%). Exiting..."
            $DIALOG_BIN \
            --title "macOS Update Required - Battery Low" \
            --icon "SF=battery.25" \
            --message "<br>The macOS update attempted to install an update but your battery is under 50% ($battery_percent%)." \
            --mini \
            --infobuttontext "Need Help" \
            --infobuttonaction "$supportURL"
            exit
        else
            echo "MacBook detected. Battery is over 50% ($battery_percent%). Continuing..."
        fi
    else
        echo "No battery detected (not a MacBook). Continuing..."
    fi
}

prompt_for_password() {

    local pass_json
    pass_json=$( $DIALOG_BIN \
        --title "macOS Update Required - Password Prompt" \
        --message "To install the macOS update, please enter your password. Make sure to **SAVE ALL** open documents before continuing.<br><br>Your computer will restart automatically or after the update processes." \
        --icon "$dialogIcon" \
        --textfield "Password:,required,prompt=Password,secure,name=Password" \
        --button1text "Continue" \
        --button2text "Cancel" \
        --width 850 \
        --height 275 \
        --ontop \
        --moveable \
        --center \
        --json 2>/dev/null)
    
    # Extract password
    user_pass=$(echo "$pass_json" | /usr/bin/plutil -extract "Password" raw - 2>/dev/null)
}

install_latest_macos_update() { # $1: enforce update
    
    local MACOS_VERSION CURRENT_MAJOR
    MACOS_VERSION=$(sw_vers -productVersion)
    CURRENT_MAJOR=$(echo "$MACOS_VERSION" | cut -d '.' -f 1)
    
    echo "Checking updates for macOS major version: $CURRENT_MAJOR..."
    
    # Call get_latest_update
    get_latest_update
    
    echo "Installing macOS update: $LATEST_UPDATE_LABEL"
    
    local IS_APPLE_SILICON
    if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" -eq 1 ]]; then
        echo "Running on Apple Silicon or ARM-based VM"
        IS_APPLE_SILICON="yes"
    else
        echo "Not Apple Silicon"
        IS_APPLE_SILICON="no"
    fi
    
    local CURRENT_USER
    CURRENT_USER=$(stat -f "%Su" /dev/console)
    
    if [[ "$IS_APPLE_SILICON" == "yes" ]]; then
        echo "Using Secure Ownership Auth with --user and --stdinpass"
        
        local attempt
        if [[ -z "$1" ]]; then
            attempt=1  # Optional update
        else
            attempt=3  # Enforced update
        fi
        local max_attempts=3
        local UPDATE_OUTPUT=""
        local USER_PASS=""
        
        while [[ $attempt -le $max_attempts ]]; do
            
           if ! prompt_for_password; then
                echo "[INFO] User clicked Cancel in password prompt."
                track_deferral
                exit 
            fi
            
            UPDATE_OUTPUT=$(softwareupdate --install "$LATEST_UPDATE_LABEL" --restart --user "$CURRENT_USER" --stdinpass --verbose <<< "$user_pass" 2>&1) 
            
            # Check for failure string
            if echo "$UPDATE_OUTPUT" | grep -q "Failed to authenticate"; then
                echo "[ERROR] Authentication failed for $CURRENT_USER."
                ((attempt++))
                continue
            else
                echo "[SUCCESS] Update process launched."
                # Unset to remove it from memory
                unset user_pass
                # Cleanup deferral files after install triggered
               if [[ -f "$DEFER_COUNT_FILE" ]]; then
                    rm -rf "$DEFER_COUNT_FILE"
                    echo "Cleaned up previous deferral files."
                fi
                break
            fi
        done
        
        if [[ $attempt -gt $max_attempts ]]; then
            echo "[ERROR] Failed to authenticate after $max_attempts attempts."
            # Unset to remove it from memory
            unset user_pass
            # Display failed on 3 attempts
            $DIALOG_BIN \
            --title "macOS Update Required - Failed" \
            --message "The macOS update failed due to too many incorrect password attempts.<br>Please contact your $dept_orgname Administrators." \
            --mini \
            --button1text "OK" \
            --infobuttontext "Need Help" \
            --infobuttonaction "$supportURL"
            
            exit 1
        fi
    else
        
        # Cleanup deferral files after install triggered
        if [[ -f "$DEFER_COUNT_FILE" ]]; then
            rm -rf "$DEFER_COUNT_FILE"
            echo "Cleaned up previous deferral files."
        fi

        softwareupdate --install "$LATEST_UPDATE_LABEL" --restart
        echo "[SUCCESS] Update process launched."
    fi
    
    return $?
}

# Function to track deferral count
track_deferral() {
    if [[ -f "$DEFER_COUNT_FILE" ]]; then
        CURRENT_DEFERS="$(cat "$DEFER_COUNT_FILE")"
    else
        echo "0" > "$DEFER_COUNT_FILE"
        CURRENT_DEFERS=0
    fi

    ((CURRENT_DEFERS++))
    echo "$CURRENT_DEFERS" > "$DEFER_COUNT_FILE"

    if [[ "$CURRENT_DEFERS" -ge "$MAX_DEFERS" ]]; then
        echo "Max deferrals reached. Enforcing update."
        return 1
    else
        echo "User has deferred $CURRENT_DEFERS out of $MAX_DEFERS."
        return 0
    fi
}

# Function to display Swift Dialog
show_dialog() {
    
    remaining_deferrals=$((MAX_DEFERS - CURRENT_DEFERS))
    
    "$DIALOG_BIN" --title "macOS Update Required" \
    --titlefont "name=Avenir Next,size=30" \
    --icon "$dialogIcon" \
    --message "For continued security and compatibility, your Apple computer requires an update to the latest version, **${LATEST_UPDATE}**.<br><br>You may defer the update for an additional **$remaining_deferrals** times before it becomes mandatory.<br><br>Thank you,<br>$dept_orgname" \
    --infobox "**Computer Name**: $DISPLAYNAME <br>
**Serial Number**: $SERIAL_NUMBER <br>
**macOS Version**: $MACOS_VERSION <br>" \
    --infobuttontext "Need Help" \
    --infobuttonaction "$supportURL" \
    --button1text "Update Now" \
    --button2text "Defer" \
    --ontop \
    --timer 300

}

# =============================
# Main Execution
# =============================

# Get the current console user
LOGIN_USER=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

# Exit if no user is logged in
if [[ -z "$LOGIN_USER" || "$LOGIN_USER" == "loginwindow" ]]; then
    echo "[INFO] No user logged in. Exiting script."
    exit 0
fi

echo "[INFO] Logged-in user detected: $LOGIN_USER"

# Ensure defer directory exists
mkdir -p "$DEFER_DIR"
chmod 755 "$DEFER_DIR"

CURRENT_OS_VERSION=$(get_current_version)
echo "Current macOS version: $CURRENT_OS_VERSION"

# Load deferral count from file, or initialize to 0 if not found
if [[ -f "$DEFER_COUNT_FILE" ]]; then
    CURRENT_DEFERS=$(cat "$DEFER_COUNT_FILE")
else
    CURRENT_DEFERS=0
    echo "0" > "$DEFER_COUNT_FILE"
fi

# If current version is greater than or equal to required, exit
if version_greater_equal "$CURRENT_OS_VERSION" "$REQUIRED_OS_VERSION"; then
    echo "macOS is up to date."
    if [[ -f "$DEFER_COUNT_FILE" ]]; then
        rm -rf "$DEFER_COUNT_FILE"
    fi
    exit 0
fi

echo "macOS update required. Checking updates..."
get_latest_update

# Check to make sure dialog binary is valid
# Remove hash to check for valid binary and/or install via jamf
check_dialog_binary

# Show update dialog
show_dialog
DIALOG_RESULT=$?

case "$DIALOG_RESULT" in
    0)
        echo "User chose to update now."
        test_battery
        install_latest_macos_update
        ;;
    2)
        echo "User clicked Defer."
        track_deferral
        DEF_RESULT=$?
        if [[ "$DEF_RESULT" -eq 1 ]]; then
            echo "Max deferrals reached. Forcing update."
            test_battery
            install_latest_macos_update "enforce"
        fi
        ;;
    4)
        echo "Dialog timer expired. Treating as deferral."
        track_deferral
        DEF_RESULT=$?
        if [[ "$DEF_RESULT" -eq 1 ]]; then
            echo "Max deferrals reached. Forcing update."
            test_battery
            install_latest_macos_update "enforce"
        fi
        ;;
    10)
        echo "[WARN] Dialog ext with code 10 and was quit abnormally (Command+Q or force quit). Treating as deferral."
        track_deferral
        DEF_RESULT=$?
        if [[ "$DEF_RESULT" -eq 1 ]]; then
            echo "Max deferrals reached. Forcing update."
            test_battery
            install_latest_macos_update "enforce"
        fi
        ;;
    *)
        echo "[ERROR] Unexpected dialog exit code: $DIALOG_RESULT"
        exit 1
        ;;
esac
