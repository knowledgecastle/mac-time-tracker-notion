import SwiftUI

let kTaskStatusOrder = ["Not started", "In progress", "On-Hold", "Client Revision", "Done", "Cancelled"]
let kBusinessOrder = ["EBF", "Mabel", "Both / Shared"]
let kTaskTypeOrder = ["Investigation", "Process", "Build", "Automation", "Cleanup", "Modification"]

struct TimerView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTask: Task?
    @State private var filter = DBFilterState()

    // Trackable tasks: not done/closed, and under an active project.
    private var candidateTasks: [Task] {
        store.tasks.filter { t in
            guard !t.isDone, !t.isClosed else { return false }
            guard let p = store.project(for: t.projectId), !p.isDone, !p.isClosed else { return false }
            return true
        }
    }

    private var facets: [FilterFacet] {
        [FilterFacet(id: "Status", title: "Status",
                     options: orderedOptions(Set(candidateTasks.map(\.status).filter { !$0.isEmpty }), canonical: kTaskStatusOrder)),
         FilterFacet(id: "Business", title: "Business",
                     options: orderedOptions(Set(candidateTasks.map(\.business).filter { !$0.isEmpty }), canonical: kBusinessOrder)),
         FilterFacet(id: "Type", title: "Type",
                     options: orderedOptions(Set(candidateTasks.flatMap(\.taskType)), canonical: kTaskTypeOrder))]
    }

    private var hasActiveFilter: Bool { !filter.search.isEmpty || filter.activeFacetCount > 0 }

    // Get all active tasks with their project and time info
    private var activeTasks: [(task: Task, project: Project?, totalTime: TimeInterval)] {
        candidateTasks
            .filter { task in
                filter.passes(name: task.name, values: [
                    "Status": task.status.isEmpty ? [] : [task.status],
                    "Business": task.business.isEmpty ? [] : [task.business],
                    "Type": task.taskType
                ])
            }
            .compactMap { task -> (Task, Project?, TimeInterval)? in
                let project = store.project(for: task.projectId)
                return (task, project, store.totalDuration(for: task))
            }
            .sorted { $0.1?.name ?? "" < $1.1?.name ?? "" } // Sort by project name
    }
    
    private var runningTask: Task? {
        guard let entry = store.activeEntry else { return nil }
        return store.task(for: entry.taskId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Page title
            HStack(spacing: 10) {
                Text("⏱").font(.system(size: 22))
                Text("Timer").font(.system(size: 22, weight: .bold)).foregroundStyle(NTheme.text)
                Spacer()
                if runningTask != nil {
                    HStack(spacing: 5) {
                        Circle().fill(Color.red).frame(width: 7, height: 7)
                        Text("Running").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.red.opacity(0.9), in: Capsule())
                }
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10)

            HStack {
                FilterBar(facets: facets, state: $filter)
            }
            .padding(.horizontal, 24).padding(.bottom, 8)

            Rectangle().fill(NTheme.divider).frame(height: 1)

            // Tasks list
            ScrollView {
                if activeTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: hasActiveFilter ? "line.3.horizontal.decrease.circle" : "timer.square")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text(hasActiveFilter ? "No tasks match your filters" : "No active tasks")
                            .font(.system(size: 13, weight: .medium))
                        Text(hasActiveFilter ? "Try clearing a filter." : "Create tasks in the Projects tab, or sync from Notion.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if hasActiveFilter {
                            Button("Reset filters") { filter = DBFilterState() }
                                .font(.system(size: 12))
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // Group by project
                        ForEach(groupedByProject(), id: \.project.id) { group in
                            Section {
                                ForEach(group.tasks, id: \.task.id) { item in
                                    TimerTaskRow(
                                        task: item.task,
                                        project: item.project,
                                        totalTime: item.totalTime,
                                        isSelected: selectedTask?.id == item.task.id,
                                        isRunning: store.activeEntry?.taskId == item.task.id
                                    ) {
                                        selectedTask = item.task
                                    } onToggleTimer: {
                                        toggleTimer(for: item.task)
                                    }
                                    
                                    if item.task.id != group.tasks.last?.task.id {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            } header: {
                                ProjectHeader(project: group.project, taskCount: group.tasks.count)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private func groupedByProject() -> [(project: Project, tasks: [(task: Task, project: Project?, totalTime: TimeInterval)])] {
        let grouped = Dictionary(grouping: activeTasks) { $0.project?.id ?? UUID() }
        return grouped.compactMap { (projectId, tasks) -> (Project, [(Task, Project?, TimeInterval)])? in
            guard let project = tasks.first?.project else { return nil }
            return (project, tasks.sorted { $0.task.name < $1.task.name })
        }.sorted { $0.project.name < $1.project.name }
    }
    
    private func toggleTimer(for task: Task) {
        if store.activeEntry?.taskId == task.id {
            store.stopTracking()
        } else {
            store.startTracking(task: task)
        }
    }
}

struct ProjectHeader: View {
    let project: Project
    let taskCount: Int
    
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color.projectColor(named: project.color))
                .frame(width: 8, height: 8)
            Text(project.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NTheme.text)
            Text("\(taskCount)")
                .font(.system(size: 12))
                .foregroundStyle(NTheme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 7)
        .background(NTheme.bg)
    }
}

struct TimerTaskRow: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    let project: Project?
    let totalTime: TimeInterval
    let isSelected: Bool
    let isRunning: Bool
    let action: () -> Void
    let onToggleTimer: () -> Void
    
    private var elapsed: TimeInterval {
        isRunning ? (store.activeEntry?.duration ?? 0) : 0
    }

    @State private var hover = false
    private var accent: Color { Color.projectColor(named: project?.color ?? "indigo") }

    var body: some View {
        HStack(spacing: 11) {
            // Play/Stop button
            Button(action: onToggleTimer) {
                ZStack {
                    Circle()
                        .fill(isRunning ? Color.red : accent.opacity(0.14))
                        .frame(width: 30, height: 30)
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isRunning ? .white : accent)
                }
            }
            .buttonStyle(.plain)

            Text(task.name)
                .font(.system(size: 13))
                .foregroundStyle(NTheme.text)
                .lineLimit(1)

            StatusPill(status: task.status)

            Spacer(minLength: 8)

            if isRunning {
                Text(elapsed.shortFormatted)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 5))
                    .id(store.tick)
            } else if totalTime > 0 {
                Text(totalTime.shortFormatted)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(NTheme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(hover ? NTheme.hover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

// MARK: - Tasks tab

// Column widths for the Tasks table.
let kTColStatus: CGFloat = 132
let kTColDue: CGFloat = 96
let kTColBiz: CGFloat = 78
let kTColTime: CGFloat = 84

/// The Tasks database: every task grouped by project, Notion-table style, with
/// status, due date, business, filters, logged time, and start/stop tracking.
struct TasksView: View {
    @EnvironmentObject var store: AppStore
    @State private var filter = DBFilterState()
    @State private var didInitFilter = false
    @State private var collapsed: Set<UUID> = []
    @State private var peekTaskId: UUID?
    @State private var viewMode: DBViewMode = .table

    /// Tasks grouped by status, for the board view.
    private var statusGroups: [(status: String, tasks: [Task])] {
        let byStatus = Dictionary(grouping: filtered) { $0.status.isEmpty ? "No status" : $0.status }
        let order = kTaskStatusOrder + byStatus.keys.filter { !kTaskStatusOrder.contains($0) && $0 != "No status" }.sorted() + ["No status"]
        return order.compactMap { s in
            guard let ts = byStatus[s], !ts.isEmpty else { return nil }
            return (s, ts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    private var candidateTasks: [Task] {
        store.tasks.filter { store.project(for: $0.projectId) != nil }
    }

    private var statusOptions: [String] {
        orderedOptions(Set(candidateTasks.map(\.status).filter { !$0.isEmpty }), canonical: kTaskStatusOrder)
    }
    private var facets: [FilterFacet] {
        [FilterFacet(id: "Status", title: "Status", options: statusOptions),
         FilterFacet(id: "Business", title: "Business",
                     options: orderedOptions(Set(candidateTasks.map(\.business).filter { !$0.isEmpty }), canonical: kBusinessOrder)),
         FilterFacet(id: "Type", title: "Type",
                     options: orderedOptions(Set(candidateTasks.flatMap(\.taskType)), canonical: kTaskTypeOrder))]
    }

    private var filtered: [Task] {
        candidateTasks.filter { t in
            let project = store.project(for: t.projectId)
            let haystack = t.name + " " + (project?.name ?? "")
            return filter.passes(name: haystack, values: [
                "Status": t.status.isEmpty ? [] : [t.status],
                "Business": t.business.isEmpty ? [] : [t.business],
                "Type": t.taskType
            ])
        }
    }
    private var groups: [(project: Project, tasks: [Task])] {
        let byProject = Dictionary(grouping: filtered) { $0.projectId }
        return byProject.compactMap { pid, ts -> (Project, [Task])? in
            guard let p = store.project(for: pid) else { return nil }
            let sorted = ts.sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            return (p, sorted)
        }.sorted { $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending }
    }

    private var hasActiveFilter: Bool { !filter.search.isEmpty || filter.activeFacetCount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            // Page title
            HStack(spacing: 10) {
                Text("✅").font(.system(size: 22))
                Text("Tasks").font(.system(size: 22, weight: .bold)).foregroundStyle(NTheme.text)
                Spacer()
                Text("\(filtered.count) task\(filtered.count == 1 ? "" : "s")")
                    .font(.system(size: 12)).foregroundStyle(NTheme.textTertiary)
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10)

            // Toolbar
            HStack(spacing: 14) {
                ViewModeTabs(mode: $viewMode)
                FilterBar(facets: facets, state: $filter)
            }
            .padding(.horizontal, 24).padding(.bottom, 2)

            Rectangle().fill(NTheme.divider).frame(height: 1)

            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: hasActiveFilter ? "line.3.horizontal.decrease.circle" : "checklist")
                        .font(.system(size: 30)).foregroundStyle(NTheme.textTertiary)
                    Text(hasActiveFilter ? "No tasks match your filters" : "No tasks yet")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(NTheme.text)
                    if hasActiveFilter {
                        Button("Reset filters") { filter = DBFilterState() }
                            .font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(NTheme.blue)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 60)
                Spacer()
            } else if viewMode == .table {
                taskColumnHeader
                Rectangle().fill(NTheme.divider).frame(height: 1)
                taskTable
            } else {
                taskBoard
            }
        }
        .background(NTheme.bg)
        .overlay {
            PeekOverlay(isPresented: peekTaskId != nil, onClose: { peekTaskId = nil }) {
                if let id = peekTaskId, let task = store.task(for: id) {
                    TaskPeek(task: task, onClose: { peekTaskId = nil })
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: peekTaskId)
        .onAppear { applyDefaultFilterIfNeeded() }
        .onChange(of: store.tasks.count) { _, _ in applyDefaultFilterIfNeeded() }
    }

    private var taskTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groups, id: \.project.id) { group in
                    let doneCount = group.tasks.filter(\.isDone).count
                    GroupHeaderRow(
                        title: group.project.name,
                        count: group.tasks.count,
                        dotColor: Color.projectColor(named: group.project.color),
                        isExpanded: !collapsed.contains(group.project.id),
                        trailing: "\(doneCount)/\(group.tasks.count) done"
                    ) {
                        if collapsed.contains(group.project.id) { collapsed.remove(group.project.id) }
                        else { collapsed.insert(group.project.id) }
                    }
                    .padding(.horizontal, 24)

                    if !collapsed.contains(group.project.id) {
                        ForEach(group.tasks) { task in
                            NotionTaskRow(task: task, onOpen: { peekTaskId = task.id })
                            Rectangle().fill(NTheme.divider).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var taskBoard: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(statusGroups, id: \.status) { group in
                    BoardColumn(
                        title: group.status,
                        count: group.tasks.count,
                        dotColor: group.status == "No status" ? NTheme.textTertiary : NTheme.statusDot(group.status),
                        onDropId: group.status == "No status" ? nil : { droppedId in
                            if let uuid = UUID(uuidString: droppedId), let t = store.task(for: uuid), t.status != group.status {
                                store.setTaskStatus(t, group.status)
                            }
                        }
                    ) {
                        VStack(spacing: 8) {
                            ForEach(group.tasks) { task in
                                BoardCard(dragId: task.id.uuidString, onTap: { peekTaskId = task.id }) {
                                    TaskCardBody(task: task)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var taskColumnHeader: some View {
        HStack(spacing: 12) {
            PropertyHeader(icon: "textformat", title: "Task name").frame(maxWidth: .infinity, alignment: .leading)
            PropertyHeader(icon: "circle.dashed", title: "Status").frame(width: kTColStatus, alignment: .leading)
            PropertyHeader(icon: "calendar", title: "Due").frame(width: kTColDue, alignment: .leading)
            PropertyHeader(icon: "tag", title: "Business").frame(width: kTColBiz, alignment: .leading)
            PropertyHeader(icon: "clock", title: "Time").frame(width: kTColTime, alignment: .trailing)
        }
        .padding(.horizontal, 24).padding(.vertical, 7)
    }

    private func applyDefaultFilterIfNeeded() {
        guard !didInitFilter else { return }
        let active = statusOptions.filter { !Task.closedStatuses.contains($0) }
        guard !active.isEmpty else { return }
        didInitFilter = true
        filter.selected["Status"] = Set(active)
    }
}

/// A Notion database row for a task: checkbox + name, status, due, business, and
/// a trailing cell that shows logged time or a start/stop control on hover.
struct NotionTaskRow: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    var onOpen: () -> Void = {}
    @State private var hover = false

    private var accent: Color { Color.projectColor(named: store.project(for: task.projectId)?.color ?? "indigo") }
    private var isTracking: Bool { store.activeEntry?.taskId == task.id }
    private var logged: TimeInterval { store.totalDuration(for: task) }

    var body: some View {
        HStack(spacing: 12) {
            // Name cell
            HStack(spacing: 9) {
                Button { store.toggleTaskDone(task) } label: {
                    Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14))
                        .foregroundStyle(task.isDone ? NTheme.statusDot("Done") : NTheme.textTertiary)
                }
                .buttonStyle(.plain)

                Text(task.name)
                    .font(.system(size: 13))
                    .foregroundStyle(task.isDone ? NTheme.textTertiary : NTheme.text)
                    .strikethrough(task.isDone, color: NTheme.textTertiary)
                    .lineLimit(1)

                if hover {
                    OpenPeekButton(action: onOpen)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            // Status (inline-editable)
            OptionPicker(options: kTaskStatusOrder, allowNone: false, style: .status, onSelect: { if let s = $0 { store.setTaskStatus(task, s) } }) {
                Group { if task.status.isEmpty { EmptyValue() } else { StatusPill(status: task.status) } }
                    .frame(width: kTColStatus, height: 20, alignment: .leading)
            }

            // Due (inline-editable)
            DateEditButton(date: task.deadline, onSet: { store.setTaskDeadline(task, $0) }) {
                Text(task.deadline.map { DateFmt.short.string(from: $0) } ?? " ")
                    .font(.system(size: 12)).foregroundStyle(NTheme.textSecondary)
                    .frame(width: kTColDue, height: 20, alignment: .leading)
            }

            // Business (inline-editable)
            OptionPicker(options: kBusinessOrder, style: .tag, onSelect: { store.setTaskBusiness(task, $0 ?? "") }) {
                Group { if task.business.isEmpty { Color.clear } else { NotionTag(task.business, colors: NTheme.Tag.gray) } }
                    .frame(width: kTColBiz, height: 20, alignment: .leading)
            }

            // Time / tracking control
            trackCell.frame(width: kTColTime, height: 20, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(hover ? NTheme.hover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }

    @ViewBuilder
    private var trackCell: some View {
        Group {
            if isTracking {
                Button { store.stopTracking() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.fill").font(.system(size: 8, weight: .bold))
                        Text((store.activeEntry?.duration ?? 0).shortFormatted)
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .id(store.tick)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            } else if hover && !task.isDone {
                Button { store.startTracking(task: task) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill").font(.system(size: 8, weight: .bold))
                        Text("Start").font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            } else if logged > 0 {
                Text(logged.shortFormatted)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(NTheme.textSecondary)
            } else {
                Color.clear
            }
        }
    }
}

/// Card body for a task in the board view.
struct TaskCardBody: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    private var project: Project? { store.project(for: task.projectId) }
    private var accent: Color { Color.projectColor(named: project?.color ?? "indigo") }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(task.isDone ? NTheme.textTertiary : NTheme.text)
                .strikethrough(task.isDone, color: NTheme.textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 7, height: 7)
                Text(project?.name ?? "—").font(.system(size: 11)).foregroundStyle(NTheme.textSecondary).lineLimit(1)
            }

            HStack(spacing: 6) {
                if !task.business.isEmpty {
                    NotionTag(task.business, colors: NTheme.Tag.gray)
                }
                Spacer()
                let logged = store.totalDuration(for: task)
                if logged > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.system(size: 9))
                        Text(logged.shortFormatted).font(.system(size: 11).monospacedDigit())
                    }
                    .foregroundStyle(NTheme.textTertiary)
                }
            }
        }
    }
}

/// Notion-style peek panel showing a task's properties and tracking control.
struct TaskPeek: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    let onClose: () -> Void

    private var project: Project? { store.project(for: task.projectId) }
    private var accent: Color { Color.projectColor(named: project?.color ?? "indigo") }
    private var isTracking: Bool { store.activeEntry?.taskId == task.id }
    private var entries: [TimeEntry] {
        store.entries.filter { $0.taskId == task.id }.sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NTheme.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Menu {
                    Button(task.isDone ? "Mark as not done" : "Mark as done") { store.toggleTaskDone(task) }
                    Button("Delete task", role: .destructive) { store.deleteTask(task); onClose() }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 13)).foregroundStyle(NTheme.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    HStack(alignment: .top, spacing: 9) {
                        Button { store.toggleTaskDone(task) } label: {
                            Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                                .font(.system(size: 17))
                                .foregroundStyle(task.isDone ? NTheme.statusDot("Done") : NTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 3)
                        EditableText(task.name, font: .system(size: 21, weight: .bold)) {
                            store.renameTask(task, to: $0)
                        }
                    }
                    .padding(.bottom, 10)

                    // Start / stop
                    Button { isTracking ? store.stopTracking() : store.startTracking(task: task) } label: {
                        HStack(spacing: 7) {
                            Image(systemName: isTracking ? "stop.fill" : "play.fill").font(.system(size: 12, weight: .bold))
                            Text(isTracking ? "Stop · \((store.activeEntry?.duration ?? 0).shortFormatted)" : "Start timer")
                                .font(.system(size: 13, weight: .semibold))
                                .id(store.tick)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(isTracking ? Color.red : accent, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(task.isDone)
                    .opacity(task.isDone ? 0.5 : 1)
                    .padding(.bottom, 12)

                    PeekPropRow(icon: "circle.dashed", label: "Status") {
                        OptionPicker(options: kTaskStatusOrder, allowNone: false, style: .status, onSelect: { if let s = $0 { store.setTaskStatus(task, s) } }) {
                            if task.status.isEmpty { EmptyValue() } else { StatusPill(status: task.status) }
                        }
                    }
                    PeekPropRow(icon: "folder", label: "Project") {
                        Menu {
                            ForEach(store.projects.filter { !$0.isClosed }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { p in
                                Button(p.name) { store.reassignTask(task, toProject: p.id) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(accent).frame(width: 8, height: 8)
                                Text(project?.name ?? "Empty").foregroundStyle(project == nil ? NTheme.textTertiary : NTheme.text)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    PeekPropRow(icon: "calendar", label: "Due") {
                        DateEditButton(date: task.deadline, onSet: { store.setTaskDeadline(task, $0) }) {
                            Text(task.deadline.map { DateFmt.short.string(from: $0) } ?? "Empty")
                                .foregroundStyle(task.deadline == nil ? NTheme.textTertiary : NTheme.text)
                        }
                    }
                    PeekPropRow(icon: "tag", label: "Business") {
                        OptionPicker(options: kBusinessOrder, style: .tag, onSelect: { store.setTaskBusiness(task, $0 ?? "") }) {
                            if task.business.isEmpty { EmptyValue() } else { NotionTag(task.business, colors: NTheme.Tag.gray) }
                        }
                    }
                    PeekPropRow(icon: "square.grid.2x2", label: "Type") {
                        MultiOptionPicker(options: kTaskTypeOrder, selected: task.taskType, style: .blueTag, onChange: { store.setTaskType(task, $0) }) {
                            if task.taskType.isEmpty { EmptyValue() }
                            else { HStack(spacing: 5) { ForEach(task.taskType, id: \.self) { t in NotionTag(t, colors: NTheme.Tag.blue) } } }
                        }
                    }
                    PeekPropRow(icon: "clock", label: "Time logged") {
                        Text(store.totalDuration(for: task).formatted)
                    }

                    if !entries.isEmpty {
                        Rectangle().fill(NTheme.divider).frame(height: 1).padding(.vertical, 12)
                        Text("SESSIONS  ·  \(entries.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NTheme.textTertiary)
                            .padding(.bottom, 6)
                        ForEach(entries.prefix(8)) { entry in
                            HStack {
                                Text(entry.startTime, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 12)).foregroundStyle(NTheme.textSecondary)
                                Spacer()
                                Text(entry.duration.formatted)
                                    .font(.system(size: 12).monospacedDigit()).foregroundStyle(NTheme.text)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    let icon: String
    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 2)
    }
}

