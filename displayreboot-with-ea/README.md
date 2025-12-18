# Display Computer Information 

## `computerinfo-jamf-swiftdialog`

This script gathers and displays detailed information about a macOS device using [SwiftDialog](https://github.com/bartreardon/swiftDialog). 
It is designed for use in Jamf Pro environments to provide a user-friendly overview of system, hardware, network, and resource data.  Helpful for remote support calls to gather information.
Built off jamf's [Build a Computer Information script for your Help Desk](https://www.jamf.com/blog/build-a-computer-information-script-for-your-help-desk/)

### 📝 Description
- Displays system info (macOS version, model, serial number)
- Shows hardware details (CPU, memory, storage)
- Provides network information (IP address, Wi-Fi SSID, etc.)
- Uses SwiftDialog for clean and interactive UI
- Deployed via Jamf Self Service
- Customizable with **Jamf Parameter Inputs (4–9)**

![Display Reboot](./displayreboot.png)

#### Tested On
- macOS 	14.x,15.x,26.x
- jamfpro 	11.15.x

#### Use Case
Perfect for IT support teams or users to quickly verify computer specs and status without needing Terminal access or open Jamf Pro web console.

#### 🛠 Requirements
- SwiftDialog installed (can be deployed via Jamf)
- macOS 12.x or later
- Admin access to Jamf Pro for script deployment