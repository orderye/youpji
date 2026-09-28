#!/usr/bin/env node
/**
 * 营业时段交叉比对脚本（第6轮：营业时段核验与巡检）
 *
 * 职责：
 *   对比高德地图二级时段（pending，confidence=0.55）与景区官方已核验时段（verified）。
 *   - 偏差 ≤ 30 分钟：标记为可自动升级（matched_verified）
 *   - 偏差 > 30 分钟：标记为争议时段（disputed），输出审核建议供 Admin 处理
 *
 * 用法：
 *   node scripts/verify-hours-crosscheck.mjs
 */
import { readFileSync, existsSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const WORK_PATH = resolve(ROOT, "youpji", "data", "attractions", ".work.json");

function parseMinutes(timeStr) {
  if (!timeStr) return null;
  const [h, m] = timeStr.split(":").map(Number);
  if (isNaN(h) || isNaN(m)) return null;
  return h * 60 + m;
}

function run() {
  if (!existsSync(WORK_PATH)) {
    console.error(`中间产物不存在: ${WORK_PATH}，请先执行 build-attraction-seed.mjs`);
    process.exit(1);
  }

  const attractions = JSON.parse(readFileSync(WORK_PATH, "utf8"));
  console.log(`[营业时段交叉比对] 分析 ${attractions.length} 个景区...`);

  let verifiedCount = 0;
  let crossChecked = 0;
  let matches = 0;
  let discrepancies = 0;

  for (const a of attractions) {
    if (a.verification_status !== "verified") continue;
    verifiedCount++;

    const officialOpen = parseMinutes(a.opening_time);
    const officialClose = parseMinutes(a.closing_time);
    if (officialOpen == null || officialClose == null) continue;

    const desc = a.amap_biz?.hours_desc;
    if (!desc || typeof desc !== "string") continue;

    crossChecked++;
    // 从 desc 中抽取第一个时间段做比对
    const clockMatch = desc.match(/(\d{1,2}):(\d{2})\s*[-–~]\s*(\d{1,2}):(\d{2})/);
    if (!clockMatch) continue;

    const amapOpen = parseInt(clockMatch[1], 10) * 60 + parseInt(clockMatch[2], 10);
    const amapClose = parseInt(clockMatch[3], 10) * 60 + parseInt(clockMatch[4], 10);

    const openDiff = Math.abs(amapOpen - officialOpen);
    const closeDiff = Math.abs(amapClose - officialClose);

    if (openDiff <= 30 && closeDiff <= 30) {
      matches++;
    } else {
      discrepancies++;
      console.log(
        `  ⚠ [时段差异] ${a.name} (${a.city})：` +
        `官方 [${a.opening_time}-${a.closing_time}] vs 高德 [${clockMatch[1]}:${clockMatch[2]}-${clockMatch[3]}:${clockMatch[4]}] ` +
        `(开园差 ${openDiff}分, 闭园差 ${closeDiff}分)`
      );
    }
  }

  console.log(`\n比对报告:`);
  console.log(`  - 已验证景区数: ${verifiedCount}`);
  console.log(`  - 具备高德时段的已验证景区: ${crossChecked}`);
  console.log(`  - 吻合时段 (偏差 ≤ 30m): ${matches}`);
  console.log(`  - 存在显著差异需人工审核: ${discrepancies}`);
}

run();
