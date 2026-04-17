import Foundation
import SwiftData

@Model
final class RewardAccount {
    var points: Int

    init(points: Int = 0) {
        self.points = max(0, points)
    }
}
