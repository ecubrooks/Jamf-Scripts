#!/bin/bash
#
# policyinstaller-swiftdialog.sh
#
# Description:
#   Runs one or more Jamf policy triggers using SwiftDialog for visual feedback.
#   Accepts a comma-separated list of triggers from Jamf Parameter 6.
#   Accepts a comma-separated list of labels from Jamf Parameter 7.
#
# Parameters:
#   $4 - Dialog title (optional)
#   $5 - Dialog icon path (optional)
#   $6 - Comma-separated Jamf triggers (e.g. installvpn,setupconfig,inventory)
#   $7 - Comma-separated friendly labels (e.g. Install VPN,Configure Mac,Inventory Update)
#   $8 - Operation mode: test or live (default: test)
#   $9 - Support URL:  URL for IT support/help documentation (default: https://support.example.com)
#
# Requirements:
#   - SwiftDialog installed at /usr/local/bin/dialog
#   - Jamf binary available in PATH
#
# Inspired by the dialog logic and structure used in Dan Snelson's SwiftDialog projects
# https://github.com/dan-snelson
#
# Author: Brooks Person
# Date: 2025-07-22
#
# ---------------------------------------------------------------------

# ----------- Script Parameters -----------
dialogTitle="${4:-Jamf Policy Runner}"
displayIcon="${5:-/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarAdvanced.icns}"
triggerList="${6}"             # Parameter 6 = comma-separated triggers
labelList="${7}"               # Parameter 7 = comma-separated labels
operationMode="${8:-test}"     # Parameter 8 = test or live
supportURL="${9:-https://support.example.com}" # Link for IT support help site

# ----------- SwiftDialog Binary -----------
dialogBinary="/usr/local/bin/dialog"

# -----------  Check SwiftDialog ----------- 
if [[ ! -x "$dialogBinary" ]]; then
  # Remove hash if you want to install swift dialog again
  #echo "SwiftDialog binary not found at ${dialogBinary}, attempting to install..."
  #jamf policy -event "customtrigger" #insert custom jamf trigger
  if [[ ! -x "$dialogBinary" ]]; then
    echo "ERROR: SwiftDialog binary not found at ${dialogBinary}"
    exit 1
  fi
fi

# ----------- Append Test Flags (after check) -----------
dialogCommand="$dialogBinary"
if [[ "$operationMode" == "test" ]]; then
  dialogCommand+=" --verbose --resizable"
fi


# ----------- Parse trigger and label arrays -----------
if [[ -n "$triggerList" ]]; then
  IFS=',' read -r -a triggers <<< "$triggerList"
else
  echo "INFO: No triggers provided. Using default list."
  declare -a triggers=(
    "appinstall" 
    "inventory" 
  )
fi

labelParamGiven=false
if [[ -n "$labelList" ]]; then
  IFS=',' read -r -a labels <<< "$labelList"
  labelParamGiven=true
else
  echo "INFO: No labels provided. Using default labels."
  declare -a labels=(
    "Install App"
    "Inventory Update"
  )
fi

