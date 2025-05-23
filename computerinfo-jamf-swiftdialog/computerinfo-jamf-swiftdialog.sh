#!/bin/bash

################################################################
# Computer Information Script
# This script gathers and displays information about the 
# computer's system, hardware, network, and resources.
# Author: Brooks Person
# Last Updated: 2025-04-30, 2025-05-03
# Designed for portability in other Jamf environments
################################################################

################################################################
# Jamf Script Parameters (4–9):
# $4 = Full path to SwiftDialog binary (default: /usr/local/bin/dialog)
# $5 = Dialog icon (URL to PNG or SFSymbol)
# $6 = URL for IT support/help documentation
# $7 = Dialog window title
# $8 = IT support phone number to be displayed
# $9 = Jamf custom trigger to enable remote support session
################################################################

# ----- Configurable Variables -----
dialogCommandFile="${4:-/usr/local/bin/dialog}" # Use Jamf parameter 4 or default path to dialog
dialogIcon="${5:-https://www.apple.com/ac/structured-data/images/knowledge_graph_logo.png}" # Icon shown in the dialog
supportURL="${6:-https://support.example.com}" # Link for IT support help site
dialogTitle="${7:-System Information Summary}" # Title shown in the dialog
supportPhone="${8:-111-111-1111}" # Phone number displayed for user assistance
remoteSupportEvent="${9:-remoteaccess}" # Jamf policy event name for remote support
# Set optional Button 2 only if $9 is not empty
button2=()
if [[ -n "$9" ]]; then
  button2=(--button2text "Enable Remote Support")
fi

# ----- Check SwiftDialog -----
# Verify that the SwiftDialog binary exists and is executable
if [[ ! -x "$dialogCommandFile" ]]; then
    echo "ERROR: SwiftDialog binary not found at $dialogCommandFile"
    exit 1
fi

# ----- Gather System Info -----
# Get various system identifiers
computername=$(scutil --get ComputerName)
CurrentUser=$(stat -f%Su /dev/console)
hostnamename=$(hostname)
# Get macOS version and determine major release name
OSVersion=$(sw_vers -productVersion)
OSMAJOR=$(echo "$OSVersion" | awk -F '.' '{print $1}')
case "$OSMAJOR" in
  11) OSNAME="Big Sur" ;;
  12) OSNAME="Monterey" ;;
  13) OSNAME="Ventura" ;;
  14) OSNAME="Sonoma" ;;
  15) OSNAME="Sequoia" ;;
  *)
    OSNAME="X"
  ;;
esac
# Retrieve system serial number
SerialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
# Convert RAM from bytes to GB
TotalRam=$(sysctl -n hw.memsize | awk '{printf "%.2f GB", $1/1073741824}')
# Get system uptime (days or hours and minutes)
#UPTIME=$(uptime | awk -F'( |,|:)+' '{print $6 "h " $7 "m"}') #work in progress
UPTIME=$(uptime | awk -F'up ' '{print $2}' | awk -F', ' '{print $1}'| xargs)
# Retrieve Mac model name and assign a SwiftDialog SF Symbol icon based on the Mac model type
model=$(system_profiler SPHardwareDataType | awk -F': ' '/Model Name/ {print $2}')
case "$model" in
  "MacBook Pro"|"MacBook Air")
    MODEL_ICON="SF=laptopcomputer"
  ;;
  "Mac mini")
    MODEL_ICON="SF=macmini.fill"
  ;;
  "iMac")
    MODEL_ICON="SF=desktopcomputer"
  ;;
  "Mac Studio")
    MODEL_ICON="SF=macpro.gen3"
  ;;
  *)
    MODEL_ICON="SF=macwindow"
  ;;
esac
# Detect whether chip is Apple Silicon or Intel and format string accordingly (simplified)
CHIP=$(system_profiler SPHardwareDataType | awk -F ':' '/Chip/ {print $2}' | xargs)
# Fallback for Intel Macs if Chip is empty
if [[ -z "$CHIP" ]]; then
  raw_chip=$(sysctl -n machdep.cpu.brand_string)
  # Example: "Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz"
  CHIP=$(echo "$raw_chip" | grep -oE 'Intel.*?Core.*?i[3579]' | sed 's/(TM)//g' | sed 's/(R)//g' | xargs)
fi

# ----- Network Info -----
#Determine the default network interface and Get IP and MAC address for that interface
INTERFACE=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
if [[ -n "$INTERFACE" ]]; then
  IP_ADDRESS=$(ipconfig getifaddr "$INTERFACE" 2>/dev/null)
  MAC_ADDRESS=$(ifconfig "$INTERFACE" | grep ether | awk '{print $2}')
else
  IP_ADDRESS="Unavailable"
  MAC_ADDRESS="Unavailable"
fi

# ----- Network Type Labeling -----
#Determines interfaces and labels based off network type
if [[ "$INTERFACE" =~ utun* ]]; then
  IP_ADDRESS=$(ifconfig $INTERFACE | grep inet | awk '{print $2}' | head -n 1)
  MAC_ADDRESS=$(ifconfig $INTERFACE| grep $INTERFACE | awk '{print $2}' | tail -n 1 | awk -F'%' '{print $1}')
  NETWORK_LABEL="VPN IP"
  NETICON="SF=lock.shield"
elif [[ "$INTERFACE" =~ ^en[0-9]+$ ]]; then
  NETWORK_LABEL="IP Address ($INTERFACE)"
  NETICON="SF=dot.radiowaves.left.and.right"
else
  NETWORK_LABEL="IP Address"
  NETICON="SF=network"
fi
# If IP not found, reset values to "Unavailable"
if [[ -z "$IP_ADDRESS" ]]; then
  NETWORK_LABEL="IP Address"
  IP_ADDRESS="Unavailable"
  NETICON="SF=network"
