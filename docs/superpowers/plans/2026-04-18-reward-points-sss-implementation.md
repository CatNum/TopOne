# Reward Points and SSS Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the new reward economy on top of the current reward page: capped point production, pity-based direct exchange for normal rewards, a non-draw `SSS` reward tier with minimum custom cost `888`, and inline rule hints that explain the new behavior.

**Architecture:** Keep task ranks as `S / A / B / C`, but split reward tiers away from tasks by introducing a reward-only tier type that includes `SSS`. Extend the existing reward domain models and `RewardService.swift` with the minimum persistent state needed for daily caps, pity credits, direct exchange, and `SSS` custom costs, then adapt `HomeViewModel.swift` and `TopOneRootView.swift` so the current reward page switches between normal draw mode and `SSS` direct-exchange mode without adding new pages.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PhotosUI, Swift Testing, `xcodebuild`

---

## File Map

### Modify
- `Domain/Models/RewardDefinition.swift` — add a reward-only tier type that includes `SSS`, a direct-exchange cost field, and helpers for distinguishing `SSS` rewards from normal rewards.
- `Domain/Models/RewardAccount.swift` — persist daily point counters plus per-rank draw counts and pity credits.
- `Application/Services/RewardService.swift` — enforce daily caps, draw gating, pity credits, normal direct exchange, `SSS` cost validation, and transaction recording.
- `Application/Services/GoalService.swift` — keep task completion integrated with reward point awarding while preserving task-side `S / A / B / C` ranks.
- `Presentation/Shared/HomeViewModel.swift` — expand reward draft state, expose direct-exchange actions, and add user-facing messages for new errors.
- `App/Shared/TopOneRootView.swift` — switch reward-home content when `SSS` is selected, add inline rule hints, and update the reward form for `SSS` cost input.
- `Tests/TopOneCoreTests/TopOneCoreTests.swift` — add focused in-memory tests for the new domain types, service rules, draft flow, and transaction semantics.
- `docs/superpowers/plans/2026-04-18-reward-points-sss-implementation.md` — this implementation plan.

### Keep As-Is But Read For Context
- `Domain/Models/DailyTask.swift` — task ranks remain `S / A / B / C`; do not add `SSS` here.
- `docs/superpowers/specs/2026-04-16-reward-page-design.md` — baseline reward page structure spec.
- `docs/superpowers/specs/2026-04-18-reward-points-sss-design.md` — additive rules spec that this plan implements.

### Test Strategy
- Put all new rule coverage in `Tests/TopOneCoreTests/TopOneCoreTests.swift` using the existing in-memory `ModelContainer` helper.
- Validate service changes first with targeted `TopOneCoreTests` selectors.
- Validate the integrated app build with `xcodebuild build -project "TopOne.xcodeproj" -scheme "TopOnemacOS"` after service and UI work land.

---

### Task 1: Add reward-only `SSS` tier and `SSS` direct cost to the domain

**Files:**
- Modify: `Domain/Models/RewardDefinition.swift:1-65`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing domain tests**

```swift
@MainActor
@Test
func rewardDefinitionSupportsSSSTierAndCustomCost() throws {
    let container = try makeInMemoryContainer()
    let context = container.mainContext

    let reward = RewardDefinition(
        name: "欧洲旅行",
        iconImageData: validRewardImageData(),
        rewardTier: .sss,
        detail: "长期大奖励",
        availabilityMode: .unlimited,
        remainingCount: 0,
        sssPointCost: 888
    )
    context.insert(reward)
    try context.save()

    let rewards = try context.fetch(FetchDescriptor<RewardDefinition>())

    #expect(rewards.count == 1)
    #expect(rewards[0].rewardTier == .sss)
    #expect(rewards[0].sssPointCost == 888)
    #expect(rewards[0].isSSSReward == true)
}

@MainActor
@Test
func rewardDefinitionKeepsTaskRankForNormalRewards() throws {
    let reward = RewardDefinition(
        name: "咖啡券",
        iconImageData: validRewardImageData(),
        rewardTier: .a,
        detail: "普通奖励"
    )

    #expect(reward.rewardTier == .a)
    #expect(reward.normalRank == .a)
    #expect(reward.isSSSReward == false)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardDefinitionSupportsSSSTierAndCustomCost -only-testing:TopOneCoreTests/rewardDefinitionKeepsTaskRankForNormalRewards`
Expected: FAIL because `RewardDefinition` does not yet have `rewardTier`, `sssPointCost`, `isSSSReward`, or `normalRank`.

- [ ] **Step 3: Add the reward-only tier model**

`Domain/Models/RewardDefinition.swift`

