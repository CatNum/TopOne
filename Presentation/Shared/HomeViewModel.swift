import Foundation
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {
    struct GoalDraft: Identifiable {
        let id = UUID()
        var goal: Goal?
        var title: String
        var rank: TaskRank

        init(goal: Goal? = nil) {
            self.goal = goal
            title = goal?.title ?? ""
            rank = goal?.rank ?? .a
        }
    }

    struct DailyTaskDraft: Identifiable {
        let id = UUID()
        var task: DailyTask?
        var title: String
        var rank: TaskRank
        var goal: Goal?

        init(task: DailyTask? = nil, defaultGoal: Goal? = nil) {
            self.task = task
            title = task?.title ?? ""
            rank = task?.rank ?? .a
            goal = task?.goal ?? defaultGoal
        }
    }

    struct RewardDraft: Identifiable {
        let id = UUID()
        var reward: RewardDefinition?
        var name: String
        var icon: String
        var iconImageData: Data
        var rewardTier: RewardTier
        var detail: String
        var availabilityMode: RewardAvailabilityMode
        var remainingCount: Int
        var sssPointCost: Int

        init(reward: RewardDefinition? = nil) {
            self.reward = reward
            name = reward?.name ?? ""
            icon = reward?.icon ?? ""
            iconImageData = reward?.iconImageData ?? Data()
            rewardTier = reward?.rewardTier ?? .a
            detail = reward?.detail ?? ""
            availabilityMode = reward?.availabilityMode ?? .unlimited
            remainingCount = reward?.remainingCount ?? 0
            sssPointCost = reward?.sssPointCost ?? RewardDefinition.minimumSSSPointCost
        }
    }

    enum PendingAction: Identifiable {
        case chooseTopOne(Goal)
        case unbindTopOne(Goal)
        case editProgress(Goal)
        case deleteGoal(Goal)
        case deleteTask(DailyTask)
        case deleteReward(RewardDefinition)

        var id: String {
            switch self {
            case let .chooseTopOne(goal):
                "choose-top-one-\(goal.persistentModelID)"
            case let .unbindTopOne(goal):
                "unbind-top-one-\(goal.persistentModelID)"
            case let .editProgress(goal):
                "edit-progress-\(goal.persistentModelID)"
            case let .deleteGoal(goal):
                "delete-goal-\(goal.persistentModelID)"
            case let .deleteTask(task):
                "delete-task-\(task.persistentModelID)"
            case let .deleteReward(reward):
                "delete-reward-\(reward.persistentModelID)"
            }
        }
    }

    @Published private(set) var headline: String
    @Published var goalDraft: GoalDraft?
    @Published var dailyTaskDraft: DailyTaskDraft?
    @Published var rewardDraft: RewardDraft?
    @Published var pendingAction: PendingAction?
    @Published var lockGoal: Goal?
    @Published var customLockGoal: Goal?
    @Published var switchReasonGoal: Goal?
    @Published var progressGoal: Goal?
    @Published var customLockDaysText = ""
    @Published var switchReason = ""
    @Published var progressText = ""
    @Published var selectedRewardTier: RewardTier = .a
    @Published var rewardUseAmountText = "1"
    @Published var errorMessage: String?

    private let service = GoalService()
    private let rewardService = RewardService()

    init(headline: String = "TopOne") {
        self.headline = headline
    }

    func showCreateGoal() {
        goalDraft = GoalDraft()
    }

    func showEditGoal(_ goal: Goal) {
        goalDraft = GoalDraft(goal: goal)
    }

    func showCreateDailyTask(defaultGoal: Goal?) {
        dailyTaskDraft = DailyTaskDraft(defaultGoal: defaultGoal)
    }

    func showEditDailyTask(_ task: DailyTask, defaultGoal: Goal?) {
        dailyTaskDraft = DailyTaskDraft(task: task, defaultGoal: defaultGoal)
    }

    func showCreateRewardDefinition() {
        rewardDraft = RewardDraft()
    }

    func showEditRewardDefinition(_ reward: RewardDefinition) {
        rewardDraft = RewardDraft(reward: reward)
    }

    func saveGoal(in modelContext: ModelContext) {
        guard let draft = goalDraft else { return }

        do {
            if let goal = draft.goal {
                try service.updateGoal(goal, title: draft.title, rank: draft.rank, in: modelContext)
            } else {
                _ = try service.createGoal(title: draft.title, rank: draft.rank, in: modelContext)
            }
            goalDraft = nil
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func saveDailyTask(in modelContext: ModelContext) {
        guard let draft = dailyTaskDraft, let goal = draft.goal else {
            errorMessage = "请选择一个长期任务"
            return
        }

        do {
            if let task = draft.task {
                try service.updateDailyTask(task, title: draft.title, rank: draft.rank, goal: goal, in: modelContext)
            } else {
                _ = try service.createDailyTask(title: draft.title, rank: draft.rank, goal: goal, in: modelContext)
            }
            dailyTaskDraft = nil
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func deleteGoal(_ goal: Goal, in modelContext: ModelContext) {
        do {
            try service.deleteGoal(goal, in: modelContext)
            pendingAction = nil
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func deleteTask(_ task: DailyTask, in modelContext: ModelContext) {
        do {
            try service.deleteDailyTask(task, in: modelContext)
            pendingAction = nil
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func saveRewardDefinition(in modelContext: ModelContext) {
        guard let draft = rewardDraft else { return }

        do {
            if let reward = draft.reward {
                try rewardService.updateRewardDefinition(
                    reward,
                    name: draft.name,
                    icon: draft.icon,
                    iconImageData: draft.iconImageData,
                    rewardTier: draft.rewardTier,
                    sssPointCost: draft.rewardTier == .sss ? draft.sssPointCost : RewardDefinition.minimumSSSPointCost,
                    detail: draft.detail,
                    availabilityMode: draft.availabilityMode,
                    remainingCount: draft.remainingCount,
                    in: modelContext
                )
            } else {
                _ = try rewardService.createRewardDefinition(
                    name: draft.name,
                    icon: draft.icon,
                    iconImageData: draft.iconImageData,
                    rewardTier: draft.rewardTier,
                    sssPointCost: draft.rewardTier == .sss ? draft.sssPointCost : RewardDefinition.minimumSSSPointCost,
                    detail: draft.detail,
                    availabilityMode: draft.availabilityMode,
                    remainingCount: draft.remainingCount,
                    in: modelContext
                )
            }
            rewardDraft = nil
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func deleteRewardDefinition(_ reward: RewardDefinition, in modelContext: ModelContext) {
        do {
            try rewardService.deleteRewardDefinition(reward, in: modelContext)
            pendingAction = nil
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func prepareRewardUsage() {
        rewardUseAmountText = "1"
        errorMessage = nil
    }

    @discardableResult
    func drawReward(in modelContext: ModelContext) -> RewardDefinition? {
        guard let rank = selectedRewardTier.normalRank else {
            errorMessage = "SSS 奖励不参与抽卡，请直接兑换"
            return nil
        }
        return drawReward(for: rank, in: modelContext)
    }

    @discardableResult
    func drawReward(for rank: TaskRank, in modelContext: ModelContext) -> RewardDefinition? {
        do {
            let reward = try rewardService.drawReward(for: rank, in: modelContext)
            selectedRewardTier = RewardTier(rawValue: rank.rawValue) ?? .a
            errorMessage = nil
            return reward
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func useReward(_ item: RewardInventoryItem, in modelContext: ModelContext) {
        let trimmed = rewardUseAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Int(trimmed) else {
            errorMessage = message(for: RewardServiceError.invalidUseAmount)
            return
        }

        do {
            try rewardService.useReward(item, amount: amount, in: modelContext)
            rewardUseAmountText = "1"
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    @discardableResult
    func exchangeNormalRewardDirectly(_ reward: RewardDefinition, in modelContext: ModelContext) -> RewardInventoryItem? {
        do {
            let item = try rewardService.exchangeNormalRewardDirectly(reward, in: modelContext)
            errorMessage = nil
            return item
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    @discardableResult
    func exchangeSSSRewardDirectly(_ reward: RewardDefinition, in modelContext: ModelContext) -> RewardInventoryItem? {
        do {
            let item = try rewardService.exchangeSSSRewardDirectly(reward, in: modelContext)
            errorMessage = nil
            return item
        } catch {
            errorMessage = message(for: error)
            return nil
        }
    }

    func setTopOne(_ goal: Goal, lockDuration: LockDuration, in modelContext: ModelContext) {
        do {
            if case let .custom(days) = lockDuration,
               !(1 ... GoalService.maximumCustomLockDays).contains(days)
            {
                throw GoalServiceError.invalidCustomLockDuration
            }
            try service.setTopOne(goal, lockDuration: lockDuration, in: modelContext)
            pendingAction = nil
            customLockGoal = nil
            customLockDaysText = ""
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func setCustomTopOne(_ goal: Goal, in modelContext: ModelContext) {
        guard let days = Int(customLockDaysText) else {
            errorMessage = message(for: GoalServiceError.invalidCustomLockDuration)
            return
        }
        setTopOne(goal, lockDuration: .custom(days: days), in: modelContext)
    }

    func unbindTopOne(_ goal: Goal, in modelContext: ModelContext) {
        do {
            let reason = switchReason.trimmingCharacters(in: .whitespacesAndNewlines)
            try service.unbindTopOne(goal, reason: reason.isEmpty ? nil : reason, in: modelContext)
            pendingAction = nil
            switchReasonGoal = nil
            switchReason = ""
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func updateProgress(for goal: Goal, in modelContext: ModelContext) {
        let sanitized = progressText.trimmingCharacters(in: .whitespacesAndNewlines)
        let numericValue = Double(sanitized) ?? 0
        let normalized = numericValue > 1 ? numericValue / 100 : numericValue
        updateProgress(for: goal, value: normalized, in: modelContext)
        if errorMessage == nil {
            pendingAction = nil
            progressGoal = nil
            progressText = ""
        }
    }

    func updateProgress(for goal: Goal, value: Double, in modelContext: ModelContext) {
        do {
            try service.updateProgress(for: goal, progress: value, in: modelContext)
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func updateTaskStatus(_ task: DailyTask, status: DailyTaskStatus, in modelContext: ModelContext) {
        do {
            try service.updateDailyTaskStatus(task, status: status, in: modelContext)
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func lockDurationFromInput(_ days: Int?) -> LockDuration? {
        guard let days else { return nil }
        switch days {
        case 7: return .sevenDays
        case 14: return .fourteenDays
        case 30: return .thirtyDays
        case 1 ... GoalService.maximumCustomLockDays: return .custom(days: days)
        default: return nil
        }
    }

    func prepareProgressEditor(for goal: Goal) {
        progressText = String(Int((goal.progress * 100).rounded()))
        progressGoal = goal
    }

    func prepareSwitchReason(for goal: Goal) {
        switchReason = ""
        switchReasonGoal = goal
    }

    func prepareLock(for goal: Goal) {
        customLockDaysText = ""
        lockGoal = goal
        pendingAction = nil
    }

    func prepareCustomLock(for goal: Goal) {
        customLockDaysText = ""
        customLockGoal = goal
        lockGoal = nil
        pendingAction = nil
    }

    private func message(for error: Error) -> String {
        if let error = error as? GoalServiceError {
            switch error {
            case .invalidGoalTitle:
                return "长期任务标题需为 1 到 16 个字符"
            case .invalidDailyTaskTitle:
                return "日常任务标题需为 1 到 32 个字符"
            case .activeGoalLimitReached:
                return "未完成长期任务最多 3 个"
            case .dailyTaskLimitReached:
                return "该长期任务下未完成日常任务最多 5 个"
            case .inProgressDailyTaskLimitReached:
                return "执行中的日常任务最多 2 个"
            case .goalRequired:
                return "请选择所属长期任务"
            case .topOneAlreadyExists:
                return "请先解绑当前 TopOne"
            case .topOneRequired:
                return "仅当前 TopOne 下的日常任务可更新状态"
            case let .reasonTooShort(required, actual):
                return "更换理由至少 \(required) 字，当前 \(actual) 字"
            case let .reasonTooLong(maximum):
                return "更换理由不能超过 \(maximum) 字"
            case .invalidCustomLockDuration:
                return "自定义锁定时间需在 1 到 180 天内"
            }
        }

        if let error = error as? RewardServiceError {
            switch error {
            case .invalidRewardName:
                return "奖励名称需为 1 到 32 个字符"
            case .rewardImageRequired:
                return "请为奖励选择一张图片图标"
            case .invalidLimitedRewardCount:
                return "限量奖励至少需要 1 份库存"
            case let .invalidSSSPointCost(minimum):
                return "SSS 奖励至少需要 \(minimum) 积分"
            case let .insufficientPoints(required, actual):
                return "积分不足，还需 \(max(required - actual, 0)) 分"
            case .rewardNotFound:
                return "该等级下暂无可用奖励"
            case .rewardUnavailable:
                return "奖励已被领完，请换一个试试"
            case let .drawPoolTooSmall(_, minimum, actual):
                return "当前等级可用奖励仅有 \(actual) 个，至少需要 \(minimum) 个才能抽取"
            case .noExchangeCredit:
                return "当前等级暂无可用直兑次数，请先抽奖累积"
            case .invalidUseAmount:
                return "使用数量至少为 1"
            case .insufficientInventory:
                return "库存不足，无法完成本次领取"
            }
        }

        return "操作失败，请重试"
    }
}