fi
# ----- Network Type Detection -----
# Flags to track Wi-Fi or Ethernet activity
wifi_active=false
ethernet_active=false
#Get the wireless name to return (runs if Network Connection is Wi-Fi)
getssid() {
  WirelessPort=$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk '/Wi-Fi|AirPort/{getline; print $NF}')
  #What SSID is the machine connected to
  SSIDLookup=$(/usr/sbin/ipconfig getsummary "$WirelessPort" | /usr/bin/awk -F ' SSID : ' '/ SSID : / {print $2}')
  echo "$SSIDLookup"
}
# Loop through network service order to identify active Wi-Fi/Ethernet
while IFS= read -r line; do
  servicename=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $2}' 2>/dev/null)
  devicename=$(echo "$line" | awk -F  "(, )|(: )|[)]" '{print $4}' 2>/dev/null)
  
  if [[ -n "$devicename" ]]; then
    if ifconfig "$devicename" 2>/dev/null | grep -q 'status: active' 2>/dev/null; then
      if [[ "$servicename" == *"Wi-Fi"* || "$servicename" == *"AirPort"* ]]; then
        wifi_active=true
      elif [[ "$servicename" == *"Ethernet"* || "$servicename" == *"Thunderbolt"* ]]; then
        ethernet_active=true
      fi
    fi
  fi
done <<< "$(networksetup -listnetworkserviceorder 2>/dev/null | grep 'Hardware Port' 2>/dev/null)"
# Determine the network connection type and appropriate SF Symbol
if $wifi_active && $ethernet_active; then
  networktype="Wi-Fi + Ethernet"
  networkicon="SF=network"
elif $wifi_active; then
  ssid=$(echo "$(getssid)" | cut -c1-20)
  networktype="Wi-Fi SSID: $ssid"
  networkicon="SF=wifi"
elif $ethernet_active; then
  networktype="Ethernet"
  networkicon="SF=cable.connector.horizontal"
else
  networktype="No active connection"
  networkicon="SF=xmark.octagon"
fi

# ----- Drive Info -----
# Get the name of the current boot volume
BootVolume=$(diskutil info / | awk -F': ' '/Volume Name/ {print $2}')
# Extract total and free space from container info
containerInfo=$(diskutil info / | awk -F': *' '
  /Container Total Space/ { total=$2 }
  /Container Free Space/ { free=$2 }
  END {
    print total "|" free
  }')
TotalContainerSize=$(echo "$containerInfo" | cut -d'|' -f1 | awk -F'(' '{print $1}')
FreeContainerSpace=$(echo "$containerInfo" | cut -d'|' -f2 | awk -F'(' '{print $1}')

#Get the wireless name to return (runs if Network Connection is Wi-Fi)
getssid() {
  WirelessPort=$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/awk '/Wi-Fi|AirPort/{getline; print $NF}')
  #What SSID is the machine connected to
  SSIDLookup=$(/usr/sbin/ipconfig getsummary "$WirelessPort" | /usr/bin/awk -F ' SSID : ' '/ SSID : / {print $2}')
  echo "$SSIDLookup"
}
# ----- List Item Array Construction -----
# Prepare array to feed into SwiftDialog's list format
listItems=()
# Function to simplify adding list items to the dialog
add_listitem() {
  local title="$1"
  local statustext="$2"
  local icon="$3"

  listItems+=(
    "--listitem"
    "title=${title},status=info,statustext=${statustext},icon=${icon}"
  )
}

# Add system and network information to the list
add_listitem "Computer Name" "$computername" "$MODEL_ICON"
add_listitem "Current User" "$CurrentUser" "SF=person.fill"
add_listitem "Hostname" "$hostnamename" "SF=network"
add_listitem "macOS Version" "$OSVersion" "SF=info.circle"
add_listitem "Serial Number" "$SerialNumber" "SF=number"
add_listitem "Network Connection" "$networktype" "$networkicon"
add_listitem "$NETWORK_LABEL" "$IP_ADDRESS" "$NETICON"
add_listitem "MAC Address" "$MAC_ADDRESS" "SF=network"
add_listitem "Boot Volume" "$BootVolume" "SF=internaldrive"
add_listitem "Boot Drive Size" "$TotalContainerSize" "SF=externaldrive.fill"
add_listitem "Free Drive Space" "$FreeContainerSpace" "SF=externaldrive"
add_listitem "System Uptime" "$UPTIME" "SF=clock.arrow.2.circlepath"

# ----- Display with SwiftDialog -----
  
# Show SwiftDialog window with system summary and infobox
# Window set to quit after 5 minutes
"$dialogCommandFile" \
--title "$dialogTitle" \
--titlefont "name=Avenir Next,shadow=true,size=24" \
--icon "$dialogIcon" \
--message "Below is a snippet of your Mac’s system info:" \
--iconsize 120 \
--height 750 \
--width 900 \
--timer 300 \
--hidetimerbar \
--infobox "**System Summary**<br><br>This information may be used for IT diagnostics or support.<br><br>IT Support: [$supportPhone](tel:$supportPhone)<br><br>**Model:**<br>$model<br><br>**OS Version:**<br>macOS $OSNAME<br><br>**Processor:**<br>$CHIP<br><br>**Memory:**<br>$TotalRam" \
--infobuttontext "Need Help" \
--infobuttonaction "$supportURL" \
--button1text "Close" \
"${button2[@]}" \
"${listItems[@]}"

# ----- Remote Support Trigger -----
# If user clicked button 2, initiate Jamf remote support policy
if [[ $? == 2 ]]; then
  echo "User selected Remote Support option"
  jamf policy -event "$remoteSupportEvent"
fi
  