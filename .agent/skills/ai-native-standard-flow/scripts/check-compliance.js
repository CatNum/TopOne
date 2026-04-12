#!/usr/bin/env node
"use strict";

/**
 * check-compliance.js — 合规检查脚本（迭代中反复运行）
 *
 * 职责：检测工具链与文档状态，写入 checklist.md + checklist.json。
 * 不做项目初始化（目录/模板创建由 bootstrap.js 负责）。
 *
 * 用法：
 *   node check-compliance.js --repo <path> [--config <path>] [--mode plan|apply-safe]
 *
 * --mode plan / --dry-run      检查但仅在 planWritesReports=true 时写报告
 * --mode apply-safe / --apply  检查并写报告（默认）
 *
 * 退出码：
 *   0  overall_status=pass
 *   1  overall_status=fail 或 unknown
 *   2  参数错误
 */

const fs = require("fs");
const path = require("path");
const {
  ITEM_DEFS,
  MACRO1_STAGES,
  STAGE_ORDER,
  loadConfig,
  normalizeConfig,
  resolveCurrentStage,
  collectState,
  isStageReached,
  normalizeStage,
  nowIso,
  writeUtf8,
  exists,
} = require("./lib/core");

// ---------------------------------------------------------------------------
// Arg parsing
// ---------------------------------------------------------------------------

function usage() {
  console.error(
    "Usage: node check-compliance.js --repo <repoRoot> [--config <path>] [--mode plan|apply-safe]"
  );
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

// ---------------------------------------------------------------------------
// Check item builders
// ---------------------------------------------------------------------------

function readPackageScripts(repoRoot) {
  const fs = require("fs");
  const pkgPath = path.join(repoRoot, "package.json");
  if (!fs.existsSync(pkgPath)) return {};
  try { return JSON.parse(fs.readFileSync(pkgPath, "utf8")).scripts || {}; } catch (_) { return {}; }
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
    designDoc: adapterState.docsDelivery.designVersion === "pass" ? [`docs/design/${pv}/`] : [],
  };

  return ITEM_DEFS.map((def) => {
    const checkCfg = toolChecks[def.key] || {};
    const requiredLevel = checkCfg.requiredLevel || def.defaultRequiredLevel || "required";
    const mode = checkCfg.mode || (def.key === "versionReview" ? "manual" : "auto");
    const checkStage = normalizeStage(
      checkCfg.checkStage || checkCfg.checkPhase || def.defaultCheckStage || "初始化基线"
    );
    const shouldCheckNow = isStageReached(currentStage, checkStage);
    const forcedStatus = checkCfg.forceStatus || "";
    let adoptionStatus = shouldCheckNow
      ? (mode === "manual" ? "manual" : (autoStatus[def.key] || "unknown"))
      : "unknown";
    if (forcedStatus) adoptionStatus = forcedStatus;

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

    const itemLabel = def.key === "designDoc" ? `技术方案文档（docs/design/${pv}/）` : def.item;
    return {
      item: itemLabel,
      category: def.category,
      checkStage,
      requiredLevel,
      adoptionStatus,
      exceptionReason: checkCfg.exceptionReason || "",
      evidence: evidenceByKey[def.key] || [],
      owner: "",
      nextAction,
      updatedAt,
    };
  });
}

