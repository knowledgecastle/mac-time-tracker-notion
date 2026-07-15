import Foundation

// MARK: - XP & Leveling

struct XPLevel {
    let level: Int
    let title: String
    let totalXPRequired: Int
    let color: String

    static func forXP(_ xp: Int) -> XPLevel {
        let levels = allLevels
        return levels.last(where: { xp >= $0.totalXPRequired }) ?? levels[0]
    }

    static func next(after level: XPLevel) -> XPLevel? {
        allLevels.first { $0.level == level.level + 1 }
    }

    static let allLevels: [XPLevel] = [
        XPLevel(level: 1,  title: "Rookie",       totalXPRequired: 0,    color: "teal"),
        XPLevel(level: 2,  title: "Hustler",      totalXPRequired: 120,  color: "teal"),
        XPLevel(level: 3,  title: "Grinder",      totalXPRequired: 300,  color: "green"),
        XPLevel(level: 4,  title: "Go-Getter",    totalXPRequired: 540,  color: "green"),
        XPLevel(level: 5,  title: "Achiever",     totalXPRequired: 840,  color: "blue"),
        XPLevel(level: 6,  title: "Warrior",      totalXPRequired: 1200, color: "blue"),
        XPLevel(level: 7,  title: "Expert",       totalXPRequired: 1620, color: "indigo"),
        XPLevel(level: 8,  title: "Champion",     totalXPRequired: 2100, color: "indigo"),
        XPLevel(level: 9,  title: "Legend",       totalXPRequired: 2700, color: "purple"),
        XPLevel(level: 10, title: "Unstoppable",  totalXPRequired: 3600, color: "pink"),
    ]
}

struct TaskCompletion: Identifiable, Codable {
    var id = UUID()
    var taskId: UUID
    var projectId: UUID
    var completedAt: Date
    var bonusXP: Int = 20
}

// MARK: - Models

struct Project: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var color: String
    var createdAt = Date()
    var notionPageId: String? = nil
    var isDone: Bool = false
    // Notion-synced properties
    var status: String = ""
    var priority: String = ""
    var startDate: Date? = nil
    var endDate: Date? = nil
    var client: String = ""

    var isFromNotion: Bool { notionPageId != nil }
    static let closedStatuses: Set<String> = ["Paid", "Done", "Dead"]
    var isClosed: Bool { Project.closedStatuses.contains(status) }

    init(name: String, color: String) {
        self.name = name
        self.color = color
    }

    // Custom decoding so older saved data (missing the new keys) still loads.
    enum CodingKeys: String, CodingKey {
        case id, name, color, createdAt, notionPageId, isDone, status, priority, startDate, endDate, client
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "indigo"
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        notionPageId = try c.decodeIfPresent(String.self, forKey: .notionPageId)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        priority = try c.decodeIfPresent(String.self, forKey: .priority) ?? ""
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        client = try c.decodeIfPresent(String.self, forKey: .client) ?? ""
    }
}

struct Task: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var projectId: UUID
    var notionPageId: String? = nil
    var isDone: Bool = false
    // Notion-synced properties
    var status: String = ""
    var business: String = ""
    var tracked: String = ""
    var taskType: [String] = []
    var deadline: Date? = nil

    var isFromNotion: Bool { notionPageId != nil }
    static let closedStatuses: Set<String> = ["Done", "Cancelled"]
    var isClosed: Bool { Task.closedStatuses.contains(status) }

    init(name: String, projectId: UUID) {
        self.name = name
        self.projectId = projectId
    }

    enum CodingKeys: String, CodingKey {
        case id, name, projectId, notionPageId, isDone, status, business, tracked, taskType, deadline
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        projectId = try c.decodeIfPresent(UUID.self, forKey: .projectId) ?? UUID()
        notionPageId = try c.decodeIfPresent(String.self, forKey: .notionPageId)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        business = try c.decodeIfPresent(String.self, forKey: .business) ?? ""
        tracked = try c.decodeIfPresent(String.self, forKey: .tracked) ?? ""
        taskType = try c.decodeIfPresent([String].self, forKey: .taskType) ?? []
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
    }
}

struct TimeEntry: Identifiable, Codable {
    var id = UUID()
    var taskId: UUID
    var projectId: UUID
    var startTime: Date
    var endTime: Date?
    var note: String = ""
    var notionPageId: String? = nil  // set once this entry is pushed to Notion

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var isRunning: Bool { endTime == nil }

    var xpEarned: Int {
        guard endTime != nil else { return 0 }
        return max(1, Int(duration / 60))
    }
}
