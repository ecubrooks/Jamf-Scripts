# Jamf LAPS Retrieval and Keychain Info

## `laps-swiftdialog.sh`

### 📝 Description

A SwiftDialog-based interactive script that allows IT support staff to securely retrieve the local administrator password (LAPS) for a Jamf-managed Mac by entering the device’s serial number. It leverages the Jamf Pro API with validated input and clear user feedback.

- Uses **SwiftDialog**
- Customizable with **Jamf Parameter Inputs (4–11)** for message icons, title, account name
- Requires Two Keychains for ClientID and ClientSecret

#### Use Case

Designed for Apple computers managed by **Jamf Pro**, this script enables IT staff to:

- Quickly retrieve the local admin password when needed for maintenance or support
- Display or copy the password securely based on configuration
- Validate serial numbers before querying
- Operate in environments where admin credentials are rotated regularly using LAPS

---

## 🔐 Security Notes

To securely authenticate with the Jamf Pro API, the following **macOS Keychain items must be created** on the client machine running this script:

- `JSSCID` – contains the **Client ID**
- `JSSCIDSRT` – contains the **Client Secret**

These are used to generate a secure bearer token for API access without hardcoding credentials into the script or Jamf.  

Use the following commands to manually create them:

```bash
# Store the Jamf Client ID
security add-generic-password -a "JamfID" -s "JSSID" -w "$CLIENT_ID" -T "/usr/bin/security" "/Library/Keychains/System.keychain"

# Store the Jamf Client Secret
security add-generic-password -a "JamfSecret" -s "JSSCIDSRT" -w "$SECRET" -T "/usr/bin/security" "/Library/Keychains/System.keychain"

