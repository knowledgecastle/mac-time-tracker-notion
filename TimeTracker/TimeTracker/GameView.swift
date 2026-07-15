import SwiftUI

// MARK: - Game Dashboard (main tab)

struct GameView: View {
    @EnvironmentObject var store: AppStore
    @State private var showXPPop = false
    @State private var xpPopValue: Int = 0
    @State private var motivePulse = false

    private var level: XPLevel { store.currentLevel }
    private var todayXP: Int { store.todayXP() }
    private var accountability: AccountabilityMessage { AccountabilityMessage.current(todayXP: todayXP, tasksCompleted: store.completions.filter { Calendar.current.isDateInToday($0.completedAt) }.count) }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Level card
                    LevelCard()

                    // Today's XP callout
                    TodayXPCard(todayXP: todayXP)

                    // Accountability message
                    AccountabilityCard(message: accountability)

                    // Active quests
                    ActiveQuestsPanel()

                    Spacer(minLength: 10)
                }
                .padding(16)
            }

            // XP burst overlay
            if let burst = store.xpPopBurst {
                XPBurstView(xp: burst)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Level Card

struct LevelCard: View {
    @EnvironmentObject var store: AppStore
    @State private var animProgress: Double = 0

    private var level: XPLevel { store.currentLevel }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                // Level badge
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.projectColor(named: level.color), Color.projectColor(named: level.color).opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                    VStack(spacing: 0) {
                        Text("LV")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("\(level.level)")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(level.title.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(Color.projectColor(named: level.color))
                    Text("\(store.totalXP) XP total")
                        .font(.system(size: 13, weight: .semibold))
                    if let next = XPLevel.next(after: level) {
                        Text("\(store.xpToNextLevel - store.xpIntoCurrentLevel) XP to \(next.title)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Max level reached!")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // XP progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color.projectColor(named: level.color).opacity(0.7), Color.projectColor(named: level.color)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * animProgress, height: 10)
                        .animation(.spring(duration: 1.2, bounce: 0.2), value: animProgress)
                }
            }
            .frame(height: 10)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.projectColor(named: level.color).opacity(0.3), lineWidth: 1.5))
        .onAppear { animProgress = store.levelProgress }
        .onChange(of: store.totalXP) { animProgress = store.levelProgress }
    }
}

// MARK: - Today XP card

struct TodayXPCard: View {
    let todayXP: Int
    @EnvironmentObject var store: AppStore

    private var todayDuration: TimeInterval {
        store.todayEntries().reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(todayXP)", label: "XP TODAY", icon: "bolt.fill", color: .yellow)
            Divider().frame(height: 36)
            StatPill(value: "\(store.completions.filter { Calendar.current.isDateInToday($0.completedAt) }.count)", label: "DONE", icon: "checkmark.seal.fill", color: .green)
            Divider().frame(height: 36)
            StatPill(value: todayDuration.shortFormatted, label: "TIME", icon: "clock.fill", color: .cyan)
        }
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 18, weight: .black).monospacedDigit())
            }
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Accountability Card

struct AccountabilityCard: View {
    let message: AccountabilityMessage

