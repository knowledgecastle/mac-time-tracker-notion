import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab: Tab = .game
    @State private var showingSettings = false

    enum Tab { case game, timer, projects, tasks, log, report }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Workspace header
                HStack(spacing: 8) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                        .resizable()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Quest Tracker")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NTheme.text)
                        Text("Level \(store.currentLevel.level) · \(store.currentLevel.title)")
                            .font(.system(size: 10))
                            .foregroundStyle(NTheme.textTertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Navigation
                VStack(spacing: 1) {
                    NotionNavItem(label: "Quest",    icon: "target",              tab: .game,     selected: $selectedTab)
                    NotionNavItem(label: "Timer",    icon: "timer",               tab: .timer,    selected: $selectedTab)
                    NotionNavItem(label: "Projects", icon: "folder",              tab: .projects, selected: $selectedTab)
                    NotionNavItem(label: "Tasks",    icon: "checklist",           tab: .tasks,    selected: $selectedTab)
                    NotionNavItem(label: "Log",      icon: "list.bullet",         tab: .log,      selected: $selectedTab)
                    NotionNavItem(label: "Report",   icon: "chart.bar.xaxis",     tab: .report,   selected: $selectedTab)
                }
                .padding(.horizontal, 8)

                Spacer()

                // Bottom: sync status + settings
                HStack(spacing: 8) {
                    if store.isSyncing {
                        ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                        Text("Syncing…").font(.system(size: 11)).foregroundStyle(NTheme.textTertiary)
                    } else if store.lastSyncDate != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(NTheme.statusDot("Done"))
                        Text("Synced").font(.system(size: 11)).foregroundStyle(NTheme.textTertiary)
                    }
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundStyle(NTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .frame(width: 210)
            .background(NTheme.sidebar)
            .overlay(alignment: .trailing) {
                Rectangle().fill(NTheme.divider).frame(width: 1)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(store)
            }

            // Main content area
            VStack(spacing: 0) {
                if let entry = store.activeEntry,
                   let task = store.task(for: entry.taskId),
                   let project = store.project(for: entry.projectId) {
                    ActiveTimerBanner(entry: entry, task: task, project: project)
                }

                Group {
                    switch selectedTab {
                    case .game:     GameView()
                    case .timer:    TimerView()
                    case .projects: ProjectsView()
                    case .tasks:    TasksView()
                    case .log:      LogView()
                    case .report:   DailyReportView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(NTheme.bg)
        }
        .preferredColorScheme(store.appTheme.colorScheme)
    }
}

/// A horizontal Notion-style sidebar nav row.
struct NotionNavItem: View {
    let label: String
    let icon: String
    let tab: ContentView.Tab
    @Binding var selected: ContentView.Tab
    @State private var hover = false

    var isSelected: Bool { selected == tab }

    var body: some View {
        Button { selected = tab } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? NTheme.text : NTheme.textSecondary)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? NTheme.text : NTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isSelected ? NTheme.hoverStrong : (hover ? NTheme.hover : Color.clear),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Menu Bar

/// The text/icon shown in the macOS menu bar. Displays the live elapsed time
/// while a timer is running, otherwise a plain timer icon.
struct MenuBarLabel: View {
    @ObservedObject var store: AppStore

    var body: some View {
        // Always keep an Image at the root so the status item never gets torn
        // down when switching between running/idle (a known MenuBarExtra pitfall).
        HStack(spacing: 4) {
            Image(systemName: store.activeEntry != nil ? "timer.circle.fill" : "timer")
            if let entry = store.activeEntry {
                // `store.tick` publishes every second while tracking, so this refreshes live.
                Text(entry.duration.formatted)
            }
        }
    }
}

/// The popover shown when clicking the menu bar item: current timer, a task
/// picker to start/switch, and quick actions.
struct MenuBarView: View {
    @EnvironmentObject var store: AppStore

    private var runningTask: Task? {
        guard let entry = store.activeEntry else { return nil }
        return store.task(for: entry.taskId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if let entry = store.activeEntry, let task = runningTask {
                runningSection(entry: entry, task: task)
                Divider()
            }

            recentSection

            taskPicker

            Divider()

            footer
        }
        .frame(width: 300)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .foregroundStyle(Color.accentColor)
            Text("Time Tracker")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("LV \(store.currentLevel.level)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.projectColor(named: store.currentLevel.color))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Running timer

    private func runningSection(entry: TimeEntry, task: Task) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if let project = store.project(for: entry.projectId) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.projectColor(named: project.color))
                            .frame(width: 7, height: 7)
                        Text(project.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(entry.duration.formatted)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .id(store.tick)

            Button {
                store.stopTracking()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Recent tasks (quick restart)

    private var recentTasks: [Task] {
        // Exclude whatever is currently running — it already shows above.
        store.recentlyTrackedTasks(limit: 5)
            .filter { $0.id != store.activeEntry?.taskId }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !recentTasks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("RECENT")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                ForEach(recentTasks) { task in
                    MenuTaskRow(
                        task: task,
                        color: store.project(for: task.projectId)?.color ?? "indigo",
                        isRunning: store.activeEntry?.taskId == task.id
                    ) {
                        store.startTracking(task: task)
                    }
                }
            }
            .padding(.bottom, 4)

            Divider()
        }
    }

    // MARK: Task picker

    private var pickableProjects: [Project] {
        store.projects.filter { !$0.isDone && !$0.isClosed }.sorted { $0.name < $1.name }
    }

    private func pickableTasks(for project: Project) -> [Task] {
        store.tasks
            .filter { $0.projectId == project.id && !$0.isDone && !$0.isClosed }
            .sorted { $0.name < $1.name }
    }

    private var taskPicker: some View {
        Group {
            if pickableProjects.allSatisfy({ pickableTasks(for: $0).isEmpty }) {
                Text("No active tasks. Add some in the app.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(pickableProjects) { project in
                            let tasks = pickableTasks(for: project)
                            if !tasks.isEmpty {
                                Text(project.name.uppercased())
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)

                                ForEach(tasks) { task in
                                    MenuTaskRow(
                                        task: task,
                                        color: project.color,
                                        isRunning: store.activeEntry?.taskId == task.id
                                    ) {
                                        if store.activeEntry?.taskId == task.id {
                                            store.stopTracking()
                                        } else {
                                            store.startTracking(task: task)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: 280)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                Label("Open Time Tracker", systemImage: "macwindow")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 4)
    }
}

/// A single tappable task row inside the menu bar popover.
struct MenuTaskRow: View {
    let task: Task
    let color: String
    let isRunning: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(isRunning ? .red : Color.projectColor(named: color))
                Text(task.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(hovering ? Color.accentColor.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
