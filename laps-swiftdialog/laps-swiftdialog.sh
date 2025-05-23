#!/bin/zsh

################################################################
# LAPS Management Script
# This script retrieves, rotates, or displays the LAPS password 
# for the local administrator account using Jamf Pro's API.
# Author: Brooks Person
# Last Updated: 2025-03-28
# Designed for secure, scalable usage in Jamf Pro environments
################################################################

################################################################
# Jamf Script Parameters (4–11):
# $4  = Full path to SwiftDialog binary (default: /usr/local/bin/dialog)
# $5  = API base URL (e.g., https://your-jamf-url.jamfcloud.com)
# $6  = Path or URL to main dialog icon (PNG, ICNS, or SFSymbol)
# $7  = Path or URL to alert icon (for warnings/errors)
# $8  = Dialog window title (e.g., "Temporary Admin Access Lookup")
# $9  = URL to IT support/help documentation
# $10 = Expected local administrator account (e.g., lapsadmin)
# $11 = Method to Retrieve or View Password (clipboard, display, both)
################################################################

######################################
# ----- Configurable Variables -----
######################################
dialogApp="${4:-/usr/local/bin/dialog}"
apiURL="${5:-https://your-jamf-url.jamfcloud.com}"
mainIcon="${6:-/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarApplicationsFolderIcon.icns}"
alertIcon="${7:-/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns}"
dialogTitle="${8:-Temporary Admin Access}"
supportURL="${9:-https://your.support.url}"
expectedLocalAdminAccount="${10:-lapsadmin}" 
display_method="${11:-clipboard}" 

# Check Swift Dialog if is missing
DIALOG="$dialogApp"
if [[ ! -x "$DIALOG" ]]; then
    echo "SwiftDialog is missing or not executable."
    jamf policy -event swiftdialoginstaller
    sleep 1
    if [[ ! -x "$DIALOG" ]]; then
        echo "ERROR: SwiftDialog is missing or not executable."
        exit
    fi
fi

######################################
# Collect System Information
######################################
consoleUser() {
    scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/  { print $3 }'
}
DISPLAYNAME=$(scutil --get ComputerName)
SERIAL_NUMBER=$(system_profiler SPHardwareDataType | awk '/Serial Number/ {print $4}')
MACOS_VERSION=$(sw_vers -productVersion)

APITokenValidationCheck() {
    
    # Confirm the API token is valid by issuing a test request  
    # that returns only the HTTP status code.    
    api_authentication_check=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "${apiURL}/api/v1/auth" --request GET --header "Authorization: Bearer ${apiBearerToken}")
    
}

