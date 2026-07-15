import Foundation
import Combine
import UserNotifications
import SwiftUI

class AppStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var tasks: [Task] = []
    @Published var entries: [TimeEntry] = []
    @Published var completions: [TaskCompletion] = []
    @Published var activeEntry: TimeEntry?
    @Published var tick: Date = Date()
    @Published var isSyncing = false
    @Published var syncError: String? = nil
    @Published var lastSyncDate: Date? = nil
    @Published var xpPopBurst: Int? = nil  // triggers XP animation

    /// How often to remind the user that a timer is still running.
    @Published var reminderInterval: ReminderInterval = .off

    /// Light / Dark / System appearance.
    @Published var appTheme: AppTheme = .system

    private var timer: AnyCancellable?
    private var syncTimer: AnyCancellable?
    private let saveKey = "timetracker_data"
    private let reminderKey = "timetracker_reminder_interval"
    private let themeKey = "timetracker_theme"

    init() {
        load()
        loadReminderInterval()
        if let raw = UserDefaults.standard.string(forKey: themeKey), let t = AppTheme(rawValue: raw) {
            appTheme = t
        }
        startTick()
        startAutoSync()
    }

    func setAppTheme(_ theme: AppTheme) {
        appTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
    }

    // MARK: - Auto-sync (near real-time pull from Notion)

    private func startAutoSync() {
        // Pull immediately on launch, then poll so Notion changes show up on their own.
        if NotionService.shared.hasToken {
            _Concurrency.Task { await syncWithNotion() }
        }
        syncTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, NotionService.shared.hasToken, !self.isSyncing else { return }
                _Concurrency.Task { await self.syncWithNotion() }
            }
    }

    // MARK: - Timer tick

    private func startTick() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                if self?.activeEntry != nil { self?.tick = date }
            }
    }

    // MARK: - Projects

    func addProject(name: String, color: String) {
        // Projects created in the app stay local — never pushed to Notion.
        let p = Project(name: name, color: color)
        projects.append(p)
        save()
    }

    func deleteProject(_ project: Project) {
        // Archive the project (and its Notion tasks) in Notion so the deletion syncs.
        let notionTaskPages = tasks.filter { $0.projectId == project.id }.compactMap(\.notionPageId)
        if let projectPage = project.notionPageId {
            _Concurrency.Task {
                try? await NotionService.shared.archivePage(pageId: projectPage)
                for tp in notionTaskPages { try? await NotionService.shared.archivePage(pageId: tp) }
            }
        }

        let tids = tasks.filter { $0.projectId == project.id }.map(\.id)
        entries.removeAll { tids.contains($0.taskId) }
        tasks.removeAll { $0.projectId == project.id }
        projects.removeAll { $0.id == project.id }
        if let a = activeEntry, tids.contains(a.taskId) { activeEntry = nil }
        save()
    }

    func toggleProjectDone(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].isDone.toggle()
            
            // If marking as done, stop tracking if currently tracking a task from this project
            if projects[index].isDone, let entry = activeEntry, entry.projectId == project.id {
                stopTracking()
            }
            save()
        }
    }

    // MARK: - Tasks

    func addTask(name: String, projectId: UUID) {
        let t = Task(name: name, projectId: projectId)
        tasks.append(t)
        save()

        // Push the task to Notion ONLY when its parent project is a Notion project.
        // Tasks under local projects stay local.
        guard let proj = project(for: projectId), let projectPageId = proj.notionPageId else { return }
        let taskId = t.id
        _Concurrency.Task { [weak self] in
            guard let pageId = try? await NotionService.shared.createTask(name: name, projectPageId: projectPageId) else { return }
            await MainActor.run {
                guard let self else { return }
                if let idx = self.tasks.firstIndex(where: { $0.id == taskId }) {
                    self.tasks[idx].notionPageId = pageId
                    if self.tasks[idx].status.isEmpty { self.tasks[idx].status = "Not started" }
                    self.save()
                }
            }
        }
    }

    func deleteTask(_ task: Task) {
        if let pid = task.notionPageId {
            _Concurrency.Task { try? await NotionService.shared.archivePage(pageId: pid) }
        }
        entries.removeAll { $0.taskId == task.id }
        if activeEntry?.taskId == task.id { activeEntry = nil }
        tasks.removeAll { $0.id == task.id }
        save()
    }

    // MARK: - Editing (syncs to Notion)

    private func mutateTask(_ id: UUID, _ change: (inout Task) -> Void, push: @escaping (String) async -> Void) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[i])
        save()
        if let pid = tasks[i].notionPageId { _Concurrency.Task { await push(pid) } }
    }
    private func mutateProject(_ id: UUID, _ change: (inout Project) -> Void, push: @escaping (String) async -> Void) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        change(&projects[i])
        save()
        if let pid = projects[i].notionPageId { _Concurrency.Task { await push(pid) } }
    }

    func renameTask(_ task: Task, to name: String) {
        mutateTask(task.id, { $0.name = name }) { try? await NotionService.shared.renameTask(pageId: $0, name: name) }
    }
    func setTaskStatus(_ task: Task, _ status: String) {
        let closed = Task.closedStatuses.contains(status)
        if closed, activeEntry?.taskId == task.id { stopTracking() }
        mutateTask(task.id, { $0.status = status; $0.isDone = closed }) { try? await NotionService.shared.setTaskStatus(pageId: $0, status: status) }
    }
    func setTaskBusiness(_ task: Task, _ value: String) {
        mutateTask(task.id, { $0.business = value }) { try? await NotionService.shared.setTaskBusiness(pageId: $0, value: value.isEmpty ? nil : value) }
    }
    func setTaskType(_ task: Task, _ values: [String]) {
        mutateTask(task.id, { $0.taskType = values }) { try? await NotionService.shared.setTaskType(pageId: $0, values: values) }
    }
    func setTaskDeadline(_ task: Task, _ date: Date?) {
        mutateTask(task.id, { $0.deadline = date }) { try? await NotionService.shared.setTaskDeadline(pageId: $0, date: date) }
    }
    func reassignTask(_ task: Task, toProject projectId: UUID) {
        let targetPage = project(for: projectId)?.notionPageId
        mutateTask(task.id, { $0.projectId = projectId }) { taskPage in
            if let targetPage { try? await NotionService.shared.setTaskProject(pageId: taskPage, projectPageId: targetPage) }
        }
    }

    func renameProject(_ project: Project, to name: String) {
        mutateProject(project.id, { $0.name = name }) { try? await NotionService.shared.renameProject(pageId: $0, name: name) }
    }
    func setProjectStatus(_ project: Project, _ status: String) {
        mutateProject(project.id, { $0.status = status }) { try? await NotionService.shared.setProjectStatus(pageId: $0, status: status) }
    }
    func setProjectPriority(_ project: Project, _ value: String) {
        mutateProject(project.id, { $0.priority = value }) { try? await NotionService.shared.setProjectPriority(pageId: $0, value: value.isEmpty ? nil : value) }
    }
    func setProjectDates(_ project: Project, start: Date?, end: Date?) {
        mutateProject(project.id, { $0.startDate = start; $0.endDate = end }) { try? await NotionService.shared.setProjectDates(pageId: $0, start: start, end: end) }
    }
    func setProjectClient(_ project: Project, _ text: String) {
        mutateProject(project.id, { $0.client = text }) { try? await NotionService.shared.setProjectClient(pageId: $0, text: text) }
    }

    /// Edit a logged time entry's start/end/note; recomputes duration and syncs to Notion.
    func updateEntry(_ entry: TimeEntry, start: Date, end: Date, note: String) {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[i].startTime = start
        entries[i].endTime = end
        entries[i].note = note
        save()
        if let pid = entries[i].notionPageId {
            let hours = end.timeIntervalSince(start) / 3600
            _Concurrency.Task { try? await NotionService.shared.updateTimeEntry(pageId: pid, start: start, end: end, hours: hours, note: note) }
        }
    }

    func toggleTaskDone(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isDone.toggle()
            let nowDone = tasks[index].isDone
            let notionPageId = tasks[index].notionPageId

            // If marking as done, stop tracking if currently tracking this task
            if nowDone, activeEntry?.taskId == task.id {
                stopTracking()
            }
            save()

            // Push the status change back to Notion.
            if let notionPageId {
                _Concurrency.Task {
                    try? await NotionService.shared.updateTaskStatus(pageId: notionPageId, done: nowDone)
                }
            }
        }
    }

    // MARK: - Tracking

    func startTracking(task: Task) {
        // Prevent tracking if task or its project is marked as done
        if task.isDone {
            return
        }
        if let proj = project(for: task.projectId), proj.isDone {
            return
        }
        
        stopTracking()
        let entry = TimeEntry(taskId: task.id, projectId: task.projectId, startTime: Date())
        activeEntry = entry

        // Start reminding the user so they don't forget the timer is running.
        NotificationManager.shared.scheduleActiveReminder(taskName: task.name, interval: reminderInterval)
    }

    func stopTracking() {
        guard var entry = activeEntry else {
            NotificationManager.shared.cancelActiveReminder()
            return
        }
        NotificationManager.shared.cancelActiveReminder()
        entry.endTime = Date()
        entries.append(entry)
        activeEntry = nil
        save()

        // Push a Time Entry row to Notion if this task came from Notion.
        guard let trackedTask = task(for: entry.taskId),
              let taskPageId = trackedTask.notionPageId else { return }

        let entryId = entry.id
        let start = entry.startTime
        let end = entry.endTime ?? Date()
        let hours = entry.duration / 3600.0
        let taskName = trackedTask.name
        let note = entry.note
        let projectPageId = project(for: entry.projectId)?.notionPageId

        _Concurrency.Task { [weak self] in
            guard let pageId = try? await NotionService.shared.createTimeEntry(
                taskPageId: taskPageId,
                projectPageId: projectPageId,
                taskName: taskName,
                start: start,
                end: end,
                hours: hours,
                note: note
            ) else { return }

            await MainActor.run {
                guard let self else { return }
                if let idx = self.entries.firstIndex(where: { $0.id == entryId }) {
                    self.entries[idx].notionPageId = pageId
                    self.save()
                }
            }
        }
    }

    func deleteEntry(_ entry: TimeEntry) {
        if let pid = entry.notionPageId {
            _Concurrency.Task { try? await NotionService.shared.archivePage(pageId: pid) }
        }
        entries.removeAll { $0.id == entry.id }
        save()
    }

    // MARK: - Reminders

    private func loadReminderInterval() {
        if let raw = UserDefaults.standard.string(forKey: reminderKey),
           let interval = ReminderInterval(rawValue: raw) {
            reminderInterval = interval
        }
    }

    /// Update how often the "timer still running" reminder fires and persist it.
    /// If a timer is currently running, the pending reminder is rescheduled immediately.
    func setReminderInterval(_ interval: ReminderInterval) {
        reminderInterval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: reminderKey)

        if let entry = activeEntry, let task = task(for: entry.taskId) {
            NotificationManager.shared.scheduleActiveReminder(taskName: task.name, interval: interval)
        }
    }

    // MARK: - Notion Sync

    @MainActor
    func syncWithNotion() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let result = try await NotionService.shared.sync()
            reconcile(with: result)
            lastSyncDate = Date()
            save()
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// Merge Notion data into the local model *by page id*, updating existing
    /// records in place so their local UUIDs stay stable. This keeps a running
    /// timer and all historical time entries valid across repeated auto-syncs.
    private func reconcile(with result: NotionSyncResult) {
        // Projects: keep local-only ones, update/add Notion ones, drop Notion
        // projects that no longer come back (closed/removed in Notion).
        var newProjects = projects.filter { !$0.isFromNotion }
        for np in result.projects {
            var p = projects.first(where: { $0.notionPageId == np.pageId }) ?? {
                var new = Project(name: np.name, color: np.color)
                new.notionPageId = np.pageId
                return new
            }()
            p.name = np.name
            p.color = np.color
            p.status = np.status
            p.priority = np.priority
            p.startDate = np.startDate
            p.endDate = np.endDate
            p.client = np.client
            newProjects.append(p)
        }
        projects = newProjects.sorted { $0.name < $1.name }

        // Build page-id -> local project UUID map from the reconciled projects.
        var projectByPage: [String: UUID] = [:]
        for p in projects { if let pid = p.notionPageId { projectByPage[pid] = p.id } }

        // Tasks: same approach. Never drop the task that's currently being tracked.
        let activeTaskId = activeEntry?.taskId
        var newTasks = tasks.filter { !$0.isFromNotion }
        for nt in result.tasks {
            guard let localProjectId = projectByPage[nt.projectPageId] else { continue }
            var t = tasks.first(where: { $0.notionPageId == nt.pageId }) ?? {
                var new = Task(name: nt.name, projectId: localProjectId)
                new.notionPageId = nt.pageId
                return new
            }()
            t.name = nt.name
            t.projectId = localProjectId
            t.status = nt.status
            t.business = nt.business
            t.tracked = nt.tracked
            t.taskType = nt.taskType
            t.deadline = nt.deadline
            t.isDone = Task.closedStatuses.contains(nt.status)  // keep checkmark in sync with Notion
            newTasks.append(t)
        }
        // Preserve the actively-tracked task even if Notion filtered it out this cycle.
        if let activeTaskId, !newTasks.contains(where: { $0.id == activeTaskId }),
           let stillTracked = tasks.first(where: { $0.id == activeTaskId }) {
            newTasks.append(stillTracked)
        }
        tasks = newTasks
    }

    // MARK: - XP & Levels

    var totalXP: Int {
        entries.reduce(0) { $0 + $1.xpEarned }
        + completions.reduce(0) { $0 + $1.bonusXP }
    }

    var currentLevel: XPLevel { XPLevel.forXP(totalXP) }

    var xpIntoCurrentLevel: Int {
        totalXP - currentLevel.totalXPRequired
    }

    var xpToNextLevel: Int {
        guard let next = XPLevel.next(after: currentLevel) else { return 1 }
        return next.totalXPRequired - currentLevel.totalXPRequired
    }

    var levelProgress: Double {
        Double(xpIntoCurrentLevel) / Double(max(1, xpToNextLevel))
    }

    func todayXP() -> Int {
        let todayEntries = entries.filter { Calendar.current.isDateInToday($0.startTime) }
        let todayCompletions = completions.filter { Calendar.current.isDateInToday($0.completedAt) }
        return todayEntries.reduce(0) { $0 + $1.xpEarned }
             + todayCompletions.reduce(0) { $0 + $1.bonusXP }
    }

    func isTaskCompleted(_ task: Task) -> Bool {
        completions.contains { $0.taskId == task.id && Calendar.current.isDateInToday($0.completedAt) }
    }

    func markTaskComplete(_ task: Task) {
        guard !isTaskCompleted(task) else { return }
        let completion = TaskCompletion(taskId: task.id, projectId: task.projectId, completedAt: Date())
        completions.append(completion)
        xpPopBurst = completion.bonusXP
        if activeEntry?.taskId == task.id { stopTracking() }
        save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.xpPopBurst = nil }
    }

    func todayEntries() -> [TimeEntry] {
        entries.filter { Calendar.current.isDateInToday($0.startTime) }
            .sorted { $0.startTime > $1.startTime }
    }

    func todayTaskSummary() -> [(task: Task, project: Project?, duration: TimeInterval, xp: Int, completed: Bool)] {
        let today = todayEntries()
        let byTask = Dictionary(grouping: today) { $0.taskId }
        return byTask.compactMap { taskId, taskEntries -> (Task, Project?, TimeInterval, Int, Bool)? in
            guard let t = task(for: taskId) else { return nil }
            let dur = taskEntries.reduce(0) { $0 + $1.duration }
            let xp = taskEntries.reduce(0) { $0 + $1.xpEarned }
            return (t, project(for: t.projectId), dur, xp, isTaskCompleted(t))
        }.sorted { $0.2 > $1.2 }
    }

    // MARK: - Helpers

    func project(for id: UUID) -> Project? { projects.first { $0.id == id } }
    func task(for id: UUID) -> Task? { tasks.first { $0.id == id } }

    /// The most recently tracked tasks (newest first), for quick restart from the
    /// menu bar. Only returns tasks that can still be started — i.e. the task and
    /// its project both still exist and aren't marked done.
    func recentlyTrackedTasks(limit: Int = 5) -> [Task] {
        var seen = Set<UUID>()
        var result: [Task] = []
        for entry in entries.sorted(by: { $0.startTime > $1.startTime }) {
            guard !seen.contains(entry.taskId) else { continue }
            seen.insert(entry.taskId)
            guard let task = task(for: entry.taskId), !task.isDone, !task.isClosed else { continue }
            if let proj = project(for: task.projectId), (proj.isDone || proj.isClosed) { continue }
            result.append(task)
            if result.count >= limit { break }
        }
        return result
    }

    func entries(for projectId: UUID) -> [TimeEntry] {
        entries.filter { $0.projectId == projectId }.sorted { $0.startTime > $1.startTime }
    }

    func totalDuration(for projectId: UUID) -> TimeInterval {
        entries(for: projectId).reduce(0) { $0 + $1.duration }
    }

    func totalDuration(for task: Task) -> TimeInterval {
        entries.filter { $0.taskId == task.id }.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Persistence

    private struct SaveData: Codable {
        var projects: [Project]
        var tasks: [Task]
        var entries: [TimeEntry]
        var completions: [TaskCompletion]
        var lastSyncDate: Date?
    }

    func save() {
        let data = SaveData(projects: projects, tasks: tasks, entries: entries, completions: completions, lastSyncDate: lastSyncDate)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode(SaveData.self, from: data) else { return }
        projects = decoded.projects
        tasks = decoded.tasks
        entries = decoded.entries
        completions = decoded.completions
        lastSyncDate = decoded.lastSyncDate
    }
}

