#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const ITEM_DEFS = [
  { key: "skill", item: "skill（.agent/skills/）：团队 SOP 固化", category: "AI 原生协作工具" },
  { key: "mcp", item: "MCP：工具连接层", category: "AI 原生协作工具" },
  { key: "openSpec", item: "OpenSpec：变更与任务分解规范库", category: "AI 原生协作工具" },
  { key: "openSkills", item: "OpenSkills：技能生命周期与同步", category: "AI 原生协作工具" },
  { key: "agentsMd", item: "AGENTS.md：代理入口（与 skills 目录配套）", category: "AI 原生协作工具" },
  { key: "aiCodingAssistant", item: "AI 编码助手", category: "工程基础工具" },
  { key: "git", item: "Git（仓库版本控制）", category: "工程基础工具" },
  { key: "versionReview", item: "代码评审（PR/MR）", category: "工程基础工具" },
  { key: "lint", item: "质量工程 / Lint", category: "工程基础工具" },
  { key: "typeCheck", item: "质量工程 / Type Check", category: "工程基础工具" },
  { key: "unitTest", item: "质量工程 / Unit Test", category: "工程基础工具" },
  { key: "ciCd", item: "CI/CD", category: "工程基础工具" },
  {
    key: "prototypeMaterial",
    item: "本版原型（docs/prototype/）",
    category: "前端交付资料",
  },
  {
    key: "uiMaterial",
    item: "UI 规范（docs/ui/）",
    category: "前端交付资料",
  },
  {
    key: "taskManagement",
    item: "任务管理：需求到任务的外部或流程入口",
    category: "工程基础工具",
  },
  {
    key: "requirementsDoc",
    item: "需求文档（docs/requirements/）",
    category: "文档交付",
    defaultCheckStage: "需求分析",
    defaultRequiredLevel: "recommended",
  },
  {
    key: "designDoc",
    item: "技术方案文档",
    category: "文档交付",
    defaultCheckStage: "技术方案",
    defaultRequiredLevel: "recommended",
  },
  { key: "observability", item: "可观测性：日志、指标与错误追踪", category: "工程基础工具" },
];

const ACTION_SAFE_ADD = "safe_add";
const ACTION_SAFE_PATCH = "safe_patch";
const ACTION_MANUAL_ONLY = "manual_only";

const STAGE_ORDER = [
  "初始化基线",
  "技术栈确认",
  "需求分析",
  "UI/原型",
  "技术方案",
  "开发",
  "测试",
  "上线准备",
];

const MACRO1_STAGES = new Set(["初始化基线", "技术栈确认"]);

const STAGE_ALIASES = {
  需求评审: "需求分析",
  方案评审: "技术方案",
};

const LEGACY_PROJECT_PHASE_TO_STAGE = {
  初始化阶段: "初始化基线",
  技术栈确认阶段: "技术栈确认",
  版本规划阶段: "需求分析",
  实施与验证阶段: "开发",
  上线准备阶段: "上线准备",
};

function normalizeStage(stage) {
  if (!stage) return "初始化基线";
  const mapped = STAGE_ALIASES[stage] || stage;
  return STAGE_ORDER.includes(mapped) ? mapped : "初始化基线";
}

function resolveCurrentStage(config) {
  if (config.currentStage) {
    return normalizeStage(config.currentStage);
  }
  const legacy = LEGACY_PROJECT_PHASE_TO_STAGE[config.projectPhase];
  if (legacy) return legacy;
  if (config.projectPhase) {
    return normalizeStage(config.projectPhase);
  }
  return "初始化基线";
}

function isStageReached(currentStage, checkStage) {
  const c = normalizeStage(currentStage);
  const k = normalizeStage(checkStage);
  const currentIdx = STAGE_ORDER.indexOf(c);
  const checkIdx = STAGE_ORDER.indexOf(k);
  if (currentIdx === -1 || checkIdx === -1) return true;
  return currentIdx >= checkIdx;
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (err) {
    throw new Error(`Failed to read or parse JSON: ${filePath}\n  ${err.message}`);
  }
}

function exists(repoRoot, relPath) {
  return fs.existsSync(path.join(repoRoot, relPath));
}

