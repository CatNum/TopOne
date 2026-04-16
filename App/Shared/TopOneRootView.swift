import SwiftData
import SwiftUI

struct TopOneRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
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
                case .deleteGoal, .deleteTask:
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
                    placeholderPage(
                        eyebrow: "REWARD SPACE",
                        title: "奖励页稍后开启",
                        message: "底部切换已经接通。接下来我们可以在这里实现奖励池与兑换流程。"
                    )
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
            .sheet(item: deleteModalAction) { action in
                deleteConfirmationSheet(action)
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

                floatingAddButton
                    .padding(.trailing, max(12, min(proxy.size.width * 0.038, 20)))
                    .padding(.bottom, max(12, min(proxy.size.width * 0.038, 20)))
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
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(PrototypeColors.primary.opacity(0.18))
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.lockGoal = nil
                    }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        Circle()
                            .fill(PrototypeColors.surfaceContainerHigh)
                            .frame(width: 88, height: 88)
                            .overlay {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(PrototypeColors.primary)
                            }
                            .padding(.top, 12)

                        VStack(spacing: 14) {
                            Text("确认选择此长期任务？")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(PrototypeColors.primary)
                            Text("一旦开始，我们建议您保持节奏，每日精进\n一点。")
                                .font(.system(size: 18, weight: .medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                        }

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

                        Button {
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
                        } label: {
                            HStack(spacing: 12) {
                                Text("确认承诺")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 19)
                            .background(PrototypeColors.primary, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button("稍后再说") {
                            viewModel.lockGoal = nil
                        }
                        .buttonStyle(.plain)
                        .font(.body.weight(.medium))
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 30)
                }
                .frame(width: min(proxy.size.width - 16, 620))
                .frame(maxHeight: min(proxy.size.height * 0.78, 720))
                .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 42, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 42).stroke(.white.opacity(0.9), lineWidth: 1.3))
                .shadow(color: PrototypeColors.primary.opacity(0.14), radius: 28, y: 18)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
        .presentationDetents([.fraction(0.72)])
        .presentationBackground(.clear)
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
                VStack(alignment: .leading, spacing: 20) {
                    Text("更新进度")
                        .font(.largeTitle.bold())
                        .foregroundStyle(PrototypeColors.primary)
                    Text(goal.title)
                        .foregroundStyle(PrototypeColors.onSurfaceVariant)
                    TextField("进度百分比（0-100）", text: $viewModel.progressText)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(PrototypeColors.tertiary)
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Spacer()
                }
                .padding(24)
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
                    VStack(spacing: 26) {
                        VStack(spacing: 10) {
                            Text("荣耀揭晓")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(4)
                                .foregroundStyle(PrototypeColors.tertiary)
                            Text("太棒了！\n这是属于你的时刻")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(PrototypeColors.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 20)

                        VStack(spacing: 20) {
                            Text(celebration.badge)
                                .font(.system(size: 11, weight: .black))
                                .tracking(1.8)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(LinearGradient(colors: [PrototypeColors.primary, PrototypeColors.primaryContainer], startPoint: .leading, endPoint: .trailing), in: Capsule())

                            ZStack {
                                Circle()
                                    .fill(PrototypeColors.surfaceContainerLow)
                                    .frame(width: 132, height: 132)
                                Circle()
                                    .stroke(PrototypeColors.tertiary.opacity(0.14), lineWidth: 1.5)
                                    .frame(width: 156, height: 156)
                                Circle()
                                    .stroke(PrototypeColors.tertiary.opacity(0.08), lineWidth: 1)
                                    .frame(width: 186, height: 186)
                                Image(systemName: celebration.icon)
                                    .font(.system(size: 42, weight: .semibold))
                                    .foregroundStyle(PrototypeColors.tertiary)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                            VStack(spacing: 10) {
                                Text(celebration.title)
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(PrototypeColors.primary)
                                    .multilineTextAlignment(.center)
                                Text(celebration.message)
                                    .font(.body)
                                    .foregroundStyle(PrototypeColors.onSurfaceVariant)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Text(celebration.archiveNote)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PrototypeColors.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(PrototypeColors.secondaryContainer.opacity(0.36), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                            VStack(spacing: 12) {
                                Button {
                                    self.celebration = nil
                                } label: {
                                    Label("立即领取奖励", systemImage: "sparkles")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                        .background(PrototypeColors.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                Button("在奖励池查看更多") {
                                    self.celebration = nil
                                }
                                .buttonStyle(.plain)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PrototypeColors.primary.opacity(0.74))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(PrototypeColors.surfaceContainerLowest.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(PrototypeColors.outlineVariant.opacity(0.24)))
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 28)
                        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 40).stroke(.white.opacity(0.9), lineWidth: 1.2))
                        .shadow(color: PrototypeColors.primary.opacity(0.12), radius: 28, y: 16)

                        Text("请在月底前完成兑换")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2.8)
                            .foregroundStyle(PrototypeColors.onSurfaceVariant.opacity(0.48))
                            .padding(.bottom, 18)
                    }
                    .padding(.horizontal, 24)
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

    var icon: String {
        switch self {
        case .goal:
            "trophy.fill"
        case .dailyTask:
            "checkmark.circle.fill"
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

    var archiveNote: String {
        switch self {
        case let .goal(goal):
            "此成就已永久存入《\(goal.title)》的里程碑档案。"
        case let .dailyTask(task):
            "此完成记录已写入《\(task.goal?.title ?? "当前专注")》的执行轨迹。"
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