// MARK: - Appearance

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Reminder Interval

enum ReminderInterval: String, CaseIterable, Identifiable {
    case off
    case thirtyMinutes
    case oneHour

    var id: String { rawValue }

    /// Trigger interval in seconds, or nil when reminders are disabled.
    var seconds: TimeInterval? {
        switch self {
        case .off:           return nil
        case .thirtyMinutes: return 30 * 60
        case .oneHour:       return 60 * 60
        }
    }

    var label: String {
        switch self {
        case .off:           return "Off"
        case .thirtyMinutes: return "Every 30 minutes"
        case .oneHour:       return "Every hour"
        }
    }
}

// MARK: - Notifications

/// Handles the "your timer is still running" reminders in the macOS Notification Center.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let reminderID = "timetracker.active.reminder"

    override init() {
        super.init()
        center.delegate = self
    }

    /// Ask the user for permission to show notifications. Safe to call on every launch.
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedule a repeating reminder while `taskName` is being tracked.
    /// Any previously scheduled reminder is replaced. Does nothing when the interval is `.off`.
    func scheduleActiveReminder(taskName: String, interval: ReminderInterval) {
        cancelActiveReminder()
        guard let seconds = interval.seconds else { return }

        let content = UNMutableNotificationContent()
        content.title = "Timer still running"
        content.body = "You're still tracking “\(taskName)”. Don't forget to stop it when you're done."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
        let request = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(request)
    }

    /// Remove the pending running-timer reminder.
    func cancelActiveReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    // Show the banner even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
