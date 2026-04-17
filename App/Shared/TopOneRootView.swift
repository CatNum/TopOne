#if canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#endif
import PhotosUI
import SwiftData
import SwiftUI

private extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(AppKit)
        self.init(nsImage: platformImage)
        #elseif canImport(UIKit)
        self.init(uiImage: platformImage)
        #endif
    }
}

@MainActor
struct TopOneRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query(sort: [SortDescriptor(\RewardDefinition.rankRawValue), SortDescriptor(\RewardDefinition.name)]) private var rewardDefinitions: [RewardDefinition]
    @Query(sort: \RewardInventoryItem.currentCount, order: .reverse) private var rewardInventoryItems: [RewardInventoryItem]
    @Query(sort: \RewardAccount.points) private var rewardAccounts: [RewardAccount]
    @StateObject private var viewModel = HomeViewModel()
    @State private var expandedPausedGoalIDs: Set<PersistentIdentifier> = []
    @State private var swipedDailyTaskID: PersistentIdentifier?
    @State private var swipedGoalID: PersistentIdentifier?
    @State private var showsPausedSection = true
    @State private var showsCompletedSection = false
    @State private var createTaskPage: CreateTaskPage?
    @State private var selectedLockCommitment: LockCommitmentOption = .sevenDays
    @State private var showsLockCommitmentHint = false
    @State private var showsForceSwitchHint = false
    @State private var celebration: CompletionCelebration?
    @State private var selectedRootPage: RootPage = .tasks
    @State private var selectedInventoryItem: RewardInventoryItem?
    @State private var confirmingRewardUsageItem: RewardInventoryItem?
    @State private var showsRewardInventory = false
    @State private var showsRewardManagement = false
    @State private var showsRewardPointHistory = false
    @State private var showsRewardPointRules = false
    @State private var rewardPointHistoryPageSize = 20
    @State private var rewardDrawResult: RewardDefinition?
    @State private var selectedRewardImageItem: PhotosPickerItem?
    @State private var isRewardCarouselAnimating = false
    @State private var rewardCarouselBoost = false

    private let service = GoalService()

    private var currentTopOne: Goal? {
        goals.first(where: { $0.isTopOne })
    }

    private var pausedGoalsByRank: [(TaskRank, [Goal])] {
        let paused = goals.filter { !$0.isTopOne && $0.completedAt == nil }
        return TaskRank.allCases.map { rank in
            (rank, paused.filter { $0.rank == rank })
        }
        .filter { !$0.1.isEmpty }
    }

    private var completedGoals: [Goal] {
        goals.filter { $0.completedAt != nil }
    }

    private var rewardPoints: Int {
        rewardAccounts.reduce(0) { $0 + $1.points }
    }

    private var rewardDefinitionsByRank: [(TaskRank, [RewardDefinition])] {
        TaskRank.allCases.map { rank in
            (rank, rewardDefinitions.filter { $0.rank == rank })
        }
        .filter { !$0.1.isEmpty }
    }

    private var currentRewardRank: TaskRank {
        viewModel.selectedRewardRank
    }

    private var currentRankRewards: [RewardDefinition] {
        rewardDefinitions.filter { $0.rank == currentRewardRank }
    }

    private var currentRankAvailableRewards: [RewardDefinition] {
        currentRankRewards.filter { $0.availabilityMode == .unlimited || $0.remainingCount > 0 }
    }

    private var availableRewardCount: Int {
        rewardDefinitions.reduce(into: 0) { total, reward in
            if reward.availabilityMode == .unlimited {
                total += 1
            } else {
                total += reward.remainingCount
            }
        }
    }

    private var inventoryItemsByRank: [(TaskRank, [RewardInventoryItem])] {
        TaskRank.allCases.map { rank in
            (rank, rewardInventoryItems.filter { $0.rewardDefinition.rank == rank })
        }
        .filter { !$0.1.isEmpty }
    }

    private var inventoryRewardCount: Int {
        rewardInventoryItems.reduce(0) { $0 + $1.currentCount }
    }

    private var editGoalSheet: Binding<HomeViewModel.GoalDraft?> {
        Binding(
            get: {
                guard createTaskPage == nil,
                      viewModel.goalDraft?.goal != nil else { return nil }
                return viewModel.goalDraft
            },
            set: { viewModel.goalDraft = $0 }
        )
    }

    private var editDailyTaskSheet: Binding<HomeViewModel.DailyTaskDraft?> {
        Binding(
            get: {
                guard createTaskPage == nil,
                      viewModel.dailyTaskDraft?.task != nil else { return nil }
                return viewModel.dailyTaskDraft
            },
            set: { viewModel.dailyTaskDraft = $0 }
        )
    }

    private var deleteModalAction: Binding<HomeViewModel.PendingAction?> {
        Binding(
            get: {
                guard let action = viewModel.pendingAction else { return nil }
                switch action {
                case .deleteGoal, .deleteTask, .deleteReward:
                    return action
                default:
                    return nil
                }
            },
            set: { newValue in
                if newValue == nil,
                   case .deleteGoal = viewModel.pendingAction {
                    viewModel.pendingAction = nil
                } else if newValue == nil,
                          case .deleteTask = viewModel.pendingAction {
                    viewModel.pendingAction = nil
                } else if newValue == nil,
                          case .deleteReward = viewModel.pendingAction {
                    viewModel.pendingAction = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedRootPage {
                case .tasks:
                    tasksPage
                case .rewards:
                    rewardsPage
                case .settings:
                    placeholderPage(
                        eyebrow: "SETTINGS SPACE",
                        title: "设置页稍后开启",
                        message: "底部切换已经接通。接下来我们可以在这里实现设置与偏好管理。"
                    )
                }
            }
            .background(PrototypeColors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomNavigationBar
            }
            .sheet(item: $createTaskPage, onDismiss: discardCreateDrafts) { page in
                createTaskForm(page: page)
            }
            .sheet(item: editGoalSheet) { draft in
                goalForm(draft: draft)
            }
            .sheet(item: editDailyTaskSheet) { draft in
                dailyTaskForm(draft: draft)
            }
            .sheet(item: $viewModel.lockGoal) { goal in
                lockCommitmentSheet(goal)
            }
            .sheet(item: $viewModel.customLockGoal) { goal in
                customLockForm(goal)
            }
            .sheet(item: $viewModel.switchReasonGoal) { goal in
                forceSwitchView(goal)
            }
            .sheet(item: $viewModel.progressGoal) { goal in
                progressForm(goal)
            }
            .sheet(item: $celebration) { value in
                completionCelebrationSheet(value)
            }
            .sheet(isPresented: $showsRewardInventory) {
                rewardInventorySheet
            }
            .sheet(isPresented: $showsRewardManagement) {
                rewardManagementSheet
            }
            .sheet(isPresented: $showsRewardPointHistory) {
                rewardPointHistorySheet
            }
            .sheet(item: $rewardDrawResult) { (reward: RewardDefinition) in
                rewardDrawResultSheet(reward)
            }
            .sheet(item: deleteModalAction) { (action: HomeViewModel.PendingAction) in
                deleteConfirmationSheet(action)
            }
            .alert("确认使用奖励", isPresented: Binding(
                get: { confirmingRewardUsageItem != nil },
                set: { if !$0 { confirmingRewardUsageItem = nil } }
            ), presenting: confirmingRewardUsageItem) { item in
                Button("取消", role: .cancel) {
                    confirmingRewardUsageItem = nil
                }
                Button("确认使用") {
                    viewModel.useReward(item, in: modelContext)
                    if viewModel.errorMessage == nil {
                        selectedInventoryItem = nil
                    }
                    confirmingRewardUsageItem = nil
                }
            } message: { item in
                let rewardName = item.rewardDefinition.name.isEmpty ? "未命名奖励" : item.rewardDefinition.name
                Text("将使用 \(viewModel.rewardUseAmountText) 份“\(rewardName)”。")
            }
        }
    }

    private var tasksPage: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                PrototypeColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        topBar
                        topGuidance
                        if let errorMessage = viewModel.errorMessage {
                            errorBanner(errorMessage)
                        }
                        topOneSection
                        dailyTaskSection
                        pausedGoalsSection
                        completedGoalsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 132)
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }

                if selectedRootPage == .tasks {
                    floatingAddButton
                        .padding(.trailing, max(12, min(proxy.size.width * 0.038, 20)))
                        .padding(.bottom, max(12, min(proxy.size.width * 0.038, 20)))
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "line.3.horizontal")
                .font(.title3.weight(.medium))
                .foregroundStyle(PrototypeColors.primary)
                .frame(width: 36, height: 36)
                .background(PrototypeColors.surfaceContainerLow, in: Circle())

            Text("TopOne")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .tracking(-0.4)
                .foregroundStyle(PrototypeColors.primary)

            Spacer()

            Circle()
                .fill(PrototypeColors.primaryFixed)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PrototypeColors.primary.opacity(0.55))
                }
        }
    }

    private var topGuidance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("步履不停，终抵繁星。")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(PrototypeColors.primary)
            Text("通过有意识的每日专注，开启你的卓越之路。")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var topOneSection: some View {
        if let currentTopOne {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    Text("当前专注")
                        .sectionEyebrow()
                    Spacer()
                    Text(currentTopOne.remainingLockDurationText ?? "未锁定")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PrototypeColors.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PrototypeColors.tertiaryFixed.opacity(0.32), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CURRENT FOCUS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(2.2)
                                .foregroundStyle(PrototypeColors.tertiaryFixedDim)
                            Text(currentTopOne.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .tracking(-0.7)
                                .foregroundStyle(.white)
                                .lineLimit(3)
                            Text("点击百分比可手动编辑进度")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        Spacer()
                        Button {
                            if currentTopOne.lockEndsAt != nil {
                                viewModel.prepareSwitchReason(for: currentTopOne)
                            } else {
                                viewModel.pendingAction = .unbindTopOne(currentTopOne)
                            }
                        } label: {
                            Text("放弃")
                                .font(.subheadline.weight(.bold))
                                .underline()
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 10) {
                        HStack(alignment: .bottom) {
                            Text("进度")
                                .font(.caption.weight(.semibold))
                                .tracking(1.2)
                                .foregroundStyle(PrototypeColors.onPrimaryContainer)
                            Spacer()
                            Button {
                                viewModel.prepareProgressEditor(for: currentTopOne)
                            } label: {
                                Text("\(Int(currentTopOne.progress * 100))%")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .tracking(-1)
                                    .foregroundStyle(PrototypeColors.tertiaryFixedDim)
                            }
                            .buttonStyle(.plain)
                        }

                        Slider(
                            value: Binding(
                                get: { currentTopOne.progress },
                                set: { updateGoalProgress(currentTopOne, value: $0) }
                            ),
                            in: 0...1
                        )
                        .tint(PrototypeColors.tertiaryFixedDim)
                    }
                }
                .padding(28)
                .background {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(LinearGradient(colors: [PrototypeColors.primary, PrototypeColors.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(PrototypeColors.tertiary)
                                .frame(width: 4)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .overlay(alignment: .topTrailing) {
                            Circle()
                                .fill(PrototypeColors.tertiaryFixedDim.opacity(0.08))
                                .frame(width: 210, height: 210)
                                .blur(radius: 32)
                                .offset(x: 56, y: -72)
                        }
                }
            }
        } else {
            emptyTopOneSection
        }
    }

    private var emptyTopOneSection: some View {
        let hasGoals = !goals.isEmpty

        return VStack(alignment: .leading, spacing: 18) {
            Text("当前专注")
                .sectionEyebrow()
            VStack(alignment: .leading, spacing: 18) {
                Text(hasGoals ? "当前已有长期任务。" : "先选择一件真正重要的事。")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(hasGoals ? "请在任务池中左滑长期任务，并通过“专注”把它设为当前 TopOne。" : "创建长期目标后，在任务列表中把它锁定为当前 TopOne。")
                    .font(.subheadline)
                    .foregroundStyle(PrototypeColors.onPrimaryContainer)

                if !hasGoals {
                    Button("新增长期任务") {
                        viewModel.showCreateGoal()
                        viewModel.showCreateDailyTask(defaultGoal: currentTopOne ?? goals.first)
                        createTaskPage = CreateTaskPage(selectedType: .goal)
                    }
                    .buttonStyle(.plain)
                    .font(.headline)
                    .foregroundStyle(PrototypeColors.onTertiaryFixed)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 13)
                    .background(PrototypeColors.tertiaryFixedDim, in: Capsule())
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PrototypeColors.primary, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
    }

    private var dailyTaskSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("日常任务")
                .sectionEyebrow()

            if let currentTopOne {
                let tasks = service.sortedDailyTasks(for: currentTopOne)
                if tasks.isEmpty {
                    quietEmptyCard("还没有日常任务。用右下角 + 添加一个推进动作。")
                } else {
                    VStack(spacing: 12) {
                        ForEach(tasks) { task in
                            dailyTaskRow(task, allowsStatusUpdate: true)
                        }
                    }
                }
            } else {
                quietEmptyCard("设置当前 TopOne 后，这里会显示它的日常推进任务。")
            }
        }
    }

    private var pausedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showsPausedSection.toggle()
                }
            } label: {
                sectionHeader(title: "暂停任务库", subtitle: "按 Rank S / A / B / C 分组，默认安静收起", expanded: showsPausedSection, emphasis: .muted)
            }
            .buttonStyle(.plain)

            if showsPausedSection {
                if pausedGoalsByRank.isEmpty {
                    quietEmptyCard("暂无暂停任务。", emphasis: .muted)
                } else {
                    VStack(spacing: 18) {
                        ForEach(pausedGoalsByRank, id: \.0) { rank, rankGoals in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Rank \(rank.rawValue)")
                                    .font(.caption.weight(.bold))
                                    .tracking(1.2)
                                    .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.56))
                                    .padding(.horizontal, 4)
                                ForEach(rankGoals) { goal in
                                    pausedGoalCard(goal)
                                }
                            }
                            .padding(18)
                            .background(PrototypeColors.surfaceContainerLowest.opacity(0.44), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(PrototypeColors.outlineVariant.opacity(0.12)))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var completedGoalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showsCompletedSection.toggle()
                }
            } label: {
                sectionHeader(title: "已达成里程碑", subtitle: "完成后的长期目标归档", expanded: showsCompletedSection, emphasis: .subdued)
            }
            .buttonStyle(.plain)

            if showsCompletedSection {
                if completedGoals.isEmpty {
                    quietEmptyCard("暂无已达成里程碑。", emphasis: .subdued)
                } else {
                    VStack(spacing: 10) {
                        ForEach(completedGoals) { goal in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(goal.title)
                                    .font(.headline)
                                    .foregroundStyle(PrototypeColors.primary.opacity(0.78))
                                Text("Rank \(goal.rank.rawValue) · 已完成")
                                    .font(.caption)
                                    .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(PrototypeColors.surfaceContainerLowest.opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(PrototypeColors.outlineVariant.opacity(0.08)))
                        }
                    }
                    .opacity(0.82)
                }
            }
        }
    }

    private var floatingAddButton: some View {
        Button {
            viewModel.showCreateGoal()
            viewModel.showCreateDailyTask(defaultGoal: currentTopOne ?? goals.first)
            createTaskPage = CreateTaskPage()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(PrototypeColors.onTertiaryFixed)
                .frame(width: 64, height: 64)
                .background(PrototypeColors.tertiaryFixedDim, in: Circle())
                .shadow(color: PrototypeColors.tertiary.opacity(0.28), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var bottomNavigationBar: some View {
        HStack(spacing: 14) {
            ForEach(RootPage.allCases) { page in
                let isSelected = selectedRootPage == page

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRootPage = page
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: page.icon)
                            .font(.system(size: isSelected ? 20 : 19, weight: .semibold))
                        Text(page.title)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundStyle(isSelected ? PrototypeColors.onPrimary : PrototypeColors.onSurfaceVariant.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(PrototypeColors.primary)
                                .shadow(color: PrototypeColors.primary.opacity(0.12), radius: 10, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background {
            ZStack(alignment: .top) {
                PrototypeColors.surfaceContainerLowest
                Rectangle()
                    .fill(PrototypeColors.outlineVariant.opacity(0.18))
                    .frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var rewardsPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                rewardsHeader
                rewardPoolSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 172)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollClipDisabled()
    }

    private var rewardsHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("奖励")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(PrototypeColors.primary)
                Text("让每一次完成都立刻转化成期待感：积分累积、即时抽卡、正反馈不断回流。")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button {
                    showsRewardInventory = true
                } label: {
                    Label("我的奖励", systemImage: "shippingbox.fill")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .foregroundStyle(PrototypeColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PrototypeColors.surfaceContainerHigh, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    showsRewardManagement = true
                } label: {
                    Label("奖励管理", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .foregroundStyle(PrototypeColors.onTertiaryFixed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PrototypeColors.tertiaryFixedDim, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }


    @ViewBuilder
    private var rewardPoolSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            rewardPointsCard

            rankSelectionCard(
                title: "选择抽卡等级",
                rank: Binding(
                    get: { viewModel.selectedRewardRank },
                    set: { viewModel.selectedRewardRank = $0 }
                ),
                note: "等级选择固定在页面上方；下方奖池会按当前等级滚动预览。"
            )

            if currentRankRewards.isEmpty {
                rewardEmptyStateCard(
                    title: "当前等级池还没有奖励",
                    message: "先去奖励管理添加 Rank \(currentRewardRank.rawValue) 的奖励，再回来抽卡。"
                )
            } else {
                rewardCarouselCard
                rewardPrimaryDrawButton
            }
        }
    }


    private func placeholderPage(eyebrow: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            topBar

            Spacer()

            VStack(alignment: .leading, spacing: 14) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.8)
                    .foregroundStyle(PrototypeColors.tertiary)
                Text(title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(PrototypeColors.primary)
                Text(message)
                    .font(.body)
                    .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(PrototypeColors.outlineVariant.opacity(0.16)))

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 92)
        .frame(maxWidth: 680, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dailyTaskRow(_ task: DailyTask, allowsStatusUpdate: Bool) -> some View {
        let isSwiped = swipedDailyTaskID == task.persistentModelID

        return ZStack(alignment: .trailing) {
            taskSwipeActions(task, allowsStatusUpdate: allowsStatusUpdate)
                .padding(.trailing, 6)
                .opacity(isSwiped ? 1 : 0)
                .allowsHitTesting(isSwiped)

            HStack(spacing: 14) {
                Button {
                    guard allowsStatusUpdate else { return }
                    updateDailyTaskStatus(task, status: nextStatus(after: task.status))
                } label: {
                    Image(systemName: task.status == .completed ? "checkmark.circle.fill" : task.status == .inProgress ? "play.circle.fill" : "circle")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(taskStatusColor(task, allowsStatusUpdate: allowsStatusUpdate))
                }
                .buttonStyle(.plain)
                .disabled(!allowsStatusUpdate)

                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(task.status == .completed ? PrototypeColors.onSurfaceVariant : PrototypeColors.primary)
                        .strikethrough(task.status == .completed, color: PrototypeColors.onSurfaceVariant.opacity(0.6))
                    Text(taskSubtitle(task))
                        .font(.caption)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                }

                Spacer()

                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PrototypeColors.outlineVariant)
            }
            .padding(18)
            .background(taskRowBackground(task), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .trailing) {
                if allowsStatusUpdate && !isSwiped {
                    Text("左滑以开始 / 编辑 / 删除")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.26))
                        .padding(.trailing, 30)
                }
            }
            .offset(x: isSwiped ? -198 : 0)
            .opacity(task.status == .completed ? 0.58 : 1)
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            if value.translation.width < -42 {
                                swipedDailyTaskID = task.persistentModelID
                                swipedGoalID = nil
                            } else if value.translation.width > 28 {
                                swipedDailyTaskID = nil
                            }
                        }
                    }
            )
        }
        .clipped()
    }

    private func pausedGoalCard(_ goal: Goal) -> some View {
        let isExpanded = expandedPausedGoalIDs.contains(goal.persistentModelID)
        let isSwiped = swipedGoalID == goal.persistentModelID

        return VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .trailing) {
                goalSwipeActions(goal)
                    .padding(.trailing, 6)
                    .opacity(isSwiped ? 1 : 0)
                    .allowsHitTesting(isSwiped)

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.title)
                            .font(.headline)
                            .foregroundStyle(PrototypeColors.primary.opacity(0.86))
                        HStack(spacing: 8) {
                            miniProgressBar(goal.progress)
                            Text("\(Int(goal.progress * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.85))
                        }
                    }

                    Spacer()

                    Text("左滑以专注 / 编辑 / 删除")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(isSwiped ? 0 : 0.26))
                }
                .padding(18)
                .background(PrototypeColors.surfaceContainerLow.opacity(0.64), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.10)))
                .offset(x: isSwiped ? -198 : 0)
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onEnded { value in
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                if value.translation.width < -42 {
                                    swipedGoalID = goal.persistentModelID
                                    swipedDailyTaskID = nil
                                } else if value.translation.width > 28 {
                                    swipedGoalID = nil
                                }
                            }
                        }
                )
            }
            .clipped()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedPausedGoalIDs.remove(goal.persistentModelID)
                    } else {
                        expandedPausedGoalIDs.insert(goal.persistentModelID)
                    }
                }
            } label: {
                HStack {
                    Text(isExpanded ? "收起日常任务" : "展开日常任务")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.9))
            }
            .buttonStyle(.plain)

            if isExpanded {
                let tasks = service.sortedDailyTasks(for: goal)
                if tasks.isEmpty {
                    Text("暂无日常任务")
                        .font(.caption)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.9))
                } else {
                    VStack(spacing: 10) {
                        ForEach(tasks) { task in
                            dailyTaskRow(task, allowsStatusUpdate: false)
                        }
                    }
                }
            }
        }
    }

    private var rewardPrimaryDrawButton: some View {
        Button {
            triggerRewardDraw()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                Text(rewardDrawButtonLabel(for: currentRewardRank))
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .foregroundStyle(PrototypeColors.onTertiaryFixed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(PrototypeColors.tertiaryFixedDim, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
        .disabled(currentRankAvailableRewards.isEmpty || rewardPoints < RewardService().drawCost(for: currentRewardRank) || isRewardCarouselAnimating)
    }

    private var rewardPointsCard: some View {
        Button {
            showsRewardPointHistory = true
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("当前积分")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    Text("\(rewardPoints)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(PrototypeColors.primary)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("积分明细")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(PrototypeColors.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PrototypeColors.outlineVariant)
                }
            }
            .padding(20)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(PrototypeColors.outlineVariant.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private var rewardCarouselCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("当前奖池预览")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Rank \(currentRewardRank.rawValue)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PrototypeColors.tertiaryFixed)
            }

            rewardIconCarouselRow(offsetSeed: 0)
            rewardIconCarouselRow(offsetSeed: 1)

            if currentRankAvailableRewards.isEmpty {
                Text("当前奖池暂时不可抽，可能是限量奖励已抽空。")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PrototypeColors.tertiaryFixed)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [PrototypeColors.primary, PrototypeColors.primaryContainer.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.06)))
    }

    private func rewardIconCarouselRow(offsetSeed: Int) -> some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                let items = carouselRewards(offsetSeed: offsetSeed)
                let base = context.date.timeIntervalSinceReferenceDate
                let speed = rewardCarouselBoost ? 110.0 : 34.0
                let iconSize: CGFloat = 68
                let spacing: CGFloat = 12
                let unitWidth = CGFloat(items.count) * iconSize + CGFloat(max(items.count - 1, 0)) * spacing
                let minimumLoopWidth = max(unitWidth, proxy.size.width + iconSize)
                let repeatCount = max(2, Int(ceil(minimumLoopWidth / max(unitWidth, 1))) + 1)
                let loopItems = Array((0..<repeatCount).flatMap { _ in items })
                let offset = CGFloat((base * speed).truncatingRemainder(dividingBy: max(unitWidth, 1)))

                HStack(spacing: spacing) {
                    ForEach(Array(loopItems.enumerated()), id: \.offset) { _, reward in
                        rewardCarouselIcon(reward)
                    }
                }
                .offset(x: -offset)
            }
            .frame(width: proxy.size.width, height: 68, alignment: .leading)
            .clipped()
        }
        .frame(height: 68)
    }

    private func rewardCarouselIcon(_ reward: RewardDefinition) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.10))
                .frame(width: 68, height: 68)

            rewardImageView(for: reward, size: 44)
        }
    }

    private var rewardInventorySheet: some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        creationHeader(
                            eyebrow: "我的奖励",
                            title: "奖励库存",
                            subtitle: "这里展示你已经抽到的全部奖励，同名奖励会合并展示数量。"
                        )

                        rewardInventorySections
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showsRewardInventory = false }
                }
            }
            .sheet(item: $selectedInventoryItem) { (item: RewardInventoryItem) in
                rewardInventoryDetailSheet(item)
            }
        }
    }

    private var rewardManagementSheet: some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        creationHeader(
                            eyebrow: "奖励管理",
                            title: "奖励定义",
                            subtitle: "这里专门维护奖励的增删改查，不包含库存维护。"
                        )

                        Button {
                            viewModel.showCreateRewardDefinition()
                        } label: {
                            Label("新增奖励", systemImage: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(PrototypeColors.onTertiaryFixed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(PrototypeColors.tertiaryFixedDim, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if rewardDefinitionsByRank.isEmpty {
                            rewardEmptyStateCard(
                                title: "还没有奖励定义",
                                message: "先新增奖励，再配置等级、图标和供应方式。"
                            )
                        } else {
                            VStack(spacing: 18) {
                                ForEach(rewardDefinitionsByRank, id: \.0.id) { rank, rewards in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Rank \(rank.rawValue)")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(PrototypeColors.primary)

                                        VStack(spacing: 12) {
                                            ForEach(rewards) { reward in
                                                rewardDefinitionCard(reward)
                                            }
                                        }
                                    }
                                    .padding(20)
                                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(PrototypeColors.outlineVariant.opacity(0.12)))
                                }
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showsRewardManagement = false }
                }
            }
            .sheet(item: $viewModel.rewardDraft) { draft in
                rewardForm(draft: draft)
            }
        }
    }

    private var rewardInventorySections: some View {
        Group {
            if inventoryItemsByRank.isEmpty {
                rewardEmptyStateCard(
                    title: "还没有抽到奖励",
                    message: "先回到抽卡页抽取，再来这里查看与使用。"
                )
            } else {
                VStack(spacing: 18) {
                    ForEach(inventoryItemsByRank, id: \.0.id) { rank, items in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Rank \(rank.rawValue)")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(PrototypeColors.primary)
                                Spacer()
                            }

                            VStack(spacing: 12) {
                                ForEach(items) { item in
                                    rewardInventoryCard(item)
                                }
                            }
                        }
                        .padding(20)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(PrototypeColors.outlineVariant.opacity(0.12)))
                    }
                }
            }
        }
    }

    private var rewardPointHistorySheet: some View {
        let transactions = (try? RewardService().fetchPointTransactions(in: modelContext)) ?? []
        let pagedTransactions = Array(transactions.prefix(rewardPointHistoryPageSize))

        return NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("积分明细")
                                .font(.caption.weight(.bold))
                                .tracking(1.8)
                                .foregroundStyle(PrototypeColors.tertiary)

                            HStack(alignment: .bottom, spacing: 8) {
                                Text("奖励积分记录")
                                    .font(.system(size: 31, weight: .heavy, design: .rounded))
                                    .tracking(-0.8)
                                    .foregroundStyle(PrototypeColors.primary)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showsRewardPointRules.toggle()
                                    }
                                } label: {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.headline)
                                        .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.42))
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, 4)
                                .accessibilityLabel("查看积分规则")
                            }

                            Text("查看每次积分变化，也可随时展开规则对照当前奖励机制。")
                                .font(.subheadline)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if showsRewardPointRules {
                            inlineHintCard(
                                title: "积分规则说明",
                                message: "奖励积分只在任务完成时发生变化；抽卡会按当前等级池消耗对应积分。",
                                highlights: [
                                    "完成日常任务：S 12 / A 8 / B 5 / C 3",
                                    "完成长期任务：S 20 / A 10 / B 6 / C 4",
                                    "抽卡消耗：S 12 / A 5 / B 3 / C 2"
                                ]
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .center, spacing: 12) {
                                Text("变更记录")
                                    .font(.caption.weight(.bold))
                                    .tracking(1.1)
                                    .foregroundStyle(PrototypeColors.onSurfaceVariant)

                                Spacer()

                                Menu {
                                    ForEach([10, 20, 30, 50], id: \.self) { pageSize in
                                        Button {
                                            rewardPointHistoryPageSize = pageSize
                                        } label: {
                                            if rewardPointHistoryPageSize == pageSize {
                                                Label("每页 \(pageSize) 条", systemImage: "checkmark")
                                            } else {
                                                Text("每页 \(pageSize) 条")
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("每页 \(rewardPointHistoryPageSize) 条")
                                            .font(.caption.weight(.semibold))
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2.weight(.bold))
                                    }
                                    .foregroundStyle(PrototypeColors.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(PrototypeColors.surfaceContainerHigh, in: Capsule())
                                }
                                .menuStyle(.button)
                            }

                            if transactions.isEmpty {
                                rewardEmptyStateCard(
                                    title: "还没有积分记录",
                                    message: "完成任务或抽卡之后，这里会开始累积你的积分变化轨迹。"
                                )
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("当前展示 \(pagedTransactions.count) / \(transactions.count) 条")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(PrototypeColors.onSurfaceVariant)

                                    VStack(spacing: 12) {
                                        ForEach(pagedTransactions) { transaction in
                                            rewardPointTransactionCard(transaction)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showsRewardPointHistory = false }
                }
            }
        }
    }

    private func rewardDrawResultSheet(_ reward: RewardDefinition) -> some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("抽取结果")
                                .font(.caption.weight(.bold))
                                .tracking(2.2)
                                .foregroundStyle(PrototypeColors.tertiary)
                            Text(reward.name.isEmpty ? "未命名奖励" : reward.name)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(PrototypeColors.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("已加入我的奖励")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                        }
                        Spacer()
                        Text("Rank \(reward.rank.rawValue)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PrototypeColors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(PrototypeColors.surfaceContainerHigh, in: Capsule())
                    }

                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(PrototypeColors.tertiaryFixedDim)
                                .frame(width: 82, height: 82)
                            rewardImageView(for: reward, size: 40)
                        }

                        if !reward.detail.isEmpty {
                            Text(reward.detail)
                                .font(.subheadline)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("稍后可前往库存页手动使用。")
                                .font(.subheadline)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.12)))

                    Button("继续抽卡") {
                        rewardDrawResult = nil
                    }
                    .buttonStyle(.plain)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PrototypeColors.onTertiaryFixed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(PrototypeColors.tertiaryFixedDim, in: Capsule())
                }
                .padding(22)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { rewardDrawResult = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func triggerRewardDraw() {
        guard !isRewardCarouselAnimating else { return }
        isRewardCarouselAnimating = true
        rewardCarouselBoost = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let result = viewModel.drawReward(in: modelContext)
            rewardCarouselBoost = false
            isRewardCarouselAnimating = false
            if let result {
                rewardDrawResult = result
            }
        }
    }

    private func carouselRewards(offsetSeed: Int) -> [RewardDefinition] {
        let source = currentRankRewards.isEmpty ? currentRankAvailableRewards : currentRankRewards
        let rewards = source.isEmpty ? rewardDefinitions : source
        guard !rewards.isEmpty else { return [] }

        let start = offsetSeed % rewards.count
        let rotated = Array(rewards[start...]) + Array(rewards[..<start])
        return Array((0..<4).flatMap { _ in rotated })
    }

    private func rewardDefinitionCard(_ reward: RewardDefinition) -> some View {
        let isAvailable = reward.availabilityMode == .unlimited || reward.remainingCount > 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PrototypeColors.tertiaryFixed.opacity(0.88))
                        .frame(width: 42, height: 42)
                    rewardImageView(for: reward, size: 24)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(reward.name.isEmpty ? "未命名奖励" : reward.name)
                        .font(.headline)
                        .foregroundStyle(PrototypeColors.primary)
                    if !reward.detail.isEmpty {
                        Text(reward.detail)
                            .font(.subheadline)
                            .foregroundStyle(PrototypeColors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(rewardAvailabilityText(reward))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.9))
                }

                Spacer()

                Menu {
                    Button("编辑", systemImage: "pencil") {
                        viewModel.showEditRewardDefinition(reward)
                    }
                    Button("删除", systemImage: "trash", role: .destructive) {
                        viewModel.pendingAction = .deleteReward(reward)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.72))
                }
                .buttonStyle(.plain)
            }

            Text(isAvailable ? "奖励预览 · 可能从当前等级池随机抽到" : "奖励预览 · 当前已不可抽")
                .font(.footnote.weight(.medium))
                .foregroundStyle(isAvailable ? PrototypeColors.onSurfaceVariant : PrototypeColors.error)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isAvailable ? 1 : 0.56)
        .background(PrototypeColors.surfaceContainerLowest, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PrototypeColors.outlineVariant.opacity(0.08)))
    }

    private func rewardInventoryCard(_ item: RewardInventoryItem) -> some View {
        let isDisabled = item.currentCount == 0

        return Button {
            viewModel.prepareRewardUsage()
            selectedInventoryItem = item
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PrototypeColors.primaryFixed)
                        .frame(width: 42, height: 42)
                    rewardImageView(for: item.rewardDefinition, size: 24)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.rewardDefinition.name.isEmpty ? "未命名奖励" : item.rewardDefinition.name)
                        .font(.headline)
                        .foregroundStyle(PrototypeColors.primary)
                    Text("当前持有 \(item.currentCount) 份 · Rank \(item.rewardDefinition.rank.rawValue)")
                        .font(.caption)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PrototypeColors.outlineVariant)
            }
            .padding(18)
            .background(PrototypeColors.surfaceContainerLowest, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(PrototypeColors.outlineVariant.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private func rewardEmptyStateCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(PrototypeColors.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypeColors.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(PrototypeColors.outlineVariant.opacity(0.12)))
    }

    private func rewardAvailabilityText(_ reward: RewardDefinition) -> String {
        switch reward.availabilityMode {
        case .unlimited:
            return "无限供应"
        case .limited:
            return "剩余 \(reward.remainingCount) 份"
        }
    }

    @ViewBuilder
    private func rewardDraftImagePreview(imageData: Data) -> some View {
        if let image = RewardService.decodedImage(from: imageData) {
            Image(platformImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PrototypeColors.surfaceContainerHigh)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "photo")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PrototypeColors.outlineVariant)
                }
        }
    }

    @ViewBuilder
    private func rewardImageView(for reward: RewardDefinition, size: CGFloat) -> some View {
        if let image = RewardService.decodedImage(from: reward.iconImageData) {
            Image(platformImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: min(size * 0.32, 18), style: .continuous))
        } else {
            Image(systemName: reward.icon.isEmpty ? "gift.fill" : reward.icon)
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func pointRuleRow(rank: TaskRank, taskPoints: Int, goalPoints: Int, drawCost: Int) -> some View {
        HStack(alignment: .top) {
            Text("Rank \(rank.rawValue)")
                .font(.headline.weight(.bold))
                .foregroundStyle(PrototypeColors.primary)
                .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("完成日常任务 +\(taskPoints) 分")
                Text("完成长期任务 +\(goalPoints) 分")
                Text("抽取该等级奖励 -\(drawCost) 分")
            }
            .font(.subheadline)
            .foregroundStyle(PrototypeColors.onSurfaceVariant)

            Spacer()
        }
        .padding(16)
        .background(PrototypeColors.surfaceContainerLowest, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(PrototypeColors.outlineVariant.opacity(0.08)))
    }

    private func rewardPointTransactionCard(_ transaction: RewardPointTransaction) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(transaction.pointsDelta >= 0 ? PrototypeColors.primaryFixed : PrototypeColors.errorContainer)
                    .frame(width: 42, height: 42)
                Image(systemName: transaction.pointsDelta >= 0 ? "plus" : "minus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(transaction.pointsDelta >= 0 ? PrototypeColors.primary : PrototypeColors.error)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(rewardPointTransactionTitle(transaction))
                    .font(.headline)
                    .foregroundStyle(PrototypeColors.primary)
                Text(rewardPointTransactionSubtitle(transaction))
                    .font(.subheadline)
                    .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                Text(rewardPointTransactionTimestamp(transaction.createdAt))
                    .font(.caption)
                    .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.75))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(transaction.pointsDelta >= 0 ? "+\(transaction.pointsDelta)" : "\(transaction.pointsDelta)")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(transaction.pointsDelta >= 0 ? PrototypeColors.primary : PrototypeColors.error)
                    .monospacedDigit()
                Text("余额 \(transaction.balanceAfterChange)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    .monospacedDigit()
            }
        }
        .padding(18)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PrototypeColors.outlineVariant.opacity(0.12)))
    }

    private func rewardPointTransactionTitle(_ transaction: RewardPointTransaction) -> String {
        switch transaction.reason {
        case .completeDailyTask:
            return "完成日常任务"
        case .completeGoal:
            return "完成长期任务"
        case .drawReward:
            return "抽取 Rank \(transaction.rank.rawValue) 奖励"
        }
    }

    private func rewardPointTransactionSubtitle(_ transaction: RewardPointTransaction) -> String {
        let title = transaction.referenceTitle.isEmpty ? "未命名条目" : transaction.referenceTitle
        switch transaction.reason {
        case .completeDailyTask, .completeGoal:
            return "\(title) · Rank \(transaction.rank.rawValue)"
        case .drawReward:
            return "消耗积分后抽中了“\(title)”"
        }
    }

    private func rewardPointTransactionTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func rewardDrawButtonLabel(for rank: TaskRank) -> String {
        let cost: Int
        switch rank {
        case .s:
            cost = 12
        case .a:
            cost = 5
        case .b:
            cost = 3
        case .c:
            cost = 2
        }
        return "消耗 \(cost) 积分抽取 Rank \(rank.rawValue) 奖励"
    }

    private func taskSwipeActions(_ task: DailyTask, allowsStatusUpdate: Bool) -> some View {
        HStack(spacing: 0) {
            if allowsStatusUpdate {
                swipeActionButton(
                    title: statusActionLabel(for: task.status),
                    icon: statusActionIcon(for: task.status),
                    color: PrototypeColors.swipeActionPrimary,
                    foreground: PrototypeColors.onTertiaryFixed,
                    width: 66,
                    corner: .left
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        swipedDailyTaskID = nil
                    }
                    updateDailyTaskStatus(task, status: nextStatus(after: task.status))
                }
            }
            swipeActionButton(
                title: "编辑",
                icon: "pencil",
                color: PrototypeColors.swipeActionDark,
                foreground: .white,
                width: 66,
                corner: allowsStatusUpdate ? .none : .left
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    swipedDailyTaskID = nil
                }
                viewModel.showEditDailyTask(task, defaultGoal: currentTopOne ?? goals.first)
            }
            swipeActionButton(
                title: "删除",
                icon: "trash",
                color: PrototypeColors.swipeActionDelete,
                foreground: .white,
                width: 66,
                corner: .right
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    swipedDailyTaskID = nil
                }
                viewModel.pendingAction = .deleteTask(task)
            }
        }
        .background(PrototypeColors.surfaceContainerLowest, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func goalSwipeActions(_ goal: Goal) -> some View {
        HStack(spacing: 0) {
            swipeActionButton(
                title: "专注",
                icon: "sparkles",
                color: PrototypeColors.swipeActionPrimary,
                foreground: PrototypeColors.onTertiaryFixed,
                width: 66,
                corner: .left
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    swipedGoalID = nil
                }
                viewModel.prepareLock(for: goal)
            }
            swipeActionButton(
                title: "编辑",
                icon: "pencil",
                color: PrototypeColors.swipeActionDark,
                foreground: .white,
                width: 66,
                corner: .none
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    swipedGoalID = nil
                }
                viewModel.showEditGoal(goal)
            }
            swipeActionButton(
                title: "删除",
                icon: "trash",
                color: PrototypeColors.swipeActionDelete,
                foreground: .white,
                width: 66,
                corner: .right
            ) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    swipedGoalID = nil
                }
                viewModel.pendingAction = .deleteGoal(goal)
            }
        }
        .background(PrototypeColors.surfaceContainerLowest, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func swipeActionButton(title: String, icon: String, color: Color, foreground: Color, width: CGFloat, corner: SwipeActionCorner, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(width: width, height: 54)
            .foregroundStyle(foreground)
            .background(color, in: swipeActionShape(for: corner))
        }
        .buttonStyle(.plain)
    }

    private enum SectionEmphasis {
        case regular
        case muted
        case subdued
    }

    private func sectionHeader(title: String, subtitle: String, expanded: Bool, emphasis: SectionEmphasis = .regular) -> some View {
        let background: Color = switch emphasis {
        case .regular:
            PrototypeColors.surfaceContainerLow
        case .muted:
            PrototypeColors.surfaceContainerLowest.opacity(0.58)
        case .subdued:
            PrototypeColors.surfaceContainerLowest.opacity(0.34)
        }
        let titleColor: Color = switch emphasis {
        case .regular:
            PrototypeColors.primary
        case .muted:
            PrototypeColors.primary.opacity(0.78)
        case .subdued:
            PrototypeColors.primary.opacity(0.64)
        }
        let subtitleColor: Color = switch emphasis {
        case .regular:
            PrototypeColors.onSurfaceVariant
        case .muted:
            PrototypeColors.onSurfaceVariant.opacity(0.82)
        case .subdued:
            PrototypeColors.onSurfaceVariant.opacity(0.68)
        }

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(titleColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(subtitleColor)
            }
            Spacer()
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(subtitleColor)
        }
        .padding(18)
        .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(PrototypeColors.outlineVariant.opacity(emphasis == .regular ? 0.12 : 0.08)))
    }

    private func quietEmptyCard(_ text: String, emphasis: SectionEmphasis = .regular) -> some View {
        let background: Color = switch emphasis {
        case .regular:
            PrototypeColors.surfaceContainerLow
        case .muted:
            PrototypeColors.surfaceContainerLowest.opacity(0.58)
        case .subdued:
            PrototypeColors.surfaceContainerLowest.opacity(0.30)
        }
        let foreground: Color = switch emphasis {
        case .regular:
            PrototypeColors.onSurfaceVariant
        case .muted:
            PrototypeColors.onSurfaceVariant.opacity(0.82)
        case .subdued:
            PrototypeColors.onSurfaceVariant.opacity(0.66)
        }

        return Text(text)
            .font(.subheadline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(PrototypeColors.outlineVariant.opacity(0.08)))
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .foregroundStyle(PrototypeColors.error)
        .padding(14)
        .background(PrototypeColors.errorContainer.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func creationHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(PrototypeColors.tertiary)
            Text(title)
                .font(.system(size: 31, weight: .heavy, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(PrototypeColors.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func creationFooter(discardLabel: String, confirmLabel: String, onDiscard: @escaping () -> Void, onConfirm: @escaping () -> Void, isConfirmDisabled: Bool) -> some View {
        VStack(spacing: 12) {
            Button(discardLabel, action: onDiscard)
                .font(.headline)
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white.opacity(0.85), in: Capsule())
                .overlay(Capsule().stroke(PrototypeColors.outlineVariant.opacity(0.26)))

            Button(confirmLabel, action: onConfirm)
                .font(.headline)
                .foregroundStyle(PrototypeColors.onTertiaryFixed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PrototypeColors.tertiaryFixedDim, in: Capsule())
                .opacity(isConfirmDisabled ? 0.45 : 1)
                .disabled(isConfirmDisabled)
        }
    }

    private func createTaskForm(page: CreateTaskPage) -> some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        creationHeader(
                            eyebrow: "任务精炼",
                            title: page.selectedType == .daily ? "确定你的推进动作" : "确定你的头等大事",
                            subtitle: "卓越源于专注。剥离杂音，探寻本质。"
                        )

                        createTaskTypeToggle(page)

                        if page.selectedType == .daily {
                            createDailyTaskContent()
                        } else {
                            createGoalContent()
                        }

                        creationFooter(
                            discardLabel: "舍弃草稿",
                            confirmLabel: "保存意图",
                            onDiscard: closeCreateTaskPage,
                            onConfirm: {
                                switch page.selectedType {
                                case .daily:
                                    viewModel.saveDailyTask(in: modelContext)
                                    if viewModel.dailyTaskDraft == nil {
                                        closeCreateTaskPage()
                                    }
                                case .goal:
                                    viewModel.saveGoal(in: modelContext)
                                    if viewModel.goalDraft == nil {
                                        closeCreateTaskPage()
                                    }
                                }
                            },
                            isConfirmDisabled: page.selectedType == .daily && goals.isEmpty
                        )

                        createTaskQuote
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: closeCreateTaskPage)
                }
            }
        }
    }

    private func createTaskTypeToggle(_ page: CreateTaskPage) -> some View {
        HStack(spacing: 4) {
            ForEach(CreateTaskType.allCases) { type in
                Button {
                    createTaskPage?.selectedType = type
                } label: {
                    Text(type.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(page.selectedType == type ? .white : PrototypeColors.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(page.selectedType == type ? PrototypeColors.primary : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(PrototypeColors.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func createGoalContent() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            goalIntentCard(
                title: viewModel.goalDraft?.title ?? "",
                placeholder: "输入任务名称...",
                helper: "它会先进入暂停任务库，只有被你亲自选择后，才会成为当前 TopOne。",
                onChange: {
                    guard var current = viewModel.goalDraft else { return }
                    current.title = $0
                    viewModel.goalDraft = current
                }
            )

            rankSelectionCard(
                title: "纪律等级",
                rank: Binding(
                    get: { viewModel.goalDraft?.rank ?? .a },
                    set: {
                        guard var current = viewModel.goalDraft else { return }
                        current.rank = $0
                        viewModel.goalDraft = current
                    }
                ),
                note: "等级用于表达这件长期任务的战略重要度。"
            )
        }
    }

    private func createDailyTaskContent() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            goalIntentCard(
                title: viewModel.dailyTaskDraft?.title ?? "",
                placeholder: "输入任务名称...",
                helper: "写成一段能真实推进的行动，而不是模糊愿望。",
                onChange: {
                    guard var current = viewModel.dailyTaskDraft else { return }
                    current.title = $0
                    viewModel.dailyTaskDraft = current
                }
            )

            VStack(alignment: .leading, spacing: 24) {
                rankSelectionCard(
                    title: "纪律等级",
                    rank: Binding(
                        get: { viewModel.dailyTaskDraft?.rank ?? .a },
                        set: {
                            guard var current = viewModel.dailyTaskDraft else { return }
                            current.rank = $0
                            viewModel.dailyTaskDraft = current
                        }
                    ),
                    note: "等级用于表达这段行动的推进优先级。"
                )

                strategicAssociationCard
            }
        }
    }

    private func goalIntentCard(title: String, placeholder: String, helper: String, onChange: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("核心目标")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(PrototypeColors.tertiaryFixedDim)
            TextField(placeholder, text: Binding(get: { title }, set: onChange))
                .textFieldStyle(.plain)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Rectangle()
                .fill(PrototypeColors.onPrimaryContainer.opacity(0.22))
                .frame(height: 2)
            Text(helper)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [PrototypeColors.primary, PrototypeColors.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(PrototypeColors.tertiaryFixedDim)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.vertical, 18)
        }
        .shadow(color: PrototypeColors.primary.opacity(0.16), radius: 24, y: 14)
    }

    private func rankSelectionCard(title: String, rank: Binding<TaskRank>, note: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
            HStack(spacing: 10) {
                ForEach(TaskRank.allCases) { item in
                    Button {
                        rank.wrappedValue = item
                    } label: {
                        Text(item.rawValue)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(rank.wrappedValue == item ? .white : PrototypeColors.primary)
                            .frame(width: 50, height: 50)
                            .background(rank.wrappedValue == item ? PrototypeColors.primary : PrototypeColors.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(rank.wrappedValue == item ? PrototypeColors.tertiary.opacity(0.22) : .clear, lineWidth: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(note)
                .font(.footnote)
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.18)))
    }

    private var strategicAssociationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("战略关联")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    Text("关联至长期架构目标。")
                        .font(.footnote)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.72))
                }
                Spacer()
            }

            Picker("所属长期任务", selection: Binding(
                get: { viewModel.dailyTaskDraft?.goal?.persistentModelID },
                set: { newValue in
                    guard var current = viewModel.dailyTaskDraft else { return }
                    current.goal = goals.first(where: { $0.persistentModelID == newValue })
                    viewModel.dailyTaskDraft = current
                }
            )) {
                ForEach(goals) { goal in
                    Text(goal.title).tag(Optional(goal.persistentModelID))
                }
            }
            .disabled(goals.isEmpty)

            Text(goals.isEmpty ? "请先创建至少一个长期任务。" : "存在当前 TopOne 时，会默认选中它，但你仍可改选其他长期任务。")
                .font(.footnote)
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.18)))
    }

    private var createTaskQuote: some View {
        VStack(spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PrototypeColors.tertiary.opacity(0.22))
            Text("“成功人士与极其成功人士的区别在于，后者几乎对所有事情都说‘不’。”")
                .font(.system(size: 18, weight: .light).italic())
                .multilineTextAlignment(.center)
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
            Text("— 专注的策展人")
                .font(.caption.weight(.bold))
                .tracking(2.2)
                .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private func closeCreateTaskPage() {
        createTaskPage = nil
        discardCreateDrafts()
    }

    private func discardCreateDrafts() {
        if viewModel.goalDraft?.goal == nil {
            viewModel.goalDraft = nil
        }
        if viewModel.dailyTaskDraft?.task == nil {
            viewModel.dailyTaskDraft = nil
        }
    }

    private func deleteConfirmationSheet(_ action: HomeViewModel.PendingAction) -> some View {
        let title: String
        let message: String
        let confirmTitle: String

        switch action {
        case .deleteGoal:
            title = "确定删除该任务吗？"
            message = "删除后此任务的所有进度和历史记录将无法恢复。"
            confirmTitle = "确认删除"
        case .deleteTask:
            title = "确定删除该任务吗？"
            message = "删除后此任务的所有进度和历史记录将无法恢复。"
            confirmTitle = "确认删除"
        case .deleteReward:
            title = "确定删除这个奖励吗？"
            message = "删除后该奖励将从奖励池中移除，已有库存也会一并删除。"
            confirmTitle = "确认删除"
        default:
            title = ""
            message = ""
            confirmTitle = ""
        }

        return ZStack {
            PrototypeColors.primary.opacity(0.18).ignoresSafeArea()
            VStack(spacing: 28) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(PrototypeColors.errorContainer)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(PrototypeColors.error)
                    }

                VStack(spacing: 14) {
                    Text(title)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(PrototypeColors.primary)
                    Text(message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                }

                VStack(spacing: 16) {
                    Button {
                        switch action {
                        case let .deleteGoal(goal):
                            viewModel.deleteGoal(goal, in: modelContext)
                        case let .deleteTask(task):
                            viewModel.deleteTask(task, in: modelContext)
                        case let .deleteReward(reward):
                            viewModel.deleteRewardDefinition(reward, in: modelContext)
                        default:
                            viewModel.pendingAction = nil
                        }
                    } label: {
                        Text(confirmTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(PrototypeColors.swipeActionDelete, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.pendingAction = nil
                    } label: {
                        Text("取消")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PrototypeColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(PrototypeColors.surfaceContainerLow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .frame(maxWidth: 380)
            .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 36).stroke(.white.opacity(0.8), lineWidth: 1.2))
            .shadow(color: PrototypeColors.primary.opacity(0.14), radius: 26, y: 16)
            .padding(24)
        }
        .presentationDetents([.fraction(0.48)])
        .presentationBackground(.clear)
    }

    private func goalForm(draft: HomeViewModel.GoalDraft) -> some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        creationHeader(
                            eyebrow: "任务精炼",
                            title: draft.goal == nil ? "确定你的头等大事" : "调整你的长期方向",
                            subtitle: "写下一件真正值得长期看见、长期投入的事。"
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("核心目标")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.tertiaryFixedDim)
                            TextField("例如：精通 AI 产品设计", text: Binding(
                                get: { viewModel.goalDraft?.title ?? draft.title },
                                set: {
                                    guard var current = viewModel.goalDraft else { return }
                                    current.title = $0
                                    viewModel.goalDraft = current
                                }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            Text("它会先进入暂停任务库，只有被你亲自选择后，才会成为当前 TopOne。")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(colors: [PrototypeColors.primary, PrototypeColors.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                        )
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(PrototypeColors.tertiaryFixedDim)
                                .frame(width: 4)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(.vertical, 18)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("任务等级")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                            Picker("等级", selection: Binding(
                                get: { viewModel.goalDraft?.rank ?? draft.rank },
                                set: {
                                    guard var current = viewModel.goalDraft else { return }
                                    current.rank = $0
                                    viewModel.goalDraft = current
                                }
                            )) {
                                ForEach(TaskRank.allCases) { rank in
                                    Text(rank.rawValue).tag(rank)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text("等级用于表达这件长期目标的战略重要度，而不是视觉徽章。")
                                .font(.footnote)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                        }
                        .padding(22)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.18)))

                        creationFooter(
                            discardLabel: "舍弃草稿",
                            confirmLabel: draft.goal == nil ? "保存意图" : "保存修改",
                            onDiscard: { viewModel.goalDraft = nil },
                            onConfirm: { viewModel.saveGoal(in: modelContext) },
                            isConfirmDisabled: false
                        )
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { viewModel.goalDraft = nil }
                }
            }
        }
    }

    private func rewardInventoryDetailSheet(_ item: RewardInventoryItem) -> some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        creationHeader(
                            eyebrow: "我的奖励",
                            title: item.rewardDefinition.name.isEmpty ? "未命名奖励" : item.rewardDefinition.name,
                            subtitle: "当下拥有 \(item.currentCount) 份。认真使用，也认真享受。"
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("奖励详情")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.tertiaryFixedDim)

                            HStack(spacing: 10) {
                                rewardImageView(for: item.rewardDefinition, size: 24)
                                Text("Rank \(item.rewardDefinition.rank.rawValue)")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                            }

                            if !item.rewardDefinition.detail.isEmpty {
                                Text(item.rewardDefinition.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.68))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(colors: [PrototypeColors.primary, PrototypeColors.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                        )

                        VStack(alignment: .leading, spacing: 16) {
                            Text("使用数量")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)

                            TextField("输入使用数量", text: $viewModel.rewardUseAmountText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Text("当前可使用 \(item.currentCount) 份，确认后才会从库存中扣减。")
                                .font(.footnote)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                        }
                        .padding(22)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.18)))

                        if let errorMessage = viewModel.errorMessage {
                            errorBanner(errorMessage)
                        }

                        creationFooter(
                            discardLabel: "稍后使用",
                            confirmLabel: "确认使用",
                            onDiscard: { selectedInventoryItem = nil },
                            onConfirm: {
                                confirmingRewardUsageItem = item
                            },
                            isConfirmDisabled: item.currentCount == 0
                        )
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { selectedInventoryItem = nil }
                }
            }
        }
    }

    private func rewardForm(draft: HomeViewModel.RewardDraft) -> some View {
        let rewardImageData = viewModel.rewardDraft?.iconImageData ?? draft.iconImageData

        return NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        creationHeader(
                            eyebrow: "奖励池",
                            title: draft.reward == nil ? "添加一个新奖励" : "调整这个奖励",
                            subtitle: "奖励要足够具体，才能在兑现时真正带来期待感。"
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("奖励内容")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.tertiaryFixedDim)
                            TextField("例如：咖啡馆放空 30 分钟", text: Binding(
                                get: { viewModel.rewardDraft?.name ?? draft.name },
                                set: {
                                    guard var current = viewModel.rewardDraft else { return }
                                    current.name = $0
                                    viewModel.rewardDraft = current
                                }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            Text("只写真正让你期待的奖励，不写抽象口号。")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(colors: [PrototypeColors.primary, PrototypeColors.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                        )
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(PrototypeColors.tertiaryFixedDim)
                                .frame(width: 4)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(.vertical, 18)
                        }

                        rankSelectionCard(
                            title: "奖励等级",
                            rank: Binding(
                                get: { viewModel.rewardDraft?.rank ?? draft.rank },
                                set: {
                                    guard var current = viewModel.rewardDraft else { return }
                                    current.rank = $0
                                    viewModel.rewardDraft = current
                                }
                            ),
                            note: "奖励等级与任务等级共用同一套 S / A / B / C 体系。"
                        )

                        VStack(alignment: .leading, spacing: 16) {
                            Text("奖励图标与说明")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)

                            PhotosPicker(selection: $selectedRewardImageItem, matching: .images, photoLibrary: .shared()) {
                                HStack(spacing: 14) {
                                    if let image = RewardService.decodedImage(from: rewardImageData) {
                                        Image(platformImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(PrototypeColors.surfaceContainerHigh)
                                            .frame(width: 56, height: 56)
                                            .overlay {
                                                Image(systemName: "photo")
                                                    .font(.headline.weight(.bold))
                                                    .foregroundStyle(PrototypeColors.outlineVariant)
                                            }
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(rewardImageData.isEmpty ? "选择奖励图片" : "更换奖励图片")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(PrototypeColors.primary)
                                        Text("图片为必选项，建议使用清晰、单主体的小图标。")
                                            .font(.footnote)
                                            .foregroundStyle(PrototypeColors.onSurfaceVariant)
                                    }

                                    Spacer()
                                }
                                .padding(16)
                                .background(PrototypeColors.surfaceContainerLowest, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(PrototypeColors.outlineVariant.opacity(0.08)))
                            }
                            .buttonStyle(.plain)

                            TextField("补充描述（可选）", text: Binding(
                                get: { viewModel.rewardDraft?.detail ?? draft.detail },
                                set: {
                                    guard var current = viewModel.rewardDraft else { return }
                                    current.detail = $0
                                    viewModel.rewardDraft = current
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        .padding(22)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.18)))

                        VStack(alignment: .leading, spacing: 16) {
                            Text("供应方式")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)

                            Picker("供应方式", selection: Binding(
                                get: { viewModel.rewardDraft?.availabilityMode ?? draft.availabilityMode },
                                set: {
                                    guard var current = viewModel.rewardDraft else { return }
                                    current.availabilityMode = $0
                                    if $0 == .unlimited {
                                        current.remainingCount = 0
                                    } else if current.remainingCount <= 0 {
                                        current.remainingCount = 1
                                    }
                                    viewModel.rewardDraft = current
                                }
                            )) {
                                Text("无限供应").tag(RewardAvailabilityMode.unlimited)
                                Text("限量库存").tag(RewardAvailabilityMode.limited)
                            }
                            .pickerStyle(.segmented)

                            if (viewModel.rewardDraft?.availabilityMode ?? draft.availabilityMode) == .limited {
                                Stepper(value: Binding(
                                    get: { max(viewModel.rewardDraft?.remainingCount ?? draft.remainingCount, 1) },
                                    set: {
                                        guard var current = viewModel.rewardDraft else { return }
                                        current.remainingCount = max($0, 1)
                                        viewModel.rewardDraft = current
                                    }
                                ), in: 1...99) {
                                    Text("剩余 \(max(viewModel.rewardDraft?.remainingCount ?? draft.remainingCount, 1)) 份")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(PrototypeColors.primary)
                                }
                            }
                        }
                        .padding(22)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.18)))

                        creationFooter(
                            discardLabel: "舍弃草稿",
                            confirmLabel: draft.reward == nil ? "保存奖励" : "保存修改",
                            onDiscard: { viewModel.rewardDraft = nil },
                            onConfirm: { viewModel.saveRewardDefinition(in: modelContext) },
                            isConfirmDisabled: rewardImageData.isEmpty
                        )
                        .onChange(of: selectedRewardImageItem) { _, newValue in
                            guard let newValue else { return }
                            Task {
                                if let data = try? await newValue.loadTransferable(type: Data.self) {
                                    let optimizedData = RewardService.optimizedImageData(from: data)
                                    await MainActor.run {
                                        guard var current = viewModel.rewardDraft else { return }
                                        current.iconImageData = optimizedData
                                        current.icon = ""
                                        viewModel.rewardDraft = current
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { viewModel.rewardDraft = nil }
                }
            }
        }
    }

    private func dailyTaskForm(draft: HomeViewModel.DailyTaskDraft) -> some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        creationHeader(
                            eyebrow: "任务精炼",
                            title: draft.task == nil ? "把推进动作写清楚" : "调整推进动作",
                            subtitle: "日常任务是你把长期方向落到具体行动里的阶段任务。"
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("行动标题")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.tertiaryFixedDim)
                            TextField("例如：完成推荐系统实验记录", text: Binding(
                                get: { viewModel.dailyTaskDraft?.title ?? draft.title },
                                set: {
                                    guard var current = viewModel.dailyTaskDraft else { return }
                                    current.title = $0
                                    viewModel.dailyTaskDraft = current
                                }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            Text("写成一段能真实推进的行动，而不是模糊愿望。")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(colors: [PrototypeColors.primary, PrototypeColors.primaryContainer], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                        )
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(PrototypeColors.tertiaryFixedDim)
                                .frame(width: 4)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(.vertical, 18)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("任务等级")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                            Picker("等级", selection: Binding(
                                get: { viewModel.dailyTaskDraft?.rank ?? draft.rank },
                                set: {
                                    guard var current = viewModel.dailyTaskDraft else { return }
                                    current.rank = $0
                                    viewModel.dailyTaskDraft = current
                                }
                            )) {
                                ForEach(TaskRank.allCases) { rank in
                                    Text(rank.rawValue).tag(rank)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(22)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.18)))

                        VStack(alignment: .leading, spacing: 16) {
                            Text("战略关联")
                                .font(.caption.weight(.bold))
                                .tracking(1.1)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                            Picker("所属长期任务", selection: Binding(
                                get: { viewModel.dailyTaskDraft?.goal?.persistentModelID },
                                set: { newValue in
                                    guard var current = viewModel.dailyTaskDraft else { return }
                                    current.goal = goals.first(where: { $0.persistentModelID == newValue })
                                    viewModel.dailyTaskDraft = current
                                }
                            )) {
                                ForEach(goals) { goal in
                                    Text(goal.title).tag(Optional(goal.persistentModelID))
                                }
                            }
                            .disabled(goals.isEmpty)
                            Text(goals.isEmpty ? "请先创建至少一个长期任务。" : "存在当前 TopOne 时，会默认选中它，但你仍可改选其他长期任务。")
                                .font(.footnote)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                        }
                        .padding(22)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(PrototypeColors.outlineVariant.opacity(0.18)))

                        creationFooter(
                            discardLabel: "舍弃草稿",
                            confirmLabel: draft.task == nil ? "保存意图" : "保存修改",
                            onDiscard: { viewModel.dailyTaskDraft = nil },
                            onConfirm: { viewModel.saveDailyTask(in: modelContext) },
                            isConfirmDisabled: goals.isEmpty
                        )
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { viewModel.dailyTaskDraft = nil }
                }
            }
        }
    }

    private func lockCommitmentSheet(_ goal: Goal) -> some View {
        ZStack {
            PrototypeColors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    creationHeader(
                        eyebrow: "专注确认",
                        title: "确认选择此长期任务？",
                        subtitle: "一旦开始，我们建议你保持节奏，每日精进一点。"
                    )

                    VStack(spacing: 14) {
                        HStack {
                            Text("选择承诺周期")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.78))
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showsLockCommitmentHint.toggle()
                                }
                            } label: {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.42))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }

                        if showsLockCommitmentHint {
                            inlineHintCard(
                                title: "承诺周期说明",
                                message: "承诺周期不是限制你，而是帮你把注意力从反复犹豫中解放出来。周期越清晰，日常执行越稳定。",
                                highlights: [
                                    "7 / 14 / 30 天适合不同强度的专注实验。",
                                    "自定义天数适用于更长期的专注承诺。",
                                    "中途放弃会进入放弃流程，并提高下次切换门槛。"
                                ]
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            lockOptionButton(.sevenDays)
                            lockOptionButton(.fourteenDays)
                            lockOptionButton(.thirtyDays)
                            lockOptionButton(.custom)
                        }
                    }
                    .padding(22)
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(PrototypeColors.outlineVariant.opacity(0.12)))

                    creationFooter(
                        discardLabel: "稍后再说",
                        confirmLabel: "确认承诺",
                        onDiscard: { viewModel.lockGoal = nil },
                        onConfirm: {
                            switch selectedLockCommitment {
                            case .sevenDays:
                                viewModel.setTopOne(goal, lockDuration: .sevenDays, in: modelContext)
                                if viewModel.errorMessage == nil { viewModel.lockGoal = nil }
                            case .fourteenDays:
                                viewModel.setTopOne(goal, lockDuration: .fourteenDays, in: modelContext)
                                if viewModel.errorMessage == nil { viewModel.lockGoal = nil }
                            case .thirtyDays:
                                viewModel.setTopOne(goal, lockDuration: .thirtyDays, in: modelContext)
                                if viewModel.errorMessage == nil { viewModel.lockGoal = nil }
                            case .custom:
                                viewModel.prepareCustomLock(for: goal)
                            }
                        },
                        isConfirmDisabled: false
                    )
                }
                .padding(24)
                .padding(.bottom, 12)
            }
        }
        .presentationDetents([.fraction(0.72)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            selectedLockCommitment = .sevenDays
            showsLockCommitmentHint = false
        }
    }

    private func lockOptionButton(_ option: LockCommitmentOption) -> some View {
        Button {
            selectedLockCommitment = option
        } label: {
            Text(option.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(selectedLockCommitment == option ? .white : PrototypeColors.primary.opacity(0.72))
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .background(selectedLockCommitment == option ? PrototypeColors.primary : PrototypeColors.surfaceContainerLow, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func customLockForm(_ goal: Goal) -> some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("自定义承诺周期")
                        .font(.largeTitle.bold())
                        .foregroundStyle(PrototypeColors.primary)
                    Text(goal.title)
                        .font(.headline)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    TextField("自定义天数（1-180）", text: $viewModel.customLockDaysText)
                        .font(.title2.weight(.semibold))
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Spacer()
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { viewModel.customLockGoal = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("锁定") { viewModel.setCustomTopOne(goal, in: modelContext) }
                }
            }
        }
    }

    private func forceSwitchView(_ goal: Goal) -> some View {
        let service = GoalService()
        let required = service.requiredReasonLength(for: goal)
        let progress = min(max(CGFloat(viewModel.switchReason.count) / CGFloat(required), 0), 1)

        return ZStack {
            PrototypeColors.surface.ignoresSafeArea()
            RadialGradient(colors: [PrototypeColors.primaryFixed.opacity(0.20), .clear], center: .topLeading, startRadius: 30, endRadius: 340)
                .ignoresSafeArea()
            RadialGradient(colors: [PrototypeColors.tertiaryFixed.opacity(0.28), .clear], center: .bottomLeading, startRadius: 24, endRadius: 300)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Text("CONFESSION OF ABSENCE")
                            .font(.caption.weight(.bold))
                            .tracking(2.8)
                            .foregroundStyle(PrototypeColors.tertiary)
                        Text("确定放弃吗")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .tracking(-1)
                            .foregroundStyle(PrototypeColors.primary)
                        Text("放弃是一种选择，但所有选择都有其沉重的回响。")
                            .font(.system(size: 17, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(PrototypeColors.tertiary)
                            Text("放弃理由")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(PrototypeColors.primary.opacity(0.82))
                        }

                        ZStack(alignment: .topLeading) {
                            if viewModel.switchReason.isEmpty {
                                Text("请输入放弃理由（ 最少 \(required) 字 ）")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.25))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }

                            TextEditor(text: $viewModel.switchReason)
                                .font(.body.weight(.medium))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 280)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Text("REQUIRED DEPTH")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.72))
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showsForceSwitchHint.toggle()
                                    }
                                } label: {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.46))
                                }
                                .buttonStyle(.plain)
                            }

                            if showsForceSwitchHint {
                                inlineHintCard(
                                    title: "为什么要写放弃理由？",
                                    message: "这段理由不是为了阻止你更换，而是帮助你更深入地看见自己此刻的真实动机，确认你确实有必须更换的理由，而不是一时想逃开当前任务。",
                                    highlights: [
                                        "写下理由的过程，是一次面向内心的复盘，帮助你分辨冲动与真正的需要。",
                                        "只有当理由足够具体、足够清晰时，才更能说明这次更换是经过认真思考的决定。",
                                        "如果只是短暂疲惫、焦虑或分心，这段文字也会提醒你先停下来，再判断是否真的需要放弃。",
                                        "字数规则会随结果动态变化：如果放弃，则下次字数 = 当前字数 × 2；如果完成一个长期任务，则下次字数 = 当前字数 ÷ 2。最小值为 50，最大值为 500。"
                                    ]
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            HStack(alignment: .bottom, spacing: 18) {
                                Text("\(viewModel.switchReason.count) / \(required)")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundStyle(PrototypeColors.primary)

                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(PrototypeColors.outlineVariant.opacity(0.42))
                                        .frame(height: 8)
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(PrototypeColors.tertiary)
                                                .frame(width: max(10, proxy.size.width * progress), height: 8)
                                        }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                    .padding(24)
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(PrototypeColors.outlineVariant.opacity(0.22)))
                    .shadow(color: PrototypeColors.primary.opacity(0.08), radius: 18, y: 10)

                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("代价与惩罚")
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PrototypeColors.error)

                        Text("由于放弃未完成的任务，下次更换门槛将翻倍。")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(PrototypeColors.primary)

                        Text("当前惩罚字数：\(required)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PrototypeColors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 22)
                    .background(PrototypeColors.errorContainer.opacity(0.26), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(PrototypeColors.error.opacity(0.16)))

                    Button {
                        viewModel.switchReasonGoal = nil
                        viewModel.switchReason = ""
                    } label: {
                        Label("再坚持一下", systemImage: "sparkles")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(PrototypeColors.primary, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.unbindTopOne(goal, in: modelContext)
                    } label: {
                        Text("确定放弃")
                            .font(.headline.weight(.bold))
                            .underline()
                            .foregroundStyle(PrototypeColors.primary.opacity(0.88))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.clear, in: Capsule())
                            .overlay(Capsule().stroke(PrototypeColors.outlineVariant.opacity(0.78)))
                            .overlay {
                                Text("THE DISCIPLINED WORK — DISCIPLINE IS FREEDOM")
                                    .font(.system(size: 9, weight: .medium))
                                    .tracking(3)
                                    .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.14))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
            .frame(maxWidth: 680)
        }
    }

    private func progressForm(_ goal: Goal) -> some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("更新进度")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(PrototypeColors.primary)
                    Text(goal.title)
                        .font(.subheadline)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                        .lineLimit(2)
                    TextField("进度百分比（0-100）", text: $viewModel.progressText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(PrototypeColors.tertiary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Text("输入新的完成比例，保存后立即同步到长期任务。")
                        .font(.footnote)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                }
                .padding(22)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { viewModel.progressGoal = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveGoalProgress(goal) }
                }
            }
        }
        .presentationDetents([.fraction(0.34)])
    }

    private func inlineHintCard(title: String, message: String, highlights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PrototypeColors.primary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(highlights, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PrototypeColors.tertiary)
                            .padding(.top, 4)
                        Text(item)
                            .font(.footnote)
                            .foregroundStyle(PrototypeColors.primary.opacity(0.82))
                    }
                }
            }
        }
        .padding(16)
        .background(PrototypeColors.surfaceContainerLow.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(PrototypeColors.outlineVariant.opacity(0.18)))
    }

    private func completionCelebrationSheet(_ celebration: CompletionCelebration) -> some View {
        NavigationStack {
            ZStack {
                PrototypeColors.background.ignoresSafeArea()
                RadialGradient(colors: [PrototypeColors.tertiaryFixed.opacity(0.24), .clear], center: .top, startRadius: 36, endRadius: 360)
                    .ignoresSafeArea()
                RadialGradient(colors: [PrototypeColors.primaryFixed.opacity(0.32), .clear], center: .bottomTrailing, startRadius: 20, endRadius: 320)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            Text("任务完成")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(3.2)
                                .foregroundStyle(PrototypeColors.tertiary)
                            Text(celebration.title)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(PrototypeColors.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(celebration.message)
                                .font(.subheadline)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 10)

                        VStack(spacing: 18) {
                            Text(celebration.badge)
                                .font(.system(size: 10, weight: .black))
                                .tracking(1.4)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(LinearGradient(colors: [PrototypeColors.primary, PrototypeColors.primaryContainer], startPoint: .leading, endPoint: .trailing), in: Capsule())

                            ZStack {
                                Circle()
                                    .fill(PrototypeColors.surfaceContainerLow)
                                    .frame(width: 124, height: 124)
                                Circle()
                                    .stroke(PrototypeColors.tertiary.opacity(0.12), lineWidth: 2)
                                    .frame(width: 144, height: 144)

                                VStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(PrototypeColors.tertiary)
                                    Text("+\(celebration.pointsAwarded)")
                                        .font(.system(size: 34, weight: .black, design: .rounded))
                                        .foregroundStyle(PrototypeColors.primary)
                                        .monospacedDigit()
                                    Text("积分")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                                }
                            }

                            if case let .dailyTask(task) = celebration,
                               let relatedGoal = task.goal {
                                Button {
                                    self.celebration = nil
                                    viewModel.prepareProgressEditor(for: relatedGoal)
                                } label: {
                                    Label("更新长期任务进度", systemImage: "chart.line.uptrend.xyaxis")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(PrototypeColors.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 15)
                                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }

                            Button("去抽卡") {
                                self.celebration = nil
                                selectedRootPage = .rewards
                            }
                            .buttonStyle(.plain)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(PrototypeColors.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 22)
                        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.9), lineWidth: 1.2))
                        .shadow(color: PrototypeColors.primary.opacity(0.10), radius: 22, y: 12)
                    }
                    .padding(.horizontal, 22)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { self.celebration = nil }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func updateGoalProgress(_ goal: Goal, value: Double) {
        let wasCompleted = goal.progress >= 1
        viewModel.updateProgress(for: goal, value: value, in: modelContext)
        if viewModel.errorMessage == nil, !wasCompleted, goal.progress >= 1 {
            presentCelebration(.goal(goal))
        }
    }

    private func saveGoalProgress(_ goal: Goal) {
        let wasCompleted = goal.progress >= 1
        viewModel.updateProgress(for: goal, in: modelContext)
        if viewModel.errorMessage == nil {
            viewModel.progressGoal = nil
            viewModel.progressText = ""
            if !wasCompleted, goal.progress >= 1 {
                presentCelebration(.goal(goal))
            }
        }
    }

    private func updateDailyTaskStatus(_ task: DailyTask, status: DailyTaskStatus) {
        let wasCompleted = task.status == .completed
        viewModel.updateTaskStatus(task, status: status, in: modelContext)
        if viewModel.errorMessage == nil, !wasCompleted, task.status == .completed {
            presentCelebration(.dailyTask(task))
        }
    }

    private func presentCelebration(_ celebration: CompletionCelebration) {
        self.celebration = celebration
    }

    private func miniProgressBar(_ progress: Double) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(PrototypeColors.surfaceVariant)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(PrototypeColors.primary)
                        .frame(width: proxy.size.width * progress)
                }
        }
        .frame(width: 74, height: 5)
    }

    private func taskSubtitle(_ task: DailyTask) -> String {
        switch task.status {
        case .inProgress:
            "执行中 · Rank \(task.rank.rawValue)"
        case .notStarted:
            "未开始 · Rank \(task.rank.rawValue)"
        case .completed:
            "已完成 · Rank \(task.rank.rawValue)"
        }
    }

    private func taskRowBackground(_ task: DailyTask) -> Color {
        switch task.status {
        case .inProgress:
            PrototypeColors.surfaceContainerHigh
        case .notStarted:
            PrototypeColors.surfaceContainerLow
        case .completed:
            PrototypeColors.surfaceContainerLowest
        }
    }

    private func taskStatusColor(_ task: DailyTask, allowsStatusUpdate: Bool) -> Color {
        guard allowsStatusUpdate else { return PrototypeColors.outlineVariant }
        switch task.status {
        case .inProgress:
            return PrototypeColors.tertiary
        case .notStarted:
            return PrototypeColors.primary.opacity(0.42)
        case .completed:
            return PrototypeColors.tertiaryFixedDim
        }
    }

    private func nextStatus(after status: DailyTaskStatus) -> DailyTaskStatus {
        switch status {
        case .notStarted:
            .inProgress
        case .inProgress:
            .completed
        case .completed:
            .notStarted
        }
    }

    private func statusActionLabel(for status: DailyTaskStatus) -> String {
        switch status {
        case .notStarted:
            "开始"
        case .inProgress:
            "完成"
        case .completed:
            "重开"
        }
    }

    private func statusActionIcon(for status: DailyTaskStatus) -> String {
        switch status {
        case .notStarted:
            "play.fill"
        case .inProgress:
            "checkmark"
        case .completed:
            "arrow.counterclockwise"
        }
    }

    private func swipeActionShape(for corner: SwipeActionCorner) -> UnevenRoundedRectangle {
        switch corner {
        case .left:
            UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 0, topTrailingRadius: 0)
        case .right:
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 18, topTrailingRadius: 18)
        case .none:
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 0)
        }
    }
}

