#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const ITEM_DEFS = [
  { key: "skill", item: "skill（.agent/skills/）", category: "AI 原生协作工具" },
  { key: "mcp", item: "MCP", category: "AI 原生协作工具" },
  { key: "openSpec", item: "OpenSpec", category: "AI 原生协作工具" },
  { key: "openSkills", item: "OpenSkills", category: "AI 原生协作工具" },
  { key: "agentsMd", item: "AGENTS.md", category: "AI 原生协作工具" },
  { key: "aiCodingAssistant", item: "AI 编码助手", category: "工程基础工具" },
  { key: "versionReview", item: "版本与评审", category: "工程基础工具" },
  { key: "lint", item: "质量工程 / Lint", category: "工程基础工具" },
  { key: "typeCheck", item: "质量工程 / Type Check", category: "工程基础工具" },
  { key: "unitTest", item: "质量工程 / Unit Test", category: "工程基础工具" },
  { key: "ciCd", item: "CI/CD", category: "工程基础工具" },
  { key: "prototypeMaterial", item: "原型资料（docs/prototype/）", category: "前端交付资料" },
  { key: "uiMaterial", item: "UI 规范资料（docs/ui/）", category: "前端交付资料" },
  { key: "taskManagement", item: "任务管理", category: "工程基础工具" },
  { key: "observability", item: "可观测性", category: "工程基础工具" },
];

const ACTION_SAFE_ADD = "safe_add";
const ACTION_SAFE_PATCH = "safe_patch";
const ACTION_MANUAL_ONLY = "manual_only";

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function exists(repoRoot, relPath) {
  return fs.existsSync(path.join(repoRoot, relPath));
}