lapss(){  # [l]ocal [a]dministrator [p]assword [s]olution in the [s]tage lane
    
    # Retrieve Client ID & Secret from Keychain
    JAMF_CLIENT_ID=$(security find-generic-password -s "JSSCID" -w 2>/dev/null)
    JAMF_CLIENT_SECRET=$(security find-generic-password -s "JSSCIDSRT" -w 2>/dev/null)
    # Request Jamf Pro API token using the credentials
    apiBearerToken=$(/usr/bin/curl -s -X POST "${apiURL}/api/oauth/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode client_id="$JAMF_CLIENT_ID" --data-urlencode 'grant_type=client_credentials' --data-urlencode client_secret="$JAMF_CLIENT_SECRET" | plutil -extract access_token raw -)
    
    # Validate the API token
    APITokenValidationCheck
    
    # Checks api_authentication_check has a value of 200 and bearer token is valid and usable.
    if [[ ${api_authentication_check} == 200 ]]; then
        echo "API Token Valid"
    else
        # Displays prompt if validation check fails and exits
        "$DIALOG" --title "Script Error" \
        --message "API Token Invalid - Run Again Exiting." \
        --infobox "**Tech Computer Name**: $DISPLAYNAME <br>
**Tech Serial Number**: $SERIAL_NUMBER <br>" \
        --button1 "Exit" \
        --icon "$alertIcon"
        exit 1
    fi
    
    # Determine the computer's Jamf Pro ID via the computer's Serial Number
    jssID=$( /usr/bin/curl -H "Authorization: Bearer ${apiBearerToken}" -s "${apiURL}"/JSSResource/computers/serialnumber/"${1}"/subset/general | xpath -e "/computer/general/id/text()" )
    echo "$jssID"
    
    # If not found, show an error dialog and allow retry
    if [[ -z "$jssID" ]]; then
        "$DIALOG" --title "Error" --message "Serial number not found in Jamf Pro.<br>Please check serial number and try again." \
        --infobox "**Tech Computer Name**: $DISPLAYNAME <br>**Tech Serial Number**: $SERIAL_NUMBER<br>" \
        --small \
        --button1 "Retry" --icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
        continue
    fi
    
    # Get the computer's Jamf Pro ID via the computer's Serial Number
    # Retrieve various pieces of general and inventory info using the Jamf Pro ID.
    generalComputerInfo=$( /usr/bin/curl -H "Authorization: Bearer ${apiBearerToken}" -H "Accept: text/xml" -sfk "${apiURL}"/JSSResource/computers/id/"${jssID}/subset/General" -X GET )
    computerName=$( echo ${generalComputerInfo} | xpath -q -e "/computer/general/name/text()" )
    computerIpAddress=$( echo ${generalComputerInfo} | xpath -q -e "/computer/general/ip_address/text()" ) 
    computerIpAddressLastReported=$( echo ${generalComputerInfo} | xpath -q -e "/computer/general/last_reported_ip/text()" )
    computerInventoryGeneral=$( /usr/bin/curl -H "Authorization: Bearer ${apiBearerToken}" -s "${apiURL}/api/v1/computers-inventory/${jssID}?section=GENERAL" -H "accept: application/json" )
    managementId=$( echo "${computerInventoryGeneral}" | awk '/managementId/{print $NF}' | tr -d '",' )
    localAdminAccountsRaw=$( /usr/bin/curl -H "Authorization: Bearer ${apiBearerToken}" -s "${apiURL}"/api/v2/local-admin-password/${managementId}/accounts -H "accept: application/json" )
    username=$( echo "${localAdminAccountsRaw}" | awk '/username/{print $NF}' | tr -d '",' )
    
    # Compare Local Admin Account with Username from Jamf Pro 
    if [[ "${username}" == *"${expectedLocalAdminAccount}"* ]]; then
        
        localAdminPasswordRaw=$( /usr/bin/curl -H "Authorization: Bearer ${apiBearerToken}" -s "${apiURL}"/api/v2/local-admin-password/${managementId}/account/${expectedLocalAdminAccount}/password -H "accept: application/json" )
        
        admin_password=$( echo "${localAdminPasswordRaw}" | awk '/password/{print $NF}' | tr -d '",' )
        
        # If No Password Found, Show Error Dialog
        if [[ -z "$admin_password" ]]; then
            "$DIALOG" --title "Error" \
            --message "No password found for this serial number. - Exiting." \
            --infobox "**Tech Computer Name**: $DISPLAYNAME <br>
**Tech Serial Number**: $SERIAL_NUMBER <br>" \
            --button1 "Exit" \
            --icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
            continue
        fi
        
        # Check method to display password
        # Copy password to clipboard if needed
        if [[ "$display_method" == "clipboard" || "$display_method" == "both" ]]; then
            echo -n "$admin_password" | pbcopy
            PASSWORD_NOTICE="The password has been copied to your clipboard"
        fi
        
        # Add password to dialog if needed
        if [[ "$display_method" == "dialog" || "$display_method" == "both" ]]; then
            PASSWORD_NOTICE="${PASSWORD_NOTICE}<br><br>**Admin Password**: \`$admin_password\`"
        fi
        
        # Display Password with Display or Copy Confirmation
        "$DIALOG" \
        --title "Jamf LAPS Password Retrieved" \
        --icon "$mainIcon" \
        --message "$PASSWORD_NOTICE<br><br>**Computer Name**: $computerName <br>
**Serial Number**: ${1} <br>
**IP Address**: $computerIpAddress, $computerIpAddressLastReported<br><br>[View Computer in Jamf Pro](https://contour.ecu.edu:8443/computers.html?id=$jssID)<br><br>Click **OK** to close." \
        --infobox "**Tech Computer Name**: $DISPLAYNAME <br>
**Tech Serial Number**: $SERIAL_NUMBER<br>" \
        --height 400 \
        --infobuttontext "Need Help" \
        --infobuttonaction "$supportURL" \
        --button1 "OK" \
        --moveable 
        
        # Invalidate the Bearer Token
        apiBearerToken=$( /usr/bin/curl "${apiURL}/api/v1/auth/invalidate-token" --silent  --header "Authorization: Bearer ${apiBearerToken}" -X POST )
        apiBearerToken=""
        
    else
        # Display Prompt Accounts Do Not Match exit script instead of continuing
        "$DIALOG" --title "Script Error" \
        --message "Expected Local Admin Account NOT found - Exiting." \
        --infobox "**Tech Computer Name**: $DISPLAYNAME <br>
**Tech Serial Number**: $SERIAL_NUMBER <br>" \
        --timer 10
        --hidetimer
        --button1 "Exit" \
        --icon "$alertIcon"
        exit
        
    fi
}

##############################################################
#                         MAIN  
# This section contains the primary logic of the script. 
# The script requires technological interaction and continues 
# until the user terminates the session.
#
# If the serial number is invalid or empty, display an 
# error message and enable retry functionality.
##############################################################

# Prompt User to Enter Serial Number
while true; do
USER_INPUT=$("$DIALOG" --title "$dialogTitle" \
--icon "$mainIcon" \
--message "Fetches Local Administration Account Password.<br><br>Please enter a Jamf Pro computer serial number:" \
--textfield "Serial Number",required,prompt="Serial Number",regex="^[A-Z0-9]{8,12}$",regexerror="Invalid serial number format." \
--infobox "**Tech Computer Name**: $DISPLAYNAME <br>**Tech Serial Number**: $SERIAL_NUMBER<br>" \
--infobuttontext "Need Help" \
--infobuttonaction "$supportURL" \
--small \
--button1 "Continue" \
--button2 "Cancel")

# Check if user clicked "Cancel"
if [[ $? -ne 0 ]]; then
    echo "User canceled the request."
    exit
fi

# Extract Serial Number from User Input
SERIALNUMBER=$(echo "$USER_INPUT" | awk -F 'Serial Number : ' '{print $2}' | awk '{print $1}')

# Backup check for swift dialog if no Serial Number provided or error and display message 
if [[ -z "$SERIALNUMBER" ]]; then
    "$DIALOG" --title "Error" --message "No serial number entered." \
    --infobox "**Tech Computer Name**: $DISPLAYNAME <br>
**Tech Serial Number**: $SERIAL_NUMBER<br>" \
    --small \
    --button1 "OK" \
    --icon "$alertIcon"
    continue
elif [[ ! "$SERIALNUMBER" =~ ^[A-Z0-9]{8,12}$ ]]; then
    "$DIALOG" --title "Error" --message "Invalid serial number format." \
    --infobox "**Tech Computer Name**: $DISPLAYNAME <br>**Tech Serial Number**: $SERIAL_NUMBER<br>" \
    --small \
    --button1 "OK" \
    --icon "$alertIcon"
    continue 
fi
    
lapss $SERIALNUMBER
break
done 
exit 0
