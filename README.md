# Jamf Scripts

 A repository of custom Bash scripts designed to automate and simplify macOS device management within Jamf Pro environments.

---

## 📍 Included Scripts

### computerinfo-jamf-swiftdialog

This script gathers and displays detailed information about a macOS device using [SwiftDialog](https://github.com/bartreardon/swiftDialog). 
It is designed for use in Jamf Pro environments to provide a user-friendly overview of system, hardware, network, and resource data.

#### 📝 Description
- Displays system info (macOS version, model, serial number)
- Shows hardware details (CPU, memory, storage)
- Provides network information (IP address, Wi-Fi SSID, etc.)
- Uses SwiftDialog for clean and interactive UI
- Deployed via Jamf Self Service
- Customizable with **Jamf Parameter Inputs (4–9)**

#### Tested On
- macOS 	14.x,15.x
- jamfpro 	11.15.x

# Use Case
Perfect for IT support teams or users to quickly verify computer specs and status without needing Terminal access or open Jamf Pro web console.
## 🛠 Requirements
- SwiftDialog installed (can be deployed via Jamf)
- macOS 12.x or later
- Admin access to Jamf Pro for script deployment

---

### `displayreboot-jamfswiftdialog.sh`

Prompts users to reboot their macOS device if system uptime exceeds a specified threshold. 

#### 📝 Description
- Uses **SwiftDialog** (preferred) or **Jamf Helper** as a fallback
- Customizable with **Jamf Parameter Inputs (4–6)** for message icons and org name
- Requires a **Smart Group** (e.g., "Last Reboot > X Days") and **Jamf Policy** for deployment

#### 🛠 Requirements
- SwiftDialog installed (can be deployed via Jamf)
- macOS 10.x or later
- Jamf Pro 11
- Admin access to deploy policy and smart group
- Uncomment time_up to test and shutdown before deploying

#### Tested On
- macOS 10.x-15.x

### `lastreboot-ea.sh`

Jamf Extension Attribute that calculates the date/time of last reboot. 

#### 📝 Description
- Returns the date/time since the system was last reboot.

#### 📦 Requirements
- Jamf Pro Extension Attribute with Data Type Date (YYYY-MM-DD hh:mm:ss)