function readUtf8(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function writeUtf8(filePath, content) {
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
    if (argv[i] === "--repo") args.repo = argv[++i];
    else if (argv[i] === "--config") args.config = argv[++i];
    else if (argv[i] === "--mode") args.mode = argv[++i];
    else if (argv[i] === "--dry-run") args.mode = "plan";
    else if (argv[i] === "--apply") args.mode = "apply-safe";
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
  return {
    ...config,
    outputs: config.outputs || {
      complianceMarkdownFile: "ai-native-compliance.md",
      complianceJsonFile: "ai-native-compliance.json",
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

function buildToolCheckItems(repoRoot, config, adapterState) {
  const toolChecks = config.toolChecks || {};
  const updatedAt = nowIso();

  const autoStatus = {
    skill: adapterState.skillRegistry.status,
    openSpec: adapterState.openSpec.status,
    agentsMd: adapterState.agentsMd.status,
    versionReview: adapterState.quality.versionReview,
    lint: adapterState.quality.lint,
    typeCheck: adapterState.quality.typeCheck,
    unitTest: adapterState.quality.unitTest,
    ciCd: adapterState.quality.ciCd,
    openSkills: adapterState.openSkills.status,
    prototypeMaterial: adapterState.frontend.prototype,
    uiMaterial: adapterState.frontend.ui,
  };

  const evidenceByKey = {
    skill: adapterState.skillRegistry.evidence,
    openSpec: adapterState.openSpec.evidence,
    agentsMd: adapterState.agentsMd.evidence,
    versionReview: adapterState.quality.versionReview === "pass" ? [".git"] : [],
    lint: adapterState.quality.lint === "pass" ? ["lint markers found"] : [],
    typeCheck: adapterState.quality.typeCheck === "pass" ? ["type-check markers found"] : [],
    unitTest: adapterState.quality.unitTest === "pass" ? ["unit-test markers found"] : [],
    ciCd: adapterState.quality.ciCd === "pass" ? [".github/workflows/"] : [],
    openSkills: adapterState.openSkills.evidence,
    mcp: adapterState.mcp.evidence,
    prototypeMaterial: adapterState.frontend.prototype === "pass" ? ["docs/prototype/"] : [],
    uiMaterial: adapterState.frontend.ui === "pass" ? ["docs/ui/"] : [],
  };

  const items = ITEM_DEFS.map((def) => {
    const checkCfg = toolChecks[def.key] || {};
    const requiredLevel = checkCfg.requiredLevel || "required";
    const mode = checkCfg.mode || "auto";
    const adoptionStatus = mode === "manual" ? "manual" : (autoStatus[def.key] || "unknown");
    return {
      item: def.item,
      category: def.category,
      requiredLevel,
      adoptionStatus,
      exceptionReason: "",
      evidence: evidenceByKey[def.key] || [],
      owner: "",
      nextAction: mode === "manual" ? "需要人工补充证据并确认状态" : "",
      updatedAt,
    };
  });

  return items;
}

function buildPathCheckItems(repoRoot, config) {
  const checks = [];
  const requiredPaths = config.requiredPaths || [];
  const projectType = config.projectType || "monolith";
  const conditionalPaths = config.conditionalPaths || [];
  const updatedAt = nowIso();

  requiredPaths.forEach((relPath) => {
    checks.push({
      item: `路径存在: ${relPath}`,
      category: "仓库结构",
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

function toYaml(items, overallStatus, outputFile) {
  const lines = [
    "schema_version: \"1.1\"",
    `project_file: "${outputFile}"`,
    `overall_status: "${overallStatus}" # pass | fail | unknown`,
    "items:",
  ];

  items.forEach((it) => {
    lines.push(`  - item: "${it.item}"`);
    lines.push(`    category: "${it.category}"`);
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
      return `| ${it.item} | ${humanStatus} | ${it.exceptionReason} | ${evidence} | ${it.owner} | ${it.nextAction} | ${it.updatedAt} |`;
    })
    .join("\n");
}

function renderComplianceMarkdown(outputFile, overallStatus, items, summary) {
  const badge = overallStatus === "pass" ? "✅ 通过" : "❌ 不通过";
  const yamlBlock = toYaml(items, overallStatus, outputFile);
  const rows = toTableRows(items);

  return `# AI Native 合规状态

> 目的：记录当前项目是否采用 AI Native 标准必需项。
> 范围：项目实例文件应放在仓库根目录：\`ai-native-compliance.md\`。

## 人类速览

- 总体状态：\`${badge}\`
- 采用状态图例：\`✅ 通过 | ❌ 不通过 | 🟡 人工确认 | 🟣 豁免 | ⚪ 未知\`
- 检查人：
- 备注：
- 执行模式：\`${summary.mode}\`
- 变更统计：\`created=${summary.created}, patched=${summary.patched}, manual=${summary.manual}\`
- 计划变更数：\`${summary.planned_changes}\`
- 机器可读文件：\`${summary.machine_readable_file}\`

## 检查项

| 检查项 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|
${rows}

## 机器可读

\`说明：本节采用英文枚举（pass/fail/manual/waived/unknown）供自动化解析。\`

\`\`\`yaml
${yamlBlock}
\`\`\`
`;
}

function computeOverallStatus(items) {
  const required = items.filter((it) => it.requiredLevel === "required");
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
  const openSkillsSignal = Boolean(scripts.openskills) || detectByMarkers(repoRoot, [".agent/skills/"]);
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
      versionReview: exists(repoRoot, ".git") ? "pass" : "fail",
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
        evidence: openSkillsSignal ? ["skill directory or script signal"] : [],
      },
      agentsMd: {
        status: hasAgentsMd ? "pass" : "fail",
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

  if (safePatchSet.has("AGENTS.md") && state.hasAgentsMd && !state.hasAvailableSkills) {
    addAction(actions, ACTION_SAFE_PATCH, "AGENTS.md", "missing <available_skills> block", {
      append: "\n\n<!-- AUTO-BOOTSTRAP NOTE: please add <available_skills> block -->\n",
    });
  }

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

function renderJsonReport(summary, items, actions, overallStatus) {
  return {
    schema_version: "1.1",
    overall_status: overallStatus,
    status_semantics: {
      human_readable: "中文图标状态",
      machine_readable: "pass|fail|manual|waived|unknown",
    },
    summary,
    items: items.map((it) => ({
      item: it.item,
      category: it.category,
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
  const mode = args.mode || config.executionPolicy.defaultMode || "apply-safe";
  const state = collectState(repoRoot, config);
  const changePlan = planChanges(state);
  const applyResult = applyActions(repoRoot, changePlan, {
    mode,
    allowSafePatch: Boolean(config.executionPolicy.allowSafePatch),
  });

  const refreshedState = collectState(repoRoot, config);
  const toolItems = buildToolCheckItems(repoRoot, config, {
    ...refreshedState.adapters,
    quality: refreshedState.quality,
    frontend: refreshedState.frontend,
  });
  const pathItems = buildPathCheckItems(repoRoot, config);
  const items = [...toolItems, ...pathItems];
  const overallStatus = computeOverallStatus(items);
  const outputFile = config.outputs.complianceMarkdownFile || "ai-native-compliance.md";
  const outputJson = config.outputs.complianceJsonFile || "ai-native-compliance.json";
  const outputPath = path.join(repoRoot, outputFile);
  const outputJsonPath = path.join(repoRoot, outputJson);
  const summary = {
    mode,
    created: applyResult.created,
    patched: applyResult.patched,
    manual: applyResult.manual,
    planned_changes: changePlan.length,
    machine_readable_file: config.outputs.complianceJsonFile || "ai-native-compliance.json",
    manual_finalize_files: applyResult.createdFiles,
  };
  const markdown = renderComplianceMarkdown(outputFile, overallStatus, items, summary);
  const jsonReport = renderJsonReport(summary, items, applyResult.actions, overallStatus);

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

  const blockOnRequiredManual = Boolean(config.executionPolicy.blockOnRequiredManual);
  const shouldBlockOnUnknown = blockOnRequiredManual && overallStatus === "unknown";
  if (overallStatus === "fail" || shouldBlockOnUnknown) {
    process.exit(1);
  }
}

main();
