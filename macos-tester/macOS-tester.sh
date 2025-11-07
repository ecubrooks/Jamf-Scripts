#!/bin/bash
########################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	macOS-tester.sh
#
# SYNOPSIS
#  ./macOS-tester.sh
#  v1.0  — designed for Jamf, macOS 13–26
#  Can run from jamf as a Self Service script, uses Swift Dialog
#  Requires: SwiftDialog (/usr/local/bin/dialog)
#
# AUTHOR
# Brooks Person 09-30-2025
#
# Jamf Parameters 
#   Parameter 4 — APPS_PARAM
#       List of apps to test. Use semicolon (;) to separate items.
#       Supports CFBundleIdentifiers (e.g. com.apple.Safari) OR full app paths
#       (ex: /Applications/Microsoft Word.app).
#
#   Parameter 5 — URLS_PARAM
#       List of websites to test HTTPS reachability.
#       Accepts comma (,), semicolon (;), or newline as separators.
#       URLS will append hostnames with https:// prefix.
#
#   Parameter 6 — DIALOG_PARAM
#       Optional override for SwiftDialog binary path.
#       Default is /usr/local/bin/dialog.
#
#   Parameter 7 — ICON_PARAM
#       Optional override for dialog icon.
#       Accepts path to .icns file OR .app bundle.
#       Default is system icon: ToolbarAdvanced.icns.
######################################################################################## 

########################################################################################
# App Config Parameters
########################################################################################

# Jamf parameters (Parameters 4–7)
APPS_PARAM="${4:-}"      # e.g. 'com.apple.Safari;org.mozilla.firefox;/Applications/Microsoft Word.app'
URLS_PARAM="${5:-}"      # e.g. 'https://captive.apple.com, https://www.jamf.com;'
DIALOG_PARAM="${6:-}"    # optional: override SwiftDialog path
ICON_PARAM="${7:-}"      # optional: override icon path

# SwiftDialog and application paths (csv)
CURRENTUSER=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && !/loginwindow/ { print $3 }')
DIALOG="${DIALOG_PARAM:-/usr/local/bin/dialog}"
RESULTS_DIR="/Users/$CURRENTUSER/Desktop"
STAMP="$(date +"%Y%m%d-%H%M%S")"
CSV_PATH="${RESULTS_DIR}/os-upgrade-validation-${STAMP}.csv"

TITLE="macOS System and App Validation"
ICON_DEFAULT="${ICON_PARAM:-/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarAdvanced.icns}"

# Apps list: prefer Jamf Param 4; otherwise use hardcoded default
if [[ -n "$APPS_PARAM" ]]; then
  APPS_CSV="$APPS_PARAM"
else
  # Hardcoded fallback
  APPS_CSV="com.apple.Safari"
fi

# Websites list: prefer Jamf Param 5; otherwise use hardcoded defaults
if [[ -n "$URLS_PARAM" ]]; then
  # Normalize separators: commas/semicolons/newlines → spaces, then read into array
  _norm_urls="$(echo "$URLS_PARAM" | tr ',;\n' ' ')"
  read -r -a TEST_URLS <<< "$_norm_urls"
  unset _norm_urls
else
  TEST_URLS=("https://www.apple.com/library/test/success.html"
    "https://captive.apple.com"
  )
fi

########################################################################################
# Helpers
########################################################################################


# HELPER: error / log
# error(): print an error to stderr and exit the entire script immediately
# log():   timestamped echo for uniform logging (kept simple for policy logs)
error(){ 
  echo "[ERROR] $*" >&2 
  exit 1 
}
log(){ 
  echo "[$(date '+%F %T')] $*" 
}


