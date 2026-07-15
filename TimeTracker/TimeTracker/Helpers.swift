import Foundation
import SwiftUI
import AppKit

extension TimeInterval {
    var formatted: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
    
    var shortFormatted: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}

extension Color {
    static let projectColors: [(name: String, color: Color)] = [
        ("indigo",  .indigo),
        ("blue",    .blue),
        ("teal",    .teal),
        ("green",   .green),
        ("orange",  .orange),
        ("pink",    .pink),
        ("purple",  .purple),
        ("red",     .red),
    ]

    static func projectColor(named name: String) -> Color {
        projectColors.first { $0.name == name }?.color ?? .indigo
    }

    /// Color for a Notion status / stage value.
    static func statusColor(_ status: String) -> Color {
        switch status {
        case "In progress":              return .blue
        case "New request", "Quoted":    return .teal
        case "Client Revision", "On-Hold": return .orange
        case "Not started":              return .gray
        case "Done", "Paid":             return .green
        case "Dead", "Cancelled":        return .red
        default:                          return .secondary
        }
    }

    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }

    /// A color that resolves differently for light vs dark appearance.
    static func dynamic(_ light: Color, _ dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
    }
}

// MARK: - Notion design tokens

/// Notion's visual language (light + dark), adapted for this app.
enum NTheme {
    static let bg            = Color.dynamic(Color(hex: 0xFFFFFF), Color(hex: 0x191919))
    static let sidebar       = Color.dynamic(Color(hex: 0xF7F7F5), Color(hex: 0x202020))
    static let text          = Color.dynamic(Color(hex: 0x37352F), Color(hex: 0xE6E6E5))
    static let textSecondary = Color.dynamic(Color(hex: 0x787774), Color(hex: 0x9B9B9B))
    static let textTertiary  = Color.dynamic(Color(hex: 0x9B9A97), Color(hex: 0x6E6E6E))
    static let divider       = Color.dynamic(Color(hex: 0x37352F, alpha: 0.09), Color(hex: 0xFFFFFF, alpha: 0.094))
    static let hover         = Color.dynamic(Color(hex: 0x37352F, alpha: 0.045), Color(hex: 0xFFFFFF, alpha: 0.055))
    static let hoverStrong   = Color.dynamic(Color(hex: 0x37352F, alpha: 0.08), Color(hex: 0xFFFFFF, alpha: 0.09))
    static let selected      = Color.dynamic(Color(hex: 0x2383E2, alpha: 0.11), Color(hex: 0x2383E2, alpha: 0.24))
    static let blue          = Color(hex: 0x2383E2)
    static let inputBg       = Color.dynamic(Color(hex: 0x37352F, alpha: 0.05), Color(hex: 0xFFFFFF, alpha: 0.06))
    static let cardBg        = Color.dynamic(Color(hex: 0xFFFFFF), Color(hex: 0x232323))
    static let cardBorder    = Color.dynamic(Color(hex: 0x37352F, alpha: 0.10), Color(hex: 0xFFFFFF, alpha: 0.10))

