## Jamf Scripts
 A repository of custom Bash scripts designed to automate and simplify macOS device management within Jamf Pro environments.

# computerinfo-jamf-swiftdialog

This script gathers and displays detailed information about a macOS device using [SwiftDialog](https://github.com/bartreardon/swiftDialog). 
It is designed for use in Jamf Pro environments to provide a user-friendly overview of system, hardware, network, and resource data.

# Features
- Displays system info (macOS version, model, serial number)
- Shows hardware details (CPU, memory, storage)
- Provides network information (IP address, Wi-Fi SSID, etc.)
- Uses SwiftDialog for clean and interactive UI
- Easily deployed via Jamf Self Service
- Customizable with Jamf Parameter Inputs (4–9)

# Tested On
- macOS 	14.x,15.x
- jamfpro 	11.15.x

# Use Case
Perfect for IT support teams or users to quickly verify computer specs and status without needing Terminal access or open Jamf Pro web console.
## 🛠 Requirements
- SwiftDialog installed (can be deployed via Jamf)
- macOS 12.x or later
- Admin access to Jamf Pro for script deployment