# HELPER: downloadswiftDialog
# If SwiftDialog is missing, discover the latest .pkg from GitHub releases
# and install it so user-facing dialogs can run
downloadswiftDialog() {
  echo "SwiftDialog not found at $DIALOG — attempting to download latest release..."
  
  # Get latest pkg URL from GitHub API
  local LATESTSWIFTPKG
  LATESTSWIFTPKG=$(/usr/bin/curl -sL https://api.github.com/repos/bartreardon/swiftDialog/releases/latest | /usr/bin/grep "browser_download_url" | /usr/bin/grep "pkg" | head -n 1 | cut -d '"' -f 4)
  
  if [[ -n "$LATESTSWIFTPKG" ]]; then
    local TMPPKG="/var/tmp/swiftdialog-latest.pkg"
    /usr/bin/curl -L "$LATESTSWIFTPKG" -o "$TMPPKG"
    if /usr/sbin/installer -pkg "$TMPPKG" -target /; then
      echo "SwiftDialog installed successfully."
    else
      error "Failed to install SwiftDialog from $LATESTSWIFTPKG"
    fi
  else
    error "Could not determine latest SwiftDialog release URL."
  fi
}

# HELPER: checkdialog
# Checks SwiftDialog exists at $DIALOG before showing any UI.
checkdialog() {
  if [[ ! -x "$DIALOG" ]]; then
    # Remove hashes if you either want to bail out
      # echo "SwiftDialog not found at $DIALOG"
      # exit 1
    # Or auto-install:
    downloadswiftDialog
  fi
}

# HELPER: osinfo
# Capture basic system metadata for later inclusion in the CSV and dialogs.
osinfo() {
  OS_VER=$(sw_vers -productVersion 2>/dev/null)
  OS_BUILD=$(sw_vers -buildVersion 2>/dev/null)
  HW_MODEL=$(sysctl -n hw.model 2>/dev/null)
  CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | awk '{print $1}')
  if [[ -z "$CPU" ]]; then
    if /usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null | grep -q 1; then
      CPU="AppleSilicon"
    else
      CPU="Intel"
    fi
  fi
}

# HELPER: resolveapppath
# Input requires either a full .app path OR a CFBundleIdentifier
# Returns a resolved .app bundle path or empty string on failure
resolveapppath() {
  local app_identifier="$1"
  # If it looks like a path and ends with .app, use it
  if [[ -d "$app_identifier" && "$app_identifier" == *.app ]]; then
    echo "$app_identifier"
    return 0
  fi
  # Otherwise treat as bundle id and search app path
  local app_path=""
  app_path="$(/usr/bin/mdfind "kMDItemCFBundleIdentifier == '$app_identifier'" | head -n1)"
  if [[ -n "$app_path" ]]; then
    echo "$app_path"
    return 0
  fi

  echo ""
  return 1
}

# HELPER: appmeta
# Reads Info.plist keys via `defaults read`. Falls back to the .app basename for App name.
appmeta() {
  local apppath="$1"
  local plist="${apppath}/Contents/Info.plist"

  local bunname bunid shrtvers bunvers
  bunname=$(/usr/bin/defaults read "$plist" CFBundleName 2>/dev/null)
  if [[ -z "$bunname" ]]; then
    bunname=$(basename "$apppath" .app)
  fi
  bunid=$(/usr/bin/defaults read "$plist" CFBundleIdentifier 2>/dev/null)
  shrtvers=$(/usr/bin/defaults read "$plist" CFBundleShortVersionString 2>/dev/null)
  bunvers=$(/usr/bin/defaults read "$plist" CFBundleVersion 2>/dev/null)

  echo "$bunname|$bunid|$shrtvers|$bunvers"
}

# HELPER: appendcsvheader / appendcsvrow
# appendcsvheader():
# If CSV doesn’t exist yet, write the column header line once.
# appendcsvrow():
# Adds a single, fully-quoted CSV row using the current OS/HW values and inputs.
# Notes are escaped for quotes to keep CSV parsers happy.

appendcsvheader() {
  if [[ ! -f "$CSV_PATH" ]]; then
    echo "Timestamp,Tester,Email,OSVersion,OSBuild,Hardware,AppName,BundleID,AppVersion,AppBuild,Result,Notes" > "$CSV_PATH"
  fi
}

