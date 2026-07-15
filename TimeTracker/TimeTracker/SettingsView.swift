import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var token: String = NotionService.shared.token
    @State private var showToken = false
    @State private var projectsDB: String = NotionService.shared.projectsDBId
    @State private var tasksDB: String = NotionService.shared.tasksDBId
    @State private var timeEntriesDB: String = NotionService.shared.timeEntriesDBId

    private func saveNotionConfig() {
        NotionService.shared.token = token
        NotionService.shared.projectsDBId = projectsDB.trimmingCharacters(in: .whitespacesAndNewlines)
        NotionService.shared.tasksDBId = tasksDB.trimmingCharacters(in: .whitespacesAndNewlines)
        NotionService.shared.timeEntriesDBId = timeEntriesDB.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var configComplete: Bool {
        !token.isEmpty && !projectsDB.isEmpty && !tasksDB.isEmpty && !timeEntriesDB.isEmpty
    }

    @ViewBuilder
    private func dbIdField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            TextField("0000000000000000…", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
    }

    private var lastSyncText: String {
        guard let d = store.lastSyncDate else { return "Never" }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return fmt.localizedString(for: d, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Notion section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.accentColor)
                            Text("Notion Integration")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("INTEGRATION TOKEN")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)

                            HStack(spacing: 8) {
                                Group {
                                    if showToken {
                                        TextField("secret_...", text: $token)
                                    } else {
                                        SecureField("secret_...", text: $token)
                                    }
                                }
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))

                                Button {
                                    showToken.toggle()
                                } label: {
                                    Image(systemName: showToken ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Text("Create one at notion.so/my-integrations, then share your Projects, Tasks & Time Entries databases with it.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        dbIdField(label: "PROJECTS DATABASE ID", text: $projectsDB)
                        dbIdField(label: "TASKS DATABASE ID", text: $tasksDB)
                        dbIdField(label: "TIME ENTRIES DATABASE ID", text: $timeEntriesDB)

                        Text("Open a database in Notion, copy its link, and paste the 32-character ID from the URL. See the README for the exact property names each database must have.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            saveNotionConfig()
                        } label: {
                            Text("Save")
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(!configComplete)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Sync section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.accentColor)
                            Text("Sync")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Databases")
                                    .font(.system(size: 12, weight: .medium))
                                Text(configComplete ? "Projects, Tasks & Time Entries connected" : "Not configured yet — add IDs above")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: configComplete ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(configComplete ? .green : .secondary)
                                .font(.system(size: 14))
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last synced")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text(lastSyncText)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            Spacer()

                            Button {
                                saveNotionConfig()
                                _Concurrency.Task { await store.syncWithNotion() }
                            } label: {
                                HStack(spacing: 6) {
                                    if store.isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 11))
                                    }
                                    Text(store.isSyncing ? "Syncing…" : "Sync Now")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isSyncing || !configComplete)
                        }

                        if let err = store.syncError {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Label("Active projects & incomplete tasks are imported", systemImage: "arrow.down.circle")
                            Label("Time Spent on Notion tasks updates when you stop a timer", systemImage: "clock.badge.checkmark")
                            Label("Local-only projects & tasks are preserved", systemImage: "lock.shield")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Reminders section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.accentColor)
                            Text("Reminders")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("REMIND ME WHILE A TIMER IS RUNNING")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)

                            Picker("", selection: Binding(
                                get: { store.reminderInterval },
                                set: { store.setReminderInterval($0) }
                            )) {
                                ForEach(ReminderInterval.allCases) { interval in
                                    Text(interval.label).tag(interval)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text("Get a notification at this interval so you don't forget to stop the timer.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Appearance section
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.accentColor)
                            Text("Appearance")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        Picker("", selection: Binding(
                            get: { store.appTheme },
                            set: { store.setAppTheme($0) }
                        )) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.label).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Text("Switch between light and dark, or follow your system setting.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 720)
    }
}