    /// Notion pastel tag palette: (background, foreground text) — adaptive.
    enum Tag {
        static let gray   = (bg: Color.dynamic(Color(hex: 0xE3E2E0, alpha: 0.7), Color(hex: 0xFFFFFF, alpha: 0.09)), fg: Color.dynamic(Color(hex: 0x373530), Color(hex: 0xB4B4B4)))
        static let brown  = (bg: Color.dynamic(Color(hex: 0xEEE0DA), Color(hex: 0x3A2E28)), fg: Color.dynamic(Color(hex: 0x64473A), Color(hex: 0xC1957D)))
        static let orange = (bg: Color.dynamic(Color(hex: 0xFAEBDD), Color(hex: 0x3D2E1F)), fg: Color.dynamic(Color(hex: 0x77552B), Color(hex: 0xD9A05B)))
        static let yellow = (bg: Color.dynamic(Color(hex: 0xFBF3DB), Color(hex: 0x3A331F)), fg: Color.dynamic(Color(hex: 0x7A6A2B), Color(hex: 0xD9C179)))
        static let green  = (bg: Color.dynamic(Color(hex: 0xDDEDEA), Color(hex: 0x1F332E)), fg: Color.dynamic(Color(hex: 0x2C5850), Color(hex: 0x6BC0A8)))
        static let blue   = (bg: Color.dynamic(Color(hex: 0xDDEBF1), Color(hex: 0x1E3A4D)), fg: Color.dynamic(Color(hex: 0x28456C), Color(hex: 0x6BB1DF)))
        static let purple = (bg: Color.dynamic(Color(hex: 0xEAE4F2), Color(hex: 0x2E2440)), fg: Color.dynamic(Color(hex: 0x492F64), Color(hex: 0xB18BD9)))
        static let pink   = (bg: Color.dynamic(Color(hex: 0xF4DFEB), Color(hex: 0x3A2430)), fg: Color.dynamic(Color(hex: 0x6D3A4E), Color(hex: 0xD98BB0)))
        static let red    = (bg: Color.dynamic(Color(hex: 0xFBE4E4), Color(hex: 0x3A2422)), fg: Color.dynamic(Color(hex: 0x6E3630), Color(hex: 0xE08A82)))
    }

    /// A saturated dot color for status pills.
    static func statusDot(_ status: String) -> Color {
        switch status {
        case "In progress":                return Color(hex: 0x337EA9)
        case "Done", "Paid":               return Color(hex: 0x448361)
        case "Client Revision", "On-Hold": return Color(hex: 0xCB912F)
        case "Dead", "Cancelled":          return Color(hex: 0xD44C47)
        case "New request", "Quoted":      return Color(hex: 0x9065B0)
        default:                            return Color(hex: 0x9B9A97) // Not started / unknown
        }
    }

    static func tagColors(forStatus status: String) -> (bg: Color, fg: Color) {
        switch status {
        case "In progress":                return Tag.blue
        case "Done", "Paid":               return Tag.green
        case "Client Revision", "On-Hold": return Tag.yellow
        case "Dead", "Cancelled":          return Tag.red
        case "New request", "Quoted":      return Tag.purple
        default:                            return Tag.gray
        }
    }

    static func tagColors(forPriority priority: String) -> (bg: Color, fg: Color) {
        switch priority {
        case "High":   return Tag.red
        case "Medium": return Tag.yellow
        case "Low":    return Tag.green
        default:        return Tag.gray
        }
    }
}

// MARK: - Date display

enum DateFmt {
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// e.g. "Jul 1 → Aug 15", "from Jul 1", "due Aug 15", or "" when no dates.
    static func range(_ start: Date?, _ end: Date?) -> String {
        switch (start, end) {
        case let (s?, e?): return "\(short.string(from: s)) → \(short.string(from: e))"
        case let (s?, nil): return "from \(short.string(from: s))"
        case let (nil, e?): return "due \(short.string(from: e))"
        default: return ""
        }
    }
}

// MARK: - Notion-style filtering

struct FilterFacet: Identifiable {
    let id: String       // the facet key (also the property name)
    let title: String
    let options: [String]
}

struct DBFilterState: Equatable {
    var search: String = ""
    var selected: [String: Set<String>] = [:]

    /// An item passes when: its name matches the search, and for every facet with
    /// a selection, the item's value(s) intersect that selection. Items with no
    /// value for a facet are not filtered out by it.
    func passes(name: String, values: [String: [String]]) -> Bool {
        if !search.isEmpty && !name.localizedCaseInsensitiveContains(search) { return false }
        for (facet, chosen) in selected where !chosen.isEmpty {
            let vals = values[facet] ?? []
            if vals.isEmpty { continue }
            if Set(vals).isDisjoint(with: chosen) { return false }
        }
        return true
    }

    var activeFacetCount: Int {
        selected.values.reduce(0) { $0 + ($1.isEmpty ? 0 : 1) }
    }
}

