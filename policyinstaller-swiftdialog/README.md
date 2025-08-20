# Policy Installer - SwiftDialog

This script provides a SwiftDialog-based user interface for executing one or more Jamf policy triggers. It's designed to provide users with real-time visual feedback while Jamf runs a series of custom policies behind the scenes.

### policyinstaller-swiftdialog

## 📋 Description

* Accepts Jamf parameters for title, icon, triggers, labels, and support URL
* Supports **test** modes
* Dynamically builds SwiftDialog list items and progress display
* Locks the dialog until completion
* Tracks failure or success of each policy trigger
* Optionally installs SwiftDialog if not present
* Default color is purple for items but can be changed to match org or school.

---

### Jamf Policy Parameters

| Parameter | Description                                                  |
| --------- | ------------------------------------------------------------ |
| 4         | Dialog Title *(optional)*                                    |
| 5         | Icon Path *(optional)*                                       |
| 6         | Comma-separated Jamf triggers (e.g. `vpnsetup,inventory`)    |
| 7         | Comma-separated labels (e.g. `Install VPN,Update Inventory`) |
| 8         | Operation mode: `test` or `live` *(default: test)*           |
| 9         | Support URL *(optional)*                                     |

---

### Requirements

* SwiftDialog installed at `/usr/local/bin/dialog`
  *(Optionally remove hashes in code to install swtift using Jamf policy trigger if not found)*
* Jamf binary available in the system path

---

### Test Mode

Running in test mode will simulate each step with a short delay and return a success message for all triggers.

![Jamf Policy Installer](./Jamf%20Policy%20Installer.png)

---

### Example Jamf Policy Setup

* **Display Name**: `Policy Installer - Swift Dialog - VPN`
* **Category**: Custom
* **Trigger**: `Self Service`
* **Parameters**:

  * `$4`: `VPN Setup Assistant`
  * `$5`: `/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns`
  * `$6`: `vpnsetup,configvpn,inventory`
  * `$7`: `Install VPN,Configure Settings,Update Inventory`
  * `$8`: `live`
  * `$9`: `https://your-support-url.com/help`

---

### Cleanup

Temporary files are deleted at the end of script execution.

---

### 🙌 Acknowledgments

This project was inspired by the work of [Dan Snelson](https://github.com/dan-snelson), whose use of SwiftDialog for interactive feedback helped shape this workflow.
