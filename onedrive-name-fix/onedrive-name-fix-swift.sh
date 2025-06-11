#!/bin/bash

##################################################################
#
# Script to rename files to work with OneDrive
# Based on the work from: https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
# Also from: https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
#
# From @RHIO on Slack
# Modified by Brooks Person to run in Jamf and display notification with user
# using Switf Dialog and the ability to Output file changes to Text
#
# Author: Brooks Person
# Last Updated: 2023-10-23, 2025-06-11
# Designed for portability in other Jamf environments
##################################################################

################################################################
# Jamf Script Parameters (4–9):
# $4 = Full path to SwiftDialog binary (default: /usr/local/bin/dialog)
# $5 = Dialog icon (URL to PNG or SFSymbol)
# $6 = URL for IT support/help documentation
# $7 = Dialog window title
# $8 = IT support phone number to be displayed
################################################################


logger -s -p user.notice "OneDrive-Name-Fix: Loading..."

###################################################################
# Parameters (from JAMF Pro)
###################################################################
dialogPath="${4:-/usr/local/bin/dialog}"
dialogIcon="${5:-https://jamf.com/favicon.ico}" # Replace with your own default icon if preferred
helpURL="${6:-https://support.example.com}"        # Replace or pass as variable when needed
dialogTitle="${7:-OneDrive File and Folder Name Fix}"
supportPhone="${8:-111-111-1111}" #Update with your IT support line

###################################################################
# Variables for Script
###################################################################

# Get macOS version and determine major release name
OSVersion=$(sw_vers -productVersion)
OSMAJOR=$(echo "$OSVersion" | awk -F '.' '{print $1}')
case "$OSMAJOR" in
    11) OSNAME="Big Sur" ;;
    12) OSNAME="Monterey" ;;
    13) OSNAME="Ventura" ;;
    14) OSNAME="Sonoma" ;;
    15) OSNAME="Sequoia" ;;
    26) OSNAME="Tahoe" ;;
    *)
        OSNAME="X"
    ;;
esac
# Get computer name
computername=$(scutil --get ComputerName)
# Get current user
currentuser=$(stat -f%Su /dev/console)
# Folders to Search and save final changes
desktfld="/Users/${currentuser}/Desktop/"
docfld="/Users/${currentuser}/Documents/"
pathToNotice="/Users/${currentuser}"

###################################################################
# Notification Functions
###################################################################

displaynotification() { # $1: title $2: message
    title=${1:-"Notification"}
    message=${2:-"Processing..."}
    "$dialogPath" \
    --title "$title" \
    --message "$message" \
    --icon "$dialogIcon" \
    --progress \
    --ontop \
    --moveable \
    --height 300 \
    --width 600 \
    --button1disabled \
    --button1text "" &
    sleep 1
}

updateprogress() {
    logger -s -p user.notice "Progress Update: $1"
}

add_listitem() {
    local title="$1"
    listItems+=("--listitem" "title=${title}")
}

display() { # $1: title $2: message #3: button1text
    "$dialogPath" \
    --title "${1:-Title}" \
    --message "${2:-Message}" \
    --icon "$dialogIcon" \
    --height 750 \
    --button1text "${3:-Open File}" \
    --button2text "Cancel" \
    --infobox "**System Summary**<br><br>This information may be used for IT diagnostics or support.<br><br>**Computer Name:**<br>$computername<br><br>**OS Version:**<br>macOS $OSNAME<br><br>IT Support: [$supportPhone](tel:$supportPhone)" \
    --infobuttontext "Need Help" \
    --infobuttonaction "$helpURL" \
    --ontop \
    --moveable \
    "${listItems[@]}"
    return $?
}

###################################################################
# Core Functions (Check_Trailing_Chars, Check_Leading_Spaces, etc.)
###################################################################

Check_Trailing_Chars() {
    grep -vE ".pkg|.app" /tmp/cln.ffn >/tmp/fixtrail.ffn
    while IFS= read -r line; do
        name=$(basename "$line")
        path=$(dirname "$line")
        fixedname=$(echo "$name" | sed -E 's/\.*[[:space:]]*$//')
        echo "'$line' -> '$path/$fixedname'" >>/tmp/allfixed.ffn
        logger -s -p user.notice "OneDrive-Name-Fix: Trailing Chars - '$line' -> '$path/$fixedname'"
        mv -f "$line" "$path/$fixedname"
    done < /tmp/fixtrail.ffn
}