function readUtf8(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function writeUtf8(filePath, content) {
  ensureDir(path.dirname(filePath));
  fs.writeFileSync(filePath, content, "utf8");
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function detectByMarkers(repoRoot, markers) {
  return markers.some((marker) => exists(repoRoot, marker));
}

function nowIso() {
  return new Date().toISOString();
}

function usage() {
  console.error("Usage: node .agent/skills/ai-native-standard-flow/scripts/check-compliance.js --repo <repoRoot> [--config <path>] [--mode plan|apply-safe]");
}

function parseArgs(argv) {
  const args = { repo: process.cwd(), config: "", mode: "" };
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === "--repo") {
      if (i + 1 >= argv.length) { usage(); process.exit(2); }
      args.repo = argv[++i];
    } else if (argv[i] === "--config") {
      if (i + 1 >= argv.length) { usage(); process.exit(2); }
      args.config = argv[++i];
    } else if (argv[i] === "--mode") {
      if (i + 1 >= argv.length) { usage(); process.exit(2); }
      args.mode = argv[++i];
    } else if (argv[i] === "--dry-run") {
      args.mode = "plan";
    } else if (argv[i] === "--apply") {
      args.mode = "apply-safe";
    }
  }
  return args;
}

function loadConfig(repoRoot, explicitConfig) {
  const defaultConfigPath = path.resolve(
    __dirname,
    "../references/automation-config.template.json",
  );
  const repoConfigPath = path.join(repoRoot, "ai-native-automation.config.json");
  const baseConfig = readJson(defaultConfigPath);

  let merged = JSON.parse(JSON.stringify(baseConfig));
  if (exists(repoRoot, "ai-native-automation.config.json")) {
    merged = deepMerge(merged, readJson(repoConfigPath));
  }
  if (explicitConfig) {
    merged = deepMerge(merged, readJson(path.resolve(explicitConfig)));
  }
  return merged;
}

function deepMerge(base, override) {
  if (Array.isArray(base) || Array.isArray(override)) {
    return override;
  }
  if (!base || typeof base !== "object") return override;
  if (!override || typeof override !== "object") return base;
  const out = { ...base };
  Object.keys(override).forEach((key) => {
    out[key] = key in base ? deepMerge(base[key], override[key]) : override[key];
  });
  return out;
}

function normalizeConfig(config) {
  const ver = config.productVersion || "v1.0";
  return {
    ...config,
    outputs: config.outputs || {
      complianceMarkdownFile: `docs/compliance/${ver}/checklist.md`,
      complianceJsonFile: `docs/compliance/${ver}/checklist.json`,
    },
    executionPolicy: config.executionPolicy || {
      defaultMode: "apply-safe",
      allowSafePatch: true,
      allowUnsafeOverwrite: false,
      planWritesReports: true,
      blockOnRequiredManual: false,
    },
    adapters: config.adapters || {},
    changeRules: config.changeRules || { safeAdd: [], safePatch: [], manualOnly: [] },
    toolChecks: config.toolChecks || {},
  };
}

