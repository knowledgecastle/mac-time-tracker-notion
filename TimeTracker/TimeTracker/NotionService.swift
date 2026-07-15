import Foundation

private let kNotionVersion = "2022-06-28"

// Property names — must match the Notion databases exactly.
// Note: "Start–End" uses an en-dash (–), not a hyphen.
private enum Prop {
    static let projectTitle   = "Project name"
    static let projectStatus  = "Status"
    static let projectPriority = "Priority"

    static let taskTitle      = "Action item"
    static let taskStatus     = "Task Status"
    static let taskProjectRel = "Consulting Projects"

    static let entryTitle     = "Entry"
    static let entryRange     = "Start–End"
    static let entryHours     = "Hours"
    static let entryTaskRel   = "Task"
    static let entryProjRel   = "Projects / Clients"
    static let entrySource    = "Source"
}

// Raw records pulled from Notion. The AppStore reconciles these into its
// local model by matching on `pageId`, so local UUIDs stay stable across syncs.
struct NotionProject {
    var pageId: String
    var name: String
    var color: String
    var status: String
    var priority: String
    var startDate: Date?
    var endDate: Date?
    var client: String
}

struct NotionTask {
    var pageId: String
    var name: String
    var projectPageId: String
    var status: String
    var business: String
    var tracked: String
    var taskType: [String]
    var deadline: Date?
}

struct NotionSyncResult {
    var projects: [NotionProject]
    var tasks: [NotionTask]
}

enum NotionError: LocalizedError {
    case missingToken
    case httpError(Int, String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:             return "Notion isn't configured. Add your token and the three database IDs in Settings."
        case .httpError(let c, let m):  return "Notion API error \(c): \(m)"
        case .decodingError(let m):     return "Could not parse Notion response: \(m)"
        }
    }
}

class NotionService {
    static let shared = NotionService()
    private init() {}

    // MARK: - Token

