import Foundation
import SwiftData

enum RewardAvailabilityMode: String, CaseIterable, Identifiable, Codable {
    case unlimited = "unlimited"
    case limited = "limited"

    var id: String { rawValue }
}

@Model
final class RewardDefinition {
    var name: String
    var icon: String
    @Attribute(.externalStorage) var iconImageData: Data
    var rankRawValue: String
    var detail: String
    var availabilityModeRawValue: String
    var remainingCount: Int

    @Relationship(deleteRule: .cascade, inverse: \RewardInventoryItem.rewardDefinition)
    var inventoryItems: [RewardInventoryItem]

    var rank: TaskRank {
        get { TaskRank(rawValue: rankRawValue) ?? .c }
        set { rankRawValue = newValue.rawValue }
    }

    var availabilityMode: RewardAvailabilityMode {
        get { RewardAvailabilityMode(rawValue: availabilityModeRawValue) ?? .unlimited }
        set { availabilityModeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        icon: String = "",
        iconImageData: Data,
        rank: TaskRank,
        detail: String = "",
        availabilityMode: RewardAvailabilityMode = .unlimited,
        remainingCount: Int = 0,
        inventoryItems: [RewardInventoryItem] = []
    ) {
        self.name = RewardDefinition.normalizedName(from: name)
        self.icon = RewardDefinition.normalizedIcon(from: icon)
        self.iconImageData = iconImageData
        self.rankRawValue = rank.rawValue
        self.detail = RewardDefinition.normalizedDetail(from: detail)
        self.availabilityModeRawValue = availabilityMode.rawValue
        self.remainingCount = max(0, remainingCount)
        self.inventoryItems = inventoryItems
    }

    static func normalizedName(from name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedIcon(from icon: String) -> String {
        icon.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedDetail(from detail: String) -> String {
        detail.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
