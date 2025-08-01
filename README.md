# ⚙️ Jamf Scripts

 A repository of custom Bash scripts designed to automate and simplify macOS device management within Jamf Pro environments.

## 📂 Available Scripts

| Script | Description |
|--------|-------------|
| [`computerinfo-jamf-swiftdialog`](./computerinfo-jamf-swiftdialog) | Displays system, network, and hardware info with SwiftDialog. |
| [`displayreboot-with-ea`](./displayreboot-with-ea) | Prompts user to reboot if uptime exceeds a threshold. Extension Attribute that returns the last reboot time. |
| [`laps-swiftdialog`](./laps-swiftdialog) | Securely retrieves local admin password via Jamf API |
| [`flush-failed-mdm`](./flush-failed-mdm) | Flushes failed MDM commands using Jamf API. Includes Power Automate Workflow screenshots. |
| [`policyinstaller-swiftdialog`](./policyinstaller-swiftdialog) | Runs one or more Jamf policy triggers using SwiftDialog for visual feedback. |
| [`poweron-behavior`](./poweron-behavior) | Users can change their Mac's power-on behavior. |
| [`onedrive-name-fix`](./onedrive-name-fix) | Renames files and folders incompatible with OneDrive sync. Displays results with SwiftDialog and saves a report of changes. 
| [`softwareupdate-swiftdialog`](./softwareupdate-swiftdialog) | Prompts users to update minor macOS update within a version and a set deferral to complete. |

Each folder contains a `README.md` with setup and usage details.