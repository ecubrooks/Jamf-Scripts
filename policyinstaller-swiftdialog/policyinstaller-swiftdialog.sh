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
#   $7 - Comma-separated friendly labels (prefer plain text).(e.g. Install VPN,Configure Mac,Inventory Update)
#   $8 - Operation mode: test or live (default: test)
#   $9 - Support URL:  URL for IT support/help documentation (default: https://support.example.com)
#   $10 - UI Mode: list (default) or inspect
#
# Requirements:
#   - SwiftDialog installed at /usr/local/bin/dialog
#   - Jamf binary available in PATH
#
# Inspired by the dialog logic and structure used in Dan Snelson's SwiftDialog projects
# https://github.com/dan-snelson
#
# Author: Brooks Person
# Date: 2025-07-22, 2026-02-28
#
# ---------------------------------------------------------------------

# ----------- Script Parameters -----------
dialogTitle="${4:-Jamf Policy Runner}"
displayIcon="${5:-SF=gear}"
triggerList="${6}"             # Parameter 6 = comma-separated triggers
labelList="${7}"               # Parameter 7 = comma-separated labels
operationMode="${8:-test}"     # Parameter 8 = test or live
supportURL="${9:-https://support.example.com}" # Link for IT support help site
uiMode="${10:-list}"            # Parameter 10 = list | inspect

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

# If Inspect Mode requested, ensure SwiftDialog major version is 3+
if [[ "$uiMode" == "inspect" ]]; then
   dialogVersion="$("$dialogBinary" --version 2>/dev/null | awk '{print $NF}')"
   dialogMajor="${dialogVersion%%.*}"   
   if [[ -z "$dialogMajor" || "$dialogMajor" -lt 3 ]]; then
      echo "INFO: SwiftDialog v3+ required for Inspect Mode. Falling back to list mode."
      uiMode="list"
   fi
fi

# ----------- Parse trigger and label arrays -----------
if [[ -n "$triggerList" ]]; then
  IFS=',' read -r -a triggers <<< "$triggerList"
