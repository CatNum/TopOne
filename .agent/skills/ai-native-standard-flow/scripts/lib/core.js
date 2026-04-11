"use strict";

const fs = require("fs");
const path = require("path");

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

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
  { key: "prototypeMaterial", item: "本版原型（docs/prototype/）", category: "前端交付资料" },
  { key: "uiMaterial", item: "UI 规范（docs/ui/）", category: "前端交付资料" },
  { key: "taskManagement", item: "任务管理：需求到任务的外部或流程入口", category: "工程基础工具" },
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

// ---------------------------------------------------------------------------
// Stage logic
// ---------------------------------------------------------------------------

function normalizeStage(stage) {
  if (!stage) return "初始化基线";
  const mapped = STAGE_ALIASES[stage] || stage;
  return STAGE_ORDER.includes(mapped) ? mapped : "初始化基线";
}

function resolveCurrentStage(config) {
  if (config.currentStage) return normalizeStage(config.currentStage);
  const legacy = LEGACY_PROJECT_PHASE_TO_STAGE[config.projectPhase];
  if (legacy) return legacy;
  if (config.projectPhase) return normalizeStage(config.projectPhase);
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

// ---------------------------------------------------------------------------
// I/O helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Config loading
// ---------------------------------------------------------------------------

function loadConfig(repoRoot, explicitConfig) {
  const defaultConfigPath = path.resolve(__dirname, "../../references/automation-config.template.json");
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
  if (Array.isArray(base) || Array.isArray(override)) return override;
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

// ---------------------------------------------------------------------------
// State collection
// ---------------------------------------------------------------------------

function readPackageScripts(repoRoot) {
  const packagePath = path.join(repoRoot, "package.json");
  if (!fs.existsSync(packagePath)) return {};
  try {
    return readJson(packagePath).scripts || {};
  } catch (_) {
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
    ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json",
    "eslint.config.js", "eslint.config.mjs", "golangci.yml", ".golangci.yml",
  ]) || Boolean(scripts.lint);
  const hasTypeCheck = detectByMarkers(repoRoot, ["tsconfig.json", "pyproject.toml", "mypy.ini", "go.mod"])
    || Boolean(scripts.typecheck || scripts["type-check"]);
  const hasUnitTest = detectByMarkers(repoRoot, ["jest.config.js", "vitest.config.ts", "pytest.ini", "go.mod", "tests/", "__tests__/"])
    || Boolean(scripts.test);

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
      mcp: { status: "manual", evidence: [] },
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
      projectStandards: { status: "unknown", evidence: [] },
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

// ---------------------------------------------------------------------------
// Bootstrap action engine
// ---------------------------------------------------------------------------

function templateRoot() {
  return path.resolve(__dirname, "../../references/bootstrap-templates");
}

function addAction(actions, type, target, reason, payload) {
  actions.push({ type, target, reason, payload: payload || {} });
}

function planChanges(state) {
  const actions = [];
  const { config, repoRoot } = state;
  const tplRoot = templateRoot();
  const safeAddSet = new Set((config.changeRules && config.changeRules.safeAdd) || []);
  const requiredPaths = config.requiredPaths || [];

  requiredPaths.forEach((relPath) => {
    if (!fs.existsSync(path.join(repoRoot, relPath))) {
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
  const { mode } = policy;

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
          return;
        }
      }
    }
    applied.push({ ...action, applied: false });
  });

  return { created, patched, manual, actions: applied, createdFiles };
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  ITEM_DEFS,
  ACTION_SAFE_ADD,
  ACTION_SAFE_PATCH,
  ACTION_MANUAL_ONLY,
  STAGE_ORDER,
  MACRO1_STAGES,
  STAGE_ALIASES,
  LEGACY_PROJECT_PHASE_TO_STAGE,
  normalizeStage,
  resolveCurrentStage,
  isStageReached,
  readJson,
  exists,
  readUtf8,
  writeUtf8,
  ensureDir,
  detectByMarkers,
  nowIso,
  loadConfig,
  deepMerge,
  normalizeConfig,
  readPackageScripts,
  collectState,
  templateRoot,
  addAction,
  planChanges,
  applyActions,
};
