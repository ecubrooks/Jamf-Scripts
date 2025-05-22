## poweronbehavior-swiftdialog.sh

### Overview

This script allows macOS users to change their device's startup behavior. It is designed to run either as a standalone script or through **Jamf Self Service**, utilizing **[SwiftDialog](https://github.com/bartreardon/swiftDialog).** or `osascript` for the user interface.

### 📝 Description
- Interactive UI using Swift Dialog or osascript
- Modifies macOS startup settings based on user input

#### Tested On
- macOS 	14.x,15.x
- jamfpro 	11.15.x and higher

#### Usage

Run the script locally or deploy via **Jamf Self Service**. No additional arguments are needed.

```bash
./poweronbehavior-swiftdialog.sh