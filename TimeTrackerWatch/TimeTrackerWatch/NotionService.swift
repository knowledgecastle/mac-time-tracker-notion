import Foundation

private let kNotionVersion = "2022-06-28"

struct NotionProject { var pageId: String; var name: String; var status: String; var color: String }
struct NotionTask { var pageId: String; var name: String; var projectPageId: String; var status: String }
struct NotionSyncResult { var projects: [NotionProject]; var tasks: [NotionTask] }

enum NotionError: LocalizedError {
    case missingToken, httpError(Int, String), decodingError(String)
    var errorDescription: String? {
        switch self {
        case .missingToken:            return "No Notion token."
        case .httpError(let c, let m): return "Notion error \(c): \(m)"
        case .decodingError(let m):    return "Parse error: \(m)"
        }
    }
}

final class NotionService {
    static let shared = NotionService()
    private init() {}

    // Token + database IDs are entered on the watch in Settings (or seeded via
    // UserDefaults). Nothing is hardcoded, so the app ships with no personal data.
    var token: String {
        get { UserDefaults.standard.string(forKey: "notion_token") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "notion_token") }
    }
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
    var hasToken: Bool { !token.isEmpty }
    var isConfigured: Bool {
        !token.isEmpty && !projectsDBId.isEmpty && !tasksDBId.isEmpty && !timeEntriesDBId.isEmpty
    }

    // MARK: Read

    func sync() async throws -> NotionSyncResult {
        guard isConfigured else { throw NotionError.missingToken }
        let rawProjects = try await queryDatabase(id: projectsDBId)
        let rawTasks = try await queryDatabase(id: tasksDBId)

        var projects: [NotionProject] = []
        var known = Set<String>()
        for page in rawProjects {
            guard let name = title(page, "Project name"), !name.isEmpty,
                  let pageId = page["id"] as? String else { continue }
            let priority = select(page, "Priority") ?? ""
            projects.append(NotionProject(pageId: pageId, name: name,
                                          status: status(page, "Status") ?? "",
                                          color: colorForPriority(priority)))
            known.insert(pageId)
        }

        var tasks: [NotionTask] = []
        for page in rawTasks {
            guard let name = title(page, "Action item"), !name.isEmpty,
                  let pageId = page["id"] as? String,
                  let projPage = firstRelation(page, "Consulting Projects"),
                  known.contains(projPage) else { continue }
            tasks.append(NotionTask(pageId: pageId, name: name, projectPageId: projPage,
                                    status: status(page, "Task Status") ?? ""))
        }
        return NotionSyncResult(projects: projects, tasks: tasks)
    }

    // MARK: Write

    @discardableResult
    func createTimeEntry(taskPageId: String, projectPageId: String?, taskName: String,
                         start: Date, end: Date, hours: Double) async throws -> String {
        var props: [String: Any] = [
            "Entry": ["title": [["text": ["content": taskName]]]],
            "Start–End": ["date": ["start": Self.iso(start), "end": Self.iso(end)]],
            "Hours": ["number": (hours * 100).rounded() / 100],
            "Task": ["relation": [["id": taskPageId]]],
            "Source": ["select": ["name": "Manual"]]
        ]
        if let projectPageId { props["Projects / Clients"] = ["relation": [["id": projectPageId]]] }
        return try await createPage(["parent": ["database_id": timeEntriesDBId], "properties": props])
    }

    func setTaskStatus(pageId: String, status: String) async throws {
        try await patch(pageId, ["Task Status": ["status": ["name": status]]])
    }

    // MARK: HTTP

    private func createPage(_ body: [String: Any]) async throws -> String {
        var req = request(URL(string: "https://api.notion.com/v1/pages")!, "POST")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(data, resp)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else { throw NotionError.decodingError("no id") }
        return id
    }

    private func patch(_ pageId: String, _ properties: [String: Any]) async throws {
        guard hasToken else { return }
        var req = request(URL(string: "https://api.notion.com/v1/pages/\(pageId)")!, "PATCH")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["properties": properties])
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(data, resp)
    }

    private func queryDatabase(id: String) async throws -> [[String: Any]] {
        let url = URL(string: "https://api.notion.com/v1/databases/\(id)/query")!
        var body: [String: Any] = ["page_size": 100]
        var all: [[String: Any]] = []
        var cursor: String? = nil
        repeat {
            if let c = cursor { body["start_cursor"] = c }
            var req = request(url, "POST")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            try Self.check(data, resp)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NotionError.decodingError("not a dict")
            }
            all.append(contentsOf: json["results"] as? [[String: Any]] ?? [])
            let more = json["has_more"] as? Bool ?? false
            cursor = more ? json["next_cursor"] as? String : nil
        } while cursor != nil
        return all
    }

    private func request(_ url: URL, _ method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(kNotionVersion, forHTTPHeaderField: "Notion-Version")
        return req
    }
    private static func check(_ data: Data, _ resp: URLResponse) throws {
        if let http = resp as? HTTPURLResponse, http.statusCode >= 300 {
            throw NotionError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.timeZone = .current; f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    // MARK: Property parsing

    private func title(_ page: [String: Any], _ key: String) -> String? {
        guard let props = page["properties"] as? [String: Any],
              let p = props[key] as? [String: Any],
              let arr = p["title"] as? [[String: Any]] else { return nil }
        let t = arr.compactMap { $0["plain_text"] as? String }.joined()
        return t.isEmpty ? nil : t
    }
    private func status(_ page: [String: Any], _ key: String) -> String? {
        guard let props = page["properties"] as? [String: Any],
              let p = props[key] as? [String: Any],
              let s = p["status"] as? [String: Any] else { return nil }
        return s["name"] as? String
    }
    private func select(_ page: [String: Any], _ key: String) -> String? {
        guard let props = page["properties"] as? [String: Any],
              let p = props[key] as? [String: Any],
              let s = p["select"] as? [String: Any] else { return nil }
        return s["name"] as? String
    }
    private func firstRelation(_ page: [String: Any], _ key: String) -> String? {
        guard let props = page["properties"] as? [String: Any],
              let p = props[key] as? [String: Any],
              let arr = p["relation"] as? [[String: Any]],
              let first = arr.first else { return nil }
        return first["id"] as? String
    }
    private func colorForPriority(_ p: String) -> String {
        switch p { case "High": return "red"; case "Medium": return "orange"; case "Low": return "teal"; default: return "blue" }
    }
}
