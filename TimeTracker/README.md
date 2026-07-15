# My Time Tracker — macOS

A minimalist macOS time-tracking app built with SwiftUI, with a Notion-style database UI and optional two-way **Notion sync**.

This is the main app in the [mac-time-tracker-notion](../) project. See the [root README](../README.md) for full setup, the required Notion database schema, and privacy details.

## Features

- ⏱ Start/stop timers per task
- 📁 Projects & tasks in a grouped/table UI (light + dark)
- 📋 Time log grouped by day + daily report
- 🔄 **Notion sync** — imports your projects & tasks; writes a Time Entry back to Notion when you stop a timer
- 💾 Local-only projects & tasks are preserved and never leave your Mac

## Install

Download `My Time Tracker.zip` from the [Releases](../../../releases) page, unzip, and run. The app is unsigned, so on first launch right-click → **Open** → **Open** to bypass Gatekeeper once.

## Notion setup

1. Create an integration at [notion.so/my-integrations](https://www.notion.so/my-integrations) and copy the token.
2. Create the three databases (Projects, Tasks, Time Entries) with the exact property names listed in the [root README](../README.md#notion-setup), and connect your integration to each.
3. In the app: **⚙️ Settings** → paste the token and the three database IDs → **Save** → **Sync Now**.

## Requirements

- macOS 14 (Sonoma) or later

## Build from source

Requires Swift (bundled with Xcode or the Command Line Tools):

```bash
swift build -c release
```

Or open `TimeTracker.xcodeproj` in Xcode and run the **TimeTracker** scheme.
