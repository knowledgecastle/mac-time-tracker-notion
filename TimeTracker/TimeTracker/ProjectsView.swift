import SwiftUI

let kProjectStatusOrder = ["Quoted", "New request", "In progress", "Client Revision", "Done", "Paid", "Dead"]
let kPriorityOrder = ["High", "Medium", "Low"]

struct ProjectsView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingAddProject = false
    @State private var expandedProjects: Set<UUID> = []
    @State private var collapsedGroups: Set<String> = []
    @State private var filter = DBFilterState()
    @State private var didInitFilter = false
    @State private var peekProjectId: UUID?
    @State private var viewMode: DBViewMode = .table

    private var statusOptions: [String] {
        orderedOptions(Set(store.projects.map(\.status).filter { !$0.isEmpty }), canonical: kProjectStatusOrder)
    }
    private var priorityOptions: [String] {
        orderedOptions(Set(store.projects.map(\.priority).filter { !$0.isEmpty }), canonical: kPriorityOrder)
    }
    private var facets: [FilterFacet] {
        [FilterFacet(id: "Status", title: "Status", options: statusOptions),
         FilterFacet(id: "Priority", title: "Priority", options: priorityOptions)]
    }
    private var filteredProjects: [Project] {
        store.projects.filter { p in
            filter.passes(name: p.name, values: [
                "Status": p.status.isEmpty ? [] : [p.status],
                "Priority": p.priority.isEmpty ? [] : [p.priority]
            ])
        }
    }
    /// Projects grouped by status, in canonical order.
    private var groups: [(status: String, projects: [Project])] {
        let byStatus = Dictionary(grouping: filteredProjects) { $0.status.isEmpty ? "No status" : $0.status }
        let order = kProjectStatusOrder + byStatus.keys.filter { !kProjectStatusOrder.contains($0) && $0 != "No status" }.sorted() + ["No status"]
        return order.compactMap { s in
            guard let ps = byStatus[s], !ps.isEmpty else { return nil }
            return (s, ps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    private func applyDefaultFilterIfNeeded() {
        guard !didInitFilter else { return }
        let active = statusOptions.filter { !Project.closedStatuses.contains($0) }
        guard !active.isEmpty else { return }
        didInitFilter = true
        filter.selected["Status"] = Set(active)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Page title
            HStack(spacing: 10) {
                Text("🗂").font(.system(size: 22))
                Text("Projects").font(.system(size: 22, weight: .bold)).foregroundStyle(NTheme.text)
                Spacer()
                Button { showingAddProject = true } label: {
                    HStack(spacing: 4) {
                        Text("New").font(.system(size: 12, weight: .semibold))
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(NTheme.blue, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 10)

            // Toolbar (view tabs + filters)
            HStack(spacing: 14) {
                ViewModeTabs(mode: $viewMode)
                FilterBar(facets: facets, state: $filter)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 2)

            Rectangle().fill(NTheme.divider).frame(height: 1)

            if store.projects.isEmpty {
                emptyState; Spacer()
            } else if filteredProjects.isEmpty {
                noMatchState; Spacer()
            } else if viewMode == .table {
                projectColumnHeader
                Rectangle().fill(NTheme.divider).frame(height: 1)
                projectTable
            } else {
                projectBoard
            }
        }
        .background(NTheme.bg)
        .overlay {
            PeekOverlay(isPresented: peekProjectId != nil, onClose: { peekProjectId = nil }) {
                if let id = peekProjectId, let project = store.project(for: id) {
                    ProjectPeek(project: project, onClose: { peekProjectId = nil })
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: peekProjectId)
        .onAppear { applyDefaultFilterIfNeeded() }
        .onChange(of: store.projects.count) { _, _ in applyDefaultFilterIfNeeded() }
        .sheet(isPresented: $showingAddProject) { AddProjectSheet() }
    }

    private var projectTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groups, id: \.status) { group in
                    GroupHeaderRow(
                        title: group.status,
                        count: group.projects.count,
                        dotColor: group.status == "No status" ? NTheme.textTertiary : NTheme.statusDot(group.status),
                        isExpanded: !collapsedGroups.contains(group.status)
                    ) {
                        toggle(&collapsedGroups, group.status)
                    }
                    .padding(.horizontal, 24)

                    if !collapsedGroups.contains(group.status) {
                        ForEach(group.projects) { project in
                            ProjectRow(
                                project: project,
                                isExpanded: expandedProjects.contains(project.id),
                                onToggle: { toggle(&expandedProjects, project.id) },
                                onOpen: { peekProjectId = project.id }
                            )
                            Rectangle().fill(NTheme.divider).frame(height: 1)
                        }
                    }
                }

                Button { showingAddProject = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 11))
                        Text("New project").font(.system(size: 13))
                        Spacer()
                    }
                    .foregroundStyle(NTheme.textTertiary)
                    .padding(.horizontal, 24).padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)
        }
    }

    private var projectBoard: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(groups, id: \.status) { group in
                    BoardColumn(
                        title: group.status,
                        count: group.projects.count,
                        dotColor: group.status == "No status" ? NTheme.textTertiary : NTheme.statusDot(group.status),
                        onDropId: group.status == "No status" ? nil : { droppedId in
                            if let uuid = UUID(uuidString: droppedId), let p = store.project(for: uuid), p.status != group.status {
                                store.setProjectStatus(p, group.status)
                            }
                        }
                    ) {
                        VStack(spacing: 8) {
                            ForEach(group.projects) { project in
                                BoardCard(dragId: project.id.uuidString, onTap: { peekProjectId = project.id }) {
                                    ProjectCardBody(project: project)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var projectColumnHeader: some View {
        HStack(spacing: 12) {
            PropertyHeader(icon: "textformat", title: "Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            PropertyHeader(icon: "calendar", title: "Dates")
                .frame(width: kColDates, alignment: .leading)
            PropertyHeader(icon: "flag", title: "Priority")
                .frame(width: kColPriority, alignment: .leading)
            PropertyHeader(icon: "checklist", title: "Tasks")
                .frame(width: kColTasks, alignment: .leading)
        }
        .padding(.horizontal, 24).padding(.vertical, 7)
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🗂").font(.system(size: 34))
            Text("No projects yet").font(.system(size: 14, weight: .medium)).foregroundStyle(NTheme.text)
            Text("They'll appear here once you sync from Notion, or create one.")
                .font(.system(size: 12)).foregroundStyle(NTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private var noMatchState: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle").font(.system(size: 28)).foregroundStyle(NTheme.textTertiary)
            Text("No projects match your filters").font(.system(size: 13, weight: .medium)).foregroundStyle(NTheme.text)
            Button("Reset filters") { filter = DBFilterState() }
                .font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(NTheme.blue)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }
}

// Shared column widths for the Projects table.
let kColDates: CGFloat = 150
let kColPriority: CGFloat = 96
let kColTasks: CGFloat = 60

/// A Notion database row for a project, expandable to its task sub-rows.
struct ProjectRow: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    let isExpanded: Bool
    let onToggle: () -> Void
    var onOpen: () -> Void = {}
    @State private var hover = false
    @State private var showingAddTask = false

    private var accent: Color { Color.projectColor(named: project.color) }
    private var tasks: [Task] {
        store.tasks.filter { $0.projectId == project.id }
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Name cell (chevron + dot + title)
                HStack(spacing: 7) {
                    Button(action: onToggle) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NTheme.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 14, height: 14)
                            .opacity(hover || isExpanded ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)

                    Circle().fill(accent).frame(width: 9, height: 9)

                    Text(project.name)
                        .font(.system(size: 13))
                        .foregroundStyle(NTheme.text)
                        .strikethrough(project.isDone, color: NTheme.textTertiary)
                        .lineLimit(1)

                    if hover {
                        OpenPeekButton(action: onOpen)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)

                // Dates
                Text(DateFmt.range(project.startDate, project.endDate))
                    .font(.system(size: 12))
                    .foregroundStyle(NTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: kColDates, alignment: .leading)

                // Priority (inline-editable)
                OptionPicker(options: kPriorityOrder, style: .priority, onSelect: { store.setProjectPriority(project, $0 ?? "") }) {
                    Group {
                        if project.priority.isEmpty { Color.clear }
                        else { NotionTag(project.priority, colors: NTheme.tagColors(forPriority: project.priority)) }
                    }
                    .frame(width: kColPriority, height: 20, alignment: .leading)
                }

                // Tasks count
                Text("\(tasks.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(NTheme.textTertiary)
                    .frame(width: kColTasks, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(hover ? NTheme.hover : Color.clear)
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.12), value: hover)
            .contextMenu {
                Button {
                    store.toggleProjectDone(project)
                } label: {
                    Label(project.isDone ? "Mark as not done" : "Mark as done",
                          systemImage: project.isDone ? "arrow.uturn.backward" : "checkmark.circle")
                }
                Divider()
                Button(role: .destructive) { store.deleteProject(project) } label: {
                    Label("Delete project", systemImage: "trash")
                }
            }

            // Expanded task sub-rows
            if isExpanded {
                if tasks.isEmpty {
                    Text("No tasks")
                        .font(.system(size: 12))
                        .foregroundStyle(NTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 56).padding(.vertical, 7)
                } else {
                    ForEach(tasks) { task in
                        ProjectTaskRow(task: task, accent: accent)
                    }
                }
                Button { showingAddTask = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus").font(.system(size: 10))
                        Text("New task").font(.system(size: 12))
                        Spacer()
                    }
                    .foregroundStyle(NTheme.textTertiary)
                    .padding(.leading, 56).padding(.trailing, 24).padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAddTask) { AddTaskSheet(project: project) }
    }
}

/// A Notion sub-item row for a task inside an expanded project.
struct ProjectTaskRow: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    let accent: Color
    @State private var hover = false

    private var isTracking: Bool { store.activeEntry?.taskId == task.id }
    private var logged: TimeInterval { store.totalDuration(for: task) }

    var body: some View {
        HStack(spacing: 10) {
            Button { store.toggleTaskDone(task) } label: {
                Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(task.isDone ? NTheme.statusDot("Done") : NTheme.textTertiary)
            }
            .buttonStyle(.plain)

            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(NTheme.textTertiary)

            Text(task.name)
                .font(.system(size: 13))
                .foregroundStyle(task.isDone ? NTheme.textTertiary : NTheme.text)
                .strikethrough(task.isDone, color: NTheme.textTertiary)
                .lineLimit(1)

            StatusPill(status: task.status)

            Spacer(minLength: 8)

            if logged > 0 {
                Text(logged.shortFormatted)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(NTheme.textSecondary)
            }

            if !task.isDone && (hover || isTracking) {
                Button { isTracking ? store.stopTracking() : store.startTracking(task: task) } label: {
                    Image(systemName: isTracking ? "stop.fill" : "play.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isTracking ? .white : accent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(isTracking ? Color.red : accent.opacity(0.14)))
                }
                .buttonStyle(.plain)
            }
            if hover && !task.isFromNotion {
                Button { store.deleteTask(task) } label: {
                    Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(NTheme.textTertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 44).padding(.trailing, 24).padding(.vertical, 6)
        .background(hover ? NTheme.hover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

/// Card body for a project in the board view.
struct ProjectCardBody: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    private var accent: Color { Color.projectColor(named: project.color) }
    private var taskCount: Int { store.tasks.filter { $0.projectId == project.id }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 7) {
                Circle().fill(accent).frame(width: 10, height: 10).padding(.top, 3)
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NTheme.text)
                    .strikethrough(project.isDone, color: NTheme.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            let dates = DateFmt.range(project.startDate, project.endDate)
            if !dates.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 9))
                    Text(dates).font(.system(size: 11))
                }
                .foregroundStyle(NTheme.textSecondary)
            }

            HStack(spacing: 6) {
                if !project.priority.isEmpty {
                    NotionTag(project.priority, colors: NTheme.tagColors(forPriority: project.priority))
                }
                Spacer()
                let logged = store.totalDuration(for: project.id)
                if logged > 0 {
                    Text(logged.shortFormatted).font(.system(size: 11).monospacedDigit()).foregroundStyle(NTheme.textTertiary)
                }
                HStack(spacing: 3) {
                    Image(systemName: "checklist").font(.system(size: 9))
                    Text("\(taskCount)").font(.system(size: 11))
                }
                .foregroundStyle(NTheme.textTertiary)
            }
        }
    }
}

/// Notion-style peek panel showing a project's properties and its tasks.
struct ProjectPeek: View {
    @EnvironmentObject var store: AppStore
    let project: Project
    let onClose: () -> Void
    @State private var showingAddTask = false

    private var accent: Color { Color.projectColor(named: project.color) }
    private var tasks: [Task] {
        store.tasks.filter { $0.projectId == project.id }
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Close")
                Spacer()
                Menu {
                    Button(project.isDone ? "Mark as not done" : "Mark as done") { store.toggleProjectDone(project) }
                    Button("Delete project", role: .destructive) { store.deleteProject(project); onClose() }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 13)).foregroundStyle(NTheme.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Title (editable)
                    HStack(spacing: 9) {
                        Circle().fill(accent).frame(width: 12, height: 12)
                        EditableText(project.name, font: .system(size: 22, weight: .bold)) {
                            store.renameProject(project, to: $0)
                        }
                    }
                    .padding(.bottom, 12)

                    PeekPropRow(icon: "circle.dashed", label: "Status") {
                        OptionPicker(options: kProjectStatusOrder, allowNone: false, style: .status, onSelect: { if let s = $0 { store.setProjectStatus(project, s) } }) {
                            if project.status.isEmpty { EmptyValue() } else { StatusPill(status: project.status) }
                        }
                    }
                    PeekPropRow(icon: "calendar", label: "Dates") {
                        HStack(spacing: 6) {
                            DateEditButton(date: project.startDate, onSet: { store.setProjectDates(project, start: $0, end: project.endDate) }) {
                                Text(project.startDate.map { DateFmt.short.string(from: $0) } ?? "Start")
                                    .foregroundStyle(project.startDate == nil ? NTheme.textTertiary : NTheme.text)
                            }
                            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundStyle(NTheme.textTertiary)
                            DateEditButton(date: project.endDate, onSet: { store.setProjectDates(project, start: project.startDate, end: $0) }) {
                                Text(project.endDate.map { DateFmt.short.string(from: $0) } ?? "End")
                                    .foregroundStyle(project.endDate == nil ? NTheme.textTertiary : NTheme.text)
                            }
                        }
                    }
                    PeekPropRow(icon: "flag", label: "Priority") {
                        OptionPicker(options: kPriorityOrder, style: .priority, onSelect: { store.setProjectPriority(project, $0 ?? "") }) {
                            if project.priority.isEmpty { EmptyValue() } else { NotionTag(project.priority, colors: NTheme.tagColors(forPriority: project.priority)) }
                        }
                    }
                    PeekPropRow(icon: "person", label: "Client") {
                        EditableText(project.client, placeholder: "Empty", allowEmpty: true) { store.setProjectClient(project, $0) }
                    }
                    PeekPropRow(icon: "clock", label: "Time logged") {
                        Text(store.totalDuration(for: project.id).formatted)
                    }

                    Rectangle().fill(NTheme.divider).frame(height: 1).padding(.vertical, 12)

                    // Tasks
                    Text("TASKS  ·  \(tasks.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NTheme.textTertiary)
                        .padding(.bottom, 4)

                    ForEach(tasks) { task in
                        ProjectTaskRow(task: task, accent: accent)
                            .padding(.horizontal, -20)
                    }

                    Button { showingAddTask = true } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "plus").font(.system(size: 10))
                            Text("New task").font(.system(size: 12))
                        }
                        .foregroundStyle(NTheme.textTertiary)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showingAddTask) { AddTaskSheet(project: project) }
    }
}

struct AddProjectSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var color = "indigo"

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("New Project")
                .font(.system(size: 17, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("NAME")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                TextField("Project name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("COLOR")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                HStack(spacing: 10) {
                    ForEach(Color.projectColors, id: \.name) { item in
                        ZStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 26, height: 26)
                            if color == item.name {
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture { withAnimation(.spring(duration: 0.2)) { color = item.name } }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Create Project") {
                    if !name.isEmpty { store.addProject(name: name, color: color); dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}

struct AddTaskSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let project: Project
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Task")
                    .font(.system(size: 17, weight: .semibold))
                Label(project.name, systemImage: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("TASK NAME")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                TextField("What will you work on?", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit {
                        if !name.isEmpty { store.addTask(name: name, projectId: project.id); dismiss() }
                    }
            }

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Add Task") {
                    if !name.isEmpty { store.addTask(name: name, projectId: project.id); dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}
