import Foundation

// MARK: - Models (slim, watch-focused)

struct Project: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var color: String = "blue"
    var notionPageId: String? = nil
    var status: String = ""

    var isFromNotion: Bool { notionPageId != nil }
    static let closedStatuses: Set<String> = ["Paid", "Done", "Dead"]
    var isClosed: Bool { Project.closedStatuses.contains(status) }
}

struct Task: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var projectId: UUID
    var notionPageId: String? = nil
    var status: String = ""

    var isFromNotion: Bool { notionPageId != nil }
    static let closedStatuses: Set<String> = ["Done", "Cancelled"]
    var isClosed: Bool { Task.closedStatuses.contains(status) }
}

struct TimeEntry: Identifiable, Codable {
    var id = UUID()
    var taskId: UUID
    var projectId: UUID
    var startTime: Date
    var endTime: Date?
    var notionPageId: String? = nil

    var duration: TimeInterval { (endTime ?? Date()).timeIntervalSince(startTime) }
    var isRunning: Bool { endTime == nil }
}

// MARK: - Duration formatting

extension TimeInterval {
    var clock: String {
        let h = Int(self) / 3600, m = (Int(self) % 3600) / 60, s = Int(self) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
    var shortText: String {
        let h = Int(self) / 3600, m = (Int(self) % 3600) / 60, s = Int(self) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
}