function buildToolCheckItems(repoRoot, config, adapterState, currentStage, productVersion) {
  const toolChecks = config.toolChecks || {};
  const updatedAt = nowIso();
  const pv = productVersion || config.productVersion || "v1.0";

  const autoStatus = {
    skill: adapterState.skillRegistry.status,
    openSpec: adapterState.openSpec.status,
    agentsMd: adapterState.agentsMd.status,
    git: adapterState.quality.git,
    lint: adapterState.quality.lint,
    typeCheck: adapterState.quality.typeCheck,
    unitTest: adapterState.quality.unitTest,
    ciCd: adapterState.quality.ciCd,
    openSkills: adapterState.openSkills.status,
    prototypeMaterial: adapterState.frontend.prototype,
    uiMaterial: adapterState.frontend.ui,
    requirementsDoc: adapterState.docsDelivery.requirements,
    designDoc: adapterState.docsDelivery.designVersion,
  };

  const evidenceByKey = {
    skill: adapterState.skillRegistry.evidence,
    openSpec: adapterState.openSpec.evidence,
    agentsMd: adapterState.agentsMd.evidence,
    git: adapterState.quality.git === "pass" ? [".git"] : [],
    versionReview: [],
    lint: adapterState.quality.lint === "pass" ? ["lint markers found"] : [],
    typeCheck: adapterState.quality.typeCheck === "pass" ? ["type-check markers found"] : [],
    unitTest: adapterState.quality.unitTest === "pass" ? ["unit-test markers found"] : [],
    ciCd: adapterState.quality.ciCd === "pass" ? [".github/workflows/"] : [],
    openSkills: adapterState.openSkills.evidence,
    mcp: adapterState.mcp.evidence,
    prototypeMaterial: adapterState.frontend.prototype === "pass" ? ["docs/prototype/"] : [],
    uiMaterial: adapterState.frontend.ui === "pass" ? ["docs/ui/"] : [],
    requirementsDoc: adapterState.docsDelivery.requirements === "pass" ? ["docs/requirements/"] : [],
    designDoc:
      adapterState.docsDelivery.designVersion === "pass" ? [`docs/design/${pv}/`] : [],
  };

  const items = ITEM_DEFS.map((def) => {
    const checkCfg = toolChecks[def.key] || {};
    const requiredLevel = checkCfg.requiredLevel || def.defaultRequiredLevel || "required";
    const mode = checkCfg.mode || (def.key === "versionReview" ? "manual" : "auto");
    const checkStage = normalizeStage(
      checkCfg.checkStage || checkCfg.checkPhase || def.defaultCheckStage || "初始化基线",
    );
    const shouldCheckNow = isStageReached(currentStage, checkStage);
    const forcedStatus = checkCfg.forceStatus || "";
    let adoptionStatus = shouldCheckNow
      ? (mode === "manual" ? "manual" : (autoStatus[def.key] || "unknown"))
      : "unknown";
    if (forcedStatus) {
      adoptionStatus = forcedStatus;
    }
    const exceptionReason = checkCfg.exceptionReason || "";
    let nextAction;
    if (!shouldCheckNow) {
      nextAction = `当前交付阶段为 ${currentStage}，该项在 ${checkStage} 开始检查`;
    } else if (adoptionStatus === "manual") {
      nextAction = "需要人工补充证据并确认状态";
    } else if (adoptionStatus === "fail" && def.key === "openSpec") {
      nextAction = "运行 `npx openspec init` 初始化 openspec/ 目录";
    } else {
      nextAction = "";
    }
    const itemLabel =
      def.key === "designDoc" ? `技术方案文档（docs/design/${pv}/）` : def.item;
    return {
      item: itemLabel,
      category: def.category,
      checkStage,
      requiredLevel,
      adoptionStatus,
      exceptionReason,
      evidence: evidenceByKey[def.key] || [],
      owner: "",
      nextAction,
      updatedAt,
    };
  });

  return items;
}

function buildPathCheckItems(repoRoot, config, _currentStage) {
  const checks = [];
  const requiredPaths = config.requiredPaths || [];
  const projectType = config.projectType || "monolith";
  const conditionalPaths = config.conditionalPaths || [];
  const updatedAt = nowIso();

  requiredPaths.forEach((relPath) => {
    checks.push({
      item: `路径存在: ${relPath}`,
      category: "仓库结构",
      checkStage: "初始化基线",
      requiredLevel: "required",
      adoptionStatus: exists(repoRoot, relPath) ? "pass" : "fail",
      exceptionReason: "",
      evidence: exists(repoRoot, relPath) ? [relPath] : [],
      owner: "",
      nextAction: exists(repoRoot, relPath) ? "" : `补齐 ${relPath}`,
      updatedAt,
    });
  });

  conditionalPaths.forEach((rule) => {
    const shouldApply = rule.when === "projectType == microservice" ? projectType === "microservice" : false;
    if (!shouldApply) return;
    const present = exists(repoRoot, rule.path);
    checks.push({
      item: `条件路径存在: ${rule.path}`,
      category: "仓库结构",
      checkStage: "初始化基线",
      requiredLevel: rule.required ? "required" : "recommended",
      adoptionStatus: present ? "pass" : "fail",
      exceptionReason: "",
      evidence: present ? [rule.path] : [],
      owner: "",
      nextAction: present ? "" : `补齐 ${rule.path}`,
      updatedAt,
    });
  });

  return checks;
}