private enum SwipeActionCorner {
    case left
    case right
    case none
}

private enum RootPage: CaseIterable, Identifiable {
    case tasks
    case rewards
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .tasks:
            "任务"
        case .rewards:
            "奖励"
        case .settings:
            "设置"
        }
    }

    var icon: String {
        switch self {
        case .tasks:
            "checkmark.circle"
        case .rewards:
            "trophy"
        case .settings:
            "gearshape"
        }
    }
}

private enum LockCommitmentOption: CaseIterable, Equatable {
    case sevenDays
    case fourteenDays
    case thirtyDays
    case custom

    var title: String {
        switch self {
        case .sevenDays:
            "7 天"
        case .fourteenDays:
            "14 天"
        case .thirtyDays:
            "30 天"
        case .custom:
            "自定义"
        }
    }
}

private enum CreateTaskType: CaseIterable, Identifiable {
    case daily
    case goal

    var id: Self { self }

    var title: String {
        switch self {
        case .daily:
            "日常任务"
        case .goal:
            "长期任务"
        }
    }
}

private struct CreateTaskPage: Identifiable {
    let id = UUID()
    var selectedType: CreateTaskType = .daily
}

private enum CompletionCelebration: Identifiable {
    case goal(Goal)
    case dailyTask(DailyTask)