```swift
import Foundation
import SwiftData

enum RewardTier: String, CaseIterable, Identifiable, Codable {
    case sss = "SSS"
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"

    var id: String { rawValue }

    var normalTaskRank: TaskRank? {
        switch self {
        case .sss:
            nil
        case .s:
            .s
        case .a:
            .a
        case .b:
            .b
        case .c:
            .c
        }
    }
}

enum RewardAvailabilityMode: String, CaseIterable, Identifiable, Codable {
    case unlimited = "unlimited"
    case limited = "limited"

    var id: String { rawValue }
}

@Model
final class RewardDefinition {
    static let minimumSSSPointCost = 888

    var name: String
    var icon: String
    @Attribute(.externalStorage) var iconImageData: Data
    var rewardTierRawValue: String
    var detail: String
    var availabilityModeRawValue: String
    var remainingCount: Int
    var sssPointCost: Int?

    @Relationship(deleteRule: .cascade, inverse: \RewardInventoryItem.rewardDefinition)
    var inventoryItems: [RewardInventoryItem]

    var rewardTier: RewardTier {
        get { RewardTier(rawValue: rewardTierRawValue) ?? .c }
        set { rewardTierRawValue = newValue.rawValue }
    }

    var availabilityMode: RewardAvailabilityMode {
        get { RewardAvailabilityMode(rawValue: availabilityModeRawValue) ?? .unlimited }
        set { availabilityModeRawValue = newValue.rawValue }
    }

    var normalRank: TaskRank? {
        rewardTier.normalTaskRank
    }

    var isSSSReward: Bool {
        rewardTier == .sss
    }

    init(
        name: String,
        icon: String = "",
        iconImageData: Data,
        rewardTier: RewardTier,
        detail: String = "",
        availabilityMode: RewardAvailabilityMode = .unlimited,
        remainingCount: Int = 0,
        sssPointCost: Int? = nil,
        inventoryItems: [RewardInventoryItem] = []
    ) {
        self.name = RewardDefinition.normalizedName(from: name)
        self.icon = RewardDefinition.normalizedIcon(from: icon)
        self.iconImageData = iconImageData
        self.rewardTierRawValue = rewardTier.rawValue
        self.detail = RewardDefinition.normalizedDetail(from: detail)
        self.availabilityModeRawValue = availabilityMode.rawValue
        self.remainingCount = max(0, remainingCount)
        self.sssPointCost = rewardTier == .sss ? max(sssPointCost ?? Self.minimumSSSPointCost, Self.minimumSSSPointCost) : nil
        self.inventoryItems = inventoryItems
    }

    static func normalizedName(from name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedIcon(from icon: String) -> String {
        icon.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedDetail(from detail: String) -> String {
        detail.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardDefinitionSupportsSSSTierAndCustomCost -only-testing:TopOneCoreTests/rewardDefinitionKeepsTaskRankForNormalRewards`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Domain/Models/RewardDefinition.swift" "Tests/TopOneCoreTests/TopOneCoreTests.swift"
git commit -m "feat(reward): add reward-only sss tier"
```

---

### Task 2: Persist daily caps and pity counters in `RewardAccount`

**Files:**
- Modify: `Domain/Models/RewardAccount.swift:1-11`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing account-state test**

```swift
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
    #expect(stored.dailyTaskPointsAwarded == 20)
    #expect(stored.didAwardGoalPointsToday == true)
    #expect(stored.drawCountsByTier[RewardTier.a.rawValue] == 9)
    #expect(stored.exchangeCreditsByTier[RewardTier.a.rawValue] == 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardAccountPersistsDailyAndPityState`
Expected: FAIL because `RewardAccount` lacks the new state fields.

- [ ] **Step 3: Add minimal persisted counters**

`Domain/Models/RewardAccount.swift`

```swift
import Foundation
import SwiftData

@Model
final class RewardAccount {
    var points: Int
    var lastPointResetAt: Date?
    var dailyTaskPointsAwarded: Int
    var didAwardGoalPointsToday: Bool
    var drawCountsByTierRawValue: Data
    var exchangeCreditsByTierRawValue: Data

    var drawCountsByTier: [String: Int] {
        get { (try? JSONDecoder().decode([String: Int].self, from: drawCountsByTierRawValue)) ?? [:] }
        set { drawCountsByTierRawValue = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var exchangeCreditsByTier: [String: Int] {
        get { (try? JSONDecoder().decode([String: Int].self, from: exchangeCreditsByTierRawValue)) ?? [:] }
        set { exchangeCreditsByTierRawValue = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(
        points: Int = 0,
        lastPointResetAt: Date? = nil,
        dailyTaskPointsAwarded: Int = 0,
        didAwardGoalPointsToday: Bool = false,
        drawCountsByTier: [String: Int] = [:],
        exchangeCreditsByTier: [String: Int] = [:]
    ) {
        self.points = max(0, points)
        self.lastPointResetAt = lastPointResetAt
        self.dailyTaskPointsAwarded = max(0, dailyTaskPointsAwarded)
        self.didAwardGoalPointsToday = didAwardGoalPointsToday
        self.drawCountsByTierRawValue = (try? JSONEncoder().encode(drawCountsByTier)) ?? Data()
        self.exchangeCreditsByTierRawValue = (try? JSONEncoder().encode(exchangeCreditsByTier)) ?? Data()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardAccountPersistsDailyAndPityState`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Domain/Models/RewardAccount.swift" "Tests/TopOneCoreTests/TopOneCoreTests.swift"