function buildVersionGateItems(currentStage, productVersion) {
  const pv = productVersion || "v1.0";
  const updatedAt = nowIso();
  const row = (checkStage, item, requiredLevel) => {
    const should = isStageReached(currentStage, checkStage);
    return {
      item,
      category: "阶段书面产出",
      checkStage,
      requiredLevel,
      adoptionStatus: should ? "manual" : "unknown",
      exceptionReason: "",
      evidence: [],
      owner: "",
      nextAction: should
        ? "按项目约定路径补齐并人工确认"
        : `当前交付阶段为 ${currentStage}，该项在 ${checkStage} 起纳入核对`,
      updatedAt,
    };
  };
  return [
    row(
      "开发",
      `开发报告（默认 docs/compliance/${pv}/development-report.md，见 skill）`,
      "required",
    ),
    row(
      "测试",
      `测试报告（默认 docs/compliance/${pv}/test-report.md，见 skill）`,
      "required",
    ),
    row("上线准备", "上线准备清单（发布说明、回滚等）", "recommended"),
  ];
}

function splitItemsByMacro(items) {
  const macro1 = [];
  const macro2 = [];
  items.forEach((it) => {
    const cs = it.checkStage || "初始化基线";
    if (MACRO1_STAGES.has(cs)) macro1.push(it);
    else macro2.push(it);
  });
  return { macro1, macro2 };
}

function humanMacroFromStage(currentStage) {
  const idx = STAGE_ORDER.indexOf(currentStage);
  if (idx === -1) return "（未知阶段）";
  if (idx <= 1) {
    return "项目配置阶段（对应微观：初始化基线～技术栈确认）";
  }
  return "版本交付循环阶段（对应微观：需求分析～上线准备）";
}

function toYaml(items, overallStatus, outputFile, currentStage, productVersion) {
  const lines = [
    "schema_version: \"1.2\"",
    `project_file: "${outputFile}"`,
    `product_version: "${productVersion}"`,
    `current_stage: "${currentStage}"`,
    `overall_status: "${overallStatus}" # pass | fail | unknown`,
    "items:",
  ];

  items.forEach((it) => {
    lines.push(`  - item: "${it.item}"`);
    lines.push(`    category: "${it.category}"`);
    lines.push(`    check_stage: "${it.checkStage || "初始化基线"}"`);
    lines.push(`    required_level: "${it.requiredLevel}"`);
    lines.push(`    adoption_status: "${it.adoptionStatus}"`);
    lines.push(`    exception_reason: "${it.exceptionReason}"`);
    lines.push("    evidence:");
    if (it.evidence.length === 0) {
      lines.push("      - \"\"");
    } else {
      it.evidence.forEach((e) => lines.push(`      - "${String(e).replace(/"/g, "\\\"")}"`));
    }
    lines.push(`    owner: "${it.owner}"`);
    lines.push(`    next_action: "${it.nextAction}"`);
    lines.push(`    updated_at: "${it.updatedAt}"`);
  });

  return lines.join("\n");
}

function toTableRows(items) {
  const statusMap = {
    pass: "✅ 通过",
    fail: "❌ 不通过",
    manual: "🟡 人工确认",
    waived: "🟣 豁免",
    unknown: "⚪ 未知",
  };
  return items
    .map((it) => {
      const evidence = it.evidence.length > 0 ? it.evidence.join(", ") : "";
      const humanStatus = statusMap[it.adoptionStatus] || `⚪ ${it.adoptionStatus}`;
      return `| ${it.item} | ${it.checkStage || "初始化基线"} | ${humanStatus} | ${it.exceptionReason} | ${evidence} | ${it.owner} | ${it.nextAction} | ${it.updatedAt} |`;
    })
    .join("\n");
}

