# Time Tracker — Apple Watch

A standalone watchOS app that talks directly to the same Notion databases as the
macOS app. (A Watch app can't pair with a Mac, so it runs independently and hits
the Notion API over the network itself.)

## What it does

- Pulls your active Projects and Tasks from Notion.
- Tap a task to start a timer; tap again (or the Stop button) to stop it.
- Stopping a timer creates a row in your Notion **Time Entries** database
  (linked to the Task + Project, with start/end and hours) — same as the Mac app.

## Run it

1. Open `TimeTrackerWatch.xcodeproj` in Xcode.
2. Select the **TimeTrackerWatch** scheme + an Apple Watch simulator (or your watch).
3. Press Run.

## Configuration

The app ships with **no credentials**. On the watch, open **Settings** (the gear
icon, top-left) and enter your Notion integration **token** and the three
**database IDs**, then **Save**.

> Entering a long token on a watch is fiddly — using **dictation** in the text
> fields is much easier. The required database property names are documented in
> the [root README](../README.md#notion-setup).

Values are stored in the app's `UserDefaults` (keys: `notion_token`,
`notion_projects_db`, `notion_tasks_db`, `notion_time_entries_db`).

## Notes

- No app icon is bundled yet; add one in Assets before installing on a real watch.
- **Note:** the watch project was last verified to compile against the watchOS
  SDK, but is best treated as developer-oriented — build and run it from your own
  Xcode.