git commit -m "feat(reward): persist pity and daily cap state"
```

---

### Task 3: Enforce daily point-production limits in `RewardService`

**Files:**
- Modify: `Application/Services/RewardService.swift:13-300`
- Modify: `Application/Services/GoalService.swift`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing point-production tests**

```swift
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

    #expect(account.points == 10)
    #expect(account.didAwardGoalPointsToday == true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/dailyTaskPointsCapAtThirtyPerDay -only-testing:TopOneCoreTests/goalPointsAwardOnlyOncePerDayAcrossAllGoals`
Expected: FAIL because point awards are currently uncapped and goal points can repeat.

- [ ] **Step 3: Add daily cap logic without changing task ranks**

`Application/Services/RewardService.swift`

```swift
enum RewardServiceError: Error, Equatable {
    case invalidRewardName
    case rewardImageRequired
    case invalidLimitedRewardCount
    case invalidSSSPointCost(minimum: Int)
    case insufficientPoints(required: Int, actual: Int)
    case rewardNotFound(tier: RewardTier)
    case rewardUnavailable
    case rewardPoolTooSmall(required: Int, actual: Int)
    case invalidUseAmount
    case insufficientInventory
}

private let dailyTaskPoints: [TaskRank: Int] = [
    .s: 12,
    .a: 8,
    .b: 5,
    .c: 3,
]

private let goalPoints: [TaskRank: Int] = [
    .s: 20,
    .a: 10,
    .b: 6,
    .c: 4,
]

private let dailyTaskPointCap = 30

private func normalizeDailyState(for account: RewardAccount, now: Date = .now, calendar: Calendar = .current) {
    guard let lastPointResetAt = account.lastPointResetAt else {
        account.lastPointResetAt = now
        return
    }
    if !calendar.isDate(lastPointResetAt, inSameDayAs: now) {
        account.lastPointResetAt = now
        account.dailyTaskPointsAwarded = 0
        account.didAwardGoalPointsToday = false
    }
}

@discardableResult
func awardPoints(for source: RewardPointSource, in modelContext: ModelContext) throws -> RewardAccount {
    let account = try ensureRewardAccount(in: modelContext)
    normalizeDailyState(for: account)

    let delta: Int
    let reason: RewardPointChangeReason
    let rank: TaskRank
    let title: String

    switch source {
    case let .dailyTask(taskRank, taskTitle):
        let rawPoints = dailyTaskPoints[taskRank] ?? 0
        let remainingToday = max(dailyTaskPointCap - account.dailyTaskPointsAwarded, 0)
        delta = min(rawPoints, remainingToday)
        account.dailyTaskPointsAwarded += delta
        reason = .completeDailyTask
        rank = taskRank
        title = taskTitle
    case let .goal(goalRank, goalTitle):
        delta = account.didAwardGoalPointsToday ? 0 : (goalPoints[goalRank] ?? 0)
        if delta > 0 {
            account.didAwardGoalPointsToday = true
        }
        reason = .completeGoal
        rank = goalRank
        title = goalTitle
    }

    account.lastPointResetAt = .now
    guard delta > 0 else {
        try modelContext.save()
        return account
    }

    account.points += delta
    recordPointTransaction(
        delta: delta,
        balanceAfterChange: account.points,
        kind: .earn,
        reason: reason,
        taskRank: rank,
        rewardTier: nil,
        referenceTitle: title,
        in: modelContext
    )
    try modelContext.save()
    return account
}
```

`Application/Services/GoalService.swift`

