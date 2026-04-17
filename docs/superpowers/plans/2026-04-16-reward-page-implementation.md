# Reward Page Implementation Plan

> 2026-04-17 说明：该计划对应的主体能力已在当前主分支落地。后续请以 `docs/superpowers/specs/2026-04-16-reward-page-design.md` 的当前实现版描述为准；本计划保留为实施过程记录。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reward page centered on积分余额、等级池抽卡、奖励库存与奖励管理，并将任务完成积分发放接入现有任务系统。

**Architecture:** Extend the current SwiftData domain with reward account, reward definitions, and reward inventory items, then add reward-specific service logic on top of the existing `GoalService` patterns. Keep the first version inside the existing app structure by reusing `TopOneRootView.swift` and `HomeViewModel.swift`, while extracting focused reward-domain logic into dedicated models and services so the feature remains testable and does not tangle with task-page rules.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing

---

## File Map

### Create
- `Domain/Models/RewardDefinition.swift` — 奖励定义模型，保存名称、图标、等级、描述、次数模式与剩余次数
- `Domain/Models/RewardAccount.swift` — 用户奖励账户模型，保存当前积分余额
- `Domain/Models/RewardInventoryItem.swift` — 奖励库存条目模型，保存某奖励定义对应的当前持有数量
- `Application/Services/RewardService.swift` — 奖励系统核心服务：积分发放、抽卡、库存消费、奖励 CRUD 校验
- `docs/superpowers/plans/2026-04-16-reward-page-implementation.md` — 本实施计划

### Modify
- `Persistence/Storage/PersistenceController.swift` — 将奖励模型加入 SwiftData schema
- `Presentation/Shared/HomeViewModel.swift` — 增加奖励页所需的草稿、状态、错误文案与调用入口
- `App/Shared/TopOneRootView.swift` — 在现有奖励页占位页基础上接入奖励首页、我的奖励、奖励管理和相关弹层/详情页
- `Application/Services/GoalService.swift` — 在任务完成路径中暴露稳定的积分发放接入点，避免奖励逻辑散落在 UI 中
- `Tests/TopOneCoreTests/TopOneCoreTests.swift` — 增加奖励模型与服务测试，扩展 in-memory container schema

### Test Strategy
- 核心规则测试放在 `Tests/TopOneCoreTests/TopOneCoreTests.swift`
- UI 行为先通过现有 `xcodebuild build` 和聚焦服务层测试验证，不新增独立 UI snapshot 测试

---

### Task 1: 建立奖励领域模型

**Files:**
- Create: `Domain/Models/RewardDefinition.swift`
- Create: `Domain/Models/RewardAccount.swift`
- Create: `Domain/Models/RewardInventoryItem.swift`
- Modify: `Persistence/Storage/PersistenceController.swift:3-17`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing model schema tests**

```swift
@MainActor
@Test
func rewardModelsWorkInSchema() throws {
    let schema = Schema([
        Goal.self,
        DailyTask.self,
        RewardAccount.self,
        RewardDefinition.self,
        RewardInventoryItem.self,
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])

    let account = RewardAccount(points: 12)
    let reward = RewardDefinition(
        name: "喝一杯喜欢的咖啡",
        icon: "cup.and.saucer.fill",
        rank: .b,
        detail: "给自己一个轻松时刻",
        availability: .finite(total: 3)
    )
    let inventory = RewardInventoryItem(definition: reward, currentCount: 2)

    container.mainContext.insert(account)
    container.mainContext.insert(reward)
    container.mainContext.insert(inventory)
    try container.mainContext.save()

    let rewards = try container.mainContext.fetch(FetchDescriptor<RewardDefinition>())
    let inventories = try container.mainContext.fetch(FetchDescriptor<RewardInventoryItem>())

    #expect(rewards.count == 1)
    #expect(inventories.count == 1)
    #expect(inventories[0].definition?.name == "喝一杯喜欢的咖啡")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardModelsWorkInSchema`
Expected: FAIL with errors like `cannot find 'RewardAccount' in scope`

- [ ] **Step 3: Write minimal reward models and schema registration**

`Domain/Models/RewardDefinition.swift`