/// A Notion status pill: a colored dot + label on a soft tinted capsule.
struct StatusPill: View {
    let status: String
    var body: some View {
        if !status.isEmpty {
            let c = NTheme.tagColors(forStatus: status)
            HStack(spacing: 5) {
                Circle().fill(NTheme.statusDot(status)).frame(width: 7, height: 7)
                Text(status).font(.system(size: 12)).foregroundStyle(c.fg)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(c.bg, in: Capsule())
        }
    }
}

/// A Notion select/tag chip (rounded rectangle, pastel fill).
struct NotionTag: View {
    let text: String
    let colors: (bg: Color, fg: Color)
    init(_ text: String, colors: (bg: Color, fg: Color)) { self.text = text; self.colors = colors }

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(colors.fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(colors.bg, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// A column-header cell with a small property-type glyph, Notion-style.
struct PropertyHeader: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10)).foregroundStyle(NTheme.textTertiary)
            Text(title).font(.system(size: 12)).foregroundStyle(NTheme.textTertiary)
        }
    }
}

/// A collapsible database group header: ▸/▾ toggle · colored dot · name · count.
struct GroupHeaderRow: View {
    let title: String
    let count: Int
    let dotColor: Color?
    let isExpanded: Bool
    var trailing: String? = nil
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NTheme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                if let dotColor {
                    Circle().fill(dotColor).frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NTheme.text)
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundStyle(NTheme.textTertiary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(NTheme.textTertiary)
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One filter chip with a popover of multi-select options (stays open for
/// multiple picks, like Notion).
struct FacetChip: View {
    let facet: FilterFacet
    @Binding var selection: Set<String>
    @State private var show = false

    var body: some View {
        Button { show.toggle() } label: {
            HStack(spacing: 4) {
                Text(selection.isEmpty ? facet.title : "\(facet.title): \(selection.count)")
                    .font(.system(size: 12))
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(selection.isEmpty ? NTheme.textSecondary : NTheme.blue)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                selection.isEmpty ? Color.clear : NTheme.selected,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $show, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text(facet.title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(NTheme.textTertiary)
                    .padding(.bottom, 4)
                ForEach(facet.options, id: \.self) { opt in
                    Button {
                        if selection.contains(opt) { selection.remove(opt) } else { selection.insert(opt) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selection.contains(opt) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selection.contains(opt) ? NTheme.blue : NTheme.textTertiary)
                            Text(opt).font(.system(size: 12)).foregroundStyle(NTheme.text)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 3)
                }
                if !selection.isEmpty {
                    Divider().padding(.vertical, 3)
                    Button("Clear") { selection.removeAll() }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundStyle(NTheme.textSecondary)
                }
            }
            .padding(12)
            .frame(minWidth: 180)
        }
    }
}

/// A Notion-style toolbar: search field + Filter facet chips + reset.
struct FilterBar: View {
    let facets: [FilterFacet]
    @Binding var state: DBFilterState

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(NTheme.textTertiary)
                TextField("Search", text: $state.search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(NTheme.text)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(NTheme.inputBg, in: RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 190)

            ForEach(facets) { facet in
                FacetChip(facet: facet, selection: Binding(
                    get: { state.selected[facet.id] ?? [] },
                    set: { state.selected[facet.id] = $0 }
                ))
            }

            if state.activeFacetCount > 0 || !state.search.isEmpty {
                Button { state = DBFilterState() } label: {
                    Text("Reset").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(NTheme.textSecondary)
                .padding(.leading, 2)
            }

            Spacer(minLength: 0)
        }
    }
}

enum DBViewMode: String { case table, board }

/// Table / Board tab switcher for a database toolbar.
struct ViewModeTabs: View {
    @Binding var mode: DBViewMode

    var body: some View {
        HStack(spacing: 10) {
            tab("Table", "tablecells", .table)
            tab("Board", "rectangle.split.3x1", .board)
        }
    }

    private func tab(_ title: String, _ icon: String, _ m: DBViewMode) -> some View {
        Button { mode = m } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(mode == m ? NTheme.text : NTheme.textTertiary)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                if mode == m { Rectangle().fill(NTheme.text).frame(height: 1.5) }
            }
        }
        .buttonStyle(.plain)
    }
}

/// A Kanban board column: header (dot + title + count) with a stack of cards.
/// Accepts dropped card ids via `onDropId` (drag-to-change-status).
struct BoardColumn<Card: View>: View {
    let title: String
    let count: Int
    let dotColor: Color
    var onDropId: ((String) -> Void)? = nil
    @ViewBuilder var cards: () -> Card
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(NTheme.text)
                Text("\(count)").font(.system(size: 12)).foregroundStyle(NTheme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 4)
            cards()
            Spacer(minLength: 0)
        }
        .frame(width: 250, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 4)
        .background(targeted ? NTheme.selected : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first, let cb = onDropId else { return false }
            cb(first); return true
        } isTargeted: { targeted = $0 }
    }
}

