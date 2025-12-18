# macOS Password Expiration Prompt

### macOS-Password-Expiration-Prompt.sh

---

## 📋 Description

`macOS-Password-Expiration-Prompt.sh` is a Bash script designed to **interact with macOS users and guide them through updating their local account password** using **SwiftDialog**.

The script provides clear, branded messaging and a direct remediation path, addressing a common gap when relying only on **password policy configuration profiles**.

This script is intended to be used **in conjunction with** a configuration profile that enforces password requirements.

---

## Why This Script Exists

This script was created to fill gap by delivering **timely, interactive prompts** that reduce confusion and service desk tickets while improving compliance.

This script **does not enforce password policy settings**.

A separate **Configuration Profile** must be used to define:
- Password complexity
- Password length
- Expiration interval

While the password policy configuration profiles enforce technical requirements the script provides:

- Clear countdowns to password expiration
- User-friendly reminders
- Branded messaging or support details
- Guided remediation actions

---

### Jamf Pro Parameters

The script supports Jamf parameters for customization. Defaults are provided so it can run outside Jamf.

| Parameter | Description | Default |
|--------|------------|---------|
| `$4`  | Password expiration policy (days) | `90` |
| `$5`  | Notification window before expiration (days) | `14` |
| `$6`  | Support department name | `IT Support` |
| `$7`  | Support phone number | `1 (800) 275-2273` |
| `$8`  | Support URL | `https://example.com` |
| `$9`  | SwiftDialog icon (URL or SF Symbol) | `SF=lock.circle.dotted` |
| `$10` | SwiftDialog location | `/usr/local/bin/dialog` |

### How It Works

1. Identifies the currently logged-in macOS user
2. Reads the local account `passwordLastSetTime`
3. Calculates:
- Days since the last password change
- Days remaining until expiration
4. Displays a SwiftDialog prompt based on policy thresholds:
- **Password Expiring Soon**
- **Password Overdue**
- **Error State**
5. Guides the user to System Settings to update their password


---

### Use Case

This script is ideal for environments that:

- Enforce password policies using **Configuration Profiles**
- Want improved user communication around password changes
- Prefer script-driven user interaction
- Deploy scripts via **Jamf Pro**

---

### Requirements

- macOS 12 or later (recommended)
- SwiftDialog installed