Check_Leading_Spaces() {
    grep -vE ".pkg|.app" /tmp/cln.ffn | grep "/[[:space:]]" >/tmp/fixlead.ffn
    while IFS= read -r line; do
        name=$(basename "$line")
        path=$(dirname "$line")
        fixedname=$(echo "$name" | sed -e 's/^[ \t]*//')
        echo "'$line' -> '$path/$fixedname'" >>/tmp/allfixed.ffn
        logger -s -p user.notice "OneDrive-Name-Fix: Leading Spaces - '$line' -> '$path/$fixedname'"
        mv -f "$line" "$path/$fixedname"
    done < /tmp/fixlead.ffn
}

Fix_Names() {
    while IFS= read -r line; do
        name=$(basename "$line")
        path=$(dirname "$line")
        fixedname=$(echo "$name" | tr ':\\\?*\"<>%|' '-')
        echo "'$line' -> '$path/$fixedname'" >>/tmp/allfixed.ffn
        logger -s -p user.notice "OneDrive-Name-Fix: Bad Chars - '$line' -> '$path/$fixedname'"
        mv -f "$line" "$path/$fixedname"
    done < /tmp/cln.ffn
}

GetFileLength() {
    userfldlen=$(echo "/Users/${currentuser}" | wc -c)
    { find "$desktfld"; find "$docfld"; } | awk -v len="$userfldlen" '{ print length($0)-len, $0 }' | awk '$1 >= 400 { $1=""; print substr($0,2) }' > /tmp/FileLengthresults.txt
    [[ $(wc -l < /tmp/FileLengthresults.txt) -eq 0 ]] && echo "No Files over 400 Characters Found" >> /tmp/FileLengthresults.txt
}

Save_Notice() {
    rm -f "$pathToNotice/onedrive-renames.txt"
    {
        echo "---OneDrive Sync Directory/File Rename Notice---"
        date
        echo "------------------------------------------------"
        echo
        echo "Illegal characters were removed or replaced."
        echo
        cat /tmp/allfixed.ffn | sed 's/^/  • /'
        echo
        echo "Files with long path lengths:"
        cat /tmp/FileLengthresults.txt | sed 's/^/  • /'
        echo
        echo "This file can be deleted. Contact IT with questions."
    } >> "$pathToNotice/onedrive-renames.txt"
    chmod 644 "$pathToNotice/onedrive-renames.txt"
    chown "$currentuser" "$pathToNotice/onedrive-renames.txt"
}

###################################################################
# Main Script Logic
###################################################################

rm -f /tmp/*.ffn
> /tmp/allfixed.ffn

displaynotification "" "Currently checking and fixing your files and folders for usage with Microsoft OneDrive.\n\nPlease, wait while this completes...\n\nThank You!"

# Remove temp OneDrive files
updateprogress "Cleaning up OneDrive files..."
find "$desktfld" "$docfld" -name ".fstemp*" -exec rm -dfR {} +

# Fix illegal characters
updateprogress "Checking for unique characters in file and folder names..."
find "$desktfld" "$docfld" -name '*[\\/:*?"<>%|]*' > /tmp/cln.ffn
#Fix_Names
rm /tmp/cln.ffn

# Fix trailing characters
updateprogress "Resolving spaces and periods..."
find "$desktfld" "$docfld" | grep -E '[[:space:]]$|\.$' > /tmp/cln.ffn
#Check_Trailing_Chars
rm /tmp/cln.ffn

# Fix leading spaces
updateprogress "Checking for spaces in names..."
find "$desktfld" "$docfld" -name "*" > /tmp/cln.ffn
#Check_Leading_Spaces
rm /tmp/cln.ffn

# Check path lengths
updateprogress "Checking file paths..."
GetFileLength

updateprogress "Finalizing and saving report..."

sleep 3

# Final summary
if [[ -s /tmp/allfixed.ffn || -s /tmp/FileLengthresults.txt ]]; then
    Save_Notice

    while IFS= read -r line; do
        [[ -n "$line" ]] && add_listitem "$line"
    done < "$pathToNotice/onedrive-renames.txt"

    display "$dialogTitle" "Multiple files/folders were renamed.\n\nSelect **Open File** to view more details about renames outside of this window.\n\nFile located: $pathToNotice/onedrive-renames.txt \n"
    if [[ $? -eq 0 ]]; then
        open "$pathToNotice/onedrive-renames.txt"
    fi
else
    display "$dialogTitle" "No renames or path issues found." "OK"
fi

rm -f /tmp/FileLengthresults.txt /tmp/allfixed.ffn

exit 0
