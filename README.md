# Mac Time Tracker for Notion

A minimalist **macOS** time-tracking app (with a companion **Apple Watch** app) built in SwiftUI. Track time across your projects and tasks with a Notion-style database UI, and sync two-way with your own Notion workspace — pull in your projects & tasks, and write time entries back automatically when you stop a timer.

> **Bring your own Notion.** The app ships with **no data and no credentials**. You connect it to *your* Notion workspace by entering your integration token and database IDs in Settings (see [Notion setup](#notion-setup)).

## Contents

- [`TimeTracker/`](TimeTracker/) — the macOS app (main app)
- [`TimeTrackerWatch/`](TimeTrackerWatch/) — a standalone Apple Watch app that talks to the same Notion databases

## Features

- ⏱ Start/stop timers per task
- 📁 Projects and tasks in a clean, Notion-style grouped/table UI (light + dark)
- 📋 Time log grouped by day, plus a daily report
- 🔄 **Two-way Notion sync** — imports your projects & tasks; writes a Time Entry back to Notion when you stop a timer
- ⌚️ Optional Apple Watch app to start/stop timers from your wrist
- 💾 Local-only projects & tasks are supported and never leave your Mac

## Install (macOS)

**Option A — download the prebuilt app**
1. Download [`TimeTracker/My Time Tracker.zip`](TimeTracker/My%20Time%20Tracker.zip) (use the **Download raw file** button) and unzip it — or grab it from the [Releases](../../releases) page if one is published.
2. The app is unsigned, so on first launch right-click the app → **Open** → **Open** to bypass Gatekeeper once.

**Option B — build from source** (see [Building](#building) below).

## Notion setup

The app talks to **three Notion databases** with specific property names. Create them in your workspace (or adapt existing ones to match), then connect the app.

### 1. Create an integration

1. Go to [notion.so/my-integrations](https://www.notion.so/my-integrations) → **New integration** → copy the **Internal Integration Secret** (starts with `ntn_` or `secret_`).
2. Open each of the three databases below → **•••** menu → **Connections** → add your integration so it can read/write them.

### 2. Create the three databases

Property names must match **exactly** (they're case- and punctuation-sensitive — note the en-dash `–` in "Start–End").

**Projects** database

| Property | Type |
|---|---|
| `Project name` | Title |
| `Status` | Status |
| `Priority` | Select |
| `Start date` | Date |
| `End date` | Date |
| `Client` | Text |

**Tasks** database

| Property | Type |
|---|---|
| `Action item` | Title |
| `Task Status` | Status |
| `Consulting Projects` | Relation → **Projects** database |
| `Business` | Select |
| `Tracked?` | Select |
| `Task type` | Multi-select |
| `Deadline` | Date |

**Time Entries** database (the app writes rows here when you stop a timer)

| Property | Type |
|---|---|
| `Entry` | Title |
| `Start–End` | Date (with end date enabled) |
| `Hours` | Number |
| `Task` | Relation → **Tasks** database |
| `Projects / Clients` | Relation → **Projects** database |
| `Source` | Select (the app uses the value `Manual`) |
| `Notes` | Text |

> Tip: `Task Status` values the app writes include `Not started`. Add whatever status options you use in Notion.

### 3. Get each database ID

Open a database as a full page in Notion → **Share/Copy link**. The ID is the 32-character hex string in the URL:

```
https://www.notion.so/workspace/<32-char-database-id>?v=...
```

### 4. Connect the app

Open the app → **⚙️ Settings** → paste your **token** and the three **database IDs** → **Save** → **Sync Now**. On the Apple Watch app, open **Settings** (gear icon) and enter the same values.

## Building

### macOS app

Requires Swift (bundled with Xcode or the Command Line Tools) and macOS 14 (Sonoma) or later.

```bash
git clone https://github.com/knowledgecastle/mac-time-tracker-notion.git
cd mac-time-tracker-notion/TimeTracker
swift build -c release
```

Or open `TimeTracker/TimeTracker.xcodeproj` in Xcode and run the **TimeTracker** scheme.

### Apple Watch app

Open `TimeTrackerWatch/TimeTrackerWatch.xcodeproj` in Xcode, select the **TimeTrackerWatch** scheme and a watch (or simulator), and run. See [`TimeTrackerWatch/README.md`](TimeTrackerWatch/README.md).

## Privacy

The app stores your Notion token and database IDs locally in macOS/watchOS `UserDefaults`, and talks directly to the Notion API from your device. Nothing is sent anywhere else. There is no analytics or telemetry.

## License

[MIT](LICENSE) — do whatever you like; attribution appreciated.
