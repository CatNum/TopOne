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
            self.title = goal?.title ?? ""
            self.rank = goal?.rank ?? .a
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
            self.title = task?.title ?? ""
            self.rank = task?.rank ?? .a
            self.goal = task?.goal ?? defaultGoal
        }
    }

    enum PendingAction: Identifiable {
        case chooseTopOne(Goal)
        case unbindTopOne(Goal)
        case editProgress(Goal)
        case deleteGoal(Goal)
        case deleteTask(DailyTask)

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
            }
        }
    }

    @Published private(set) var headline: String
    @Published var goalDraft: GoalDraft?
    @Published var dailyTaskDraft: DailyTaskDraft?
    @Published var pendingAction: PendingAction?
    @Published var lockGoal: Goal?
    @Published var customLockGoal: Goal?
    @Published var switchReasonGoal: Goal?
    @Published var progressGoal: Goal?
    @Published var customLockDaysText = ""
    @Published var switchReason = ""
    @Published var progressText = ""
    @Published var errorMessage: String?

    private let service = GoalService()

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

    func setTopOne(_ goal: Goal, lockDuration: LockDuration, in modelContext: ModelContext) {
        do {
            if case let .custom(days) = lockDuration,
               !(1...GoalService.maximumCustomLockDays).contains(days) {
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
        case 1...GoalService.maximumCustomLockDays: return .custom(days: days)
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
        guard let error = error as? GoalServiceError else {
            return "操作失败，请重试"
        }

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
}
