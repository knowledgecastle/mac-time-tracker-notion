import SwiftUI

struct DailyReportView: View {
    @EnvironmentObject var store: AppStore
    @State private var copied = false

    private var todayXP: Int { store.todayXP() }
    private var todayDuration: TimeInterval { store.todayEntries().reduce(0) { $0 + $1.duration } }
    private var completedCount: Int { store.completions.filter { Calendar.current.isDateInToday($0.completedAt) }.count }
    private var summary: [(task: Task, project: Project?, duration: TimeInterval, xp: Int, completed: Bool)] { store.todayTaskSummary() }
    private var level: XPLevel { store.currentLevel }

    var body: some View {
        ScrollView {
            if summary.isEmpty {
                VStack(spacing: 16) {
                    Text("📋")
                        .font(.system(size: 48))
                    Text("No activity yet today")
                        .font(.system(size: 14, weight: .medium))
                    Text("Log some quests and come back for your daily breakdown.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                .padding(.horizontal, 30)
            } else {
                VStack(spacing: 16) {
                    // Header banner
                    ReportHeaderCard(
                        todayXP: todayXP,
                        duration: todayDuration,
                        completedCount: completedCount,
                        level: level
                    )

                    // Task breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        Label("QUEST BREAKDOWN", systemImage: "list.bullet.clipboard")
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)

                        ForEach(summary, id: \.task.id) { item in
                            ReportTaskRow(item: item)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // XP sources
                    XPSourcesCard(summary: summary, completions: store.completions.filter { Calendar.current.isDateInToday($0.completedAt) })

                    // Copy report button
                    Button {
                        copyReport()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                            Text(copied ? "Copied!" : "Copy Daily Report")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(copied ? Color.green : Color(NSColor.controlBackgroundColor))
                        .foregroundStyle(copied ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: copied)
                }
                .padding(16)
            }
        }
    }

    private func copyReport() {
        let fmt = DateFormatter(); fmt.dateStyle = .full
        var lines: [String] = [
            "📊 Daily Report — \(fmt.string(from: Date()))",
            "",
            "⚡ XP Earned: \(todayXP) XP",
            "🕐 Time Logged: \(todayDuration.shortFormatted)",
            "✅ Quests Completed: \(completedCount)",
            "🏆 Level: \(level.level) – \(level.title)",
            "",
            "— Quest Breakdown —",
        ]
        for item in summary {
            let check = item.completed ? "✅" : "🔄"
            let proj = item.project?.name ?? ""
            lines.append("\(check) \(item.task.name) [\(proj)] — \(item.duration.shortFormatted) · +\(item.xp) XP")
        }
        lines.append("")
        lines.append("Total: \(todayXP) XP · \(todayDuration.shortFormatted) worked")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}

// MARK: - Report Header

struct ReportHeaderCard: View {
    let todayXP: Int
    let duration: TimeInterval
    let completedCount: Int
    let level: XPLevel

    private var grade: (emoji: String, label: String, color: Color) {
        switch todayXP {
        case 0..<30:   return ("😴", "Rest Day", .secondary)
        case 30..<80:  return ("🌱", "Warming Up", .teal)
        case 80..<160: return ("💪", "Solid Work", .blue)
        case 160..<280: return ("🔥", "On Fire", .orange)
        case 280..<400: return ("🚀", "Crushing It", .purple)
        default:        return ("👑", "Legendary", .pink)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Report")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(grade.emoji)
                            .font(.system(size: 28))
                        Text(grade.label)
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(grade.color)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("LV \(level.level)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.projectColor(named: level.color))
                    Text(level.title)
                        .font(.system(size: 13, weight: .semibold))
                }
            }

            HStack(spacing: 0) {
                MiniStat(value: "\(todayXP)", label: "XP", color: .yellow)
                Divider().frame(height: 32)
                MiniStat(value: duration.shortFormatted, label: "TIME", color: .cyan)
                Divider().frame(height: 32)
                MiniStat(value: "\(completedCount)", label: "DONE", color: .green)
            }
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
        .background(LinearGradient(
            colors: [Color(NSColor.controlBackgroundColor), Color(NSColor.controlBackgroundColor).opacity(0.6)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(grade.color.opacity(0.3), lineWidth: 1.5))
    }
}

struct MiniStat: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, weight: .black).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
    }
}

// MARK: - Report task row

struct ReportTaskRow: View {
    let item: (task: Task, project: Project?, duration: TimeInterval, xp: Int, completed: Bool)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.completed ? "checkmark.seal.fill" : "clock")
                .font(.system(size: 14))
                .foregroundStyle(item.completed ? .green : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.task.name)
                    .font(.system(size: 13, weight: .medium))
                    .strikethrough(item.completed, color: .secondary)
                if let proj = item.project {
                    HStack(spacing: 4) {
                        Circle().fill(Color.projectColor(named: proj.color)).frame(width: 5, height: 5)
                        Text(proj.name).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(item.xp) XP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.yellow.opacity(0.9))
                Text(item.duration.shortFormatted)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        Divider().opacity(0.5)
    }
}

// MARK: - XP Sources

struct XPSourcesCard: View {
    let summary: [(task: Task, project: Project?, duration: TimeInterval, xp: Int, completed: Bool)]
    let completions: [TaskCompletion]

    private var timeXP: Int { summary.reduce(0) { $0 + $1.xp } }
    private var bonusXP: Int { completions.reduce(0) { $0 + $1.bonusXP } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("XP SOURCES", systemImage: "bolt.fill")
                .font(.system(size: 10, weight: .black))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                XPSourcePill(label: "Time logged", xp: timeXP, icon: "clock.fill", color: .cyan)
                XPSourcePill(label: "Quest completions", xp: bonusXP, icon: "checkmark.seal.fill", color: .green)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct XPSourcePill: View {
    let label: String
    let xp: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("+\(xp) XP").font(.system(size: 14, weight: .black)).foregroundStyle(color)
                Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