else
  echo "INFO: No triggers provided. Using default list."
  declare -a triggers=(
    "appinstall"
    "appsettings"
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
    "App Settings"
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
inspectConfigFile=$(mktemp "/var/tmp/dialogInspect_${scriptID}.XXXX")
markerDir="/var/tmp/policyinstaller_${scriptID}"
mkdir -p "$markerDir"
chmod 755 "$markerDir"
chmod 644 "$dialogJSONFile"
chmod 644 "$dialogCommandFile"
chmod 644 "$inspectConfigFile"

# ----------- Dialog Update Function -----------
dialogUpdate() {
    sleep 0.3
    echo "$1" >> "$dialogCommandFile"
}

pick_random_image() {
  #List of Image Urls or Locally Stored Images
  local imageurls=(
    "/System/Library/Desktop Pictures/Solid Colors/Space Gray.png"
    "/System/Library/Desktop Pictures/Solid Colors/Silver.png"
  )
  printf "%s\n" "${imageurls[RANDOM % ${#imageurls[@]}]}"
}

bannerImage="$(pick_random_image)" # override to remove random chosen banner image

# ----------- Create listitem JSON dynamically -----------
listItemsJSON=""
color="purple"  #change color based schema
# ----------- Create Inspect Mode items dynamically -----------
inspectItemsJSON=""
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
   
   # Inspect Mode: use marker files so any trigger (include repeats) can be tracked
   trigger="${triggers[$i]}"
   safeBaseID="$(echo "$trigger" | tr -cd '[:alnum:]_-')"
   safeID="${safeBaseID}_${i}"
   markerPath="${markerDir}/${safeID}.done"
   inspectItemsJSON+="
   {
         \"id\": \"${safeID}\",
         \"displayName\": \"${label}\",
         \"icon\": \"SF=${paddedIndex}.circle.fill,colour=${color}\", 
         \"sideMessage\": [ \"Installing required software…\", \"This may take several minutes.\" ],
         \"guiIndex\": ${i},
         \"paths\": [\"${markerPath}\"]
    },"
done
listItemsJSON="${listItemsJSON%,}" # Remove trailing comma
inspectItemsJSON="${inspectItemsJSON%,}" # Remove trailing comma

# ----------- Launch Dialog (list vs inspect) -----------
if [[ "$uiMode" == "inspect" ]]; then
  
    username="$(dscl . -read /Users/$(stat -f%Su /dev/console) RealName | tail -n +2 | xargs)"
    # Build Inspect Mode config JSON
   cat > "$inspectConfigFile" <<EOF
{
   "title": "${dialogTitle}",
   "message": "${username} Need help? ${supportURL}",
   "sideMessage": [ "Installing required software... This may take several minutes." ],
   "preset": "preset1",
   "icon": "${displayIcon}",
   "button1text": "Close",
   "button1disabled": true,
   "autoEnableButton": true,
   "autoEnableButtonText": "Close",
   "scanInterval": 2,
   "cachePaths": ["/Library/Application Support/JAMF/Downloads"],
   "items": [ ${inspectItemsJSON} ]
}
EOF
   
    eval "$dialogCommand --inspect-mode --inspect-config ${inspectConfigFile} &"
    dialogPID=$!
else
# ----------- Build SwiftDialog JSON -----------
dialogJSON=$(cat <<EOF
{
  "commandfile": "${dialogCommandFile}",
  "bannerimage": "${bannerImage}",
  "bannertext": "${dialogTitle}",
  "bannerheight" : "75.0",
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
  "titlefont": "name=Avenir Next,shadow=true, size=30",
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
fi

# ----------- Run each trigger -----------
hadFailure=false
for i in "${!triggers[@]}"; do
  trigger="${triggers[$i]}"
  label="${labels[$i]:-Task $((i+1))}"
   # Inspect Mode marker for this trigger
   safeBaseID="$(echo "$trigger" | tr -cd '[:alnum:]_-')"
   safeID="${safeBaseID}_${i}"
   markerPath="${markerDir}/${safeID}.done"
   if [[ "$uiMode" != "inspect" ]]; then
     dialogUpdate "listitem: index: $i, status: wait, statustext: Executing $label"
     dialogUpdate "progresstext: Installing: $label"
   fi

  if [[ "$operationMode" == "test" ]]; then
    sleep 5
   # complete the Inspect item
   touch "$markerPath"
   if [[ "$uiMode" != "inspect" ]]; then
      dialogUpdate "listitem: index: $i, status: success, statustext: (Test Mode) Complete"
   fi
  else
    if jamf policy -event "$trigger"; then
      touch "$markerPath"
      if [[ "$uiMode" != "inspect" ]]; then
         dialogUpdate "listitem: index: $i, status: success, statustext: Complete"
      fi
   else
      hadFailure=true
      # Don't hang Inspect Mode; still mark complete, but record failure
      echo "FAILED: $trigger" >> "${markerDir}/failures.log"
      touch "$markerPath"
      if [[ "$uiMode" != "inspect" ]]; then
         dialogUpdate "listitem: index: $i, status: fail, statustext: Failed"
      fi
    fi
  fi

done

# ----------- Final Confirmation -----------
if [[ "$uiMode" != "inspect" ]]; then
  if $hadFailure; then
      dialogUpdate "progresstext: One or more steps failed. Please review and try again."
  else
      dialogUpdate "progresstext: ${dialogTitle} completed successfully. Please, Close Window"
  fi
   dialogUpdate "button1: enable"
fi

# ----------- Wait for Close -----------
wait $dialogPID
dialogResult=$?

case "$dialogResult" in
  0)
    echo "INFO: User clicked Close. Policy complete."
  ;;
  *)
    echo "ERROR: Dialog was closed without pressing Close. Exit code: $dialogResult"
    ${dialogBinary} --title "${dialogTitle} - Policy Incomplete" \
      --message "You must click Close to confirm policy closes correctly and is completed.<br><br>Please contact your local IT administrator." \
      --icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/public.generic-pc.icns" \
      --iconsize "198.0" \
      --button1text "Close" \
      --ontop \
      --small \
      --infobuttontext "Help" \
      --infobuttonaction "${supportURL}" \
      --moveable
    exit 1
  ;;
esac

rm -f "$dialogJSONFile" "$dialogCommandFile" "$inspectConfigFile"
rm -rf "$markerDir"