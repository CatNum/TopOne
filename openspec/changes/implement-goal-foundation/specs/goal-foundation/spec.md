## ADDED Requirements

### Requirement: 长期目标可被创建
系统 MUST 支持创建长期目标，并保存标题、当前状态、手动进度、创建时间与锁定截止时间等基础字段。

#### Scenario: 创建有效长期目标
- **WHEN** 用户提交一个长度在 1 到 16 个字符之间的长期目标标题
- **THEN** 系统保存该长期目标，并将其初始手动进度设为 0

#### Scenario: 拒绝空标题
- **WHEN** 用户提交空标题或只包含空白字符的标题
- **THEN** 系统拒绝创建长期目标

#### Scenario: 拒绝过长标题
- **WHEN** 用户提交超过 16 个字符的长期目标标题
- **THEN** 系统拒绝创建长期目标

### Requirement: 当前 TopOne 保持唯一
系统 MUST 保证同一时刻最多只有一个长期目标被标记为当前 TopOne。

#### Scenario: 设置一个目标为 TopOne
- **WHEN** 用户将某个长期目标设为当前 TopOne
- **THEN** 系统将该目标标记为当前 TopOne
- **THEN** 系统取消其他所有长期目标的当前 TopOne 标记

#### Scenario: 没有当前 TopOne 时允许为空
- **WHEN** 用户尚未选择任何当前 TopOne
- **THEN** 系统允许长期目标列表中不存在当前 TopOne

### Requirement: TopOne 进度可手动维护
系统 MUST 支持维护当前 TopOne 的手动进度，并将进度限制在 0 到 1 的范围内。

#### Scenario: 更新有效进度
- **WHEN** 用户将当前 TopOne 的进度更新为 0 到 1 之间的值
- **THEN** 系统保存新的进度值

#### Scenario: 限制低于最小值的进度
- **WHEN** 用户提交小于 0 的进度值
- **THEN** 系统将保存值限制为 0

#### Scenario: 限制高于最大值的进度
- **WHEN** 用户提交大于 1 的进度值
- **THEN** 系统将保存值限制为 1

### Requirement: 主界面展示目标基础状态
系统 MUST 在主界面展示当前 TopOne 的基础状态，并在没有目标时展示空状态引导。

#### Scenario: 没有任何目标
- **WHEN** 用户首次打开应用且没有任何长期目标
- **THEN** 主界面展示空状态引导文案

#### Scenario: 存在当前 TopOne
- **WHEN** 用户已经选择当前 TopOne
- **THEN** 主界面展示当前 TopOne 的标题与手动进度

### Requirement: 本 change 保持目标基础能力边界
系统 MUST 将本 change 限定在长期目标与当前 TopOne 的基础能力，不混入任务、奖励或完成归档实现。

#### Scenario: 检查实现范围
- **WHEN** 本 change 完成时检查应用能力
- **THEN** 系统已经具备目标基础创建、选择与展示能力
- **THEN** 系统尚未引入日常任务池、奖励池、完成归档或桌面常驻层完整交互
