import Foundation
import SwiftData

@Model
final class Goal {
    var title: String
    var isTopOne: Bool
    var progress: Double
    var createdAt: Date

    init(
        title: String,
        isTopOne: Bool = false,
        progress: Double = 0,
        createdAt: Date = .now
    ) {
        self.title = title
        self.isTopOne = isTopOne
        self.progress = progress
        self.createdAt = createdAt
    }
}