appendcsvrow() {
  local ts="$1" tester="$2" email="$3" appname="$4" bid="$5" avers="$6" abuild="$7" result="$8" notes="$9"
  # Escape quotes and commas in notes
  notes_escaped=$(echo "$notes" | sed 's/"/""/g')
  echo "\"$ts\",\"$tester\",\"$email\",\"$OS_VER\",\"$OS_BUILD\",\"$HW_MODEL\",\"$appname\",\"$bid\",\"$avers\",\"$abuild\",\"$result\",\"$notes_escaped\"" >> "$CSV_PATH"
}

# HELPER UI: promptfortester
# Display info about check and Collect tester name and email via SwiftDialog before running checks.
# Prompts with two required text fields (name/email) and Parses SwiftDialog's JSON result and stores TESTER_NAME / TESTER_EMAIL
promptfortester() {
  if [[ -n "$TESTER_NAME" && -n "$TESTER_EMAIL" ]]; then
    return
  fi
  local out
  out=$("$DIALOG" \
    --title "$TITLE" \
    --icon "$ICON_DEFAULT" \
    --message "You're about to run **macOS system, network, and application tests**.<br><br>We'll check **system** (SIP, FileVault, Bootstrap Token) and **network/MDM** reachability, then open each selected **application one by one** until the test completes.<br><br>Please enter your full name and email so results can be recorded." \
    --textfield "Test Full Name",name="testuser",required \
    --textfield "Test Email",name="testemail",required \
    --moveable \
    --button1text "Continue" \
    --button2text "Cancel" \
    --json 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    error "Cancelled by user."
  fi
  
  TESTER_NAME=$(echo "$out" | grep -o '"testuser" *: *"[^"]*"' | cut -d'"' -f4)
  TESTER_EMAIL=$(echo "$out" | grep -o '"testemail" *: *"[^"]*"' | cut -d'"' -f4)
  
  if [[ -z "$TESTER_NAME" ]]; then
    TESTER_NAME="Unknown Tester"
  fi
  
  if [[ -z "$TESTER_EMAIL" ]]; then
    TESTER_EMAIL="Unknown Email"
  fi
}

########################################################################################
# System Checks
########################################################################################

# CHECKS: checknetwork
# Verifies HTTPS reachability for each URL in TEST_URLS (200–499 are considered "reachable")
# Checks for a Managed Wi-Fi profile presence and current SSID observation
# Checks APNS daemon environment (apsctl) and APNS connectivity by api.push.apple.com on ports 80 and 443 using nc
checknetwork() {
  # HTTPS reachability for URLs
  local i
  for i in "${!TEST_URLS[@]}"; do
    case "${TEST_URLS[$i]}" in
      http://*|https://*) ;;                    
      *) TEST_URLS[$i]="https://${TEST_URLS[$i]}";;
    esac
  done
  # Iterate each URL and test reachability
  local w host
  for w in "${TEST_URLS[@]}"; do
    host=$(printf '%s' "$w" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##')
    #-sS: silent but show errors, -L: follow redirects
    http_code=$(/usr/bin/curl -sSL --max-time 10 --connect-timeout 5 -o /dev/null -w "%{http_code}" "$w")
    http_code="${http_code:-000}"
    
    # Only treat codes > 0 and < 500 as PASS; "000" (no response) will FAIL
    if [[ "$http_code" =~ ^[0-9]{3}$ ]] && (( http_code > 0 && http_code < 500 )); then
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" \
      "Network: HTTPS $host" "system.network.https" "" "" "reachable" "HTTP ${http_code}"
    else
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" \
      "Network: HTTPS $host" "system.network.https" "" "" "not reachable" "HTTP ${http_code}"
    fi

  done
  
  # --- Network profile status (managed Wi-Fi + current SSID) ---
  
  local OSMAJOR OSMINOR ssid
  OSMAJOR=$(sw_vers -productVersion | awk -F '.' '{print $1}')
  OSMINOR=$(sw_vers -productVersion | awk -F '.' '{print $2}')
  
  if [[ "$OSMAJOR" -gt 15 ]] || { [[ "$OSMAJOR" -eq 15 ]] && [[ "$OSMINOR" -ge 6 ]]; }; then
    #very slow but works :( (SSID may be blank if not associated)
    ssid=$(/usr/libexec/PlistBuddy -c 'Print :0:_items:0:spairport_airport_interfaces:0:spairport_current_network_information:_name' /dev/stdin <<< "$(system_profiler SPAirPortDataType -xml)" 2> /dev/null)
  else
    local WirelessPort
    WirelessPort=$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk '/Wi-Fi|AirPort/{getline; print $NF}')
    # Current SSID (may be blank if not associated)
    ssid=$(/usr/sbin/ipconfig getsummary "$WirelessPort" | /usr/bin/awk -F ' SSID : ' '/ SSID : / {print $2}')
  fi
  
  # Any managed Wi-Fi profiles present?
  local wifi_profiles
  wifi_profiles=$(/usr/bin/profiles -C -v 2>/dev/null | /usr/bin/grep -B1 -A6 "com.apple.wifi.managed" || true)
  
  if [[ -n "$wifi_profiles" ]]; then
    if [[ -n "$ssid" ]] && echo "$wifi_profiles" | /usr/bin/grep -q "$ssid"; then
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Network: Profile (Wi-Fi)" "system.network.profile" "" "" "Works" "Managed Wi-Fi profile present; SSID: ${ssid}"
    else
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Network: Profile (Wi-Fi)" "system.network.profile" "" "" "Info" "Managed Wi-Fi profile present; SSID match: ${ssid:-none}"
    fi
  else
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Network: Profile (Wi-Fi)" "system.network.profile" "" "" "Doesn't Work" "No managed Wi-Fi profile found"
  fi
  
  # --- APNS daemon status (production connection) ---
  local APSCTL="/System/Library/PrivateFrameworks/ApplePushService.framework/apsctl"
  if [[ -x "$APSCTL" ]]; then
    local apns_status
    apns_status=$("$APSCTL" status 2>/dev/null)
    if echo "$apns_status" | /usr/bin/grep -E -q 'connection environment:\s+production'; then
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Network: APNS Daemon (prod)" "system.apns.daemon" "" "" "Works" "Connected to production"
    else
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Network: APNS Daemon (prod)" "system.apns.daemon" "" "" "Doesn't Work" "Not connected to production"
      ok=0
    fi
  else
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Network: APNS Daemon (prod)" "system.apns.daemon" "" "" "Info" "apsctl not present"
  fi
  
  # --- APNS TCP port checks (init host in wildcard *.push.apple.com) ---
  local apns_host="api.push.apple.com"   # sample host in the wildcard domain
  local port
  for port in 443 2197; do
    if /usr/bin/nc -zvw5 "$apns_host" "$port" >/dev/null 2>&1; then
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Network: APNS TCP $port" "system.apns.tcp$port" "" "" "Works" "$apns_host:$port reachable"
    else
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Network: APNS TCP $port" "system.apns.tcp$port" "" "" "Doesn't Work" "$apns_host:$port not reachable"
    fi
  done
}

