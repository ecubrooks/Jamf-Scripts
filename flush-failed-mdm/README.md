# 🧑‍💻 Jamf and Power Automate Script - Flush Failed MDM

Flush failed MDM commands on macOS via Power Automate and Jamf.

## `create_flush_failed_mdm.sh`

This script checks the last run date and, if the delay threshold is met, sends MDM info to a [Power Automate webook](powerautomate/README.md) to trigger clearing of failed commands. Intended for use in Jamf with a LaunchDaemon.

`Currently working on updating the create flush failed script and automation method`

### 📝 Description

- Uses Jamf Pro Parameter 4 to send data to Power Automate
- Optionally reads inventory data from a custom plist (via configuration profile)
- LaunchDaemon runs script every 1 hour
- Gracefully exits if last run recently

1. Create `flushfailedmdm.sh` and place in `/Library/Scripts/` on target Macs.
2. Create a LaunchDaemon using `edu.sodm.clearfailedcommands.plist`.
3. Ensure Jamf sends the webhook URL as `$4` in your policy.

### Requirements

- macOS device managed by Jamf Pro
- Power Automate webhook URL passed in via `$4`
- A configuration profile to populate `/Library/Managed Preferences/info.plist`
  ([Der Flounder guide](https://derflounder.wordpress.com/2023/02/25/providing-jamf-pro-computer-inventory-information-via-macos-configuration-profile/))

## `flush-failed-commands-by-jssid.sh`

This script allows an administrator to manually flush failed MDM commands for a specific computer using the Jamf Computer ID (JSS ID).

### 📝 Description

- Prompts for Jamf API username and password
- Requests an API bearer token
- Sends a Classic API command flush request for the provided computer ID
- Invalidates the API token when complete
- Intended for manual execution from a macOS terminal for troubleshooting or one-off situations

### Usage

1. Run the script locally from a macOS terminal.
2. Enter Jamf API credentials when prompted.
3. Provide the Jamf Computer ID (JSS ID) for the target device.


### Attribution

- Based on ideas from [rtrouton_scripts](https://github.com/rtrouton/rtrouton_scripts)
- Script Input from Slack [Slack](https://macadmins.slack.com/archives/CGXNNJXJ9/p1709065446522179?thread_ts=1709060576.321669&cid=CGXNNJXJ9)
- Shared at the Labman Conference 2024
- Shared at JNUC 2025

