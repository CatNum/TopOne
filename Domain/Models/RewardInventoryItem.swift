import Foundation
import SwiftData

@Model
final class RewardInventoryItem {
    var currentCount: Int
    var rewardDefinition: RewardDefinition

    init(
        currentCount: Int = 0,
        rewardDefinition: RewardDefinition
    ) {
        self.currentCount = max(0, currentCount)
        self.rewardDefinition = rewardDefinition
    }
}