    var token: String {
        get { UserDefaults.standard.string(forKey: "notion_token") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "notion_token") }
    }
    var hasToken: Bool { !token.isEmpty }

    // MARK: - Database IDs
    // Each user points the app at their own three Notion databases (entered in
    // Settings). Nothing is hardcoded so the app ships with no personal data.

    var projectsDBId: String {
        get { UserDefaults.standard.string(forKey: "notion_projects_db") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "notion_projects_db") }
    }
    var tasksDBId: String {
        get { UserDefaults.standard.string(forKey: "notion_tasks_db") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "notion_tasks_db") }
    }
    var timeEntriesDBId: String {
        get { UserDefaults.standard.string(forKey: "notion_time_entries_db") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "notion_time_entries_db") }
    }
    var isConfigured: Bool {
        !token.isEmpty && !projectsDBId.isEmpty && !tasksDBId.isEmpty && !timeEntriesDBId.isEmpty
    }

    // MARK: - Sync (Notion -> app)

    func sync() async throws -> NotionSyncResult {
        guard isConfigured else { throw NotionError.missingToken }

        let rawProjects = try await queryDatabase(id: projectsDBId)
        let rawTasks    = try await queryDatabase(id: tasksDBId)

        var projects: [NotionProject] = []
        var knownProjectPageIds = Set<String>()

        // Pull all projects with their properties; visibility is decided by the
        // in-app filters, not hardcoded here.
        for page in rawProjects {
            guard let name = titleProperty(page, key: Prop.projectTitle), !name.isEmpty,
                  let pageId = page["id"] as? String else { continue }

            let priority = selectProperty(page, key: Prop.projectPriority) ?? ""
            projects.append(NotionProject(
                pageId: pageId,
                name: name,
                color: colorForPriority(priority.isEmpty ? "Medium" : priority),
                status: statusProperty(page, key: Prop.projectStatus) ?? "",
                priority: priority,
                startDate: dateProperty(page, key: "Start date"),
                endDate: dateProperty(page, key: "End date"),
                client: richTextProperty(page, key: "Client")
            ))
            knownProjectPageIds.insert(pageId)
        }

        var tasks: [NotionTask] = []

        for page in rawTasks {
            guard let name = titleProperty(page, key: Prop.taskTitle), !name.isEmpty,
                  let pageId = page["id"] as? String,
                  let projectPageId = firstRelationId(page, key: Prop.taskProjectRel),
                  knownProjectPageIds.contains(projectPageId) else { continue }

            tasks.append(NotionTask(
                pageId: pageId,
                name: name,
                projectPageId: projectPageId,
                status: statusProperty(page, key: Prop.taskStatus) ?? "",
                business: selectProperty(page, key: "Business") ?? "",
                tracked: selectProperty(page, key: "Tracked?") ?? "",
                taskType: multiSelectProperty(page, key: "Task type"),
                deadline: dateProperty(page, key: "Deadline")
            ))
        }

        return NotionSyncResult(projects: projects, tasks: tasks)
    }

    // MARK: - Write-back (app -> Notion)

    /// Create a Time Entry row linked to the task (and project). Returns the new page id.
    /// Notion's rollups on the Task then update the task's total hours automatically.
    @discardableResult
    func createTimeEntry(taskPageId: String,
                         projectPageId: String?,
                         taskName: String,
                         start: Date,
                         end: Date,
                         hours: Double,
                         note: String) async throws -> String {
        var properties: [String: Any] = [
            Prop.entryTitle: [
                "title": [["text": ["content": taskName]]]
            ],
            Prop.entryRange: [
                "date": ["start": Self.iso(start), "end": Self.iso(end)]
            ],
            Prop.entryHours: [
                "number": (hours * 100).rounded() / 100
            ],
            Prop.entryTaskRel: [
                "relation": [["id": taskPageId]]
            ],
            Prop.entrySource: [
                "select": ["name": "Manual"]
            ]
        ]
        if let projectPageId {
            properties[Prop.entryProjRel] = ["relation": [["id": projectPageId]]]
        }
        if !note.isEmpty {
            properties["Notes"] = ["rich_text": [["text": ["content": note]]]]
        }

        let body: [String: Any] = [
            "parent": ["database_id": timeEntriesDBId],
            "properties": properties
        ]
        return try await createPage(body: body)
    }

    /// Create a new task in the Tasks DB linked to a project. Returns the new page id.
    @discardableResult
    func createTask(name: String, projectPageId: String) async throws -> String {
        let body: [String: Any] = [
            "parent": ["database_id": tasksDBId],
            "properties": [
                Prop.taskTitle: ["title": [["text": ["content": name]]]],
                Prop.taskProjectRel: ["relation": [["id": projectPageId]]],
                Prop.taskStatus: ["status": ["name": "Not started"]]
            ]
        ]
        return try await createPage(body: body)
    }

    /// Push a task's done/active state to Notion's status property.
    func updateTaskStatus(pageId: String, done: Bool) async throws {
        try await patchPage(pageId: pageId, properties: [
            Prop.taskStatus: ["status": ["name": done ? "Done" : "In progress"]]
        ])
    }

    /// Rename a task in Notion.
    func renameTask(pageId: String, name: String) async throws {
        try await patchPage(pageId: pageId, properties: [
            Prop.taskTitle: ["title": [["text": ["content": name]]]]
        ])
    }

    // MARK: - Field edits (app -> Notion)

    // Tasks
    func setTaskStatus(pageId: String, status: String) async throws {
        try await patchPage(pageId: pageId, properties: [Prop.taskStatus: ["status": ["name": status]]])
    }
    func setTaskBusiness(pageId: String, value: String?) async throws {
        try await patchPage(pageId: pageId, properties: ["Business": Self.selectPayload(value)])
    }
    func setTaskType(pageId: String, values: [String]) async throws {
        try await patchPage(pageId: pageId, properties: ["Task type": ["multi_select": values.map { ["name": $0] }]])
    }
    func setTaskDeadline(pageId: String, date: Date?) async throws {
        try await patchPage(pageId: pageId, properties: ["Deadline": Self.datePayload(date)])
    }
    func setTaskProject(pageId: String, projectPageId: String) async throws {
        try await patchPage(pageId: pageId, properties: [Prop.taskProjectRel: ["relation": [["id": projectPageId]]]])
    }

    // Projects
    func renameProject(pageId: String, name: String) async throws {
        try await patchPage(pageId: pageId, properties: [Prop.projectTitle: ["title": [["text": ["content": name]]]]])
    }
    func setProjectStatus(pageId: String, status: String) async throws {
        try await patchPage(pageId: pageId, properties: [Prop.projectStatus: ["status": ["name": status]]])
    }
    func setProjectPriority(pageId: String, value: String?) async throws {
        try await patchPage(pageId: pageId, properties: [Prop.projectPriority: Self.selectPayload(value)])
    }
    func setProjectDates(pageId: String, start: Date?, end: Date?) async throws {
        try await patchPage(pageId: pageId, properties: [
            "Start date": Self.datePayload(start),
            "End date": Self.datePayload(end)
        ])
    }
    func setProjectClient(pageId: String, text: String) async throws {
        try await patchPage(pageId: pageId, properties: [
            "Client": ["rich_text": text.isEmpty ? [] : [["text": ["content": text]]]]
        ])
    }

    // Time entries
    func updateTimeEntry(pageId: String, start: Date, end: Date, hours: Double, note: String) async throws {
        try await patchPage(pageId: pageId, properties: [
            Prop.entryRange: ["date": ["start": Self.iso(start), "end": Self.iso(end)]],
            Prop.entryHours: ["number": (hours * 100).rounded() / 100],
            "Notes": ["rich_text": note.isEmpty ? [] : [["text": ["content": note]]]]
        ])
    }

    /// Archive (delete) any page in Notion — used when the app deletes a task/project/entry.
    func archivePage(pageId: String) async throws {
        guard hasToken else { return }
        let url = URL(string: "https://api.notion.com/v1/pages/\(pageId)")!
        var req = authorizedRequest(url: url, method: "PATCH")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["archived": true])
        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.throwIfError(data: data, response: response)
    }

    /// Build a select property payload, or a null to clear it.
    private static func selectPayload(_ value: String?) -> Any {
        if let value, !value.isEmpty { return ["select": ["name": value]] }
        return ["select": NSNull()]
    }
    /// Build a date property payload (date-only), or a null to clear it.
    private static func datePayload(_ date: Date?) -> Any {
        if let date { return ["date": ["start": isoDateOnly(date)]] }
        return ["date": NSNull()]
    }

    // MARK: - HTTP helpers

    private func createPage(body: [String: Any]) async throws -> String {
        let url = URL(string: "https://api.notion.com/v1/pages")!
        var req = authorizedRequest(url: url, method: "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.throwIfError(data: data, response: response)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw NotionError.decodingError("Create page: no id in response")
        }
        return id
    }

    private func patchPage(pageId: String, properties: [String: Any]) async throws {
        guard hasToken else { return }
        let url = URL(string: "https://api.notion.com/v1/pages/\(pageId)")!
        var req = authorizedRequest(url: url, method: "PATCH")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["properties": properties])

        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.throwIfError(data: data, response: response)
    }

    private func queryDatabase(id: String, filter: [String: Any]? = nil) async throws -> [[String: Any]] {
        let url = URL(string: "https://api.notion.com/v1/databases/\(id)/query")!
        var body: [String: Any] = ["page_size": 100]
        if let filter { body["filter"] = filter }

        var allResults: [[String: Any]] = []
        var cursor: String? = nil

        repeat {
            if let c = cursor { body["start_cursor"] = c }
            var req = authorizedRequest(url: url, method: "POST")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: req)
            try Self.throwIfError(data: data, response: response)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NotionError.decodingError("Top-level JSON not a dict")
            }
            allResults.append(contentsOf: json["results"] as? [[String: Any]] ?? [])

            let hasMore = json["has_more"] as? Bool ?? false
            cursor = hasMore ? json["next_cursor"] as? String : nil
        } while cursor != nil

        return allResults
    }

    private func authorizedRequest(url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(kNotionVersion, forHTTPHeaderField: "Notion-Version")
        return req
    }

    private static func throwIfError(data: Data, response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NotionError.httpError(http.statusCode, msg)
        }
    }

    private static func iso(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone.current
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.string(from: date)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static func isoDateOnly(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    // MARK: - Property parsing

    private func titleProperty(_ page: [String: Any], key: String) -> String? {
        guard let props = page["properties"] as? [String: Any],
              let prop  = props[key] as? [String: Any],
              let arr   = prop["title"] as? [[String: Any]] else { return nil }
        // Concatenate all rich-text segments so multi-run titles come through whole.
        let text = arr.compactMap { $0["plain_text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }

    private func statusProperty(_ page: [String: Any], key: String) -> String? {
        guard let props = page["properties"] as? [String: Any],
              let prop  = props[key] as? [String: Any],
              let status = prop["status"] as? [String: Any],
              let name  = status["name"] as? String else { return nil }
        return name
    }

    private func selectProperty(_ page: [String: Any], key: String) -> String? {
        guard let props = page["properties"] as? [String: Any],
              let prop  = props[key] as? [String: Any],
              let sel   = prop["select"] as? [String: Any],
              let name  = sel["name"] as? String else { return nil }
        return name
    }

    private func multiSelectProperty(_ page: [String: Any], key: String) -> [String] {
        guard let props = page["properties"] as? [String: Any],
              let prop  = props[key] as? [String: Any],
              let arr   = prop["multi_select"] as? [[String: Any]] else { return [] }
        return arr.compactMap { $0["name"] as? String }
    }

    private func richTextProperty(_ page: [String: Any], key: String) -> String {
        guard let props = page["properties"] as? [String: Any],
              let prop  = props[key] as? [String: Any],
              let arr   = prop["rich_text"] as? [[String: Any]] else { return "" }
        return arr.compactMap { $0["plain_text"] as? String }.joined()
    }

    /// Parse the `start` of a Notion date property (handles date-only and datetime).
    private func dateProperty(_ page: [String: Any], key: String) -> Date? {
        guard let props = page["properties"] as? [String: Any],
              let prop  = props[key] as? [String: Any],
              let date  = prop["date"] as? [String: Any],
              let start = date["start"] as? String else { return nil }
        return Self.parseNotionDate(start)
    }

    private static let notionDateTimeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let notionDateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func parseNotionDate(_ s: String) -> Date? {
        if let d = notionDateTimeFormatter.date(from: s) { return d }
        return notionDateOnlyFormatter.date(from: s)
    }

    private func firstRelationId(_ page: [String: Any], key: String) -> String? {
        guard let props = page["properties"] as? [String: Any],
              let prop  = props[key] as? [String: Any],
              let arr   = prop["relation"] as? [[String: Any]],
              let first = arr.first,
              let id    = first["id"] as? String else { return nil }
        return id
    }

    private func colorForPriority(_ priority: String) -> String {
        switch priority {
        case "High":   return "red"
        case "Medium": return "orange"
        case "Low":    return "teal"
        default:       return "indigo"
        }
    }
}