    var id: String {
        switch self {
        case let .goal(goal):
            "goal-\(goal.persistentModelID)"
        case let .dailyTask(task):
            "task-\(task.persistentModelID)-\(task.endedAt?.timeIntervalSince1970 ?? 0)"
        }
    }

    var badge: String {
        switch self {
        case let .goal(goal):
            "等级 \(goal.rank.rawValue) • 完美达成"
        case let .dailyTask(task):
            "日常推进 • \(task.rank.rawValue) 级完成"
        }
    }

    var title: String {
        switch self {
        case let .goal(goal):
            goal.title
        case let .dailyTask(task):
            task.title
        }
    }

    var message: String {
        switch self {
        case .goal:
            "你已经把这件长期任务推进到 100%。这一刻值得被看见，也值得被认真奖励。"
        case let .dailyTask(task):
            "今天的推进动作已经完成。每一个被兑现的小承诺，都会把 \(task.goal?.title ?? "你的长期目标") 往前推一点。"
        }
    }

    var pointsAwarded: Int {
        switch self {
        case let .goal(goal):
            switch goal.rank {
            case .s:
                20
            case .a:
                10
            case .b:
                6
            case .c:
                4
            }
        case let .dailyTask(task):
            switch task.rank {
            case .s:
                12
            case .a:
                8
            case .b:
                5
            case .c:
                3
            }
        }
    }