function renderComplianceMarkdown(outputFile, overallStatus, items, summary, currentStage, productVersion) {
  const badge =
    overallStatus === "pass"
      ? "✅ 通过"
      : overallStatus === "unknown"
        ? "🟡 待确认"
        : "❌ 不通过";
  const yamlBlock = toYaml(items, overallStatus, outputFile, currentStage, productVersion);
  const { macro1, macro2 } = splitItemsByMacro(items);
  const rows1 = toTableRows(macro1);
  const rows2 = toTableRows(macro2);
  const macroHuman = humanMacroFromStage(currentStage);

  return `# AI Native 合规检查清单（${productVersion}）

> 目的：记录本仓库及本版本的合规与交付物核对状态。  
> 范围：\`${outputFile}\`；机器可读：\`${summary.machine_readable_file}\`。

## 人类速览

- 产品版本：\`${productVersion}\`
- 总体状态：\`${badge}\`
- 当前交付阶段（\`current_stage\`，与 JSON 一致）：\`${currentStage}\`
- 宏观视角（仅人类阅读）：\`${macroHuman}\`
- 采用状态图例：\`✅ 通过 | ❌ 不通过 | 🟡 人工确认 | 🟣 豁免 | ⚪ 未知\`
- 检查人：
- 备注：
- 执行模式：\`${summary.mode}\`
- 变更统计：\`created=${summary.created}, patched=${summary.patched}, manual=${summary.manual}\`
- 计划变更数：\`${summary.planned_changes}\`

## 一、项目配置阶段

### 检查项

**说明**：不再单列「约定交付物」表；本表每一行即该微观阶段的验收口径（目录类行与下方路径检查共同覆盖「仓库与协作骨架」等基线）。

| 检查项 | 微观阶段 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|---|
${rows1}

## 二、本版本交付（产品版本：${productVersion}）

### 检查项

**说明**：不再单列「约定交付物」表；本表每一行即本版本在该微观阶段应满足的验收口径（含开发/测试/上线等书面产出行）。

| 检查项 | 微观阶段 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|---|
${rows2}

## 机器可读

\`说明：本节采用英文枚举（pass/fail/manual/waived/unknown）供自动化解析。\`

\`\`\`yaml
${yamlBlock}
\`\`\`
`;
}

function computeOverallStatus(items, currentStage) {
  const required = items.filter((it) => it.requiredLevel === "required" && isStageReached(currentStage, it.checkStage || "初始化基线"));
  const hasRequiredFail = required.some((it) => it.adoptionStatus === "fail");
  const hasRequiredManual = required.some((it) => it.adoptionStatus === "manual");
  if (hasRequiredFail) return "fail";
  if (hasRequiredManual) return "unknown";
  return "pass";
}

function templateRoot() {
  return path.resolve(__dirname, "../references/bootstrap-templates");
}

function readPackageScripts(repoRoot) {
  const packagePath = path.join(repoRoot, "package.json");
  if (!fs.existsSync(packagePath)) return {};
  try {
    const pkg = readJson(packagePath);
    return pkg.scripts || {};
  } catch (err) {
    return {};
  }
}

function collectState(repoRoot, config) {
  const pv = config.productVersion || "v1.0";
  const hasSkills = exists(repoRoot, ".agent/skills/");
  const hasOpenSpec = exists(repoRoot, "openspec/");
  const hasAgentsMd = exists(repoRoot, "AGENTS.md");
  const scripts = readPackageScripts(repoRoot);

  const hasLint = detectByMarkers(repoRoot, [
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.json",
    "eslint.config.js",
    "eslint.config.mjs",
    "golangci.yml",
    ".golangci.yml",
  ]) || Boolean(scripts.lint);
  const hasTypeCheck = detectByMarkers(repoRoot, ["tsconfig.json", "pyproject.toml", "mypy.ini", "go.mod"]) || Boolean(scripts.typecheck || scripts["type-check"]);
  const hasUnitTest = detectByMarkers(repoRoot, ["jest.config.js", "vitest.config.ts", "pytest.ini", "go.mod", "tests/", "__tests__/"]) || Boolean(scripts.test);

  const skillMdExists = hasSkills && detectByMarkers(repoRoot, [".agent/skills/ai-native-standard-flow/SKILL.md"]);
  const openSkillsSignal = Boolean(scripts.openskills);
  const agentsContent = hasAgentsMd ? readUtf8(path.join(repoRoot, "AGENTS.md")) : "";
  const hasAvailableSkills = agentsContent.includes("<available_skills>");
  const hasPrototype = exists(repoRoot, "docs/prototype/");
  const hasUi = exists(repoRoot, "docs/ui/");

  return {
    repoRoot,
    hasSkills,
    hasOpenSpec,
    hasAgentsMd,
    hasAvailableSkills,
    quality: {
      git: exists(repoRoot, ".git") ? "pass" : "fail",
      lint: hasLint ? "pass" : "fail",
      typeCheck: hasTypeCheck ? "pass" : "fail",
      unitTest: hasUnitTest ? "pass" : "fail",
      ciCd: exists(repoRoot, ".github/workflows/") ? "pass" : "fail",
    },
    adapters: {
      skillRegistry: {
        status: hasSkills && skillMdExists ? "pass" : "fail",
        evidence: hasSkills ? [".agent/skills/"] : [],
      },
      mcp: {
        status: "manual",
        evidence: [],
      },
      openSpec: {
        status: hasOpenSpec ? "pass" : "fail",
        evidence: hasOpenSpec ? ["openspec/"] : [],
      },
      openSkills: {
        status: openSkillsSignal ? "pass" : "manual",
        evidence: openSkillsSignal ? [".agent/skills/ or openskills script signal"] : [],
      },
      agentsMd: {
        status: hasAgentsMd && hasAvailableSkills ? "pass" : "fail",
        evidence: hasAgentsMd ? ["AGENTS.md"] : [],
      },
      qualityToolchain: {
        status: hasLint && hasTypeCheck && hasUnitTest ? "pass" : "fail",
        evidence: ["lint/typecheck/test markers"],
      },
      projectStandards: {
        status: "unknown",
        evidence: [],
      },
    },
    frontend: {
      prototype: hasPrototype ? "pass" : "fail",
      ui: hasUi ? "pass" : "fail",
    },
    docsDelivery: {
      requirements: exists(repoRoot, "docs/requirements/") ? "pass" : "fail",
      designVersion: exists(repoRoot, path.join("docs/design", pv)) ? "pass" : "fail",
    },
    config,
  };
}