```swift
import Foundation
import SwiftData

enum RewardAvailabilityMode: String, Codable {
    case finite
    case infinite
}

struct RewardAvailability: Codable, Equatable {
    var mode: RewardAvailabilityMode
    var remainingCount: Int?

    static func finite(total: Int) -> RewardAvailability {
        RewardAvailability(mode: .finite, remainingCount: max(total, 0))
    }

    static let infinite = RewardAvailability(mode: .infinite, remainingCount: nil)
}

@Model
final class RewardDefinition {
    static let minNameLength = 1
    static let maxNameLength = 24

    var name: String
    var icon: String
    var rankRawValue: String
    var detail: String
    var availabilityModeRawValue: String
    var remainingCount: Int?

    var rank: TaskRank {
        get { TaskRank(rawValue: rankRawValue) ?? .c }
        set { rankRawValue = newValue.rawValue }
    }

    var availability: RewardAvailability {
        get {
            RewardAvailability(
                mode: RewardAvailabilityMode(rawValue: availabilityModeRawValue) ?? .finite,
                remainingCount: remainingCount
            )
        }
        set {
            availabilityModeRawValue = newValue.mode.rawValue
            remainingCount = newValue.mode == .finite ? max(newValue.remainingCount ?? 0, 0) : nil
        }
    }

    init(name: String, icon: String, rank: TaskRank, detail: String, availability: RewardAvailability) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = icon
        self.rankRawValue = rank.rawValue
        self.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        self.availabilityModeRawValue = availability.mode.rawValue
        self.remainingCount = availability.mode == .finite ? max(availability.remainingCount ?? 0, 0) : nil
    }
}
```

`Domain/Models/RewardAccount.swift`

```swift
import SwiftData

@Model
final class RewardAccount {
    var points: Int

    init(points: Int = 0) {
        self.points = max(points, 0)
    }
}
```

`Domain/Models/RewardInventoryItem.swift`

```swift
import SwiftData

@Model
final class RewardInventoryItem {
    var currentCount: Int
    var definition: RewardDefinition?

    init(definition: RewardDefinition? = nil, currentCount: Int = 0) {
        self.definition = definition
        self.currentCount = max(currentCount, 0)
    }
}
```

`Persistence/Storage/PersistenceController.swift`

```swift
import SwiftData

enum PersistenceController {
    @MainActor
    static let previewContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            DailyTask.self,
            RewardAccount.self,
            RewardDefinition.self,
            RewardInventoryItem.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create preview model container: \(error)")
        }
    }()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardModelsWorkInSchema`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Domain/Models/RewardDefinition.swift Domain/Models/RewardAccount.swift Domain/Models/RewardInventoryItem.swift Persistence/Storage/PersistenceController.swift Tests/TopOneCoreTests/TopOneCoreTests.swift
git commit -m "feat(reward): 建立奖励领域模型"
```

### Task 2: 实现奖励服务核心规则

**Files:**
- Create: `Application/Services/RewardService.swift`
- Modify: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing reward service tests**

```swift
@MainActor
@Test
func awardPointsAddsMappedPointsToAccount() throws {
    let container = try makeInMemoryContainer()
    let rewardService = RewardService()
    let account = try rewardService.ensureAccount(in: container.mainContext)

    rewardService.awardPoints(for: .dailyTask(rank: .a), in: container.mainContext)

    #expect(account.points == 8)
}

@MainActor
@Test
func drawRewardConsumesPointsAndAddsInventory() throws {
    let container = try makeInMemoryContainer()
    let rewardService = RewardService()
    let account = try rewardService.ensureAccount(in: container.mainContext)
    account.points = 20

    let reward = RewardDefinition(
        name: "喝一杯喜欢的咖啡",
        icon: "cup.and.saucer.fill",
        rank: .b,
        detail: "给自己一个轻松时刻",
        availability: .finite(total: 2)
    )
    container.mainContext.insert(reward)
    try container.mainContext.save()

    let drawn = try rewardService.drawReward(rank: .b, in: container.mainContext)

    let inventories = try container.mainContext.fetch(FetchDescriptor<RewardInventoryItem>())
    #expect(drawn.name == "喝一杯喜欢的咖啡")
    #expect(account.points == 14)
    #expect(reward.remainingCount == 1)
    #expect(inventories.first?.currentCount == 1)
}

