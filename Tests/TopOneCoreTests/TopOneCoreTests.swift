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
    func rewardModelsPersistInMemoryAndLinkInventoryToDefinition() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let definition = RewardDefinition(
            name: "咖啡时光",
            iconImageData: Data([1, 2, 3]),
            rank: .a,
            detail: "完成关键任务后兑换",
            availabilityMode: .limited,
            remainingCount: -2
        )
        let account = RewardAccount(points: -10)
        let inventoryItem = RewardInventoryItem(currentCount: -3, rewardDefinition: definition)

        context.insert(definition)
        context.insert(account)
        context.insert(inventoryItem)
        try context.save()

        let definitions = try context.fetch(FetchDescriptor<RewardDefinition>())
        let accounts = try context.fetch(FetchDescriptor<RewardAccount>())
        let inventoryItems = try context.fetch(FetchDescriptor<RewardInventoryItem>())

        #expect(definitions.count == 1)
        #expect(accounts.count == 1)
        #expect(inventoryItems.count == 1)

        #expect(definitions[0].name == "咖啡时光")
        #expect(definitions[0].rank == .a)
        #expect(definitions[0].availabilityMode == .limited)
        #expect(definitions[0].remainingCount == 0)
        #expect(accounts[0].points == 0)
        #expect(inventoryItems[0].currentCount == 0)
        #expect(inventoryItems[0].rewardDefinition.name == "咖啡时光")
        #expect(inventoryItems[0].rewardDefinition === definitions[0])
    }

    @MainActor
    @Test
    func completingDailyTaskAwardsPointsOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goalService = GoalService()
        let rewardService = RewardService()
        let goal = try goalService.createGoal(title: "长期目标", rank: .s, in: context)
        let task = try goalService.createDailyTask(title: "任务一", rank: .a, goal: goal, in: context)
        try goalService.setTopOne(goal, lockDuration: .sevenDays, in: context)

        try goalService.updateDailyTaskStatus(task, status: .completed, in: context)

        let account = try #require(rewardService.fetchRewardAccount(in: context))
        #expect(account.points == 8)

        try goalService.updateDailyTaskStatus(task, status: .completed, in: context)

        #expect(account.points == 8)

        try goalService.updateDailyTaskStatus(task, status: .inProgress, in: context)
        try goalService.updateDailyTaskStatus(task, status: .completed, in: context)

        #expect(account.points == 8)
    }

    @MainActor
    @Test
    func completingGoalAwardsPointsOnce() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goalService = GoalService()
        let rewardService = RewardService()
        let goal = try goalService.createGoal(title: "完成目标", rank: .b, in: context)

        try goalService.updateProgress(for: goal, progress: 1, in: context)

        let account = try #require(rewardService.fetchRewardAccount(in: context))
        #expect(account.points == 6)
        #expect(goal.completedAt != nil)

        try goalService.updateProgress(for: goal, progress: 1, in: context)

        #expect(account.points == 6)

        try goalService.updateProgress(for: goal, progress: 0.5, in: context)
        try goalService.updateProgress(for: goal, progress: 1, in: context)

        #expect(account.points == 6)
    }

    @MainActor
    @Test
    func createRewardDefinitionRejectsBlankName() throws {
        let container = try makeInMemoryContainer()

        #expect(throws: RewardServiceError.invalidRewardName) {
            try RewardService().createRewardDefinition(name: "   ", iconImageData: validRewardImageData(), rank: .a, in: container.mainContext)
        }
    }

    @MainActor
    @Test
    func saveRewardDefinitionCreatesRewardFromDraft() throws {
        let container = try makeInMemoryContainer()
        let viewModel = HomeViewModel()

        viewModel.showCreateRewardDefinition()
        var draft = try #require(viewModel.rewardDraft)
        draft.name = "咖啡券"
        draft.rank = .b
        draft.iconImageData = validRewardImageData()
        draft.availabilityMode = .limited
        draft.remainingCount = 2
        viewModel.rewardDraft = draft

        viewModel.saveRewardDefinition(in: container.mainContext)

        #expect(viewModel.rewardDraft == nil)
        let rewards = try container.mainContext.fetch(FetchDescriptor<RewardDefinition>())
        #expect(rewards.count == 1)
        #expect(rewards[0].name == "咖啡券")
        #expect(rewards[0].rank == .b)
        #expect(rewards[0].availabilityMode == .limited)
        #expect(rewards[0].remainingCount == 2)
    }

    @MainActor
    @Test
    func updateRewardDefinitionPersistsEditedDraft() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let reward = RewardDefinition(name: "旧奖励", iconImageData: validRewardImageData(), rank: .c)
        context.insert(reward)
        try context.save()

        let viewModel = HomeViewModel()
        viewModel.showEditRewardDefinition(reward)
        var draft = try #require(viewModel.rewardDraft)
        draft.name = "新奖励"
        draft.rank = .s
        draft.detail = "完成阶段冲刺后使用"
        draft.availabilityMode = .limited
        draft.remainingCount = 4
        viewModel.rewardDraft = draft

        viewModel.saveRewardDefinition(in: context)

        #expect(viewModel.rewardDraft == nil)
        #expect(reward.name == "新奖励")
        #expect(reward.rank == .s)
        #expect(reward.detail == "完成阶段冲刺后使用")
        #expect(reward.availabilityMode == .limited)
        #expect(reward.remainingCount == 4)
    }

    @MainActor
    @Test
    func deleteRewardDefinitionCascadesInventoryItems() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let reward = RewardDefinition(name: "待删除奖励", iconImageData: validRewardImageData(), rank: .a)
        let item = RewardInventoryItem(currentCount: 2, rewardDefinition: reward)
        context.insert(reward)
        context.insert(item)
        try context.save()

        HomeViewModel().deleteRewardDefinition(reward, in: context)

        let rewards = try context.fetch(FetchDescriptor<RewardDefinition>())
        let items = try context.fetch(FetchDescriptor<RewardInventoryItem>())
        #expect(rewards.isEmpty)
        #expect(items.isEmpty)
    }

    @MainActor
    @Test
    func createLimitedRewardDefinitionRejectsZeroRemainingCount() throws {
        let container = try makeInMemoryContainer()

        #expect(throws: RewardServiceError.invalidLimitedRewardCount) {
            try RewardService().createRewardDefinition(
                name: "限量奖励",
                icon: "gift.fill",
                iconImageData: validRewardImageData(),
                rank: .a,
                availabilityMode: .limited,
                remainingCount: 0,
                in: container.mainContext
            )
        }
    }

    @MainActor
    @Test
    func switchingRewardDraftToLimitedInitializesRemainingCount() throws {
        let viewModel = HomeViewModel()

        viewModel.showCreateRewardDefinition()
        var draft = try #require(viewModel.rewardDraft)
        draft.availabilityMode = .unlimited
        draft.remainingCount = 0
        viewModel.rewardDraft = draft

        draft = try #require(viewModel.rewardDraft)
        draft.availabilityMode = .limited
        if draft.remainingCount <= 0 {
            draft.remainingCount = 1
        }
        viewModel.rewardDraft = draft

        let updatedDraft = try #require(viewModel.rewardDraft)
        #expect(updatedDraft.availabilityMode == .limited)
        #expect(updatedDraft.remainingCount == 1)
    }

    @MainActor
    @Test
    func awardPointsAddsMappedPointsToAccount() throws {
        let container = try makeInMemoryContainer()
        let service = RewardService()

        let account = try service.awardPoints(for: .dailyTask(rank: .s, title: "日常任务"), in: container.mainContext)

        #expect(account.points == 12)
        let fetchedAccounts = try container.mainContext.fetch(FetchDescriptor<RewardAccount>())
        #expect(fetchedAccounts.count == 1)
        #expect(fetchedAccounts[0] === account)
    }

    @MainActor
    @Test
    func awardAndDrawCreatePointTransactions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let reward = RewardDefinition(name: "咖啡兑换券", iconImageData: validRewardImageData(), rank: .a)
        context.insert(reward)

        _ = try service.awardPoints(for: .goal(rank: .a, title: "长期目标"), in: context)
        _ = try service.drawReward(for: .a, in: context)

        let transactions = try service.fetchPointTransactions(in: context)
        #expect(transactions.count == 2)
        #expect(transactions[0].reason == .drawReward)
        #expect(transactions[0].kind == .spend)
        #expect(transactions[0].pointsDelta == -5)
        #expect(transactions[1].reason == .completeGoal)
        #expect(transactions[1].kind == .earn)
        #expect(transactions[1].pointsDelta == 10)
    }

    @MainActor
    @Test
    func drawRewardConsumesPointsAndAddsInventory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let reward = RewardDefinition(
            name: "咖啡兑换券",
            icon: "cup.and.saucer.fill",
            iconImageData: validRewardImageData(),
            rank: .a,
            availabilityMode: .limited,
            remainingCount: 2
        )
        context.insert(reward)
        _ = try service.awardPoints(for: .goal(rank: .a, title: "长期目标"), in: context)

        let drawnReward = try service.drawReward(for: .a, in: context)

        #expect(drawnReward === reward)
        let account = try #require(service.fetchRewardAccount(in: context))
        #expect(account.points == 5)
        #expect(reward.remainingCount == 1)

        let inventoryItems = try context.fetch(FetchDescriptor<RewardInventoryItem>())
        #expect(inventoryItems.count == 1)
        #expect(inventoryItems[0].rewardDefinition === reward)
        #expect(inventoryItems[0].currentCount == 1)
    }

    @MainActor
    @Test
    func drawRewardUsesSelectedRewardWhenMultipleShareSameRank() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let firstReward = RewardDefinition(name: "电影夜", iconImageData: validRewardImageData(), rank: .a, availabilityMode: .limited, remainingCount: 2)
        let selectedReward = RewardDefinition(name: "咖啡兑换券", iconImageData: validRewardImageData(), rank: .a, availabilityMode: .limited, remainingCount: 3)
        context.insert(firstReward)
        context.insert(selectedReward)
        _ = try service.awardPoints(for: .goal(rank: .a, title: "长期目标"), in: context)

        let drawnReward = try service.drawReward(for: .a, in: context)

        #expect(drawnReward === firstReward || drawnReward === selectedReward)
        let changedCount = (firstReward.remainingCount == 1 ? 1 : 0) + (selectedReward.remainingCount == 2 ? 1 : 0)
        #expect(changedCount == 1)
        let inventoryItems = try context.fetch(FetchDescriptor<RewardInventoryItem>())
        #expect(inventoryItems.count == 1)
        #expect(inventoryItems[0].rewardDefinition === drawnReward)
    }

    @MainActor
    @Test
    func useRewardConsumesInventoryCount() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let reward = RewardDefinition(name: "散步十分钟", iconImageData: validRewardImageData(), rank: .c)
        let item = RewardInventoryItem(currentCount: 2, rewardDefinition: reward)
        context.insert(reward)
        context.insert(item)
        try context.save()

        try service.useReward(item, amount: 1, in: context)

        #expect(item.currentCount == 1)
    }

    @MainActor
    @Test
    func useRewardRejectsAmountGreaterThanInventory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let reward = RewardDefinition(name: "电影时间", iconImageData: validRewardImageData(), rank: .b)
        let item = RewardInventoryItem(currentCount: 1, rewardDefinition: reward)
        context.insert(reward)
        context.insert(item)
        try context.save()

        #expect(throws: RewardServiceError.insufficientInventory) {
            try service.useReward(item, amount: 2, in: context)
        }
    }

    @MainActor
    @Test
    func homeViewModelUseRewardResetsAmountAfterSuccess() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let reward = RewardDefinition(name: "咖啡时光", iconImageData: validRewardImageData(), rank: .a)
        let item = RewardInventoryItem(currentCount: 2, rewardDefinition: reward)
        context.insert(reward)
        context.insert(item)
        try context.save()

        let viewModel = HomeViewModel()
        viewModel.rewardUseAmountText = "2"

        viewModel.useReward(item, in: context)

        #expect(item.currentCount == 0)
        #expect(viewModel.rewardUseAmountText == "1")
        #expect(viewModel.errorMessage == nil)
    }

    @MainActor
    @Test
    func homeViewModelDrawRewardConsumesPointsAndAddsInventory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let reward = RewardDefinition(name: "咖啡兑换券", iconImageData: validRewardImageData(), rank: .a, availabilityMode: .limited, remainingCount: 2)
        context.insert(reward)
        _ = try RewardService().awardPoints(for: .goal(rank: .a, title: "长期目标"), in: context)

        let viewModel = HomeViewModel()
        viewModel.drawReward(for: .a, in: context)

        let account = try #require(RewardService().fetchRewardAccount(in: context))
        let inventoryItems = try context.fetch(FetchDescriptor<RewardInventoryItem>())
        #expect(account.points == 5)
        #expect(inventoryItems.count == 1)
        #expect(inventoryItems[0].currentCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @MainActor
    @Test
    func homeViewModelPreparesRewardCreateDraftWithDefaultRank() throws {
        let viewModel = HomeViewModel()

        viewModel.showCreateRewardDefinition()

        let draft = try #require(viewModel.rewardDraft)
        #expect(draft.reward == nil)
        #expect(draft.name == "")
        #expect(draft.icon == "")
        #expect(draft.iconImageData.isEmpty)
        #expect(draft.detail == "")
        #expect(draft.availabilityMode == .unlimited)
        #expect(draft.remainingCount == 0)
        #expect(draft.rank == .a)
    }

    @MainActor
    @Test
    func homeViewModelPreparesRewardEditDraftFromExistingReward() throws {
        let viewModel = HomeViewModel()
        let reward = RewardDefinition(
            name: "咖啡兑换券",
            icon: "cup.and.saucer.fill",
            iconImageData: validRewardImageData(),
            rank: .s,
            detail: "兑换一杯热拿铁",
            availabilityMode: .limited,
            remainingCount: 3
        )

        viewModel.showEditRewardDefinition(reward)

        let draft = try #require(viewModel.rewardDraft)
        #expect(draft.reward === reward)
        #expect(draft.name == "咖啡兑换券")
        #expect(draft.icon == reward.icon)
        #expect(draft.iconImageData == reward.iconImageData)
        #expect(draft.rank == .s)
        #expect(draft.detail == "兑换一杯热拿铁")
        #expect(draft.availabilityMode == .limited)
        #expect(draft.remainingCount == 3)
    }

    @MainActor
    @Test
    func homeViewModelDefaultsToTopOneHeadline() {
        let viewModel = HomeViewModel()
        #expect(viewModel.headline == "TopOne")
    }

    @MainActor
    @Test
    func fetchPointTransactionsReturnsMostRecentFirst() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()

        context.insert(RewardPointTransaction(
            pointsDelta: 8,
            balanceAfterChange: 8,
            kind: .earn,
            reason: .completeDailyTask,
            rank: .a,
            referenceTitle: "先发生",
            createdAt: Date(timeIntervalSince1970: 1)
        ))
        context.insert(RewardPointTransaction(
            pointsDelta: -5,
            balanceAfterChange: 3,
            kind: .spend,
            reason: .drawReward,
            rank: .a,
            referenceTitle: "后发生",
            createdAt: Date(timeIntervalSince1970: 2)
        ))
        try context.save()

        let transactions = try service.fetchPointTransactions(in: context)
        #expect(transactions.map(\.referenceTitle) == ["后发生", "先发生"])
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Goal.self,
            DailyTask.self,
            RewardDefinition.self,
            RewardAccount.self,
            RewardInventoryItem.self,
            RewardPointTransaction.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func validRewardImageData() -> Data {
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jxwAAAABJRU5ErkJggg==") ?? Data()
    }
}
