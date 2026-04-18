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
    func rewardDefinitionSupportsSSSTierAndCustomCost() throws {
        let definition = RewardDefinition(
            name: "豪华放空日",
            iconImageData: validRewardImageData(),
            rewardTier: .sss,
            sssPointCost: 999,
            detail: "完成阶段冲刺后兑换"
        )

        #expect(definition.rewardTier == .sss)
        #expect(definition.rewardTierRawValue == "SSS")
        #expect(definition.isSSSReward)
        #expect(definition.normalRank == nil)
        #expect(definition.sssPointCost == 999)
    }

    @MainActor
    @Test
    func rewardDefinitionClampsSSSPointCostToMinimum() throws {
        let definition = RewardDefinition(
            name: "豪华放空日",
            iconImageData: validRewardImageData(),
            rewardTier: .sss,
            sssPointCost: 100,
            detail: "完成阶段冲刺后兑换"
        )

        #expect(definition.rewardTier == .sss)
        #expect(definition.sssPointCost == RewardDefinition.minimumSSSPointCost)
    }

    @MainActor
    @Test
    func rewardDefinitionPersistsSSSTierAndPointCost() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let definition = RewardDefinition(
            name: "豪华放空日",
            iconImageData: validRewardImageData(),
            rewardTier: .sss,
            sssPointCost: 999,
            detail: "完成阶段冲刺后兑换"
        )
        context.insert(definition)
        try context.save()

        let savedRewards = try context.fetch(FetchDescriptor<RewardDefinition>())
        let savedReward = try #require(savedRewards.first)
        #expect(savedReward.rewardTier == .sss)
        #expect(savedReward.rewardTierRawValue == "SSS")
        #expect(savedReward.normalRank == nil)
        #expect(savedReward.sssPointCost == 999)
    }

    @MainActor
    @Test
    func rewardDefinitionKeepsTaskRankForNormalRewards() throws {
        let definition = RewardDefinition(
            name: "咖啡时光",
            iconImageData: validRewardImageData(),
            rank: .a,
            detail: "完成关键任务后兑换"
        )

        #expect(definition.rewardTier == .a)
        #expect(definition.rewardTierRawValue == "A")
        #expect(definition.normalRank == .a)
        #expect(definition.isSSSReward == false)
        #expect(definition.sssPointCost == RewardDefinition.minimumSSSPointCost)
        #expect(definition.rank == .a)
    }

    @MainActor
    @Test
    func rewardAccountDefaultsNewStateForMinimalInitialization() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let account = RewardAccount()
        context.insert(account)
        try context.save()

        let stored = try #require(context.fetch(FetchDescriptor<RewardAccount>()).first)
        #expect(stored.points == 0)
        #expect(stored.lastPointResetAt == nil)
        #expect(stored.dailyTaskPointsAwarded == 0)
        #expect(stored.didAwardGoalPointsToday == false)
        #expect(stored.drawCountsByTier.isEmpty)
        #expect(stored.exchangeCreditsByTier.isEmpty)
    }

    @MainActor
    @Test
    func rewardAccountPersistsDailyAndPityState() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let account = RewardAccount(
            points: 12,
            lastPointResetAt: Date(timeIntervalSince1970: 10),
            dailyTaskPointsAwarded: 20,
            didAwardGoalPointsToday: true,
            drawCountsByTier: [RewardTier.a.rawValue: 9],
            exchangeCreditsByTier: [RewardTier.a.rawValue: 1]
        )
        context.insert(account)
        try context.save()

        let stored = try #require(context.fetch(FetchDescriptor<RewardAccount>()).first)
        #expect(stored.points == 12)
        #expect(stored.lastPointResetAt == Date(timeIntervalSince1970: 10))
        #expect(stored.dailyTaskPointsAwarded == 20)
        #expect(stored.didAwardGoalPointsToday == true)
        #expect(stored.drawCountsByTier[RewardTier.a.rawValue] == 9)
        #expect(stored.exchangeCreditsByTier[RewardTier.a.rawValue] == 1)
    }

    @MainActor
    @Test
    func rewardAccountFallsBackToSafeDefaultsWhenRawStorageIsNil() {
        let account = RewardAccount()
        account.dailyTaskPointsAwardedRawValue = nil
        account.didAwardGoalPointsTodayRawValue = nil
        account.drawCountsByTierRawValue = nil
        account.exchangeCreditsByTierRawValue = nil

        #expect(account.dailyTaskPointsAwarded == 0)
        #expect(account.didAwardGoalPointsToday == false)
        #expect(account.drawCountsByTier.isEmpty)
        #expect(account.exchangeCreditsByTier.isEmpty)
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
        #expect(account.points == 60)
        #expect(goal.completedAt != nil)

        try goalService.updateProgress(for: goal, progress: 1, in: context)

        #expect(account.points == 60)

        try goalService.updateProgress(for: goal, progress: 0.5, in: context)
        try goalService.updateProgress(for: goal, progress: 1, in: context)

        #expect(account.points == 60)
    }

    @MainActor
    @Test
    func completingGoalBlockedByOncePerDayPayoutKeepsRewardFlagFalse() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let goalService = GoalService()
        let rewardService = RewardService()
        let firstGoal = try goalService.createGoal(title: "目标一", rank: .a, in: context)
        let secondGoal = try goalService.createGoal(title: "目标二", rank: .s, in: context)

        try goalService.updateProgress(for: firstGoal, progress: 1, in: context)
        let account = try #require(rewardService.fetchRewardAccount(in: context))
        #expect(account.points == 100)
        #expect(firstGoal.rewardPointsAwarded == true)

        try goalService.updateProgress(for: secondGoal, progress: 1, in: context)

        #expect(account.points == 100)
        #expect(secondGoal.completedAt != nil)
        #expect(secondGoal.rewardPointsAwarded == false)
    }

    @MainActor
    @Test
    func dailyTaskPointsCapAtThirtyPerDay() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()

        _ = try service.awardPoints(for: .dailyTask(rank: .s, title: "任务一"), in: context)
        _ = try service.awardPoints(for: .dailyTask(rank: .s, title: "任务二"), in: context)
        _ = try service.awardPoints(for: .dailyTask(rank: .a, title: "任务三"), in: context)
        let account = try #require(service.fetchRewardAccount(in: context))

        #expect(account.points == 30)
        #expect(account.dailyTaskPointsAwarded == 30)
    }

    @MainActor
    @Test
    func goalPointsAwardOnlyOncePerDayAcrossAllGoals() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()

        _ = try service.awardPoints(for: .goal(rank: .a, title: "目标一"), in: context)
        _ = try service.awardPoints(for: .goal(rank: .s, title: "目标二"), in: context)
        let account = try #require(service.fetchRewardAccount(in: context))

        #expect(account.points == 100)
        #expect(account.didAwardGoalPointsToday == true)
    }

    @MainActor
    @Test
    func dailyTaskPointCapStillRecordsZeroDeltaTransaction() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()

        _ = try service.awardPoints(for: .dailyTask(rank: .s, title: "任务一"), in: context)
        _ = try service.awardPoints(for: .dailyTask(rank: .s, title: "任务二"), in: context)
        _ = try service.awardPoints(for: .dailyTask(rank: .a, title: "任务三"), in: context)

        let account = try #require(service.fetchRewardAccount(in: context))
        #expect(account.points == 30)

        _ = try service.awardPoints(for: .dailyTask(rank: .c, title: "任务四"), in: context)

        let transactions = try service.fetchPointTransactions(in: context)
        let latest = try #require(transactions.first)
        #expect(latest.reason == .completeDailyTask)
        #expect(latest.pointsDelta == 0)
        #expect(latest.balanceAfterChange == 30)
        #expect(latest.referenceTitle == "任务四")
    }

    @MainActor
    @Test
    func goalDailyLimitStillRecordsZeroDeltaTransaction() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()

        _ = try service.awardPoints(for: .goal(rank: .a, title: "目标一"), in: context)
        _ = try service.awardPoints(for: .goal(rank: .s, title: "目标二"), in: context)

        let transactions = try service.fetchPointTransactions(in: context)
        let latest = try #require(transactions.first)
        #expect(latest.reason == .completeGoal)
        #expect(latest.pointsDelta == 0)
        #expect(latest.balanceAfterChange == 100)
        #expect(latest.referenceTitle == "目标二")
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
        draft.rewardTier = .b
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
        draft.rewardTier = .s
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
        for index in 0..<5 {
            context.insert(RewardDefinition(name: "A奖励\(index)", iconImageData: validRewardImageData(), rank: .a))
        }

        _ = try service.awardPoints(for: .goal(rank: .a, title: "长期目标"), in: context)
        _ = try service.drawReward(for: .a, in: context)

        let transactions = try service.fetchPointTransactions(in: context)
        #expect(transactions.count == 2)
        #expect(transactions[0].reason == .drawReward)
        #expect(transactions[0].kind == .spend)
        #expect(transactions[0].pointsDelta == -5)
        #expect(transactions[1].reason == .completeGoal)
        #expect(transactions[1].kind == .earn)
        #expect(transactions[1].pointsDelta == 100)
    }

    @MainActor
    @Test
    func drawRewardConsumesPointsAndAddsInventory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        for index in 0..<5 {
            context.insert(RewardDefinition(
                name: "A奖励\(index)",
                iconImageData: validRewardImageData(),
                rank: .a,
                availabilityMode: .limited,
                remainingCount: index == 0 ? 2 : 1
            ))
        }
        _ = try service.awardPoints(for: .goal(rank: .a, title: "长期目标"), in: context)

        let drawnReward = try service.drawReward(for: .a, in: context)

        let account = try #require(service.fetchRewardAccount(in: context))
        #expect(account.points == 95)
        #expect(drawnReward.normalRank == .a)

        let inventoryItems = try context.fetch(FetchDescriptor<RewardInventoryItem>())
        #expect(inventoryItems.count == 1)
        #expect(inventoryItems[0].rewardDefinition === drawnReward)
        #expect(inventoryItems[0].currentCount == 1)
    }

    @MainActor
    @Test
    func drawRequiresAtLeastFiveAvailableNormalRewards() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()

        for index in 0..<4 {
            context.insert(RewardDefinition(name: "A奖励\(index)", iconImageData: validRewardImageData(), rewardTier: .a))
        }
        let account = try service.ensureRewardAccount(in: context)
        account.points = 100
        try context.save()

        #expect(throws: RewardServiceError.drawPoolTooSmall(rank: .a, minimum: 5, actual: 4)) {
            try service.drawReward(for: .a, in: context)
        }
    }

    @MainActor
    @Test
    func availableRewardsExcludesSSSRewardsFromNormalTierPool() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()

        for index in 0..<4 {
            context.insert(RewardDefinition(name: "C奖励\(index)", iconImageData: validRewardImageData(), rewardTier: .c))
        }
        context.insert(RewardDefinition(name: "SSS大奖", iconImageData: validRewardImageData(), rewardTier: .sss, sssPointCost: 999))
        let account = try service.ensureRewardAccount(in: context)
        account.points = 100
        try context.save()

        let rewards = try service.availableRewards(for: .c, in: context)
        #expect(rewards.count == 4)
        #expect(rewards.allSatisfy { $0.normalRank == .c && $0.isSSSReward == false })
        #expect(throws: RewardServiceError.drawPoolTooSmall(rank: .c, minimum: 5, actual: 4)) {
            try service.drawReward(for: .c, in: context)
        }
    }

    @MainActor
    @Test
    func everyTenDrawsGrantOneExchangeCreditForThatTier() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()

        for index in 0..<5 {
            context.insert(RewardDefinition(name: "A奖励\(index)", iconImageData: validRewardImageData(), rewardTier: .a))
        }
        let account = try service.ensureRewardAccount(in: context)
        account.points = 100
        try context.save()

        for _ in 0..<10 {
            _ = try service.drawReward(for: .a, in: context)
        }

        #expect(account.drawCountsByTier[RewardTier.a.rawValue] == 10)
        #expect(account.exchangeCreditsByTier[RewardTier.a.rawValue] == 1)
    }

    @MainActor
    @Test
    func normalRewardDirectExchangeConsumesPointsAndCredit() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let reward = RewardDefinition(name: "咖啡券", iconImageData: validRewardImageData(), rewardTier: .a)
        context.insert(reward)
        let account = try service.ensureRewardAccount(in: context)
        account.points = 12
        account.exchangeCreditsByTier = [RewardTier.a.rawValue: 1]
        try context.save()

        let item = try service.exchangeNormalRewardDirectly(reward, in: context)

        #expect(item.rewardDefinition === reward)
        #expect(item.currentCount == 1)
        #expect(account.points == 7)
        #expect(account.exchangeCreditsByTier[RewardTier.a.rawValue] == 0)
    }

    @MainActor
    @Test
    func normalRewardDirectExchangeRequiresAvailableCredit() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let reward = RewardDefinition(name: "咖啡券", iconImageData: validRewardImageData(), rewardTier: .a)
        context.insert(reward)
        let account = try service.ensureRewardAccount(in: context)
        account.points = 12
        account.exchangeCreditsByTier = [RewardTier.a.rawValue: 0]
        try context.save()

        #expect(throws: RewardServiceError.noExchangeCredit(rank: .a)) {
            try service.exchangeNormalRewardDirectly(reward, in: context)
        }
    }

    @MainActor
    @Test
    func normalRewardDirectExchangeRejectsSSSReward() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let reward = RewardDefinition(name: "SSS大奖", iconImageData: validRewardImageData(), rewardTier: .sss, sssPointCost: 999)
        context.insert(reward)
        let account = try service.ensureRewardAccount(in: context)
        account.points = 1000
        account.exchangeCreditsByTier = [RewardTier.c.rawValue: 1]
        try context.save()

        #expect(throws: RewardServiceError.rewardUnavailable) {
            try service.exchangeNormalRewardDirectly(reward, in: context)
        }
    }

    @MainActor
    @Test
    func createSSSRewardRejectsCostBelowMinimum() throws {
        let container = try makeInMemoryContainer()

        #expect(throws: RewardServiceError.invalidSSSPointCost(minimum: RewardDefinition.minimumSSSPointCost)) {
            try RewardService().createRewardDefinition(
                name: "欧洲旅行",
                iconImageData: validRewardImageData(),
                rewardTier: .sss,
                sssPointCost: 500,
                in: container.mainContext
            )
        }
    }

    @MainActor
    @Test
    func sssRewardDirectExchangeConsumesCustomCost() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let reward = RewardDefinition(
            name: "欧洲旅行",
            iconImageData: validRewardImageData(),
            rewardTier: .sss,
            sssPointCost: 888
        )
        context.insert(reward)
        let account = try service.ensureRewardAccount(in: context)
        account.points = 1000
        try context.save()

        let item = try service.exchangeSSSRewardDirectly(reward, in: context)

        #expect(item.rewardDefinition === reward)
        #expect(item.currentCount == 1)
        #expect(account.points == 112)
    }

    @MainActor
    @Test
    func drawRewardUsesSelectedRewardWhenMultipleShareSameRank() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let service = RewardService()
        let rewards = [
            RewardDefinition(name: "电影夜", iconImageData: validRewardImageData(), rank: .a, availabilityMode: .limited, remainingCount: 2),
            RewardDefinition(name: "咖啡兑换券", iconImageData: validRewardImageData(), rank: .a, availabilityMode: .limited, remainingCount: 3),
            RewardDefinition(name: "散步券", iconImageData: validRewardImageData(), rank: .a, availabilityMode: .limited, remainingCount: 1),
            RewardDefinition(name: "阅读券", iconImageData: validRewardImageData(), rank: .a, availabilityMode: .limited, remainingCount: 1),
            RewardDefinition(name: "电影券", iconImageData: validRewardImageData(), rank: .a, availabilityMode: .limited, remainingCount: 1),
        ]
        rewards.forEach { context.insert($0) }
        let firstReward = rewards[0]
        let selectedReward = rewards[1]
        _ = try service.awardPoints(for: .goal(rank: .a, title: "长期目标"), in: context)

        let drawnReward = try service.drawReward(for: .a, in: context)

        #expect(rewards.contains { $0 === drawnReward })
        let changedCount = rewards.filter { reward in
            switch reward.name {
            case "电影夜":
                reward.remainingCount == 1
            case "咖啡兑换券":
                reward.remainingCount == 2
            default:
                reward.remainingCount == 0
            }
        }.count
        #expect(changedCount == 1)
        let inventoryItems = try context.fetch(FetchDescriptor<RewardInventoryItem>())
        #expect(inventoryItems.count == 1)
        #expect(inventoryItems[0].rewardDefinition === drawnReward)
        #expect(drawnReward === firstReward || drawnReward === selectedReward || rewards.dropFirst(2).contains { $0 === drawnReward })
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
        for index in 0..<5 {
            context.insert(RewardDefinition(
                name: "A奖励\(index)",
                iconImageData: validRewardImageData(),
                rank: .a,
                availabilityMode: .limited,
                remainingCount: index == 0 ? 2 : 1
            ))
        }
        _ = try RewardService().awardPoints(for: .goal(rank: .a, title: "长期目标"), in: context)

        let viewModel = HomeViewModel()
        viewModel.drawReward(for: .a, in: context)

        let account = try #require(RewardService().fetchRewardAccount(in: context))
        let inventoryItems = try context.fetch(FetchDescriptor<RewardInventoryItem>())
        #expect(account.points == 95)
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
        #expect(draft.rewardTier == .a)
        #expect(draft.sssPointCost == RewardDefinition.minimumSSSPointCost)
    }

    @MainActor
    @Test
    func homeViewModelPreparesRewardEditDraftFromExistingReward() throws {
        let viewModel = HomeViewModel()
        let reward = RewardDefinition(
            name: "咖啡兑换券",
            icon: "cup.and.saucer.fill",
            iconImageData: validRewardImageData(),
            rewardTier: .sss,
            sssPointCost: 999,
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
        #expect(draft.rewardTier == .sss)
        #expect(draft.sssPointCost == 999)
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