    var relatedGoal: Goal? {
        switch self {
        case let .goal(goal):
            goal
        case let .dailyTask(task):
            task.goal
        }
    }
}

private enum PrototypeColors {
    static let background = Color(red: 0.986, green: 0.979, blue: 0.982)
    static let surface = Color(red: 0.986, green: 0.979, blue: 0.982)
    static let surfaceContainerLowest = Color.white
    static let surfaceContainerLow = Color(red: 0.968, green: 0.960, blue: 0.964)
    static let surfaceContainerHigh = Color(red: 0.928, green: 0.918, blue: 0.924)
    static let surfaceVariant = Color(red: 0.902, green: 0.894, blue: 0.898)
    static let primary = Color(red: 0.043, green: 0.086, blue: 0.157)
    static let onPrimary = Color.white
    static let primaryContainer = Color(red: 0.118, green: 0.161, blue: 0.231)
    static let primaryFixed = Color(red: 0.847, green: 0.890, blue: 0.984)
    static let onPrimaryContainer = Color(red: 0.522, green: 0.565, blue: 0.651)
    static let secondaryContainer = Color(red: 0.835, green: 0.890, blue: 0.992)
    static let tertiary = Color(red: 0.439, green: 0.365, blue: 0.000)
    static let tertiaryFixed = Color(red: 1.000, green: 0.882, blue: 0.427)
    static let tertiaryFixedDim = Color(red: 0.914, green: 0.769, blue: 0.000)
    static let onTertiaryFixed = Color(red: 0.133, green: 0.106, blue: 0.000)
    static let onSurfaceVariant = Color(red: 0.271, green: 0.278, blue: 0.298)
    static let outlineVariant = Color(red: 0.773, green: 0.776, blue: 0.804)
    static let error = Color(red: 0.729, green: 0.102, blue: 0.102)
    static let errorContainer = Color(red: 1.000, green: 0.855, blue: 0.839)
    static let swipeActionPrimary = Color(red: 0.980, green: 0.886, blue: 0.482)
    static let swipeActionDark = Color(red: 0.118, green: 0.161, blue: 0.231)
    static let swipeActionDelete = Color(red: 0.839, green: 0.122, blue: 0.122)
}

private extension Text {
    func sectionEyebrow() -> some View {
        font(.system(size: 13, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(PrototypeColors.onSurfaceVariant)
            .textCase(.uppercase)
    }
}
