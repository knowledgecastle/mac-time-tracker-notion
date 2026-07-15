import SwiftUI

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var store: WatchStore
    @State private var showingSettings = false

    private var isConfigured: Bool { NotionService.shared.isConfigured }

    var body: some View {
        NavigationStack {
            List {
                if !isConfigured {
                    Section {
                        Button { showingSettings = true } label: {
                            Label("Connect to Notion", systemImage: "link")
                        }
                        Text("Add your Notion token and database IDs in Settings to get started.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                if let entry = store.activeEntry, let task = store.runningTask {
                    Section {
                        ActiveTimerRow(entry: entry, task: task)
                    }
                }

                Section("Projects") {
                    if store.activeProjects.isEmpty {
                        Text(store.isSyncing ? "Syncing…" : "No projects yet")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ForEach(store.activeProjects) { project in
                            NavigationLink(value: project) { ProjectRow(project: project) }
                        }
                    }
                }
            }
            .navigationTitle("Time Tracker")
            .navigationDestination(for: Project.self) { project in
                TaskListView(project: project)
            }
            .sheet(isPresented: $showingSettings) {
                WatchSettingsView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { _Concurrency.Task { await store.sync() } } label: {
                        if store.isSyncing { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(store.isSyncing)
                }
            }
        }
    }
}

// MARK: - Settings

struct WatchSettingsView: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) private var dismiss

    @State private var token = NotionService.shared.token
    @State private var projectsDB = NotionService.shared.projectsDBId
    @State private var tasksDB = NotionService.shared.tasksDBId
    @State private var timeEntriesDB = NotionService.shared.timeEntriesDBId

    var body: some View {
        NavigationStack {
            Form {
                Section("Notion token") {
                    TextField("ntn_…", text: $token)
                }
                Section("Database IDs") {
                    TextField("Projects DB", text: $projectsDB)
                    TextField("Tasks DB", text: $tasksDB)
                    TextField("Time Entries DB", text: $timeEntriesDB)
                }
                Section {
                    Text("Tip: it's far easier to enter these by dictation, or set them on the paired iPhone. See the README for the required database property names.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Section {
                    Button("Save") {
                        let ns = NotionService.shared
                        ns.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        ns.projectsDBId = projectsDB.trimmingCharacters(in: .whitespacesAndNewlines)
                        ns.tasksDBId = tasksDB.trimmingCharacters(in: .whitespacesAndNewlines)
                        ns.timeEntriesDBId = timeEntriesDB.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                        _Concurrency.Task { await store.sync() }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Active timer

struct ActiveTimerRow: View {
    @EnvironmentObject var store: WatchStore
    let entry: TimeEntry
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("TRACKING").font(.system(size: 11, weight: .semibold)).foregroundStyle(.red)
                Spacer()
            }
            Text(task.name).font(.headline).lineLimit(2)
            Text(entry.duration.clock)
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .id(store.tick)
            Button(role: .destructive) { store.stopTracking() } label: {
                Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Project row

struct ProjectRow: View {
    @EnvironmentObject var store: WatchStore
    let project: Project

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.project(project.color)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name).font(.body).lineLimit(1)
                let count = store.tasks(in: project).count
                Text("\(count) task\(count == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Task list

struct TaskListView: View {
    @EnvironmentObject var store: WatchStore
    let project: Project

    private var tasks: [Task] { store.tasks(in: project) }

    var body: some View {
        List {
            if tasks.isEmpty {
                Text("No tasks").font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                }
            }
        }
        .navigationTitle(project.name)
    }
}

struct TaskRow: View {
    @EnvironmentObject var store: WatchStore
    let task: Task

    private var isRunning: Bool { store.activeEntry?.taskId == task.id }

    var body: some View {
        Button { store.toggle(task) } label: {
            HStack(spacing: 10) {
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle")
                    .font(.title3)
                    .foregroundStyle(isRunning ? .red : .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name).font(.body).lineLimit(2).multilineTextAlignment(.leading)
                    if !task.status.isEmpty {
                        Text(task.status).font(.caption2).foregroundStyle(Color.status(task.status))
                    }
                }
                Spacer()
                if isRunning, let entry = store.activeEntry {
                    Text(entry.duration.clock)
                        .font(.caption.monospacedDigit()).foregroundStyle(.red)
                        .id(store.tick)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