if $labelParamGiven && [[ "${#labels[@]}" -ne "${#triggers[@]}" ]]; then
  echo "INFO: Number of labels doesn't match number of triggers. Adjusting..."
  for ((i=${#labels[@]}; i<${#triggers[@]}; i++)); do
    labels+=("Step $((i+1))")
  done
fi

# ----------- Derived values -----------
progressSteps="${#triggers[@]}"
scriptID="jamf_$(date +%s)"
dialogJSONFile=$(mktemp "/var/tmp/dialogJSONFile_${scriptID}.XXXX")
dialogCommandFile=$(mktemp "/var/tmp/dialogCommandFile_${scriptID}.XXXX")
chmod 644 "$dialogJSONFile"
chmod 644 "$dialogCommandFile"

# ----------- Dialog Update Function -----------
dialogUpdate() {
    sleep 0.3
    echo "$1" >> "$dialogCommandFile"
}

# ----------- Create listitem JSON dynamically -----------
listItemsJSON=""
color="purple"  #change color based schema
for i in "${!triggers[@]}"; do
  iPlusOne=$((i + 1))
  paddedIndex=$(printf "%02d" "$iPlusOne")  # Format as 01, 02, etc.
  label="${labels[$i]:-Step $((i+1))}"
  listItemsJSON+="
  {
    \"title\": \"${label}\",
    \"subtitle\": \"Processing $((i+1)) of ${#triggers[@]}: ${label}\",
    \"icon\": \"SF=${paddedIndex}.circle.fill,colour=${color}\", 
    \"status\": \"pending\",
    \"statustext\": \"Pending …\"
  },"
done
listItemsJSON="${listItemsJSON%,}" # Remove trailing comma

# ----------- Build SwiftDialog JSON -----------
dialogJSON=$(cat <<EOF
{
  "commandfile": "${dialogCommandFile}",
  "title": "${dialogTitle}",
  "icon": "${displayIcon}",
  "message": "none",
  "iconsize": "198.0",
  "infobox": "**User:** {userfullname}<br><br>**Computer Name:** {computername}<br><br>**Serial Number:** {serialnumber}",
  "infobuttontext": "Help",
  "infobuttonaction": "${supportURL}",
  "button1text": "Close",
  "button1disabled": true,
  "helpmessage": "This tool is running ${dialogTitle}.",
  "helpimage": "SF=questionmark.circle.fill",
  "position": "center",
  "progress": ${progressSteps},
  "progresstext": "Please wait …",
  "height": "750",
  "width": "900",
  "messagefont": "size=14",
  "titlefont": "name=Avenir Next,shadow=true, size=24",
  "ontop": true,
  "moveable": true,
  "windowbuttons": "min",
  "quitkey": "k",
  "listitem": [
${listItemsJSON}
  ]
}
EOF
)

# ----------- Launch Dialog -----------
echo "$dialogJSON" > "$dialogJSONFile"
eval "$dialogCommand --jsonfile ${dialogJSONFile} &"
dialogPID=$!

# ----------- Run each trigger -----------
hadFailure=false
for i in "${!triggers[@]}"; do
  trigger="${triggers[$i]}"
  label="${labels[$i]:-Task $((i+1))}"
  dialogUpdate "listitem: index: $i, status: wait, statustext: Executing $label"
  dialogUpdate "progresstext: Installing: $label"

  if [[ "$operationMode" == "test" ]]; then
    sleep 3
    dialogUpdate "listitem: index: $i, status: success, statustext: (Test Mode) Complete"
  else
    if jamf policy -event "$trigger"; then
      dialogUpdate "listitem: index: $i, status: success, statustext: Complete"
    else
      dialogUpdate "listitem: index: $i, status: fail, statustext: Failed"
      hadFailure=true
    fi
  fi

done

# ----------- Final Confirmation -----------
if $hadFailure; then
  dialogUpdate "progresstext: One or more steps failed. Please review and try again."
else
  dialogUpdate "progresstext: ${dialogTitle} completed successfully. Please, Close Window"
fi
dialogUpdate "button1: enable"

# ----------- Wait for Close -----------
wait $dialogPID
dialogResult=$?

case "$dialogResult" in
  0)
    echo "INFO: User clicked Close. Policy complete."
  ;;
  *)
    echo "ERROR: Dialog was closed without pressing Close. Exit code: $dialogResult"
    /usr/local/bin/dialog --title "$dialogTitle - Policy Incomplete" \
      --message "You must click Close to confirm policy closes correctly and is completed.<br><br>Please contact your local IT administrator." \
      --icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/public.generic-pc.icns" \
      --button1text "Close" \
      --ontop \
      --small \
      --infobuttontext "Help"\
      --infobuttonaction "${supportURL}" \
      --moveable
    exit 1
  ;;
esac

rm -f "$dialogJSONFile" "$dialogCommandFile"