function buildPathCheckItems(repoRoot, config) {
  const updatedAt = nowIso();
  const projectType = config.projectType || "monolith";
  const checks = [];

  (config.requiredPaths || []).forEach((relPath) => {
    const present = exists(repoRoot, relPath);
    checks.push({
      item: `路径存在: ${relPath}`,
      category: "仓库结构",
      checkStage: "初始化基线",
      requiredLevel: "required",
      adoptionStatus: present ? "pass" : "fail",
      exceptionReason: "",
      evidence: present ? [relPath] : [],
      owner: "",
      nextAction: present ? "" : `补齐 ${relPath}`,
      updatedAt,
    });
  });

  (config.conditionalPaths || []).forEach((rule) => {
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
    row("开发", `开发报告（默认 docs/compliance/${pv}/development-report.md，见 skill）`, "required"),
    row("测试", `测试报告（默认 docs/compliance/${pv}/test-report.md，见 skill）`, "required"),
    row("上线准备", "上线准备清单（发布说明、回滚等）", "recommended"),
  ];
}

// ---------------------------------------------------------------------------
// Status computation
// ---------------------------------------------------------------------------

function computeOverallStatus(items, currentStage) {
  const required = items.filter(
    (it) => it.requiredLevel === "required" && isStageReached(currentStage, it.checkStage || "初始化基线")
  );
  if (required.some((it) => it.adoptionStatus === "fail")) return "fail";
  if (required.some((it) => it.adoptionStatus === "manual")) return "unknown";
  return "pass";
}

function readExistingJsonReport(repoRoot, outputJson) {
  const filePath = path.join(repoRoot, outputJson);
  if (!fs.existsSync(filePath)) return null;
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (_) {
    return null;
  }
}

function mergeWithExistingConfirmedItems(items, existingReport) {
  if (!existingReport || !Array.isArray(existingReport.items)) return items;
  const existingByItem = new Map(existingReport.items.map((it) => [it.item, it]));

  return items.map((item) => {
    const existing = existingByItem.get(item.item);
    if (!existing) return item;

    const existingStatus = existing.adoption_status;
    const keepConfirmed = existingStatus === "pass" || existingStatus === "waived";
    const newStatus = item.adoptionStatus;
    const newNeedsManual = newStatus === "manual";

    if (!keepConfirmed || !newNeedsManual) return item;

    return {
      ...item,
      adoptionStatus: existing.adoption_status,
      exceptionReason: existing.exception_reason || item.exceptionReason,
      evidence: Array.isArray(existing.evidence) ? existing.evidence : item.evidence,
      owner: existing.owner || item.owner,
      nextAction: existing.next_action || "",
      updatedAt: existing.updated_at || item.updatedAt,
    };
  });
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

function splitItemsByMacro(items) {
  const macro1 = [];
  const macro2 = [];
  items.forEach((it) => {
    (MACRO1_STAGES.has(it.checkStage || "初始化基线") ? macro1 : macro2).push(it);
  });
  return { macro1, macro2 };
}

function humanMacroFromStage(currentStage) {
  const idx = STAGE_ORDER.indexOf(currentStage);
  if (idx === -1) return "（未知阶段）";
  return idx <= 1
    ? "项目配置阶段（对应微观：初始化基线～技术栈确认）"
    : "版本交付循环阶段（对应微观：需求分析～上线准备）";
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
  const statusMap = { pass: "✅ 通过", fail: "❌ 不通过", manual: "🟡 人工确认", waived: "🟣 豁免", unknown: "⚪ 未知" };
  return items.map((it) => {
    const evidence = it.evidence.length > 0 ? it.evidence.join(", ") : "";
    const humanStatus = statusMap[it.adoptionStatus] || `⚪ ${it.adoptionStatus}`;
    return `| ${it.item} | ${it.checkStage || "初始化基线"} | ${humanStatus} | ${it.exceptionReason} | ${evidence} | ${it.owner} | ${it.nextAction} | ${it.updatedAt} |`;
  }).join("\n");
}

function renderComplianceMarkdown(outputFile, overallStatus, items, summary, currentStage, productVersion) {
  const badge = overallStatus === "pass" ? "✅ 通过" : overallStatus === "unknown" ? "🟡 待确认" : "❌ 不通过";
  const { macro1, macro2 } = splitItemsByMacro(items);

  return `# AI Native 合规检查清单（${productVersion}）

> 目的：记录本仓库及本版本的合规与交付物核对状态。
> 范围：\`${outputFile}\`；机器可读：\`${summary.machine_readable_file}\`。

## 人类速览

- 产品版本：\`${productVersion}\`
- 总体状态：\`${badge}\`
- 当前交付阶段（\`current_stage\`，与 JSON 一致）：\`${currentStage}\`
- 宏观视角（仅人类阅读）：\`${humanMacroFromStage(currentStage)}\`
- 采用状态图例：\`✅ 通过 | ❌ 不通过 | 🟡 人工确认 | 🟣 豁免 | ⚪ 未知\`
- 检查人：
- 备注：
- 执行模式：\`${summary.mode}\`

## 一、项目配置阶段

### 检查项

**说明**：不再单列「约定交付物」表；本表每一行即该微观阶段的验收口径（目录类行与下方路径检查共同覆盖「仓库与协作骨架」等基线）。

| 检查项 | 微观阶段 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|---|
${toTableRows(macro1)}

## 二、本版本交付（产品版本：${productVersion}）

### 检查项

**说明**：不再单列「约定交付物」表；本表每一行即本版本在该微观阶段应满足的验收口径（含开发/测试/上线等书面产出行）。

| 检查项 | 微观阶段 | 采用状态 | 未使用原因（豁免说明） | 证据 | 负责人 | 下一步动作 | 更新时间 |
|---|---|---|---|---|---|---|---|
${toTableRows(macro2)}
`;
}

function renderJsonReport(summary, items, overallStatus, currentStage, productVersion) {
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
  };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const args = parseArgs(process.argv);
  const repoRoot = path.resolve(args.repo);

  const rawConfig = loadConfig(repoRoot, args.config);
  const config = normalizeConfig(rawConfig);
  const currentStage = resolveCurrentStage(config);
  const mode = args.mode || config.executionPolicy.defaultMode || "apply-safe";
  const productVersion = config.productVersion || "v1.0";

  const state = collectState(repoRoot, config);
  const adapterState = {
    ...state.adapters,
    quality: state.quality,
    frontend: state.frontend,
    docsDelivery: state.docsDelivery,
  };

  const toolItems = buildToolCheckItems(repoRoot, config, adapterState, currentStage, productVersion);
  const pathItems = buildPathCheckItems(repoRoot, config);
  const gateItems = buildVersionGateItems(currentStage, productVersion);

  const toolMacro1 = toolItems.filter((it) => MACRO1_STAGES.has(it.checkStage || "初始化基线"));
  const toolMacro2 = toolItems.filter((it) => !MACRO1_STAGES.has(it.checkStage || "初始化基线"));
  const items = [...toolMacro1, ...pathItems, ...toolMacro2, ...gateItems];

  const overallStatus = computeOverallStatus(items, currentStage);

  const defaultMd = `docs/compliance/${productVersion}/checklist.md`;
  const defaultJson = `docs/compliance/${productVersion}/checklist.json`;
  const outputFile = config.outputs.complianceMarkdownFile || defaultMd;
  const outputJson = config.outputs.complianceJsonFile || defaultJson;

  const existingReport = readExistingJsonReport(repoRoot, outputJson);
  const mergedItems = mergeWithExistingConfirmedItems(items, existingReport);
  const mergedOverallStatus = computeOverallStatus(mergedItems, currentStage);

  const summary = { mode, machine_readable_file: outputJson };
  const markdown = renderComplianceMarkdown(outputFile, mergedOverallStatus, mergedItems, summary, currentStage, productVersion);
  const jsonReport = renderJsonReport(summary, mergedItems, mergedOverallStatus, currentStage, productVersion);

  const shouldWriteReports = mode === "apply-safe" || Boolean(config.executionPolicy.planWritesReports);
  if (shouldWriteReports) {
    writeUtf8(path.join(repoRoot, outputFile), markdown);
    writeUtf8(path.join(repoRoot, outputJson), JSON.stringify(jsonReport, null, 2));
    console.log(`AI Native compliance written to: ${path.join(repoRoot, outputFile)}`);
    console.log(`AI Native compliance json written to: ${path.join(repoRoot, outputJson)}`);
  } else {
    console.log("plan mode with planWritesReports=false: report files are not written");
  }

  console.log(`overall_status=${mergedOverallStatus}`);
  console.log(`mode=${mode}`);

  if (mergedOverallStatus === "fail" || mergedOverallStatus === "unknown") {
    process.exit(1);
  }
}

main();