    var body: some View {
        HStack(spacing: 12) {
            Text(message.emoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 3) {
                Text(message.headline)
                    .font(.system(size: 13, weight: .bold))
                Text(message.body)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(message.bgColor.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(message.bgColor.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AccountabilityMessage {
    let emoji: String
    let headline: String
    let body: String
    let bgColor: Color

    static func current(todayXP: Int, tasksCompleted: Int) -> AccountabilityMessage {
        let hour = Calendar.current.component(.hour, from: Date())

        if todayXP == 0 {
            if hour < 10 {
                return AccountabilityMessage(emoji: "☀️", headline: "Fresh start!", body: "New day, new XP. Pick your first quest and go.", bgColor: .yellow)
            } else if hour < 14 {
                return AccountabilityMessage(emoji: "⚡", headline: "Let's go!", body: "The day is rolling. Start tracking — every minute counts.", bgColor: .orange)
            } else {
                return AccountabilityMessage(emoji: "🔥", headline: "Don't let today be a zero.", body: "Even 25 minutes of focus earns XP. Start now.", bgColor: .red)
            }
        } else if todayXP < 60 {
            return AccountabilityMessage(emoji: "🌱", headline: "You're warming up.", body: "\(todayXP) XP banked. Keep the momentum going!", bgColor: .teal)
        } else if todayXP < 150 {
            return AccountabilityMessage(emoji: "💪", headline: "Solid progress!", body: "\(todayXP) XP today. You're building real momentum.", bgColor: .blue)
        } else if todayXP < 300 {
            return AccountabilityMessage(emoji: "🚀", headline: "You're on fire!", body: "\(todayXP) XP and counting. Legendary day incoming.", bgColor: .purple)
        } else {
            return AccountabilityMessage(emoji: "👑", headline: "Unstoppable.", body: "\(todayXP) XP today — you crushed it. \(tasksCompleted) quests done!", bgColor: .pink)
        }
    }
}

// MARK: - Active Quests

struct ActiveQuestsPanel: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTask: Task?

    // Get all active (not done) tasks across all projects
    private var activeQuests: [(task: Task, project: Project?, totalTime: TimeInterval)] {
        store.tasks
            .filter { !$0.isDone }
            .compactMap { task -> (Task, Project?, TimeInterval)? in
                let project = store.project(for: task.projectId)
                let totalTime = store.totalDuration(for: task)
                return (task, project, totalTime)
            }
            .sorted { $0.2 > $1.2 } // Sort by total time spent (most time first)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ACTIVE QUESTS", systemImage: "scope")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(activeQuests.count) active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            if activeQuests.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No active quests")
                        .font(.system(size: 12, weight: .medium))
                    Text("Add tasks in the Projects tab to create quests.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 6) {
                    ForEach(activeQuests, id: \.task.id) { quest in
                        QuestRow(
                            task: quest.task,
                            project: quest.project,
                            totalTime: quest.totalTime,
                            isSelected: selectedTask?.id == quest.task.id
                        ) {
                            selectedTask = quest.task
                        }
                    }
                }
            }

            // Start / Stop button
            if let task = selectedTask {
                let isRunning = store.activeEntry?.taskId == task.id
                let isCompleted = store.isTaskCompleted(task)
                let canStartTracking = !task.isDone && (store.project(for: task.projectId)?.isDone == false || store.project(for: task.projectId) == nil)

                HStack(spacing: 10) {
                    if canStartTracking || isRunning {
                        Button {
                            isRunning ? store.stopTracking() : store.startTracking(task: task)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                                    .font(.system(size: 12))
                                Text(isRunning ? "Pause Quest" : "Start Quest")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(isRunning ? Color.red : Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 7) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Quest Completed")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    }

                    if !isCompleted && canStartTracking {
                        Button {
                            store.markTaskComplete(task)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                Text("+20 XP")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.green.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(duration: 0.25), value: isRunning)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct GameProjectChip: View {
    let project: Project
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(Color.projectColor(named: project.color)).frame(width: 7, height: 7)
                Text(project.name).font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? Color.projectColor(named: project.color).opacity(0.15) : Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                isSelected ? Color.projectColor(named: project.color).opacity(0.7) : Color(NSColor.separatorColor), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct QuestRow: View {
    @EnvironmentObject var store: AppStore
    let task: Task
    let project: Project?
    let totalTime: TimeInterval
    let isSelected: Bool
    let action: () -> Void

    private var isRunning: Bool { store.activeEntry?.taskId == task.id }
    private var isCompleted: Bool { store.isTaskCompleted(task) }
    private var todayDuration: TimeInterval {
        store.entries.filter { $0.taskId == task.id && Calendar.current.isDateInToday($0.startTime) }.reduce(0) { $0 + $1.duration }
    }
    private var todayXP: Int { max(1, Int(todayDuration / 60)) }
    private var totalXP: Int { max(1, Int(totalTime / 60)) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Status icon with project color
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green.opacity(0.15) : (isRunning ? (project != nil ? Color.projectColor(named: project!.color).opacity(0.12) : Color.accentColor.opacity(0.12)) : Color.primary.opacity(0.06)))
                        .frame(width: 34, height: 34)
                    Image(systemName: isCompleted ? "checkmark.seal.fill" : (isRunning ? "play.fill" : "scope"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isCompleted ? .green : (isRunning ? (project != nil ? Color.projectColor(named: project!.color) : Color.accentColor) : Color.secondary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Task name
                    Text(task.name)
                        .font(.system(size: 13, weight: .semibold))
                        .strikethrough(isCompleted)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // Project badge
                        if let proj = project {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.projectColor(named: proj.color))
                                    .frame(width: 5, height: 5)
                                Text(proj.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if totalTime > 0 {
                            Text("·")
                                .foregroundStyle(.secondary)
                            
                            // Total time spent
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 9))
                                Text(totalTime.formatted)
                                    .font(.system(size: 10).monospacedDigit())
                            }
                            .foregroundStyle(.secondary)
                            
                            // Total XP
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text("\(totalXP) XP")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.yellow.opacity(0.8))
                        }
                    }
                }

                Spacer()

                if isRunning {
                    LiveTimerBadge()
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(isSelected ? (project != nil ? Color.projectColor(named: project!.color).opacity(0.08) : Color.accentColor.opacity(0.07)) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? (project != nil ? Color.projectColor(named: project!.color).opacity(0.25) : Color.accentColor.opacity(0.2)) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct LiveTimerBadge: View {
    @EnvironmentObject var store: AppStore
    private var elapsed: TimeInterval {
        store.activeEntry?.duration ?? 0
    }

    var body: some View {
        Text(elapsed.shortFormatted)
            .font(.system(size: 11, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - XP Burst overlay

struct XPBurstView: View {
    let xp: Int
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("⚡ +\(xp) XP")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.yellow)
                    Text("Quest Complete!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .yellow.opacity(0.4), radius: 20)
                .opacity(opacity)
                .offset(y: offset)
                Spacer()
            }
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.4)) { opacity = 1; offset = -20 }
            withAnimation(.easeIn(duration: 0.5).delay(0.9)) { opacity = 0 }
        }
    }
}