```swift
if status == .completed, task.rewardPointsAwarded == false {
    _ = try rewardService.awardPoints(
        for: .dailyTask(rank: task.rank, title: task.title),
        in: modelContext
    )
    task.rewardPointsAwarded = true
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/dailyTaskPointsCapAtThirtyPerDay -only-testing:TopOneCoreTests/goalPointsAwardOnlyOncePerDayAcrossAllGoals`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Application/Services/RewardService.swift" "Application/Services/GoalService.swift" "Tests/TopOneCoreTests/TopOneCoreTests.swift"
git commit -m "feat(reward): cap daily point production"
```

---

### Task 4: Add normal-reward draw gating, pity credits, and direct exchange

**Files:**
- Modify: `Application/Services/RewardService.swift:18-300`
- Modify: `Presentation/Shared/HomeViewModel.swift:34-280`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing draw and exchange tests**

```swift
@MainActor
@Test
func drawRequiresAtLeastFiveAvailableNormalRewards() throws {
    let container = try makeInMemoryContainer()
    let context = container.mainContext
    let service = RewardService()

    for index in 0..<4 {
        context.insert(RewardDefinition(name: "奖励\(index)", iconImageData: validRewardImageData(), rewardTier: .a))
    }
    let account = try service.ensureRewardAccount(in: context)
    account.points = 12
    try context.save()

    #expect(throws: RewardServiceError.rewardPoolTooSmall(required: 5, actual: 4)) {
        try service.drawReward(for: .a, in: context)
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/drawRequiresAtLeastFiveAvailableNormalRewards -only-testing:TopOneCoreTests/everyTenDrawsGrantOneExchangeCreditForThatTier -only-testing:TopOneCoreTests/normalRewardDirectExchangeConsumesPointsAndCredit`
Expected: FAIL because there is no draw gate, no pity counter, and no normal direct-exchange API.

- [ ] **Step 3: Implement normal-tier draw and exchange rules**

`Application/Services/RewardService.swift`

```swift
private let drawCosts: [RewardTier: Int] = [
    .s: 12,
    .a: 5,
    .b: 3,
    .c: 2,
]
private let minimumRewardTypesForDraw = 5
private let pityThreshold = 10

func drawCost(for tier: RewardTier) -> Int {
    drawCosts[tier] ?? 0
}

func availableNormalRewards(for tier: RewardTier, in modelContext: ModelContext) throws -> [RewardDefinition] {
    let descriptor = FetchDescriptor<RewardDefinition>(sortBy: [SortDescriptor(\.name)])
    return try modelContext.fetch(descriptor).filter {
        $0.rewardTier == tier && ($0.availabilityMode == .unlimited || $0.remainingCount > 0)
    }
}

@discardableResult
func drawReward(for tier: RewardTier, in modelContext: ModelContext) throws -> RewardDefinition {
    let account = try ensureRewardAccount(in: modelContext)
    let rewards = try availableNormalRewards(for: tier, in: modelContext)
    guard rewards.count >= minimumRewardTypesForDraw else {
        throw RewardServiceError.rewardPoolTooSmall(required: minimumRewardTypesForDraw, actual: rewards.count)
    }

    let cost = drawCost(for: tier)
    guard account.points >= cost else {
        throw RewardServiceError.insufficientPoints(required: cost, actual: account.points)
    }
    guard let reward = rewards.randomElement() else {
        throw RewardServiceError.rewardNotFound(tier: tier)
    }

    account.points -= cost
    let nextDrawCount = (account.drawCountsByTier[tier.rawValue] ?? 0) + 1
    account.drawCountsByTier[tier.rawValue] = nextDrawCount
    if nextDrawCount % pityThreshold == 0 {
        let currentCredits = account.exchangeCreditsByTier[tier.rawValue] ?? 0
        account.exchangeCreditsByTier[tier.rawValue] = currentCredits + 1
    }

    recordPointTransaction(
        delta: -cost,
        balanceAfterChange: account.points,
        kind: .spend,
        reason: .drawReward,
        taskRank: nil,
        rewardTier: tier,
        referenceTitle: reward.name,
        in: modelContext
    )

    if reward.availabilityMode == .limited {
        reward.remainingCount -= 1
    }

    let inventoryItem = reward.inventoryItems.first ?? RewardInventoryItem(currentCount: 0, rewardDefinition: reward)
    if inventoryItem.modelContext == nil {
        modelContext.insert(inventoryItem)
    }
    inventoryItem.currentCount += 1

    try modelContext.save()
    return reward
}

@discardableResult
func exchangeNormalRewardDirectly(_ reward: RewardDefinition, in modelContext: ModelContext) throws -> RewardInventoryItem {
    guard let tier = reward.normalRank.flatMap({ RewardTier(rawValue: $0.rawValue) }) else {
        throw RewardServiceError.rewardUnavailable
    }

    let account = try ensureRewardAccount(in: modelContext)
    let availableCredits = account.exchangeCreditsByTier[tier.rawValue] ?? 0
    guard availableCredits > 0 else {
        throw RewardServiceError.rewardUnavailable
    }

    let cost = drawCost(for: tier)
    guard account.points >= cost else {
        throw RewardServiceError.insufficientPoints(required: cost, actual: account.points)
    }
    guard reward.availabilityMode == .unlimited || reward.remainingCount > 0 else {
        throw RewardServiceError.rewardUnavailable
    }

    account.points -= cost
    account.exchangeCreditsByTier[tier.rawValue] = availableCredits - 1
    recordPointTransaction(
        delta: -cost,
        balanceAfterChange: account.points,
        kind: .spend,
        reason: .exchangeReward,
        taskRank: nil,
        rewardTier: tier,
        referenceTitle: reward.name,
        in: modelContext
    )

    if reward.availabilityMode == .limited {
        reward.remainingCount -= 1
    }

    let inventoryItem = reward.inventoryItems.first ?? RewardInventoryItem(currentCount: 0, rewardDefinition: reward)
    if inventoryItem.modelContext == nil {
        modelContext.insert(inventoryItem)
    }
    inventoryItem.currentCount += 1

    try modelContext.save()
    return inventoryItem
}
```

`Presentation/Shared/HomeViewModel.swift`

```swift
@discardableResult
func drawReward(for tier: RewardTier, in modelContext: ModelContext) -> RewardDefinition? {
    do {
        let reward = try rewardService.drawReward(for: tier, in: modelContext)
        errorMessage = nil
        return reward
    } catch {
        errorMessage = message(for: error)
        return nil
    }
}

@discardableResult
func exchangeNormalReward(_ reward: RewardDefinition, in modelContext: ModelContext) -> RewardInventoryItem? {
    do {
        let item = try rewardService.exchangeNormalRewardDirectly(reward, in: modelContext)
        errorMessage = nil
        return item
    } catch {
        errorMessage = message(for: error)
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/drawRequiresAtLeastFiveAvailableNormalRewards -only-testing:TopOneCoreTests/everyTenDrawsGrantOneExchangeCreditForThatTier -only-testing:TopOneCoreTests/normalRewardDirectExchangeConsumesPointsAndCredit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Application/Services/RewardService.swift" "Presentation/Shared/HomeViewModel.swift" "Tests/TopOneCoreTests/TopOneCoreTests.swift"
git commit -m "feat(reward): add pity exchange rules"
```

---

### Task 5: Add `SSS` direct exchange with minimum cost `888`

**Files:**
- Modify: `Application/Services/RewardService.swift:18-300`
- Modify: `Presentation/Shared/HomeViewModel.swift:34-280`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing `SSS` tests**

```swift
@MainActor
@Test
func createSSSRewardRejectsCostBelowMinimum() throws {
    let container = try makeInMemoryContainer()

    #expect(throws: RewardServiceError.invalidSSSPointCost(minimum: 888)) {
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/createSSSRewardRejectsCostBelowMinimum -only-testing:TopOneCoreTests/sssRewardDirectExchangeConsumesCustomCost`
Expected: FAIL because the service has no `SSS` cost validation or direct-exchange API.

- [ ] **Step 3: Implement `SSS` validation and direct exchange**

`Application/Services/RewardService.swift`

```swift
@discardableResult
func createRewardDefinition(
    name: String,
    icon: String = "",
    iconImageData: Data,
    rewardTier: RewardTier,
    detail: String = "",
    availabilityMode: RewardAvailabilityMode = .unlimited,
    remainingCount: Int = 0,
    sssPointCost: Int? = nil,
    in modelContext: ModelContext
) throws -> RewardDefinition {
    guard Self.isValidRewardName(name) else {
        throw RewardServiceError.invalidRewardName
    }
    guard Self.hasRewardImage(iconImageData) else {
        throw RewardServiceError.rewardImageRequired
    }
    guard availabilityMode == .unlimited || remainingCount > 0 else {
        throw RewardServiceError.invalidLimitedRewardCount
    }
    if rewardTier == .sss, (sssPointCost ?? 0) < RewardDefinition.minimumSSSPointCost {
        throw RewardServiceError.invalidSSSPointCost(minimum: RewardDefinition.minimumSSSPointCost)
    }

    let optimizedImageData = Self.optimizedImageData(from: iconImageData)
    let reward = RewardDefinition(
        name: name,
        icon: icon,
        iconImageData: optimizedImageData,
        rewardTier: rewardTier,
        detail: detail,
        availabilityMode: availabilityMode,
        remainingCount: availabilityMode == .limited ? remainingCount : 0,
        sssPointCost: sssPointCost
    )
    modelContext.insert(reward)
    try modelContext.save()
    return reward
}

@discardableResult
func exchangeSSSRewardDirectly(_ reward: RewardDefinition, in modelContext: ModelContext) throws -> RewardInventoryItem {
    guard reward.rewardTier == .sss else {
        throw RewardServiceError.rewardUnavailable
    }
    let requiredCost = max(reward.sssPointCost ?? RewardDefinition.minimumSSSPointCost, RewardDefinition.minimumSSSPointCost)
    let account = try ensureRewardAccount(in: modelContext)
    guard account.points >= requiredCost else {
        throw RewardServiceError.insufficientPoints(required: requiredCost, actual: account.points)
    }
    guard reward.availabilityMode == .unlimited || reward.remainingCount > 0 else {
        throw RewardServiceError.rewardUnavailable
    }

    account.points -= requiredCost
    recordPointTransaction(
        delta: -requiredCost,
        balanceAfterChange: account.points,
        kind: .spend,
        reason: .exchangeReward,
        taskRank: nil,
        rewardTier: .sss,
        referenceTitle: reward.name,
        in: modelContext
    )

    if reward.availabilityMode == .limited {
        reward.remainingCount -= 1
    }

    let inventoryItem = reward.inventoryItems.first ?? RewardInventoryItem(currentCount: 0, rewardDefinition: reward)
    if inventoryItem.modelContext == nil {
        modelContext.insert(inventoryItem)
    }
    inventoryItem.currentCount += 1

    try modelContext.save()
    return inventoryItem
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/createSSSRewardRejectsCostBelowMinimum -only-testing:TopOneCoreTests/sssRewardDirectExchangeConsumesCustomCost`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Application/Services/RewardService.swift" "Tests/TopOneCoreTests/TopOneCoreTests.swift"
git commit -m "feat(reward): add sss direct exchange"
```

---

### Task 6: Expand reward draft flow and form for `SSS`

**Files:**
- Modify: `Presentation/Shared/HomeViewModel.swift:34-218`
- Modify: `App/Shared/TopOneRootView.swift:2395-2587`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing draft tests**

```swift
@MainActor
@Test
func rewardDraftStoresSSSTierAndMinimumCost() throws {
    let viewModel = HomeViewModel()

    viewModel.showCreateRewardDefinition()
    var draft = try #require(viewModel.rewardDraft)
    draft.name = "欧洲旅行"
    draft.rewardTier = .sss
    draft.iconImageData = validRewardImageData()
    draft.sssPointCost = 888
    viewModel.rewardDraft = draft

    let updated = try #require(viewModel.rewardDraft)
    #expect(updated.rewardTier == .sss)
    #expect(updated.sssPointCost == 888)
}

@MainActor
@Test
func saveRewardDefinitionPersistsSSSCost() throws {
    let container = try makeInMemoryContainer()
    let viewModel = HomeViewModel()

    viewModel.showCreateRewardDefinition()
    var draft = try #require(viewModel.rewardDraft)
    draft.name = "欧洲旅行"
    draft.rewardTier = .sss
    draft.iconImageData = validRewardImageData()
    draft.sssPointCost = 888
    viewModel.rewardDraft = draft

    viewModel.saveRewardDefinition(in: container.mainContext)

    let rewards = try container.mainContext.fetch(FetchDescriptor<RewardDefinition>())
    #expect(rewards.count == 1)
    #expect(rewards[0].rewardTier == .sss)
    #expect(rewards[0].sssPointCost == 888)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardDraftStoresSSSTierAndMinimumCost -only-testing:TopOneCoreTests/saveRewardDefinitionPersistsSSSCost`
Expected: FAIL because `RewardDraft` still uses `TaskRank` and has no `sssPointCost`.

- [ ] **Step 3: Update the reward draft and form state**

`Presentation/Shared/HomeViewModel.swift`

```swift
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
        self.name = reward?.name ?? ""
        self.icon = reward?.icon ?? ""
        self.iconImageData = reward?.iconImageData ?? Data()
        self.rewardTier = reward?.rewardTier ?? .a
        self.detail = reward?.detail ?? ""
        self.availabilityMode = reward?.availabilityMode ?? .unlimited
        self.remainingCount = reward?.remainingCount ?? 0
        self.sssPointCost = reward?.sssPointCost ?? RewardDefinition.minimumSSSPointCost
    }
}
```

```swift
try rewardService.updateRewardDefinition(
    reward,
    name: draft.name,
    icon: draft.icon,
    iconImageData: draft.iconImageData,
    rewardTier: draft.rewardTier,
    detail: draft.detail,
    availabilityMode: draft.availabilityMode,
    remainingCount: draft.remainingCount,
    sssPointCost: draft.rewardTier == .sss ? draft.sssPointCost : nil,
    in: modelContext
)
```

`App/Shared/TopOneRootView.swift`

```swift
rankSelectionCard(
    title: "奖励等级",
    rewardTier: Binding(
        get: { viewModel.rewardDraft?.rewardTier ?? draft.rewardTier },
        set: {
            guard var current = viewModel.rewardDraft else { return }
            current.rewardTier = $0
            if $0 != .sss {
                current.sssPointCost = RewardDefinition.minimumSSSPointCost
            }
            viewModel.rewardDraft = current
        }
    ),
    note: "奖励等级使用 SSS / S / A / B / C，其中 SSS 用于大奖励直接兑换。"
)

if (viewModel.rewardDraft?.rewardTier ?? draft.rewardTier) == .sss {
    Stepper(value: Binding(
        get: { max(viewModel.rewardDraft?.sssPointCost ?? draft.sssPointCost, RewardDefinition.minimumSSSPointCost) },
        set: {
            guard var current = viewModel.rewardDraft else { return }
            current.sssPointCost = max($0, RewardDefinition.minimumSSSPointCost)
            viewModel.rewardDraft = current
        }
    ), in: RewardDefinition.minimumSSSPointCost...9999) {
        Text("兑换需要 \(max(viewModel.rewardDraft?.sssPointCost ?? draft.sssPointCost, RewardDefinition.minimumSSSPointCost)) 积分")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PrototypeColors.primary)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardDraftStoresSSSTierAndMinimumCost -only-testing:TopOneCoreTests/saveRewardDefinitionPersistsSSSCost`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "Presentation/Shared/HomeViewModel.swift" "App/Shared/TopOneRootView.swift" "Tests/TopOneCoreTests/TopOneCoreTests.swift"
git commit -m "feat(reward): support sss cost in reward form"
```

---

### Task 7: Switch the reward home between normal draw mode and `SSS` list mode

**Files:**
- Modify: `App/Shared/TopOneRootView.swift:625-1100`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing ViewModel default test**

```swift
@MainActor
@Test
func rewardDraftDefaultsToATierAndMinimumSSSCost() throws {
    let viewModel = HomeViewModel()

    viewModel.showCreateRewardDefinition()

    let draft = try #require(viewModel.rewardDraft)
    #expect(draft.rewardTier == .a)
    #expect(draft.sssPointCost == 888)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardDraftDefaultsToATierAndMinimumSSSCost`
Expected: FAIL until the new draft defaults land.

- [ ] **Step 3: Replace the single-mode reward section with a tier-aware section**

`App/Shared/TopOneRootView.swift`

```swift
private var currentRewardTier: RewardTier {
    viewModel.selectedRewardTier
}

private var currentSSSRewards: [RewardDefinition] {
    rewardDefinitions.filter { $0.rewardTier == .sss }
}

private var currentNormalRewards: [RewardDefinition] {
    rewardDefinitions.filter { $0.rewardTier == currentRewardTier }
}

@ViewBuilder
private var rewardPoolSection: some View {
    VStack(alignment: .leading, spacing: 20) {
        rewardPointsCard

        rewardTierSelectionCard

        if currentRewardTier == .sss {
            sssRewardListSection
        } else if currentNormalRewards.isEmpty {
            rewardEmptyStateCard(
                title: "当前等级池还没有奖励",
                message: "先去奖励管理添加 Rank \(currentRewardTier.rawValue) 的奖励，再回来抽卡。"
            )
        } else {
            rewardCarouselCard
            rewardPrimaryDrawButton
        }
    }
}

private var sssRewardListSection: some View {
    VStack(alignment: .leading, spacing: 16) {
        if currentSSSRewards.isEmpty {
            rewardEmptyStateCard(
                title: "还没有 SSS 奖励",
                message: "先去奖励管理新增一个大奖励，再回来直接兑换。"
            )
        } else {
            ForEach(currentSSSRewards) { reward in
                sssRewardCard(reward)
            }
        }
    }
}

private func sssRewardCard(_ reward: RewardDefinition) -> some View {
    Button {
        _ = viewModel.exchangeSSSReward(reward, in: modelContext)
    } label: {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PrototypeColors.tertiaryFixed.opacity(0.88))
                    .frame(width: 48, height: 48)
                rewardImageView(for: reward, size: 26)
            }

            Text(reward.name.isEmpty ? "未命名奖励" : reward.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(PrototypeColors.primary)

            Spacer()

            Text("兑换 · \(reward.sssPointCost ?? RewardDefinition.minimumSSSPointCost) 积分")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PrototypeColors.onTertiaryFixed)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PrototypeColors.tertiaryFixedDim, in: Capsule())
        }
        .padding(18)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PrototypeColors.outlineVariant.opacity(0.12)))
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/rewardDraftDefaultsToATierAndMinimumSSSCost`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "App/Shared/TopOneRootView.swift" "Presentation/Shared/HomeViewModel.swift" "Tests/TopOneCoreTests/TopOneCoreTests.swift"
git commit -m "feat(reward): add sss list mode to reward home"
```

---

### Task 8: Add inline rule hints and refresh points copy for the new economy

**Files:**
- Modify: `App/Shared/TopOneRootView.swift:1136-2054`
- Modify: `Presentation/Shared/HomeViewModel.swift:370-420`
- Test: `Tests/TopOneCoreTests/TopOneCoreTests.swift`

- [ ] **Step 1: Write the failing transaction test that exercises the new reward tier API**

```swift
@MainActor
@Test
func directExchangeCreatesSpendTransactionForSSSReward() throws {
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
    account.points = 900
    try context.save()

    _ = try service.exchangeSSSRewardDirectly(reward, in: context)
    let transactions = try service.fetchPointTransactions(in: context)

    #expect(transactions.count == 1)
    #expect(transactions[0].pointsDelta == -888)
    #expect(transactions[0].reason == .exchangeReward)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/directExchangeCreatesSpendTransactionForSSSReward`
Expected: FAIL until `SSS` exchange is wired into point transactions.

- [ ] **Step 3: Update inline hint copy and ViewModel error text**

`Presentation/Shared/HomeViewModel.swift`

```swift
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
    case let .rewardNotFound(tier):
        return "Rank \(tier.rawValue) 当前暂无可用奖励"
    case .rewardUnavailable:
        return "当前奖励不可用，请换一个试试"
    case let .rewardPoolTooSmall(required, actual):
        return "当前奖池仅有 \(actual) 种奖励，至少需要 \(required) 种才能抽取"
    case .invalidUseAmount:
        return "使用数量至少为 1"
    case .insufficientInventory:
        return "库存不足，无法完成本次使用"
    }
}
```

`App/Shared/TopOneRootView.swift`

```swift
@State private var showsRewardTierHint = false
@State private var showsRewardDrawRulesHint = false
@State private var showsRewardFormRulesHint = false
```

```swift
if showsRewardPointRules {
    inlineHintCard(
        title: "积分规则说明",
        message: "积分仍只在任务完成时变化，但现在同时限制每日产出，并把大奖励兑换从抽卡逻辑里拆出来。",
        highlights: [
            "日常任务每日累计最多获得 30 积分",
            "长期任务每天只结算 1 次积分",
            "SSS 奖励必须至少 888 积分才能兑换"
        ]
    )
}
```

```swift
if showsRewardDrawRulesHint {
    inlineHintCard(
        title: "抽取与保底说明",
        message: "普通等级仍以抽卡为主，但现在只有在奖池足够丰富时才允许抽卡。",
        highlights: [
            "当前等级池至少 5 种奖励才能抽",
            "每 10 抽获得 1 次同等级兑换资格",
            "兑换资格不是免费奖励，兑换时仍需扣积分"
        ]
    )
}
```

```swift
if showsRewardFormRulesHint {
    inlineHintCard(
        title: "SSS 规则说明",
        message: "SSS 是大奖励直兑档位，不参与普通抽卡池。",
        highlights: [
            "SSS 只出现在奖励等级里，不出现在任务等级里",
            "SSS 奖励必须设置自定义积分",
            "SSS 积分不得低于 888"
        ]
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests/directExchangeCreatesSpendTransactionForSSSReward`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "App/Shared/TopOneRootView.swift" "Presentation/Shared/HomeViewModel.swift" "Tests/TopOneCoreTests/TopOneCoreTests.swift"
git commit -m "feat(reward): explain sss and pity rules inline"
```

---

## Final Verification

- [ ] Run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -only-testing:TopOneCoreTests`
Expected: PASS

- [ ] Run: `xcodebuild build -project "TopOne.xcodeproj" -scheme "TopOnemacOS"`
Expected: `** BUILD SUCCEEDED **`

- [ ] If focused tests are clean, run: `xcodebuild test -project "TopOne.xcodeproj" -scheme "TopOnemacOS"`
Expected: PASS or only unrelated pre-existing failures. If unrelated failures appear, document them and stop there.

- [ ] Manually verify in the macOS app:
  - Tasks still only show `S / A / B / C`.
  - Reward management shows `SSS / S / A / B / C`.
  - Picking `SSS` in the reward form exposes custom point cost and enforces the `888` minimum.
  - Switching the reward page to `SSS` hides the draw button and shows only icon, name, and `兑换 · N 积分` buttons.
  - Switching to normal reward tiers keeps the current draw-first layout.
  - Normal draw buttons stay disabled when the selected pool has fewer than `5` available reward types.
  - Every `10` draws in one normal tier grants exactly `1` direct exchange credit for that tier.
  - Normal direct exchange consumes both points and one credit.
  - `SSS` direct exchange consumes the custom cost and does not use draw credits.
  - Points detail and reward page question marks expand inline, not in new sheets.