@MainActor
@Test
func useRewardConsumesInventoryCount() throws {
    let container = try makeInMemoryContainer()
    let rewardService = RewardService()
    let reward = RewardDefinition(
        name: "电影之夜",
        icon: "popcorn.fill",
        rank: .a,
        detail: "给自己一场完整休息",
        availability: .infinite
    )
    let inventory = RewardInventoryItem(definition: reward, currentCount: 3)
    container.mainContext.insert(reward)
    container.mainContext.insert(inventory)
    try container.mainContext.save()

    try rewardService.useReward(inventory, amount: 2, in: container.mainContext)

    #expect(inventory.currentCount == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/awardPointsAddsMappedPointsToAccount -only-testing:TopOneCoreTests/drawRewardConsumesPointsAndAddsInventory -only-testing:TopOneCoreTests/useRewardConsumesInventoryCount`
Expected: FAIL with `cannot find 'RewardService' in scope`

- [ ] **Step 3: Write minimal reward service implementation**

`Application/Services/RewardService.swift`

```swift
import Foundation
import SwiftData

enum RewardServiceError: Error, Equatable {
    case invalidRewardName
    case invalidRewardDetail
    case insufficientPoints(required: Int, actual: Int)
    case noAvailableReward(rank: TaskRank)
    case invalidUseAmount
    case insufficientInventory
}

enum RewardPointSource: Equatable {
    case dailyTask(rank: TaskRank)
    case goal(rank: TaskRank)
}

struct RewardService {
    private let dailyTaskPoints: [TaskRank: Int] = [.s: 12, .a: 8, .b: 5, .c: 3]
    private let goalPoints: [TaskRank: Int] = [.s: 60, .a: 40, .b: 24, .c: 12]
    private let drawCosts: [TaskRank: Int] = [.s: 50, .a: 30, .b: 6, .c: 3]

    @discardableResult
    func ensureAccount(in modelContext: ModelContext) throws -> RewardAccount {
        let accounts = try modelContext.fetch(FetchDescriptor<RewardAccount>())
        if let account = accounts.first { return account }
        let account = RewardAccount()
        modelContext.insert(account)
        try modelContext.save()
        return account
    }

    func awardPoints(for source: RewardPointSource, in modelContext: ModelContext) {
        let account = try? ensureAccount(in: modelContext)
        guard let account else { return }
        switch source {
        case let .dailyTask(rank):
            account.points += dailyTaskPoints[rank] ?? 0
        case let .goal(rank):
            account.points += goalPoints[rank] ?? 0
        }
        try? modelContext.save()
    }

    @discardableResult
    func drawReward(rank: TaskRank, in modelContext: ModelContext) throws -> RewardDefinition {
        let account = try ensureAccount(in: modelContext)
        let required = drawCosts[rank] ?? 0
        guard account.points >= required else {
            throw RewardServiceError.insufficientPoints(required: required, actual: account.points)
        }

        let descriptor = FetchDescriptor<RewardDefinition>()
        let candidates = try modelContext.fetch(descriptor).filter {
            $0.rank == rank && ($0.availability.mode == .infinite || ($0.remainingCount ?? 0) > 0)
        }
        guard let reward = candidates.sorted(by: { $0.name < $1.name }).first else {
            throw RewardServiceError.noAvailableReward(rank: rank)
        }

        account.points -= required
        if reward.availability.mode == .finite {
            reward.remainingCount = max((reward.remainingCount ?? 0) - 1, 0)
        }

        let inventories = try modelContext.fetch(FetchDescriptor<RewardInventoryItem>())
        if let existing = inventories.first(where: { $0.definition?.persistentModelID == reward.persistentModelID }) {
            existing.currentCount += 1
        } else {
            modelContext.insert(RewardInventoryItem(definition: reward, currentCount: 1))
        }

        try modelContext.save()
        return reward
    }

    func useReward(_ inventory: RewardInventoryItem, amount: Int, in modelContext: ModelContext) throws {
        guard amount > 0 else { throw RewardServiceError.invalidUseAmount }
        guard inventory.currentCount >= amount else { throw RewardServiceError.insufficientInventory }
        inventory.currentCount -= amount
        try modelContext.save()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/awardPointsAddsMappedPointsToAccount -only-testing:TopOneCoreTests/drawRewardConsumesPointsAndAddsInventory -only-testing:TopOneCoreTests/useRewardConsumesInventoryCount`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Application/Services/RewardService.swift Tests/TopOneCoreTests/TopOneCoreTests.swift
git commit -m "feat(reward): 实现奖励服务核心规则"
```

### Task 3: 将任务完成积分发放接入现有闭环

**Files:**
- Modify: `Application/Services/GoalService.swift`
- Modify: `App/Shared/TopOneRootView.swift:2012-2038`
- Modify: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing integration tests for completed tasks and goals awarding points**

```swift
@MainActor
@Test
func completingDailyTaskAwardsPoints() throws {
    let container = try makeInMemoryContainer()
    let goalService = GoalService()
    let rewardService = RewardService()
    _ = try rewardService.ensureAccount(in: container.mainContext)
    let goal = try goalService.createGoal(title: "长期目标", rank: .a, in: container.mainContext)
    goal.isTopOne = true
    let task = try goalService.createDailyTask(title: "完成任务", rank: .b, goal: goal, in: container.mainContext)

    try goalService.updateDailyTaskStatus(task, status: .completed, in: container.mainContext)

    let account = try rewardService.ensureAccount(in: container.mainContext)
    #expect(account.points == 5)
}

@MainActor
@Test
func completingGoalAwardsPoints() throws {
    let container = try makeInMemoryContainer()
    let goalService = GoalService()
    let rewardService = RewardService()
    _ = try rewardService.ensureAccount(in: container.mainContext)
    let goal = try goalService.createGoal(title: "完成长期目标", rank: .s, in: container.mainContext)

    try goalService.updateProgress(for: goal, progress: 1, in: container.mainContext)

    let account = try rewardService.ensureAccount(in: container.mainContext)
    #expect(account.points == 60)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/completingDailyTaskAwardsPoints -only-testing:TopOneCoreTests/completingGoalAwardsPoints`
Expected: FAIL with `account.points == 0`

- [ ] **Step 3: Wire reward points into existing completion paths**

`Application/Services/GoalService.swift`

```swift
func updateProgress(for goal: Goal, progress: Double, in modelContext: ModelContext) throws {
    let wasCompleted = goal.progress >= 1
    goal.progress = Goal.clampedProgress(progress)
    if goal.progress >= 1 {
        goal.completedAt = goal.completedAt ?? .now
        goal.isTopOne = false
        goal.lockEndsAt = nil
        goal.earlySwitchCount = max(goal.earlySwitchCount / 2, 0)
        if !wasCompleted {
            RewardService().awardPoints(for: .goal(rank: goal.rank), in: modelContext)
        }
    } else {
        goal.completedAt = nil
    }
    try modelContext.save()
}

func updateDailyTaskStatus(_ task: DailyTask, status: DailyTaskStatus, in modelContext: ModelContext) throws {
    guard task.goal?.isTopOne == true else {
        throw GoalServiceError.topOneRequired
    }
    let wasCompleted = task.status == .completed
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
    try modelContext.save()

    if status == .completed && !wasCompleted {
        RewardService().awardPoints(for: .dailyTask(rank: task.rank), in: modelContext)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/completingDailyTaskAwardsPoints -only-testing:TopOneCoreTests/completingGoalAwardsPoints`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Application/Services/GoalService.swift App/Shared/TopOneRootView.swift Tests/TopOneCoreTests/TopOneCoreTests.swift
git commit -m "feat(reward): 接入任务完成积分发放"
```

### Task 4: 在 ViewModel 中加入奖励页状态与草稿

**Files:**
- Modify: `Presentation/Shared/HomeViewModel.swift`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing ViewModel state test**

```swift
@MainActor
@Test
func homeViewModelCanPrepareRewardDraft() {
    let viewModel = HomeViewModel()

    viewModel.showCreateRewardDefinition()

    #expect(viewModel.rewardDraft != nil)
    #expect(viewModel.selectedRewardRank == .c)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/homeViewModelCanPrepareRewardDraft`
Expected: FAIL with `value of type 'HomeViewModel' has no member 'showCreateRewardDefinition'`

- [ ] **Step 3: Add minimal reward state management to HomeViewModel**

`Presentation/Shared/HomeViewModel.swift`

```swift
struct RewardDraft: Identifiable {
    let id = UUID()
    var reward: RewardDefinition?
    var name: String
    var icon: String
    var rank: TaskRank
    var detail: String
    var isInfinite: Bool
    var remainingCountText: String

    init(reward: RewardDefinition? = nil) {
        self.reward = reward
        self.name = reward?.name ?? ""
        self.icon = reward?.icon ?? "gift.fill"
        self.rank = reward?.rank ?? .c
        self.detail = reward?.detail ?? ""
        self.isInfinite = reward?.availability.mode == .infinite
        self.remainingCountText = reward?.remainingCount.map(String.init) ?? "1"
    }
}

@Published var rewardDraft: RewardDraft?
@Published var selectedRewardRank: TaskRank = .c
@Published var rewardUseAmountText = "1"

func showCreateRewardDefinition() {
    rewardDraft = RewardDraft()
    selectedRewardRank = .c
}

func showEditRewardDefinition(_ reward: RewardDefinition) {
    rewardDraft = RewardDraft(reward: reward)
    selectedRewardRank = reward.rank
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/homeViewModelCanPrepareRewardDraft`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Presentation/Shared/HomeViewModel.swift Tests/TopOneCoreTests/TopOneCoreTests.swift
git commit -m "feat(reward): 增加奖励页视图状态管理"
```

### Task 5: 实现奖励页首页

**Files:**
- Modify: `App/Shared/TopOneRootView.swift`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Add a focused build-check test target expectation by preparing compile-only entry points**

```swift
@MainActor
@Test
func rewardRootPageEnumStillSupportsRewardsTab() {
    let pages = RootPage.allCases.map(\.title)
    #expect(pages.contains("奖励"))
}
```

- [ ] **Step 2: Run test to verify current placeholder behavior is the only reward output**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardRootPageEnumStillSupportsRewardsTab`
Expected: PASS, but reward page is still placeholder in app UI

- [ ] **Step 3: Replace rewards placeholder with real reward home sections**

`App/Shared/TopOneRootView.swift`

```swift
case .rewards:
    rewardsPage
```

Add focused view sections near `tasksPage`:

```swift
private var rewardsPage: some View {
    VStack(spacing: 22) {
        rewardHeader
        rewardRankSwitcher
        rewardDrawCard
        rewardPreviewStrip
        Spacer(minLength: 0)
    }
    .padding(.horizontal, 24)
    .padding(.top, 18)
    .padding(.bottom, 92)
    .frame(maxWidth: 680, maxHeight: .infinity, alignment: .top)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

private var rewardHeader: some View { /* 显示积分余额 + 各等级池成本 + 我的奖励入口 + 管理入口 */ }
private var rewardRankSwitcher: some View { /* S/A/B/C 切换器 */ }
private var rewardDrawCard: some View { /* 当前池抽卡动作区 */ }
private var rewardPreviewStrip: some View { /* 横向可滚动图标+名称卡片，仅展示可抽奖励 */ }
```

Use `@Query` for `RewardAccount`, `RewardDefinition`, and `RewardInventoryItem` at the top of the view and drive the sections from real data.

- [ ] **Step 4: Run build to verify reward page compiles**

Run: `xcodebuild build -project "TopOne.xcodeproj" -scheme "TopOnemacOS"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add App/Shared/TopOneRootView.swift Tests/TopOneCoreTests/TopOneCoreTests.swift
git commit -m "feat(reward): 实现奖励页首页"
```

### Task 6: 实现奖励管理 CRUD

**Files:**
- Modify: `Application/Services/RewardService.swift`
- Modify: `Presentation/Shared/HomeViewModel.swift`
- Modify: `App/Shared/TopOneRootView.swift`
- Modify: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing CRUD tests**

```swift
@MainActor
@Test
func createRewardDefinitionSavesFiniteReward() throws {
    let container = try makeInMemoryContainer()
    let rewardService = RewardService()

    let reward = try rewardService.createRewardDefinition(
        name: "周末晚餐",
        icon: "fork.knife",
        rank: .a,
        detail: "奖励自己一顿喜欢的晚餐",
        availability: .finite(total: 2),
        in: container.mainContext
    )

    #expect(reward.name == "周末晚餐")
    #expect(reward.remainingCount == 2)
}

@MainActor
@Test
func updateRewardDefinitionChangesAvailability() throws {
    let container = try makeInMemoryContainer()
    let rewardService = RewardService()
    let reward = try rewardService.createRewardDefinition(
        name: "咖啡",
        icon: "cup.and.saucer.fill",
        rank: .c,
        detail: "给自己一点放松",
        availability: .finite(total: 1),
        in: container.mainContext
    )

    try rewardService.updateRewardDefinition(
        reward,
        name: "精品咖啡",
        icon: "cup.and.saucer.fill",
        rank: .b,
        detail: "升级奖励",
        availability: .infinite,
        in: container.mainContext
    )

    #expect(reward.name == "精品咖啡")
    #expect(reward.rank == .b)
    #expect(reward.availability.mode == .infinite)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/createRewardDefinitionSavesFiniteReward -only-testing:TopOneCoreTests/updateRewardDefinitionChangesAvailability`
Expected: FAIL with missing methods on `RewardService`

- [ ] **Step 3: Add reward CRUD methods and connect form actions**

`Application/Services/RewardService.swift`

```swift
@discardableResult
func createRewardDefinition(
    name: String,
    icon: String,
    rank: TaskRank,
    detail: String,
    availability: RewardAvailability,
    in modelContext: ModelContext
) throws -> RewardDefinition {
    let reward = RewardDefinition(name: name, icon: icon, rank: rank, detail: detail, availability: availability)
    modelContext.insert(reward)
    try modelContext.save()
    return reward
}

func updateRewardDefinition(
    _ reward: RewardDefinition,
    name: String,
    icon: String,
    rank: TaskRank,
    detail: String,
    availability: RewardAvailability,
    in modelContext: ModelContext
) throws {
    reward.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    reward.icon = icon
    reward.rank = rank
    reward.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
    reward.availability = availability
    try modelContext.save()
}

func deleteRewardDefinition(_ reward: RewardDefinition, in modelContext: ModelContext) throws {
    modelContext.delete(reward)
    try modelContext.save()
}
```

Add save/delete wiring in `HomeViewModel.swift`, then present reward create/edit sheet in `TopOneRootView.swift` using the same sheet pattern as goal/task forms.

- [ ] **Step 4: Run tests and build to verify CRUD works**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/createRewardDefinitionSavesFiniteReward -only-testing:TopOneCoreTests/updateRewardDefinitionChangesAvailability && xcodebuild build -project "TopOne.xcodeproj" -scheme "TopOnemacOS"`
Expected: tests PASS and build succeeds

- [ ] **Step 5: Commit**

```bash
git add Application/Services/RewardService.swift Presentation/Shared/HomeViewModel.swift App/Shared/TopOneRootView.swift Tests/TopOneCoreTests/TopOneCoreTests.swift
git commit -m "feat(reward): 实现奖励管理 CRUD"
```

### Task 7: 实现“我的奖励”与库存消费流程

**Files:**
- Modify: `App/Shared/TopOneRootView.swift`
- Modify: `Presentation/Shared/HomeViewModel.swift`
- Modify: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing inventory grouping test**

```swift
@MainActor
@Test
func inventoryItemsCanBeSortedByRankAndName() throws {
    let container = try makeInMemoryContainer()
    let sReward = RewardDefinition(name: "自由日", icon: "sparkles", rank: .s, detail: "放空一天", availability: .infinite)
    let cReward = RewardDefinition(name: "咖啡", icon: "cup.and.saucer.fill", rank: .c, detail: "放松一下", availability: .infinite)
    let item1 = RewardInventoryItem(definition: cReward, currentCount: 1)
    let item2 = RewardInventoryItem(definition: sReward, currentCount: 0)
    container.mainContext.insert(sReward)
    container.mainContext.insert(cReward)
    container.mainContext.insert(item1)
    container.mainContext.insert(item2)
    try container.mainContext.save()

    let grouped = RewardService().inventorySections(from: [item1, item2])
    #expect(grouped[0].rank == .s)
    #expect(grouped[0].items[0].currentCount == 0)
    #expect(grouped[1].rank == .c)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/inventoryItemsCanBeSortedByRankAndName`
Expected: FAIL with `value of type 'RewardService' has no member 'inventorySections'`

- [ ] **Step 3: Add inventory section helper and inventory detail flow**

`Application/Services/RewardService.swift`

```swift
struct RewardInventorySection: Equatable {
    let rank: TaskRank
    let items: [RewardInventoryItem]
}

func inventorySections(from items: [RewardInventoryItem]) -> [RewardInventorySection] {
    TaskRank.allCases.compactMap { rank in
        let sectionItems = items
            .filter { $0.definition?.rank == rank }
            .sorted { ($0.definition?.name ?? "") < ($1.definition?.name ?? "") }
        guard !sectionItems.isEmpty else { return nil }
        return RewardInventorySection(rank: rank, items: sectionItems)
    }
}
```

Then in `TopOneRootView.swift`, add:

```swift
private var rewardInventoryPage: some View { /* S/A/B/C 分组、名称排序、数量 0 置灰 */ }
private func rewardInventoryDetail(_ item: RewardInventoryItem) -> some View { /* 使用奖励按钮、数量输入、二次确认 */ }
```

Use a single action button labeled `使用奖励`, backed by `rewardUseAmountText` and a confirmation dialog before calling `RewardService.useReward`.

- [ ] **Step 4: Run tests and build to verify inventory flow compiles**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/inventoryItemsCanBeSortedByRankAndName && xcodebuild build -project "TopOne.xcodeproj" -scheme "TopOnemacOS"`
Expected: PASS and `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Application/Services/RewardService.swift App/Shared/TopOneRootView.swift Presentation/Shared/HomeViewModel.swift Tests/TopOneCoreTests/TopOneCoreTests.swift
git commit -m "feat(reward): 实现我的奖励与库存消费"
```

### Task 8: 完成奖励页收尾验证与文档同步

**Files:**
- Modify: `docs/compliance/v1.0/progress.md`
- Modify: `docs/superpowers/specs/2026-04-16-reward-page-design.md` (only if implementation reveals wording mismatch)
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Run the focused reward test suite**

```bash
xcodebuild test \
  -project "TopOne.xcodeproj" \
  -scheme "TopOnemacOS"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2: Run app build for final compile validation**

```bash
xcodebuild build \
  -project "TopOne.xcodeproj" \
  -scheme "TopOnemacOS"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Update progress document to reflect reward-page planning/implementation status**

`docs/compliance/v1.0/progress.md`

```md
| T-3 | 规划并实现奖励页抽卡正反馈闭环 | 进行中 | | 2026-04-16 | `[任务]` 已完成奖励页设计与实施计划，开始进入奖励模型、积分、抽卡、库存与管理闭环实现 |
```

If implementation is fully complete by this step, change `进行中` to `已完成` and adjust the note to summarize delivery.

- [ ] **Step 4: Review spec wording against final implementation**

Check: `docs/superpowers/specs/2026-04-16-reward-page-design.md`
Expected: no contradictions with implemented reward rank costs, inventory semantics, or reward preview visibility rules

- [ ] **Step 5: Commit**

```bash
git add docs/compliance/v1.0/progress.md docs/superpowers/specs/2026-04-16-reward-page-design.md
git commit -m "docs(reward): 同步奖励页实现进度"
```

---

## Self-Review

### Spec coverage
- 奖励页首页、我的奖励、奖励管理：Task 5, Task 6, Task 7
- 积分规则与任务完成发分：Task 2, Task 3
- 奖励定义有限/无限次数与次数耗尽行为：Task 1, Task 2, Task 6
- 库存消费与数量为 0 置灰：Task 2, Task 7
- 风格约束：在 Task 5 的页面实现中遵循现有 `PrototypeColors` 与 `TopOneRootView.swift` 视觉语言，不另开新主题系统

### Placeholder scan
- No `TODO`, `TBD`, or “similar to” placeholders remain
- Every code-changing step contains code blocks
- Every run step includes exact commands and expected outcomes

### Type consistency
- Reward models use `RewardDefinition`, `RewardAccount`, and `RewardInventoryItem` consistently across all tasks
- Service types remain `RewardService`, `RewardServiceError`, `RewardPointSource`, and `RewardInventorySection`
- Inventory consumption uses `useReward(_:amount:in:)` consistently across service and UI tasks