# CHECKS: checksecurity
# Verifies Bootstrap Token escrow, Filevault and SIP status
checksecurity() {

  # --- Bootstrap Token status ---
  local bt
  bt=$(/usr/bin/profiles status -type bootstraptoken 2>/dev/null)
  if echo "$bt" | /usr/bin/grep -qi "escrowed: YES"; then
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Security: Bootstrap Token" "system.security.bootstraptoken" "" "" "Works" "$(echo "$bt" | tr -s ' ')"
  else
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Security: Bootstrap Token" "system.security.bootstraptoken" "" "" "Doesn't Work" "$(echo "$bt" | tr -s ' ')"
  fi
  
  # --- FileVault status ---
  local fv
  fv=$(/usr/bin/fdesetup status 2>/dev/null)
  if echo "$fv" | /usr/bin/grep -qi "FileVault is On"; then
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Security: FileVault" "system.security.filevault" "" "" "Works" "$(echo "$fv" | tr -s ' ')"
  else
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Security: FileVault" "system.security.filevault" "" "" "Doesn't Work" "$(echo "$fv" | tr -s ' ')"
  fi
  
  # --- SIP status ---
  local sip
  sip=$(/usr/bin/csrutil status 2>/dev/null)
  if echo "$sip" | /usr/bin/grep -qi "enabled"; then
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Security: SIP" "system.security.sip" "" "" "Works" "$(echo "$sip" | tr -s ' ')"
  else
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "Security: SIP" "system.security.sip" "" "" "Doesn't Work" "$(echo "$sip" | tr -s ' ')"
  fi
}