/// A card container used inside board columns. Draggable when `dragId` is set.
struct BoardCard<Content: View>: View {
    var dragId: String? = nil
    let onTap: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var hover = false

    var body: some View {
        let card = Button(action: onTap) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(NTheme.cardBg, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(NTheme.cardBorder, lineWidth: 1))
                .shadow(color: .black.opacity(hover ? 0.08 : 0.03), radius: hover ? 4 : 2, y: 1)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }

        if let dragId {
            card.draggable(dragId)
        } else {
            card
        }
    }
}

// MARK: - Inline editors

/// A text field that commits its value on Return or when focus leaves.
struct EditableText: View {
    @State private var text: String
    let placeholder: String
    let font: Font
    let allowEmpty: Bool
    let onCommit: (String) -> Void
    @FocusState private var focused: Bool

    init(_ initial: String, placeholder: String = "Untitled", font: Font = .system(size: 13), allowEmpty: Bool = false, onCommit: @escaping (String) -> Void) {
        _text = State(initialValue: initial)
        self.placeholder = placeholder
        self.font = font
        self.allowEmpty = allowEmpty
        self.onCommit = onCommit
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(NTheme.text)
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { _, now in if !now { commit() } }
    }
    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if allowEmpty || !trimmed.isEmpty { onCommit(trimmed) }
    }
}

/// How to render each option in a picker popover.
enum OptionStyle {
    case plain, status, priority, tag, blueTag

    @ViewBuilder func chip(_ opt: String) -> some View {
        switch self {
        case .plain:    Text(opt).font(.system(size: 12)).foregroundStyle(NTheme.text)
        case .status:   StatusPill(status: opt)
        case .priority: NotionTag(opt, colors: NTheme.tagColors(forPriority: opt))
        case .tag:      NotionTag(opt, colors: NTheme.Tag.gray)
        case .blueTag:  NotionTag(opt, colors: NTheme.Tag.blue)
        }
    }
}

/// A single option row in a picker popover, with hover highlight.
struct OptionRow<Content: View>: View {
    var leading: String? = nil   // optional SF Symbol (e.g. checkbox)
    var leadingOn: Bool = false
    let action: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let leading {
                    Image(systemName: leading).font(.system(size: 12))
                        .foregroundStyle(leadingOn ? NTheme.blue : NTheme.textTertiary)
                }
                content()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hover ? NTheme.hover : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// A button whose label opens a single-select option popover. `onSelect(nil)` clears.
struct OptionPicker<Label: View>: View {
    let options: [String]
    var allowNone: Bool = true
    var style: OptionStyle = .plain
    let onSelect: (String?) -> Void
    @ViewBuilder var label: () -> Label
    @State private var show = false

    var body: some View {
        Button { show.toggle() } label: {
            label().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $show, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                if allowNone {
                    OptionRow(action: { onSelect(nil); show = false }) {
                        Text("Empty").font(.system(size: 12)).foregroundStyle(NTheme.textSecondary)
                    }
                }
                ForEach(options, id: \.self) { opt in
                    OptionRow(action: { onSelect(opt); show = false }) {
                        style.chip(opt)
                    }
                }
            }
            .padding(6)
            .frame(minWidth: 190)
        }
    }
}