function addAction(actions, type, target, reason, payload) {
  actions.push({ type, target, reason, payload: payload || {} });
}

function planChanges(state) {
  const actions = [];
  const config = state.config;
  const repoRoot = state.repoRoot;
  const tplRoot = templateRoot();
  const safeAddSet = new Set((config.changeRules && config.changeRules.safeAdd) || []);
  const safePatchSet = new Set((config.changeRules && config.changeRules.safePatch) || []);
  const requiredPaths = config.requiredPaths || [];

  requiredPaths.forEach((relPath) => {
    const absPath = path.join(repoRoot, relPath);
    if (!fs.existsSync(absPath)) {
      addAction(actions, ACTION_SAFE_ADD, relPath, "required path missing", { kind: "directory" });
    }
  });

  safeAddSet.forEach((relPath) => {
    const dest = path.join(repoRoot, relPath);
    const src = path.join(tplRoot, relPath);
    if (!fs.existsSync(dest) && fs.existsSync(src)) {
      addAction(actions, ACTION_SAFE_ADD, relPath, "bootstrap template missing", { kind: "file", template: src });
    }
  });

  addAction(actions, ACTION_MANUAL_ONLY, "MCP", "cannot be reliably validated automatically");
  addAction(actions, ACTION_MANUAL_ONLY, "AI 编码助手", "requires workflow evidence");
  addAction(actions, ACTION_MANUAL_ONLY, "任务管理", "external system binding");
  addAction(actions, ACTION_MANUAL_ONLY, "可观测性", "tooling evidence requires manual confirmation");

  return actions;
}

function applyActions(repoRoot, actions, policy) {
  let created = 0;
  let patched = 0;
  let manual = 0;
  const createdFiles = [];
  const applied = [];
  const mode = policy.mode;
  actions.forEach((action) => {
    if (action.type === ACTION_MANUAL_ONLY) {
      manual += 1;
      applied.push({ ...action, applied: false });
      return;
    }
    if (mode === "plan") {
      applied.push({ ...action, applied: false });
      return;
    }
    if (action.type === ACTION_SAFE_ADD) {
      const absTarget = path.join(repoRoot, action.target);
      if (action.payload.kind === "directory") {
        ensureDir(absTarget);
        created += 1;
        applied.push({ ...action, applied: true });
      } else if (action.payload.kind === "file") {
        ensureDir(path.dirname(absTarget));
        writeUtf8(absTarget, readUtf8(action.payload.template));
        created += 1;
        createdFiles.push(action.target);
        applied.push({ ...action, applied: true });
      }
      return;
    }
    if (action.type === ACTION_SAFE_PATCH && policy.allowSafePatch) {
      const absTarget = path.join(repoRoot, action.target);
      if (fs.existsSync(absTarget)) {
        const original = readUtf8(absTarget);
        if (!original.includes(action.payload.append.trim())) {
          writeUtf8(absTarget, `${original}${action.payload.append}`);
          patched += 1;
          applied.push({ ...action, applied: true });
        } else {
          applied.push({ ...action, applied: false });
        }
      } else {
        applied.push({ ...action, applied: false });
      }
      return;
    }
    applied.push({ ...action, applied: false });
  });
  return { created, patched, manual, actions: applied, createdFiles };
}

