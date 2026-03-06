#!/bin/bash
#
# Name:        flush-failed-commands-by-jssid.sh
#
# Description:
# Flushes failed MDM commands for a computer in Jamf Pro using the Jamf
# Computer ID (JSS ID). The script prompts for Jamf API credentials,
# retrieves a bearer token, issues the command flush request, and then
# invalidates the API token.
#
# Notes:
# - Requires Jamf Pro API access.
# - Credentials are requested interactively and not stored.
# - Intended to be run manually from a local macOS terminal.
# - Not designed to run from a Jamf policy or automated workflow.
# - REQUIRES: Replace the Jamf URL placeholder with your Jamf Pro server.

# Prompt for Jamf credentials
read -p "Jamf API Username: " JAMF_USER
read -s -p "Jamf API Password: " JAMF_PASS
echo
read -p "JSS ID: " JSSID

# Jamf URL (add url)
jamfurl=""

# Get Jamf API Token
TOKEN=$(curl -sk -K - <<EOF | /usr/bin/plutil -extract token raw -
user = "${JAMF_USER}:${JAMF_PASS}"
request = POST
url = "${jamfurl}/api/v1/auth/token"
EOF
)

# Check if token failed
if [[ -z "$TOKEN" ]]; then
	echo "Failed to obtain Jamf API token."
	exit 1
fi

# Flush failed MDM commands
curl -sk \
	-H "Authorization: Bearer ${TOKEN}" \
	-X DELETE "${jamfurl}/JSSResource/commandflush/computers/id/${JSSID}/status/Failed"

# Invalidate token
curl -sk -X POST \
	-H "Authorization: Bearer ${TOKEN}" \
	"${jamfurl}/api/v1/auth/invalidate-token"

echo " "
echo "Completed command flush for computer ID ${JSSID}"