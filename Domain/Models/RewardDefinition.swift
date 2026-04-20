import Foundation
import SwiftData

enum RewardAvailabilityMode: String, CaseIterable, Identifiable, Codable {
    case unlimited
    case limited

    var id: String {
        rawValue
    }
}

enum RewardTier: String, CaseIterable, Identifiable, Codable {
    // swiftlint:disable identifier_name
    case sss = "SSS"
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    // swiftlint:enable identifier_name

    var id: String {
        rawValue
    }

    var normalRank: TaskRank? {
        switch self {
        case .sss:
            nil
        case .s:
            .s
        case .a:
            .a
        case .b:
            .b
        case .c:
            .c
        }
    }
}

@Model
final class RewardDefinition {
    static let minimumSSSPointCost = 888

    var name: String
    var icon: String
    @Attribute(.externalStorage) var iconImageData: Data
    var rankRawValue: String
    var sssPointCost: Int
    var detail: String
    var availabilityModeRawValue: String
    var remainingCount: Int

    @Relationship(deleteRule: .cascade, inverse: \RewardInventoryItem.rewardDefinition)
    var inventoryItems: [RewardInventoryItem]

    var rewardTierRawValue: String {
        get { rankRawValue }
        set { rankRawValue = newValue }
    }

    var rewardTier: RewardTier {
        get { RewardTier(rawValue: rewardTierRawValue) ?? .c }
        set {
            rewardTierRawValue = newValue.rawValue
            if newValue != .sss {
                sssPointCost = Self.minimumSSSPointCost
            }
        }
    }

    var normalRank: TaskRank? {
        rewardTier.normalRank
    }

    var isSSSReward: Bool {
        rewardTier == .sss
    }

    var rank: TaskRank {
        get {
            guard let normalRank else {
                assertionFailure("SSS rewards do not have a normal TaskRank; use rewardTier or normalRank instead.")
                return .c
            }
            return normalRank
        }
        set { rewardTier = RewardTier(rawValue: newValue.rawValue) ?? .c }
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
        rankRawValue = rank.rawValue
        sssPointCost = Self.minimumSSSPointCost
        self.detail = RewardDefinition.normalizedDetail(from: detail)
        availabilityModeRawValue = availabilityMode.rawValue
        self.remainingCount = max(0, remainingCount)
        self.inventoryItems = inventoryItems
    }

    init(
        name: String,
        icon: String = "",
        iconImageData: Data,
        rewardTier: RewardTier,
        sssPointCost: Int = RewardDefinition.minimumSSSPointCost,
        detail: String = "",
        availabilityMode: RewardAvailabilityMode = .unlimited,
        remainingCount: Int = 0,
        inventoryItems: [RewardInventoryItem] = []
    ) {
        self.name = RewardDefinition.normalizedName(from: name)
        self.icon = RewardDefinition.normalizedIcon(from: icon)
        self.iconImageData = iconImageData
        rankRawValue = rewardTier.rawValue
        self.sssPointCost = rewardTier == .sss ? max(Self.minimumSSSPointCost, sssPointCost) : Self.minimumSSSPointCost
        self.detail = RewardDefinition.normalizedDetail(from: detail)
        availabilityModeRawValue = availabilityMode.rawValue
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
