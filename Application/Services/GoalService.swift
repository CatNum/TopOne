import Foundation
import SwiftData

enum GoalServiceError: Error, Equatable {
    case invalidGoalTitle
    case invalidDailyTaskTitle
    case activeGoalLimitReached
    case dailyTaskLimitReached
    case inProgressDailyTaskLimitReached
    case goalRequired
    case topOneAlreadyExists
    case topOneRequired
    case reasonTooShort(required: Int, actual: Int)
    case reasonTooLong(maximum: Int)
    case invalidCustomLockDuration
}

struct GoalService {
    static let activeGoalLimit = 3
    static let activeDailyTaskLimit = 5
    static let inProgressDailyTaskLimit = 2
    static let minimumSwitchReasonLength = 50
    static let maximumSwitchReasonLength = 500
    static let maximumReasonInputLength = 1_000
    static let maximumCustomLockDays = 180

    @discardableResult
    func createGoal(title: String, rank: TaskRank, in modelContext: ModelContext) throws -> Goal {
        guard Goal.isValidTitle(title) else {
            throw GoalServiceError.invalidGoalTitle
        }
        guard try activeGoals(in: modelContext).count < Self.activeGoalLimit else {
            throw GoalServiceError.activeGoalLimitReached
        }

        let goal = Goal(title: title, rank: rank)
        modelContext.insert(goal)
        try modelContext.save()
        return goal
    }

