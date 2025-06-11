# OneDrive File and Folder Name Fix for macOS

## `onedrive-name-fix-swift.sh`

This script scans user Desktop and Documents folders for file and folder names that may cause sync issues with Microsoft OneDrive. It renames files with unsupported characters, trims leading/trailing spaces, and identifies overly long paths.

Originally adapted from work by [UoE-macOS](https://github.com/UoE-macOS/jss), this version is tailored for use in Jamf Pro with support for SwiftDialog to inform and guide the user throughout the process.

### 📝 Description

- Fixes illegal characters (`\ / : * ? " < > | %`)
- Removes leading/trailing spaces and periods
- Detects and reports file paths longer than 400 characters
- Displays progress and summary via [SwiftDialog](https://github.com/bartreardon/swiftDialog)
- Saves a report to the user’s desktop
- Accepts Jamf Pro script parameters for customization

#### Tested On
- macOS 	14.x,15.x

#### Requirements

- macOS 11 or later
- [SwiftDialog](https://github.com/bartreardon/swiftDialog) installed (default path: `/usr/local/bin/dialog`)
- Jamf Pro (optional but supported)

#### Jamf Pro Script Parameters (Positional Parameters 4–9)

| Parameter | Description |
|----------:|-------------|
| `$4` | Full path to SwiftDialog binary (default: `/usr/local/bin/dialog`) |
| `$5` | Dialog icon (URL to PNG or SFSymbol) |
| `$6` | URL for IT support/help documentation |
| `$7` | Dialog window title |
| `$8` | IT support phone number |

#### Output

If any files or folders are renamed or flagged:
- A file is saved to the user’s desktop: `onedrive-renames.txt`
- A list of changes and issues is presented in a SwiftDialog window

