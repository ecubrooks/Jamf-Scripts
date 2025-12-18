#!/bin/bash
###############################################################################
# Password Expiration Notification (SwiftDialog)
#
# Description:
#   Displays password expiration and overdue notifications to the currently
#   logged-in user using SwiftDialog. Prompts users to update their local
#   account password based on configurable policy thresholds.
#
# Features:
#   - SwiftDialog required
#   - Overdue and expiring-soon workflows
#   - Jamf Pro parameter support
#
# Jamf Parameters:
#   $4  = Password policy (days before expiration)          (default: 90)
#   $5  = Notify window before expiration (days)            (default: 14)
#   $6  = Support department / display name                 (default: IT Support)
#   $7  = Support phone number                              (default: 1 (800) 275-2273)
#   $8  = Support URL                                       (default: https://example.com)
#   $9  = SwiftDialog icon (URL or SF Symbol)               (default: SF=lock.circle.dotted)
#   $10 = SwiftDialog path                                 (default: /usr/local/bin/dialog)
#
# Requirements:
#   - SwiftDialog installed
#   - Local account passwordLastSetTime available via dscl
#
# Notes:
#   - Designed to run via Jamf Pro or locally for testing
#   - All org-specific branding should be passed via parameters
#
###############################################################################

############# Password Policy (Jamf Parameters) ##############
PWPolicy="${4:-420}"         # Days before password expires
PWNotify="${5:-14}"          # Notify window (days before expiry)

############# Support / Branding #############################
supportDept="${6:-IT Support}"
supportphone="${7:-1 (800) 275-2273}"
supportURL="${8:-https://example.com}"
swifticon="${9:-SF=lock.circle.dotted}"

################ SwiftDialog ################
DIALOG="${10:-/usr/local/bin/dialog}"

if [[ ! -x "$DIALOG" ]]; then
  echo "SwiftDialog not installed"
  exit 1
fi

############# Current User ##################
curruser=$(/usr/bin/logname)
echo "Currently logged on user is: ${curruser}"

if [[ ${curruser} == *"_"* ]] || [[ ${curruser} == "root" ]]; then
  echo "Builtin user detected, trying alternate method to find currently logged in user"
  curruser=$(stat -f%Su /dev/console)
  echo "Currently logged on user is: ${curruser}"
    if [[ ${curruser} == "root" ]]; then
      echo "Exiting due to root user detected"
      exit 1
    fi
fi

##############################################################
##################### FUNCTIONS ##############################
##############################################################

open_password_settings() {
  osMajor=$(sw_vers -productVersion | awk -F. '{print $1}')
  
  if [[ "$osMajor" -ge 13 ]]; then
    # macOS Ventura and later
    open "x-apple.systempreferences:com.apple.Users-Groups-Settings.extension"
  else
    # macOS Monterey and earlier
    sudo -u "${curruser}" open /System/Library/PreferencePanes/Accounts.prefPane
  fi
}

passwordmessage_over() {
  
  "$DIALOG" \
  --title "$supportDept - Password Prompt Overdue" \
  --icon "$swifticon" \
  --overlayicon "SF=exclamationmark.triangle.fill,colour=red" \
  --message "Your password update is overdue by **${overDays} days** <br><br>Your computer password should have been updated on **${PassDateMonth}**.<br><br>Please change your password immediately." \
  --small \
  --width 900 \
  --button1text "Change Now" \
  --defaultbutton 1 \
  
  dialogResult=$?
  
  if [[ "$dialogResult" -eq 0 ]]; then
    open_password_settings
    echo "User selected Change Now"
  fi
  
  exit
}

passwordmessage_expire() {
  
  "$DIALOG" \
  --title "Password Prompt Expiring" \
  --icon "$swifticon" \
  --message "Your computer password expires in **${expireDays} days** on **${PassDateMonth}**.<br><br>Please update your password as soon as possible.<br><br>Thank you,<br> $supportDept" \
  --small \
  --width 900 \
  --infobuttontext "Need Help" \
  --infobuttonaction "$supportURL" \
  --button2text "Ignore" \
  --button1text "Change Now" \
  --defaultbutton 1
  
  dialogResult=$?
  
  if [[ "$dialogResult" -eq 0 ]]; then
    open_password_settings
    echo "User selected Change Now"
  elif [[ "$dialogResult" -eq 2 ]]; then
    
    "$DIALOG" \
    --title "Password Prompt Warning" \
    --icon "$swifticon" \
    --overlayicon "SF=exclamationmark.triangle.fill,colour=yellow" \
    --message "You selected to ignore a password update.<br><br>You will continue to be prompted until **${PassDateMonth}**.<br><br>Thank You,<br>$supportDept" \
    --small \
    --width 900 \
    --infobuttontext "Need Help" \
    --infobuttonaction "$supportURL" \
    --button2text "Cancel" \
    --button1text "Change Now"
    
    secondResult=$?
    if [[ "$secondResult" -eq 0 ]]; then
      open_password_settings
      echo "User selected Change Now"
    fi
  fi
  
  exit
}

passwordmessage_error() {
  
  "$DIALOG" \
  --title "ERROR - Password Prompt" \
  --icon "$swifticon" \
  --overlayicon "SF=exclamationmark.triangle.fill,colour=red" \
  --message "**ERROR**<br><br>$supportDept Password Prompt policy encountered an issue.<br><br>Please contact $supportDept at **${supportphone}** or submit a ticket at: $supportURL" \
  --button1text "OK" \
  --infobuttontext "Need Help" \
  --infobuttonaction "$supportURL" \
  --small
  
  exit
}

##############################################################
###################### MAIN LOGIC ############################
##############################################################

############# User Password Date Logic ################
GetPassSetDate=$(/usr/bin/dscl . -read /Users/"${curruser}" | grep passwordLastSetTime -A 2 | grep real | awk -F'>' '{print $2}' | awk -F'.' '{print $1}')
if [[ -z "$GetPassSetDate" ]]; then
  passwordmessage_error
fi
#Convert unix date to calendar date
PassDateMonth=$(date -r ${GetPassSetDate} +"%B %d, %Y")
echo "Password was set on ${PassDateMonth}"
#Get Today in Unix
TodayUnix=$(date "+%s")
#Calculate difference between PassExpire and Today Dates in Unix
DiffUnix=$((TodayUnix - GetPassSetDate))
# Convert Unix Difference to days
DiffDays=$((DiffUnix / 86400))
echo "Days since password set: ${DiffDays}"
#calculate Number of days until password Expiry
expireDays=$((PWPolicy - DiffDays))
if [[ "$expireDays" -lt 0 ]]; then
  expireDays=0
else
  echo "Days until expiration: ${expireDays}"
fi

if [[ ${DiffDays} -ge ${PWPolicy} ]]; then
  overDays=$((DiffDays - PWPolicy))
  echo "Password overdue by ${overDays} days"
  passwordmessage_over
else
  if [[ -n "$expireDays" ]] && [[ "$expireDays" -le "$PWNotify" ]]; then
    passwordmessage_expire
  fi
fi

exit 0
