import Testing
@testable import TopOne

struct TopOneCoreTests {
    @Test
    func placeholderGoalDefaultsToTopOne() {
        let goal = GoalService().makePlaceholderGoal()
        #expect(goal.isTopOne)
    }
}
