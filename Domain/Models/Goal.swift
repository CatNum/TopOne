import Foundation
import SwiftData

@Model
final class Goal {
    static let minTitleLength = 1
    static let maxTitleLength = 16

    var title: String
    var rankRawValue: String
    var isTopOne: Bool
    var progress: Double
    var createdAt: Date
    var lockEndsAt: Date?
    var completedAt: Date?
    var earlySwitchCount: Int

    @Relationship(deleteRule: .cascade, inverse: \DailyTask.goal)
    var dailyTasks: [DailyTask]

    var rank: TaskRank {
        get { TaskRank(rawValue: rankRawValue) ?? .c }
        set { rankRawValue = newValue.rawValue }
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    init(
        title: String,
        rank: TaskRank,
        isTopOne: Bool = false,
        progress: Double = 0,
        createdAt: Date = .now,
        lockEndsAt: Date? = nil,
        completedAt: Date? = nil,
        earlySwitchCount: Int = 0,
        dailyTasks: [DailyTask] = []
    ) {
        self.title = Goal.normalizedTitle(from: title)
        self.rankRawValue = rank.rawValue
        self.isTopOne = isTopOne
        self.progress = Goal.clampedProgress(progress)
        self.createdAt = createdAt
        self.lockEndsAt = lockEndsAt
        self.completedAt = completedAt
        self.earlySwitchCount = max(0, earlySwitchCount)
        self.dailyTasks = dailyTasks
    }

    static func normalizedTitle(from title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidTitle(_ title: String) -> Bool {
        let normalized = normalizedTitle(from: title)
        return normalized.count >= minTitleLength && normalized.count <= maxTitleLength
    }

    static func clampedProgress(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
    }

    var remainingLockDurationText: String? {
        guard let lockEndsAt else {
            return nil
        }

        let remainingSeconds = Int(lockEndsAt.timeIntervalSinceNow)
        if remainingSeconds <= 0 {
            return "已可切换"
        }

        let days = remainingSeconds / 86_400
        if days > 0 {
            return "剩余 \(days) 天"
        }

        let hours = max(1, remainingSeconds / 3_600)
        return "剩余 \(hours) 小时"
    }
}
