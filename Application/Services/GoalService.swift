import Foundation

struct GoalService {
    func makePlaceholderGoal() -> Goal {
        Goal(title: "成为当前唯一重要的事", isTopOne: true, progress: 0.1)
    }
}
