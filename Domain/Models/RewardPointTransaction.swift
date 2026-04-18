import Foundation
import SwiftData

enum RewardPointChangeKind: String, Codable {
    case earn
    case spend
}

enum RewardPointChangeReason: String, Codable {
    case completeDailyTask
    case completeGoal
    case drawReward
    case exchangeReward
}

@Model
final class RewardPointTransaction {
    var pointsDelta: Int
    var balanceAfterChange: Int
    var kindRawValue: String
    var reasonRawValue: String
    var rankRawValue: String
    var referenceTitle: String
    var createdAt: Date

    var kind: RewardPointChangeKind {
        get { RewardPointChangeKind(rawValue: kindRawValue) ?? .earn }
        set { kindRawValue = newValue.rawValue }
    }

    var reason: RewardPointChangeReason {
        get { RewardPointChangeReason(rawValue: reasonRawValue) ?? .completeDailyTask }
        set { reasonRawValue = newValue.rawValue }
    }

    var rank: TaskRank {
        get { TaskRank(rawValue: rankRawValue) ?? .c }
        set { rankRawValue = newValue.rawValue }
    }

    init(
        pointsDelta: Int,
        balanceAfterChange: Int,
        kind: RewardPointChangeKind,
        reason: RewardPointChangeReason,
        rank: TaskRank,
        referenceTitle: String = "",
        createdAt: Date = .now
    ) {
        self.pointsDelta = pointsDelta
        self.balanceAfterChange = max(0, balanceAfterChange)
        self.kindRawValue = kind.rawValue
        self.reasonRawValue = reason.rawValue
        self.rankRawValue = rank.rawValue
        self.referenceTitle = referenceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}