/// A button whose label opens a multi-select popover.
struct MultiOptionPicker<Label: View>: View {
    let options: [String]
    let selected: [String]
    var style: OptionStyle = .plain
    let onChange: ([String]) -> Void
    @ViewBuilder var label: () -> Label
    @State private var show = false

    var body: some View {
        Button { show.toggle() } label: { label().contentShape(Rectangle()) }
            .buttonStyle(.plain)
            .popover(isPresented: $show, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(options, id: \.self) { opt in
                        OptionRow(leading: selected.contains(opt) ? "checkmark.square.fill" : "square",
                                  leadingOn: selected.contains(opt),
                                  action: { toggle(opt) }) {
                            style.chip(opt)
                        }
                    }
                }
                .padding(6).frame(minWidth: 190)
            }
    }
    private func toggle(_ opt: String) {
        var set = selected
        if let idx = set.firstIndex(of: opt) { set.remove(at: idx) } else { set.append(opt) }
        onChange(set)
    }
}

/// A button whose label opens a calendar to set/clear a date.
struct DateEditButton<Label: View>: View {
    let date: Date?
    let onSet: (Date?) -> Void
    @ViewBuilder var label: () -> Label
    @State private var show = false
    @State private var temp = Date()

    var body: some View {
        Button { temp = date ?? Date(); show.toggle() } label: { label().contentShape(Rectangle()) }
            .buttonStyle(.plain)
            .popover(isPresented: $show, arrowEdge: .bottom) {
                VStack(spacing: 8) {
                    DatePicker("", selection: $temp, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    HStack {
                        Button("Clear") { onSet(nil); show = false }
                            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(NTheme.textSecondary)
                        Spacer()
                        Button("Set") { onSet(temp); show = false }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(NTheme.blue)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(10).frame(width: 260)
            }
    }
}

/// Notion's "Open in side peek" button — a raised, bordered chip with an icon
/// that appears on row hover. Lifts slightly on its own hover.
struct OpenPeekButton: View {
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "sidebar.right").font(.system(size: 10, weight: .medium))
                Text("OPEN").font(.system(size: 10, weight: .semibold)).tracking(0.3)
            }
            .foregroundStyle(hover ? NTheme.text : NTheme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(NTheme.cardBg)
                    .shadow(color: .black.opacity(hover ? 0.14 : 0.07), radius: hover ? 3.5 : 1.5, y: hover ? 1.5 : 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(NTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Open in side peek")
    }
}

/// A subtle placeholder shown when a property is empty and editable.
struct EmptyValue: View {
    var body: some View {
        Text("Empty").font(.system(size: 13)).foregroundStyle(NTheme.textTertiary)
    }
}

/// One property row inside a peek panel: icon + label on the left, value on the right.
struct PeekPropRow<Content: View>: View {
    let icon: String
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(NTheme.textTertiary).frame(width: 15)
                Text(label).font(.system(size: 12)).foregroundStyle(NTheme.textSecondary)
            }
            .frame(width: 108, alignment: .leading)

            content()
                .font(.system(size: 13))
                .foregroundStyle(NTheme.text)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }
}

/// Wraps content in a right-side sliding peek panel with a dimming scrim.
struct PeekOverlay<Panel: View>: View {
    let isPresented: Bool
    let onClose: () -> Void
    @ViewBuilder var panel: () -> Panel

    var body: some View {
        if isPresented {
            ZStack(alignment: .trailing) {
                Color.black.opacity(0.18).ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                panel()
                    .frame(width: 400)
                    .frame(maxHeight: .infinity)
                    .background(NTheme.bg)
                    .overlay(alignment: .leading) { Rectangle().fill(NTheme.divider).frame(width: 1) }
                    .transition(.move(edge: .trailing))
            }
        }
    }
}

/// Order option lists by a canonical sequence, keeping any extras at the end.
func orderedOptions(_ present: Set<String>, canonical: [String]) -> [String] {
    var result = canonical.filter { present.contains($0) }
    result.append(contentsOf: present.subtracting(result).sorted())
    return result
}