checkmdm() {
  local enrolled="Unknown"
  local mdmline
  mdmline=$(/usr/bin/profiles status -type enrollment 2>/dev/null)
  if echo "$mdmline" | /usr/bin/grep -qi "Enrolled"; then
    enrolled="Yes"
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "MDM: Enrollment" "system.mdm.enrollment" "" "" "Works" "$(echo "$mdmline" | tr -s ' ')"

  else
    enrolled="No"
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "MDM: Enrollment" "system.mdm.enrollment" "" "" "Doesn't Work" "$(echo "$mdmline" | tr -s ' ')"
  fi

  # Jamf JSS reachability (if jamf binary exists)
  if [[ -x /usr/local/bin/jamf ]]; then
    if /usr/local/bin/jamf checkJSSConnection -retry 1 >/dev/null 2>&1; then
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "MDM: Jamf Connection" "system.mdm.jamf" "" "" "Works" "JSS reachable"
    else
      appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "MDM: Jamf Connection" "system.mdm.jamf" "" "" "Doesn't Work" "JSS not reachable"

    fi
  else
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "MDM: Jamf Connection" "system.mdm.jamf" "" "" "Info" "jamf binary not present"

  fi
}

########################################################################################
# Dialog Application Test(s)
########################################################################################
      
# APP TEST: testeachapp
# Tests app spec (bundle id OR full path) to help find .app path; 
# Read version/build metadata for CSV
# Launch the app quietly and Prompt the tester via SwiftDialog: Button1 → "Works", Button2 → "Doesn’t work" and notes field for context/recommendations
# Append the outcome and notes to the CSV
testeachapp() {
  local app_spec="$1"
  local app_path
  app_path="$(resolveapppath "$app_spec")"

  if [[ -z "$app_path" || ! -d "$app_path" ]]; then
    appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "N/A" "$app_spec" "N/A" "N/A" "Not Found" "Couldn’t find this app"
    return
  fi

  # Gather metadata
  IFS="|" read -r APP_NAME BUNDLE_ID APP_VER APP_BUILD < <(appmeta "$app_path")
  if [[ -z "$BUNDLE_ID" ]]; then
    BUNDLE_ID="(unknown)"
  fi
  # Launch quietly
  /usr/bin/open -g "$app_path" >/dev/null 2>&1
  sleep 2

  # Ask tech for result
  local prompt_out result notes
  prompt_out=$("$DIALOG" \
    --title "$TITLE" \
    --icon "$app_path" \
    --message "Testing **$APP_NAME** (${APP_VER:-unknown})<br><br>Confirm the application **launches** and **basic tasks** work.<br>Provide recommendations for either working or non-working applications." \
    --position topleft \
    --button1text "Works" \
    --button2text "Doesn’t work" \
    --moveable \
    --textfield "Notes (recommended)",name="notes",editor \
    --json 2>/dev/null)
  local exitcode=$?
  if [[ $exitcode -eq 0 ]]; then
    result="Works"
  else
    result="Doesn't Work"
  fi
  notes=$(echo "$prompt_out"  | grep -o '"notes" *: *"[^"]*"' | cut -d'"' -f4)

  # Try to close the app we just opened (best-effort)
  if [[ -n "$BUNDLE_ID" && "$BUNDLE_ID" != "(unknown)" ]]; then
    /usr/bin/osascript -e 'tell application id "'"$BUNDLE_ID"'" to quit' >/dev/null 2>&1
  fi

  # Log row with summary
  appendcsvrow "$(date '+%F %T')" "$TESTER_NAME" "$TESTER_EMAIL" "$APP_NAME" "$BUNDLE_ID" "${APP_VER:-}" "${APP_BUILD:-}" "$result" "$notes"
}