    func fetchGoals(in modelContext: ModelContext) throws -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor)
    }

    func currentTopOne(in modelContext: ModelContext) throws -> Goal? {
        try fetchGoals(in: modelContext).first(where: { $0.isTopOne })
    }

    func activeGoals(in modelContext: ModelContext) throws -> [Goal] {
        try fetchGoals(in: modelContext).filter { !$0.isCompleted }
    }

    func pausedGoals(in modelContext: ModelContext) throws -> [Goal] {
        try activeGoals(in: modelContext).filter { !$0.isTopOne }
    }

    func completedGoals(in modelContext: ModelContext) throws -> [Goal] {
        try fetchGoals(in: modelContext).filter(\.isCompleted)
    }

    func updateGoal(_ goal: Goal, title: String, rank: TaskRank, in modelContext: ModelContext) throws {
        guard Goal.isValidTitle(title) else {
            throw GoalServiceError.invalidGoalTitle
        }

        goal.title = Goal.normalizedTitle(from: title)
        goal.rank = rank
        try modelContext.save()
    }

    func deleteGoal(_ goal: Goal, in modelContext: ModelContext) throws {
        modelContext.delete(goal)
        try modelContext.save()
    }

    func setTopOne(_ goal: Goal, lockDuration: LockDuration, in modelContext: ModelContext) throws {
        guard try currentTopOne(in: modelContext) == nil else {
            throw GoalServiceError.topOneAlreadyExists
        }

        goal.isTopOne = true
        goal.lockEndsAt = lockDuration.endDate(from: .now)
        try modelContext.save()
    }

    func unbindTopOne(_ goal: Goal, reason: String?, in modelContext: ModelContext) throws {
        guard goal.isTopOne else {
            throw GoalServiceError.topOneRequired
        }

        if isLocked(goal) {
            let requiredLength = requiredReasonLength(for: goal)
            try validateSwitchReason(reason ?? "", requiredLength: requiredLength)
            goal.earlySwitchCount += 1
        } else if goal.isCompleted {
            goal.earlySwitchCount = 0
        }

        goal.isTopOne = false
        goal.lockEndsAt = nil
        try modelContext.save()
    }

    func updateProgress(for goal: Goal, progress: Double, in modelContext: ModelContext) throws {
        goal.progress = Goal.clampedProgress(progress)
        if goal.progress >= 1 {
            goal.completedAt = goal.completedAt ?? .now
            goal.isTopOne = false
            goal.lockEndsAt = nil
            goal.earlySwitchCount = max(goal.earlySwitchCount / 2, 0)
        } else {
            goal.completedAt = nil
        }

        if goal.isCompleted && !goal.rewardPointsAwarded {
            goal.rewardPointsAwarded = true
            _ = try RewardService().awardPoints(for: .goal(rank: goal.rank, title: goal.title), in: modelContext)
        } else {
            try modelContext.save()
        }
    }

    @discardableResult
    func createDailyTask(title: String, rank: TaskRank, goal: Goal, in modelContext: ModelContext) throws -> DailyTask {
        guard DailyTask.isValidTitle(title) else {
            throw GoalServiceError.invalidDailyTaskTitle
        }
        guard activeDailyTasks(for: goal).count < Self.activeDailyTaskLimit else {
            throw GoalServiceError.dailyTaskLimitReached
        }

        let task = DailyTask(title: title, rank: rank, goal: goal)
        modelContext.insert(task)
        try modelContext.save()
        return task
    }

    func fetchDailyTasks(in modelContext: ModelContext) throws -> [DailyTask] {
        let descriptor = FetchDescriptor<DailyTask>(sortBy: [SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor)
    }

    func sortedDailyTasks(for goal: Goal) -> [DailyTask] {
        goal.dailyTasks.sorted {
            if $0.status.sortOrder == $1.status.sortOrder {
                return $0.createdAt < $1.createdAt
            }
            return $0.status.sortOrder < $1.status.sortOrder
        }
    }

    func updateDailyTask(_ task: DailyTask, title: String, rank: TaskRank, goal: Goal, in modelContext: ModelContext) throws {
        guard DailyTask.isValidTitle(title) else {
            throw GoalServiceError.invalidDailyTaskTitle
        }

        task.title = DailyTask.normalizedTitle(from: title)
        task.rank = rank
        task.goal = goal
        try modelContext.save()
    }

    func deleteDailyTask(_ task: DailyTask, in modelContext: ModelContext) throws {
        modelContext.delete(task)
        try modelContext.save()
    }

    func updateDailyTaskStatus(_ task: DailyTask, status: DailyTaskStatus, in modelContext: ModelContext) throws {
        guard task.goal?.isTopOne == true else {
            throw GoalServiceError.topOneRequired
        }

        if status == .inProgress && task.status != .inProgress {
            guard inProgressDailyTasks(for: task.goal).count < Self.inProgressDailyTaskLimit else {
                throw GoalServiceError.inProgressDailyTaskLimitReached
            }
            task.startedAt = task.startedAt ?? .now
        }
        if status == .completed && task.status != .completed {
            task.endedAt = .now
        }

        task.status = status

        if task.status == .completed && !task.rewardPointsAwarded {
            task.rewardPointsAwarded = true
            _ = try RewardService().awardPoints(for: .dailyTask(rank: task.rank, title: task.title), in: modelContext)
        } else {
            try modelContext.save()
        }
    }

    func switchReasonDelta(for reason: String, requiredLength: Int = minimumSwitchReasonLength) -> Int {
        min(reason.count - requiredLength, 0)
    }

    func requiredReasonLength(for goal: Goal) -> Int {
        if goal.isCompleted {
            return Self.minimumSwitchReasonLength
        }
        return nextReasonLength(afterEarlySwitchCount: goal.earlySwitchCount)
    }

    func nextReasonLength(afterEarlySwitchCount count: Int) -> Int {
        min(Self.minimumSwitchReasonLength * Int(pow(2.0, Double(count))), Self.maximumSwitchReasonLength)
    }

    private func activeDailyTasks(for goal: Goal?) -> [DailyTask] {
        goal?.dailyTasks.filter { $0.status != .completed } ?? []
    }

    private func inProgressDailyTasks(for goal: Goal?) -> [DailyTask] {
        goal?.dailyTasks.filter { $0.status == .inProgress } ?? []
    }

    private func isLocked(_ goal: Goal) -> Bool {
        guard let lockEndsAt = goal.lockEndsAt else {
            return false
        }
        return lockEndsAt > .now
    }

    private func validateSwitchReason(_ reason: String, requiredLength: Int = minimumSwitchReasonLength) throws {
        if reason.count > Self.maximumReasonInputLength {
            throw GoalServiceError.reasonTooLong(maximum: Self.maximumReasonInputLength)
        }
        guard reason.count >= requiredLength else {
            throw GoalServiceError.reasonTooShort(required: requiredLength, actual: reason.count)
        }
    }
}

enum LockDuration: Equatable {
    case sevenDays
    case fourteenDays
    case thirtyDays
    case custom(days: Int)

    func endDate(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: dayCount, to: date) ?? date
    }

    var dayCount: Int {
        switch self {
        case .sevenDays:
            7
        case .fourteenDays:
            14
        case .thirtyDays:
            30
        case let .custom(days):
            min(max(days, 1), GoalService.maximumCustomLockDays)
        }
    }
}
