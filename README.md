# EmlReader

A native macOS app for opening and viewing `.eml` (email message) files.

## Features

- Open `.eml` files via File > Open, double-click, or drag-and-drop
- View email headers (From, To, Cc, Date, Subject)
- Render HTML email bodies with dark mode support
- View plain text emails
- Download individual attachments
- Save all attachments at once
- Registers as default handler for `.eml` files

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)

## Building

1. Open `EmlReader.xcodeproj` in Xcode
2. Select the EmlReader scheme
3. Build and Run (Cmd+R)

## Usage

- **Open a file:** Use File > Open (Cmd+O) or drag an `.eml` file onto the app window
- **Save an attachment:** Click on any attachment chip to save it
- **Save all attachments:** Click the "Save All..." button in the attachments bar

## Project Structure

```
EmlReader/
├── EmlReaderApp.swift          # App entry point and state management
├── Models/
│   └── EmlMessage.swift        # Data models for messages and attachments
├── Services/
│   └── EmlParser.swift         # RFC 2822 EML file parser
├── Views/
│   ├── ContentView.swift       # Main view with welcome screen
│   └── MessageView.swift       # Message display and attachment UI
├── Assets.xcassets/            # App icons and assets
├── Info.plist                  # App configuration and file type associations
└── EmlReader.entitlements      # Sandbox permissions
```
