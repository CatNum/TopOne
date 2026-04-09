# 简历与面试素材

## 项目概览
- 项目名称：`sync-skills-to-upstream`
- 业务目标：实现技能目录到上游仓库的自动化、可审查同步。
- 技术栈：GitHub Actions、Ruby、Bash、Git、GitHub CLI、YAML 配置驱动。
- 我的角色：同步体系设计与流水线演进负责人。

## 关键成果（STAR）
### 成果 1：多目标并行同步架构
- Situation（场景）：需要同时同步多个目标仓库，且失败不能相互阻断。
- Task（任务）：支持多 target 声明式配置与并行执行。
- Action（行动）：构建 plan/sync 两阶段，plan 输出矩阵，sync 并行执行且 fail-fast 关闭。
- Result（结果，尽量量化）：多目标同步效率提升，单目标失败不影响全局可用性。

### 成果 2：同步稳定性增强
- Situation（场景）：全量 checkout 容易受超长路径影响导致 CI 失败。
- Task（任务）：提升流水线稳定性并降低无关检出。
- Action（行动）：采用 sparse-checkout 仅拉取必需目录。
- Result（结果，尽量量化）：显著降低 runner 在检出阶段失败概率。

### 成果 3：可审查交付链路
- Situation（场景）：直推目标仓默认分支风险高，难审计。
- Task（任务）：改为分支同步 + PR 交付。
- Action（行动）：rsync 镜像后提交同步分支，自动创建/更新 PR。
- Result（结果，尽量量化）：同步过程可审查、可回滚，合规性提升。

## 可量化指标
- 稳定性：检出与同步失败率下降。
- 交付效率：多仓同步总时长下降（并行收益）。
- 可审计性：每次同步均可追踪到 PR 与变更集。

## 简历可复用 Bullet
### 中文
- 主导设计配置驱动的多目标技能同步流水线，落地 plan/sync 分层、并行矩阵执行与 PR 交付机制，提升同步稳定性与可审计性。

### English
- Led the design of a configuration-driven multi-target skill sync pipeline with plan/sync staging, parallel matrix execution, and PR-based delivery for better reliability and auditability.

## 面试深挖问答提纲
- Q1：为什么用 plan/sync 两阶段？
  - A：先判定可执行目标再同步，避免无效执行并降低凭据暴露面。
- Q2：为什么选择 PR 交付而非直推？
  - A：PR 提供审查与回滚能力，降低误同步风险。