function renderJsonReport(summary, items, actions, overallStatus, currentStage, productVersion) {
  return {
    schema_version: "1.2",
    product_version: productVersion,
    current_stage: currentStage,
    overall_status: overallStatus,
    status_semantics: {
      human_readable: "中文图标状态",
      machine_readable: "pass|fail|manual|waived|unknown",
    },
    summary,
    items: items.map((it) => ({
      item: it.item,
      category: it.category,
      check_stage: it.checkStage || "初始化基线",
      required_level: it.requiredLevel,
      adoption_status: it.adoptionStatus,
      exception_reason: it.exceptionReason,
      evidence: it.evidence,
      owner: it.owner,
      next_action: it.nextAction,
      updated_at: it.updatedAt,
    })),
    change_plan: actions,
  };
}

function main() {
  const args = parseArgs(process.argv);
  if (!args.repo) {
    usage();
    process.exit(2);
  }

  const repoRoot = path.resolve(args.repo);
  const rawConfig = loadConfig(repoRoot, args.config);
  const config = normalizeConfig(rawConfig);
  const currentStage = resolveCurrentStage(config);
  const mode = args.mode || config.executionPolicy.defaultMode || "apply-safe";
  const state = collectState(repoRoot, config);
  const changePlan = planChanges(state);
  const applyResult = applyActions(repoRoot, changePlan, {
    mode,
    allowSafePatch: Boolean(config.executionPolicy.allowSafePatch),
  });

  const refreshedState = collectState(repoRoot, config);
  const productVersion = config.productVersion || "v1.0";
  const defaultMd = `docs/compliance/${productVersion}/checklist.md`;
  const defaultJson = `docs/compliance/${productVersion}/checklist.json`;
  const outputFile = config.outputs.complianceMarkdownFile || defaultMd;
  const outputJson = config.outputs.complianceJsonFile || defaultJson;
  const toolItems = buildToolCheckItems(
    repoRoot,
    config,
    {
      ...refreshedState.adapters,
      quality: refreshedState.quality,
      frontend: refreshedState.frontend,
      docsDelivery: refreshedState.docsDelivery,
    },
    currentStage,
    productVersion,
  );
  const gateItems = buildVersionGateItems(currentStage, productVersion);
  const pathItems = buildPathCheckItems(repoRoot, config, currentStage);
  const toolMacro1 = toolItems.filter((it) => MACRO1_STAGES.has(it.checkStage || "初始化基线"));
  const toolMacro2 = toolItems.filter((it) => !MACRO1_STAGES.has(it.checkStage || "初始化基线"));
  const items = [...toolMacro1, ...pathItems, ...toolMacro2, ...gateItems];
  const overallStatus = computeOverallStatus(items, currentStage);
  const outputPath = path.join(repoRoot, outputFile);
  const outputJsonPath = path.join(repoRoot, outputJson);
  const summary = {
    mode,
    created: applyResult.created,
    patched: applyResult.patched,
    manual: applyResult.manual,
    planned_changes: changePlan.length,
    machine_readable_file: outputJson,
    manual_finalize_files: applyResult.createdFiles,
  };
  const markdown = renderComplianceMarkdown(outputFile, overallStatus, items, summary, currentStage, productVersion);
  const jsonReport = renderJsonReport(summary, items, applyResult.actions, overallStatus, currentStage, productVersion);

  const shouldWriteReports = mode === "apply-safe" || Boolean(config.executionPolicy.planWritesReports);
  if (shouldWriteReports) {
    writeUtf8(outputPath, markdown);
    writeUtf8(outputJsonPath, JSON.stringify(jsonReport, null, 2));
    console.log(`AI Native compliance written to: ${outputPath}`);
    console.log(`AI Native compliance json written to: ${outputJsonPath}`);
  } else {
    console.log("plan mode with planWritesReports=false: report files are not written");
  }
  console.log(`overall_status=${overallStatus}`);
  console.log(`mode=${mode}; created=${summary.created}; patched=${summary.patched}; manual=${summary.manual}`);
  if (mode === "apply-safe" && summary.manual_finalize_files.length > 0) {
    console.log("post_apply_manual_finalize_files:");
    summary.manual_finalize_files.forEach((file) => {
      console.log(`- ${file} (模板仅供参考，需人工完善)`);
    });
  }

  if (overallStatus === "fail" || overallStatus === "unknown") {
    process.exit(1);
  }
}

main();
