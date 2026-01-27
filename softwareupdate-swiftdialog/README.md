# macOS SoftwareUpdate & Upgrade Enforcement Script using SwiftDialog

This script enforces **minor macOS updates** (within the same major version) or **major macOS upgrades** by prompting users with [SwiftDialog](https://github.com/bartreardon/swiftDialog) and tracking deferrals. It makes sure that Apple Silicon systems request authentication via password prompt and enforces update or upgrade after a set number of deferrals.

### softwareupdate-swiftdialog

## 📝 Description

- Supports **Intel** and **Apple Silicon** Macs
- Uses `softwareupdate` for native macOS patching and OS upgrades
- Enforces macOS minor updates AND major upgrades **version requirements**
- Password prompt for Apple Silicon (`--stdinpass`)
- Uses **SwiftDialog** for interactions 
- Customizable with **Jamf Parameter Inputs (4–10)**
- Cleans tracking files after a successful update and exits if user at loginwindow
- Updates and upgrades are limited to what `softwareupdate --list` reports for the device.

![Software Update Display](./softwareupdate-display.png)

---

### Tested On

- macOS 14, 15, 26
- Apple Silicon & Intel Macbook

---

### Jamf Pro Script Parameters

| Parameter # | Purpose                                | Example                                     |
|-------------|----------------------------------------|---------------------------------------------|
| 4           | Path to SwiftDialog binary             | `/usr/local/bin/dialog`                     |
| 5           | Max number of deferrals                | `3`                                         |
| 6           | Directory to store deferral count      | `/Library/Application Support/SWUpdate`     |
| 7           | Dialog icon (URL or SF Symbol)         | `https://example.com/icon.png`              |
| 8           | Support URL                            | `https://support.example.com`               |
| 9           | Required macOS version                 | `26.2`                                      |
| 10          | IT Department organization name        | `IT Support`                                |

If omitted, default values will be used.

---

### ❗ Why Not Use Jamf's Built-In Update Mechanism?

This script was developed specifically for **Jamf Pro environments**, where:

- **Jamf's Software Update feature is limited or unreliable**
- Jamf’s “MDM-command only” workflows sometimes result in **updates failing silently** or **not prompting users**.
- This script provides **more reliable enforcement**, and **user-friendly dialogs** for control for macOS updates and upgrades

---

### 📂 File Structure

- `enforce_count.txt` – Tracks the number of deferrals

---

## Example Use Case (Jamf Pro Policy)

1. **Trigger**: Recurring Check-In
2. **Execution Frequency**: Once every day
3. **Script Parameters**:
   - Parameter 4: `/usr/local/bin/dialog`
   - Parameter 5: `3`
   - Parameter 6: `/Library/Application Support/SWUpdate`
   - Parameter 7: `https://example.com/icon.png`
   - Parameter 8: `https://support.mysite.com/update-help`
   - Parameter 9: `26.2`
   - Parameter 10: `IT Support`
4. **Scope**: Target macOs below macOS 26.2, Exclude macOS 26.2+

---

## 🔒 Security

- Password is collected using [SwiftDialog secure](https://github.com/swiftDialog/swiftDialog/wiki/Textfields#secure) for Apple Silicon systems.
- Apple Silicon authentication is required for both updates and major OS upgrades
- Authentication failures are handled with a retry loop.
- All prompts are optional until the deferral threshold is reached.
- The password is passed directly over stdin to softwareupdate --stdinpass and then cleared from memory.

