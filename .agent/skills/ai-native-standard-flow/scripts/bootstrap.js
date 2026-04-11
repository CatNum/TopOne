#!/usr/bin/env node
"use strict";

/**
 * bootstrap.js — 项目初始化脚本（仅运行一次）
 *
 * 职责：创建缺失的目录和模板文件，为 AI Native 工作流搭建骨架。
 * 不写 checklist.md / checklist.json，不做 CI 门禁，始终 exit(0)。
 *
 * 用法：
 *   node bootstrap.js --repo <path> [--config <path>] [--mode plan|apply-safe] [--dry-run] [--apply]
 *
 * --mode plan / --dry-run   仅打印计划，不写任何文件
 * --mode apply-safe / --apply  执行安全变更（默认）
 */

const {
  loadConfig,
  normalizeConfig,
  resolveCurrentStage,
  collectState,
  planChanges,
  applyActions,
} = require("./lib/core");

function usage() {
  console.error(
    "Usage: node bootstrap.js --repo <repoRoot> [--config <path>] [--mode plan|apply-safe] [--dry-run] [--apply]"
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

function main() {
  const args = parseArgs(process.argv);
  const path = require("path");
  const repoRoot = path.resolve(args.repo);

  const rawConfig = loadConfig(repoRoot, args.config);
  const config = normalizeConfig(rawConfig);
  const currentStage = resolveCurrentStage(config);
  const mode = args.mode || config.executionPolicy.defaultMode || "apply-safe";

  const state = collectState(repoRoot, config);
  const changePlan = planChanges(state);
  const result = applyActions(repoRoot, changePlan, {
    mode,
    allowSafePatch: Boolean(config.executionPolicy.allowSafePatch),
  });

  console.log(`bootstrap mode=${mode}; stage=${currentStage}`);
  console.log(`created=${result.created}; patched=${result.patched}; manual=${result.manual}`);

  if (mode === "plan") {
    const pending = changePlan.filter((a) => a.type !== "manual_only");
    if (pending.length === 0) {
      console.log("plan: no changes needed");
    } else {
      console.log("plan: changes that would be applied:");
      pending.forEach((a) => console.log(`  [${a.type}] ${a.target} — ${a.reason}`));
    }
  }

  if (result.createdFiles.length > 0) {
    console.log("post_apply_manual_finalize_files:");
    result.createdFiles.forEach((f) => console.log(`  - ${f} (模板仅供参考，需人工完善)`));
  }

  // bootstrap 不做 CI 门禁，始终成功退出
  process.exit(0);
}

main();
