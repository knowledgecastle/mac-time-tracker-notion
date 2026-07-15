import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingEntry: TimeEntry?

    private var groupedEntries: [(key: String, entries: [TimeEntry])] {
        let all = store.entries.sorted { $0.startTime > $1.startTime }
        let grouped = Dictionary(grouping: all) { entry -> String in
            if Calendar.current.isDateInToday(entry.startTime) { return "Today" }
            if Calendar.current.isDateInYesterday(entry.startTime) { return "Yesterday" }
            let fmt = DateFormatter(); fmt.dateStyle = .medium
            return fmt.string(from: entry.startTime)
        }
        return grouped.sorted { a, b in
            if a.key == "Today" { return true }
            if b.key == "Today" { return false }
            if a.key == "Yesterday" { return true }
            if b.key == "Yesterday" { return false }
            return a.key > b.key
        }.map { (key: $0.key, entries: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("🕘").font(.system(size: 22))
                Text("Time Log").font(.system(size: 22, weight: .bold)).foregroundStyle(NTheme.text)
                Spacer()
                Text(store.entries.map(\.duration).reduce(0, +).formatted + " total")
                    .font(.system(size: 12)).foregroundStyle(NTheme.textTertiary)
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)
            Rectangle().fill(NTheme.divider).frame(height: 1)

            ScrollView {
                if store.entries.isEmpty {
                    VStack(spacing: 10) {
                        Text("🕘").font(.system(size: 34))
                        Text("No time logged yet").font(.system(size: 14, weight: .medium)).foregroundStyle(NTheme.text)
                        Text("Start a timer to see entries here")
                            .font(.system(size: 12)).foregroundStyle(NTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(groupedEntries, id: \.key) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    LogRow(entry: entry, onOpen: { editingEntry = entry })
                                    Rectangle().fill(NTheme.divider).frame(height: 1)
                                }
                            } header: {
                                HStack {
                                    Text(group.key)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(NTheme.textSecondary)
                                    Spacer()
                                    Text(group.entries.map(\.duration).reduce(0, +).formatted)
                                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                                        .foregroundStyle(NTheme.textTertiary)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 7)
                                .background(NTheme.bg)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(NTheme.bg)
        .sheet(item: $editingEntry) { entry in
            EntryEditSheet(entry: entry).environmentObject(store)
        }
    }
}

struct LogRow: View {
    @EnvironmentObject var store: AppStore
    let entry: TimeEntry

    private var task: Task? { store.task(for: entry.taskId) }
    private var project: Project? { store.project(for: entry.projectId) }

    private var timeRange: String {
        let fmt = DateFormatter(); fmt.timeStyle = .short
        let start = fmt.string(from: entry.startTime)
        if let end = entry.endTime { return "\(start) – \(fmt.string(from: end))" }
        return "\(start) –"
    }

    var onOpen: () -> Void = {}
    @State private var hover = false

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(project.map { Color.projectColor(named: $0.color) } ?? NTheme.textTertiary)
                .frame(width: 8, height: 8)

            Text(task?.name ?? "Deleted task")
                .font(.system(size: 13))
                .foregroundStyle(task == nil ? NTheme.textTertiary : NTheme.text)
                .lineLimit(1)

            if let project {
                Text(project.name)
                    .font(.system(size: 12))
                    .foregroundStyle(NTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(timeRange)
                .font(.system(size: 11))
                .foregroundStyle(NTheme.textTertiary)

            Text(entry.duration.formatted)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(NTheme.text)
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(hover ? NTheme.hover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button { onOpen() } label: { Label("Edit Entry", systemImage: "pencil") }
            Button(role: .destructive) {
                store.deleteEntry(entry)
            } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
    }
}

/// Sheet to edit a logged time entry's start/end/note (syncs to Notion).
struct EntryEditSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let entry: TimeEntry

    @State private var start: Date
    @State private var end: Date
    @State private var note: String

    init(entry: TimeEntry) {
        self.entry = entry
        _start = State(initialValue: entry.startTime)
        _end = State(initialValue: entry.endTime ?? Date())
        _note = State(initialValue: entry.note)
    }

    private var task: Task? { store.task(for: entry.taskId) }
    private var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Edit Time Entry").font(.system(size: 17, weight: .semibold))
                Text(task?.name ?? "Deleted task").font(.system(size: 12)).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Start").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                    DatePicker("", selection: $start, displayedComponents: [.date, .hourAndMinute]).labelsHidden()
                }
                HStack {
                    Text("End").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                    DatePicker("", selection: $end, displayedComponents: [.date, .hourAndMinute]).labelsHidden()
                }
                HStack {
                    Text("Duration").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                    Text(duration.formatted).font(.system(size: 13, weight: .medium).monospacedDigit())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTE").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                TextField("Optional note", text: $note).textFieldStyle(.roundedBorder).font(.system(size: 13))
            }

            HStack {
                Button("Delete", role: .destructive) { store.deleteEntry(entry); dismiss() }
                    .buttonStyle(.plain).foregroundStyle(.red)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Button("Save") {
                    if end >= start { store.updateEntry(entry, start: start, end: end, note: note) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(end < start)
            }
        }
        .padding(22)
        .frame(width: 360)
    }
}
