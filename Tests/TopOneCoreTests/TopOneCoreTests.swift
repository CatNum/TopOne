import Foundation
import SwiftData
import Testing
@testable import TopOne

struct TopOneCoreTests {
    @MainActor
    @Test
    func createGoalAcceptsValidTitle() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()

        let goal = try service.createGoal(title: "精通 AI 开发", rank: .s, in: container.mainContext)

        #expect(goal.title == "精通 AI 开发")
        #expect(goal.rank == .s)
        #expect(goal.progress == 0)
        #expect(goal.isTopOne == false)
        #expect(goal.completedAt == nil)
    }

    @MainActor
    @Test
    func createGoalRejectsBlankTitle() throws {
        let container = try makeInMemoryContainer()

        #expect(throws: GoalServiceError.invalidGoalTitle) {
            try GoalService().createGoal(title: "   ", rank: .a, in: container.mainContext)
        }
    }

    @MainActor
    @Test
    func createGoalRejectsTooManyActiveGoals() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()

        _ = try service.createGoal(title: "目标一", rank: .s, in: container.mainContext)
        _ = try service.createGoal(title: "目标二", rank: .a, in: container.mainContext)
        _ = try service.createGoal(title: "目标三", rank: .b, in: container.mainContext)

        #expect(throws: GoalServiceError.activeGoalLimitReached) {
            try service.createGoal(title: "目标四", rank: .c, in: container.mainContext)
        }
    }

    @MainActor
    @Test
    func setTopOneRequiresNoExistingTopOne() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let first = try service.createGoal(title: "目标一", rank: .s, in: container.mainContext)
        let second = try service.createGoal(title: "目标二", rank: .a, in: container.mainContext)

        try service.setTopOne(first, lockDuration: .sevenDays, in: container.mainContext)

        #expect(throws: GoalServiceError.topOneAlreadyExists) {
            try service.setTopOne(second, lockDuration: .fourteenDays, in: container.mainContext)
        }
    }

    @MainActor
    @Test
    func unbindTopOneRequiresReasonWhileLocked() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = try service.createGoal(title: "锁定目标", rank: .s, in: container.mainContext)
        try service.setTopOne(goal, lockDuration: .sevenDays, in: container.mainContext)

        #expect(throws: GoalServiceError.reasonTooShort(required: 50, actual: 0)) {
            try service.unbindTopOne(goal, reason: nil, in: container.mainContext)
        }
    }

    @MainActor
    @Test
    func requiredReasonLengthDoublesAfterEarlySwitch() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = try service.createGoal(title: "长期挑战", rank: .s, in: container.mainContext)
        try service.setTopOne(goal, lockDuration: .sevenDays, in: container.mainContext)

        try service.unbindTopOne(goal, reason: String(repeating: "理", count: 50), in: container.mainContext)

        #expect(goal.earlySwitchCount == 1)
        #expect(service.requiredReasonLength(for: goal) == 100)
    }

    @MainActor
    @Test
    func requiredReasonLengthCapsAtFiveHundred() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = Goal(title: "长期挑战", rank: .a, earlySwitchCount: 5)

        #expect(service.requiredReasonLength(for: goal) == 500)
    }

    @MainActor
    @Test
    func updateProgressClampsOutOfRangeValues() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = try service.createGoal(title: "目标进度", rank: .a, in: container.mainContext)

        try service.updateProgress(for: goal, progress: -0.3, in: container.mainContext)
        #expect(goal.progress == 0)

        try service.updateProgress(for: goal, progress: 1.2, in: container.mainContext)
        #expect(goal.progress == 1)
    }

    @MainActor
    @Test
    func createDailyTaskAllowsAnyGoalBinding() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = try service.createGoal(title: "长期目标", rank: .s, in: container.mainContext)

        let task = try service.createDailyTask(title: "实现神经网络层", rank: .a, goal: goal, in: container.mainContext)

        #expect(task.goal === goal)
        #expect(task.status == .notStarted)
    }

    @MainActor
    @Test
    func updateDailyTaskStatusRequiresCurrentTopOne() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = try service.createGoal(title: "长期目标", rank: .s, in: container.mainContext)
        let task = try service.createDailyTask(title: "任务一", rank: .a, goal: goal, in: container.mainContext)

        #expect(throws: GoalServiceError.topOneRequired) {
            try service.updateDailyTaskStatus(task, status: .inProgress, in: container.mainContext)
        }
    }

    @MainActor
    @Test
    func sortDailyTasksByStatus() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = try service.createGoal(title: "长期目标", rank: .s, in: container.mainContext)

        let notStarted = try service.createDailyTask(title: "未开始任务", rank: .c, goal: goal, in: container.mainContext)
        let inProgress = try service.createDailyTask(title: "执行中任务", rank: .a, goal: goal, in: container.mainContext)
        let completed = try service.createDailyTask(title: "已完成任务", rank: .b, goal: goal, in: container.mainContext)

        goal.isTopOne = true
        try service.updateDailyTaskStatus(inProgress, status: .inProgress, in: container.mainContext)
        try service.updateDailyTaskStatus(completed, status: .completed, in: container.mainContext)

        let sortedTitles = service.sortedDailyTasks(for: goal).map(\.title)
        #expect(sortedTitles == ["执行中任务", "未开始任务", "已完成任务"])
        #expect(notStarted.status == .notStarted)
    }

    @MainActor
    @Test
    func updateGoalChangesTitleAndRank() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = try service.createGoal(title: "旧标题", rank: .c, in: container.mainContext)

        try service.updateGoal(goal, title: "新标题", rank: .s, in: container.mainContext)

        #expect(goal.title == "新标题")
        #expect(goal.rank == .s)
    }

    @MainActor
    @Test
    func deleteGoalCascadesDailyTasks() throws {
        let container = try makeInMemoryContainer()
        let service = GoalService()
        let goal = try service.createGoal(title: "长期目标", rank: .s, in: container.mainContext)
        _ = try service.createDailyTask(title: "任务一", rank: .a, goal: goal, in: container.mainContext)

        try service.deleteGoal(goal, in: container.mainContext)

        let remainingGoals = try service.fetchGoals(in: container.mainContext)
        let remainingTasks = try service.fetchDailyTasks(in: container.mainContext)
        #expect(remainingGoals.isEmpty)
        #expect(remainingTasks.isEmpty)
    }

    @MainActor
    @Test
    func homeViewModelDefaultsToTopOneHeadline() {
        let viewModel = HomeViewModel()
        #expect(viewModel.headline == "TopOne")
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Goal.self, DailyTask.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