########################################################################################
# Parse Args
########################################################################################

# Supported flags to run script via CLI (run with with sudo)
#   --tester "Full Name"    : pre-seeds TESTER_NAME without a dialog
#   --email "email"         : pre-seeds email without a dialog
#   --apps "id1;id2;..."    : overrides APPS_CSV with a semicolon-delimited list
TESTER_NAME=""
TESTER_EMAIL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tester) TESTER_NAME="$2"; shift 2 ;;
    --email) TESTER_EMAIL="$2"; shift 2 ;;
    --apps)   APPS_CSV="$2"; shift 2 ;;
    *) shift ;;
  esac
done

########################################################################################
# Main
# 1) Checks SwiftDialog is present (install if missing)
# 2) Gather macOS and hardware info and prepare the CSV header
# 3) Collect tester info (dialog unless preprovided)
# 4) Intro dialog summarizing the current Mac and tester; allow cancel
# 5) Run system/network/MDM/security checks (each writes rows to the CSV)
# 6) Build the application list (Jamf param > array > Safari fallback)
# 7) For each app, run testeachapp() and collect a CSV row
# 8) Summary dialog: instruct tester to review and click "Open CSV"; then open the file
# 9) Exit with status 0 if the script completes (even if some checks/apps failed)
########################################################################################

checkdialog
osinfo
appendcsvheader
promptfortester

# Show intro
"$DIALOG" --title "$TITLE" \
  --icon "$ICON_DEFAULT" \
  --message "Click **Start** to run checks now; this script will verify system setting and then open each **application one by one** for a quick ‘Works/Doesn’t Work’ review.<br><br>**macOS ${OS_VER} (${OS_BUILD})** on **${HW_MODEL}**<br><br>Tester: **${TESTER_NAME}** <${TESTER_EMAIL}>" \
  --button1text "Start" \
  --button2text "Cancel" >/dev/null
  if [[ $? -ne 0 ]]; then
      error "Cancelled by user."
  fi

# System checks
checknetwork
checkmdm
checksecurity 

# Put application list into array
declare -a APPS
if [[ -n "$APPS_CSV" ]]; then
  IFS=";" read -r -a APPS <<< "$APPS_CSV"
else
  #Default Fail will check Safari
  APPS=("com.apple.Safari")
fi

# App tests
for app_id in "${APPS[@]}"; do
  # trim whitespace
  app_id="$(echo "$app_id" | awk '{$1=$1};1')"
  if [[ -z "$app_id" ]]; then 
    continue
  fi
  testeachapp "$app_id"
done

# Final summary dialog

"$DIALOG" \
--title "$TITLE — Summary" \
--icon "$ICON_DEFAULT" \
--message "✅ **Final verification step**<br><br>All checks are complete and CSV saved to:<br><br>**$CSV_PATH**<br><br>Please review the CSV now to confirm entries look correct (tester info, network/MDM rows, each app’s status and notes).<br><br>This window has no Close, Click **Open CSV** to finish." \
--button1text "Open CSV" \
--position center \
--ontop

if [[ $? -eq 0 ]]; then
  chown "$CURRENTUSER":staff "$CSV_PATH"
  chmod 644 "$CSV_PATH"
  sleep .5
  /usr/bin/open "$CSV_PATH"
fi

exit 0
      