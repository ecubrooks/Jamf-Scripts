# 🖥️ Display Restart message with Jamf EA

## `displayreboot-jamfswiftdialog.sh`

Prompts users to reboot their macOS device if system uptime exceeds a specified threshold. 

### 📝 Description
- Uses **SwiftDialog** (preferred) or **Jamf Helper** as a fallback
- Customizable with **Jamf Parameter Inputs (4–6)** for message icons and org name
- Requires a **Smart Group** (e.g., "Last Reboot > X Days") and **Jamf Policy** for deployment

#### Tested On
- macOS 10.x-15.x

#### 🛠 Requirements
- SwiftDialog installed (can be deployed via Jamf)
- macOS 10.x or later
- Jamf Pro 11
- Admin access to deploy policy and smart group
- Uncomment time_up to test and shutdown before deploying

---
### `lastreboot-ea.sh`

Jamf Extension Attribute that calculates the date/time of last reboot. 

#### 📝 Description
- Returns the date/time since the system was last reboot.

#### Requirements
- Jamf Pro Extension Attribute with Data Type Date (YYYY-MM-DD hh:mm:ss)


