import Foundation
import Combine
import SwiftUI

@MainActor
final class WatchStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var tasks: [Task] = []
    @Published var activeEntry: TimeEntry?
    @Published var entries: [TimeEntry] = []
    @Published var tick = Date()
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var lastSync: Date?

    private var timer: AnyCancellable?
    private let saveKey = "watch_timetracker_data"

    init() {
        load()
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] date in if self?.activeEntry != nil { self?.tick = date } }
        _Concurrency.Task { await sync() }
    }

    // MARK: - Lookups

    func project(for id: UUID) -> Project? { projects.first { $0.id == id } }
    func task(for id: UUID) -> Task? { tasks.first { $0.id == id } }

    /// Active (trackable) projects, sorted by name.
    var activeProjects: [Project] {
        projects.filter { !$0.isClosed }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    func tasks(in project: Project) -> [Task] {
        tasks.filter { $0.projectId == project.id && !$0.isClosed }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    var runningTask: Task? { activeEntry.flatMap { task(for: $0.taskId) } }

    // MARK: - Tracking

    func startTracking(_ task: Task) {
        stopTracking()
        activeEntry = TimeEntry(taskId: task.id, projectId: task.projectId, startTime: Date())
    }

    func stopTracking() {
        guard var entry = activeEntry else { return }
        entry.endTime = Date()
        entries.append(entry)
        activeEntry = nil
        save()

        guard let t = task(for: entry.taskId), let taskPage = t.notionPageId else { return }
        let projPage = project(for: entry.projectId)?.notionPageId
        let start = entry.startTime, end = entry.endTime ?? Date()
        let hours = entry.duration / 3600, name = t.name
        _Concurrency.Task {
            try? await NotionService.shared.createTimeEntry(
                taskPageId: taskPage, projectPageId: projPage, taskName: name,
                start: start, end: end, hours: hours)
        }
    }

    func toggle(_ task: Task) {
        if activeEntry?.taskId == task.id { stopTracking() } else { startTracking(task) }
    }

    // MARK: - Sync

    func sync() async {
        guard !isSyncing, NotionService.shared.hasToken else { return }
        isSyncing = true; syncError = nil
        defer { isSyncing = false }
        do {
            let result = try await NotionService.shared.sync()
            reconcile(result)
            lastSync = Date()
            save()
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func reconcile(_ result: NotionSyncResult) {
        var newProjects: [Project] = []
        for np in result.projects {
            var p = projects.first(where: { $0.notionPageId == np.pageId }) ?? {
                var new = Project(name: np.name); new.notionPageId = np.pageId; return new
            }()
            p.name = np.name; p.status = np.status; p.color = np.color
            newProjects.append(p)
        }
        projects = newProjects.sorted { $0.name < $1.name }

        var byPage: [String: UUID] = [:]
        for p in projects { if let pid = p.notionPageId { byPage[pid] = p.id } }

        let activeId = activeEntry?.taskId
        var newTasks: [Task] = []
        for nt in result.tasks {
            guard let localProj = byPage[nt.projectPageId] else { continue }
            var t = tasks.first(where: { $0.notionPageId == nt.pageId }) ?? {
                var new = Task(name: nt.name, projectId: localProj); new.notionPageId = nt.pageId; return new
            }()
            t.name = nt.name; t.projectId = localProj; t.status = nt.status
            newTasks.append(t)
        }
        if let activeId, !newTasks.contains(where: { $0.id == activeId }),
           let kept = tasks.first(where: { $0.id == activeId }) { newTasks.append(kept) }
        tasks = newTasks
    }

    // MARK: - Persistence

    private struct SaveData: Codable {
        var projects: [Project]; var tasks: [Task]; var entries: [TimeEntry]; var activeEntry: TimeEntry?
    }
    private func save() {
        let d = SaveData(projects: projects, tasks: tasks, entries: entries, activeEntry: activeEntry)
        if let data = try? JSONEncoder().encode(d) { UserDefaults.standard.set(data, forKey: saveKey) }
    }
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let d = try? JSONDecoder().decode(SaveData.self, from: data) else { return }
        projects = d.projects; tasks = d.tasks; entries = d.entries; activeEntry = d.activeEntry
    }
}

// MARK: - Colors

extension Color {
    static func project(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "teal": return .teal
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "indigo": return .indigo
        default: return .blue
        }
    }
    static func status(_ status: String) -> Color {
        switch status {
        case "In progress": return .blue
        case "Done", "Paid": return .green
        case "On-Hold", "Client Revision": return .orange
        case "Dead", "Cancelled": return .red
        default: return .gray
        }
    }
}
