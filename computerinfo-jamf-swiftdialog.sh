#!/bin/bash

########################
# Computer Information Script
# This script gathers and displays information about the computer's system, hardware, network, and resources.
# Author: Brooks Person
# Last Updated: 2025-04-30
# Designed for portability in other Jamf environments
########################

########################################
# Jamf Parameter Inputs (4–9):
# $4 = Path to SwiftDialog binary (default: /usr/local/bin/dialog)
# $5 = Dialog icon URL.PNG,SFSYMBOL
# $6 = IT Path to SwiftDialog binary (default: /usr/local/bin/dialogSupport URL
# $7 = Dialog title
# $8 = Support phone number
# $9 = Jamf custom event for remote support
########################################

# ----- Configurable Variables -----
dialogCommandFile="${4:-/usr/local/bin/dialog}"
dialogIcon="${5:-https://www.apple.com/ac/structured-data/images/knowledge_graph_logo.png}"
supportURL="${6:-https://support.example.com}"
dialogTitle="${7:-System Information Summary}"
supportPhone="${8:-111-111-1111}"
remoteSupportEvent="${9:-remoteaccess}"
# Set optional Button 2 only if $9 is not empty
button2=()
if [[ -n "$9" ]]; then
  button2=(--button2text "Enable Remote Support")
fi

# ----- Check SwiftDialog -----
if [[ ! -x "$dialogCommandFile" ]]; then
    echo "ERROR: SwiftDialog binary not found at $dialogCommandFile"
    exit 1
fi

# ----- Gather System Info -----
computername=$(scutil --get ComputerName)
CurrentUser=$(stat -f%Su /dev/console)
hostnamename=$(hostname)
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
SerialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
TotalRam=$(sysctl -n hw.memsize | awk '{printf "%.2f GB", $1/1073741824}')
UPTIME=$(uptime | awk -F'( |,|:)+' '{print $6 "h " $7 "m"}')

# Model
model=$(system_profiler SPHardwareDataType | awk -F': ' '/Model Name/ {print $2}')
# Set SF Symbol icon based on model type
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

# Chip detection (simplified)
CHIP_RAW=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
if [[ "$CHIP_RAW" == *"Apple"* ]]; then
  CHIP=$(echo "$CHIP_RAW" | sed 's/.*Apple //')
  CHIP="Apple $CHIP"
else
  CHIP=$(echo "$CHIP_RAW" | sed -E 's/^.*(Intel\(R\) .*?)( CPU|$).*/\1/' | sed 's/Intel(R) //')
  CHIP="Intel $CHIP"
fi

# ----- Network Info -----
INTERFACE=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
if [[ -n "$INTERFACE" ]]; then
  IP_ADDRESS=$(ipconfig getifaddr "$INTERFACE" 2>/dev/null)
  MAC_ADDRESS=$(ifconfig "$INTERFACE" | grep ether | awk '{print $2}')
else
  IP_ADDRESS="Unavailable"
  MAC_ADDRESS="Unavailable"
fi

# ----- Network Type Labeling -----
if [[ "$INTERFACE" =~ utun* ]]; then
  IP_ADDRESS=$(ifconfig $INTERFACE | grep inet | awk '{print $2}' | head -n 1)
  MAC_ADDRESS=$(ifconfig $INTERFACE| grep $INTERFACE | awk '{print $2}' | tail -n 1 | awk -F'%' '{print $1}')
  NETWORK_LABEL="VPN IP"
  ICON="SF=lock.shield"
elif [[ "$INTERFACE" =~ ^en[0-9]+$ ]]; then
  NETWORK_LABEL="IP Address ($INTERFACE)"
  NETICON="SF=dot.radiowaves.left.and.right"
else
  NETWORK_LABEL="IP Address"
  NETICON="SF=network"
fi

if [[ -z "$IP_ADDRESS" ]]; then
  NETWORK_LABEL="IP Address"
  IP_ADDRESS="Unavailable"
  NETICON="SF=network"
fi


wifi_active=false
ethernet_active=false

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


if $wifi_active && $ethernet_active; then
  networktype="Wi-Fi + Ethernet"
  networkicon="SF=network"
elif $wifi_active; then
  networktype="Wi-Fi"
  networkicon="SF=wifi"
elif $ethernet_active; then
  networktype="Ethernet"
  networkicon="SF=cable.connector.horizontal"
else
  networktype="No active connection"
  networkicon="SF=xmark.octagon"
fi


# ----- Drive Info -----
BootVolume=$(diskutil info / | awk -F': ' '/Volume Name/ {print $2}')
containerInfo=$(diskutil info / | awk -F': *' '
  /Container Total Space/ { total=$2 }
  /Container Free Space/ { free=$2 }
  END {
    print total "|" free
  }')
TotalContainerSize=$(echo "$containerInfo" | cut -d'|' -f1 | awk -F'(' '{print $1}')
FreeContainerSpace=$(echo "$containerInfo" | cut -d'|' -f2 | awk -F'(' '{print $1}')

# ----- List Item Array Construction -----
listItems=()

add_listitem() {
  local title="$1"
  local statustext="$2"
  local icon="$3"
  listItems+=(
    "--listitem"
    "title=${title},status=info,statustext=${statustext},icon=${icon}"
  )
}

add_listitem "Computer Name" "$computername" "$MODEL_ICON"
add_listitem "Current User" "$CurrentUser" "SF=person.fill"
add_listitem "Hostname" "$hostnamename" "SF=network"
add_listitem "macOS Version" "$OSVersion" "SF=info.circle"
add_listitem "Serial Number" "$SerialNumber" "SF=number"
add_listitem "Network Connection" "$networktype" "$networkicon"
add_listitem "$NETWORK_LABEL" "$IP_ADDRESS" "$ICON"
add_listitem "MAC Address" "$MAC_ADDRESS" "SF=network"
add_listitem "Boot Volume" "$BootVolume" "SF=internaldrive"
add_listitem "Boot Drive Size" "$TotalContainerSize" "SF=externaldrive.fill"
add_listitem "Free Drive Space" "$FreeContainerSpace" "SF=externaldrive"
add_listitem "System Uptime" "$UPTIME" "SF=clock.arrow.2.circlepath"

# ----- Display with SwiftDialog -----
"$dialogCommandFile" \
--title "$dialogTitle" \
--titlefont "name=Avenir Next,shadow=true,size=24" \
--icon "$dialogIcon" \
--message "Below is a snippet of your Mac’s system info:" \
--iconsize 120 \
--height 750 \
--width 900 \
--infobox "**System Summary**<br><br>This information may be used for IT diagnostics or support.<br><br>IT Support: [$supportPhone](tel:$supportPhone)<br><br>**Model:**<br>$model<br><br>**OS Version:**<br>macOS $OSNAME<br><br>**Processor:**<br>$CHIP<br><br>**Memory:**<br>$TotalRam" \
--infobuttontext "Need Help" \
--infobuttonaction "$supportURL" \
--button1text "Close" \
"${button2[@]}" \
"${listItems[@]}"

# ----- Remote Support Trigger -----
if [[ $? == 2 ]]; then
  echo "User selected Remote Support option"
  jamf policy -event "$remoteSupportEvent"
fi
  