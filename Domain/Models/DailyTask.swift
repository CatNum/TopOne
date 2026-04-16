import Foundation
import SwiftData

enum TaskRank: String, CaseIterable, Identifiable, Codable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"

    var id: String { rawValue }
}

enum DailyTaskStatus: String, CaseIterable, Identifiable, Codable {
    case notStarted = "未开始"
    case inProgress = "执行中"
    case completed = "已完成"

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .inProgress:
            0
        case .notStarted:
            1
        case .completed:
            2
        }
    }
}

@Model
final class DailyTask {
    static let minTitleLength = 1
    static let maxTitleLength = 32

    var title: String
    var statusRawValue: String
    var rankRawValue: String
    var createdAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var goal: Goal?

    var status: DailyTaskStatus {
        get { DailyTaskStatus(rawValue: statusRawValue) ?? .notStarted }
        set { statusRawValue = newValue.rawValue }
    }

    var rank: TaskRank {
        get { TaskRank(rawValue: rankRawValue) ?? .c }
        set { rankRawValue = newValue.rawValue }
    }

    init(
        title: String,
        rank: TaskRank,
        status: DailyTaskStatus = .notStarted,
        createdAt: Date = .now,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        goal: Goal? = nil
    ) {
        self.title = DailyTask.normalizedTitle(from: title)
        self.rankRawValue = rank.rawValue
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.goal = goal
    }

    static func normalizedTitle(from title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidTitle(_ title: String) -> Bool {
        let normalized = normalizedTitle(from: title)
        return normalized.count >= minTitleLength && normalized.count <= maxTitleLength
    }
}
