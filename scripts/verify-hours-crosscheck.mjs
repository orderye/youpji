#!/usr/bin/env node
/**
 * 营业时段交叉比对脚本（第6/7轮：营业时段核验与巡检）
 *
 * 职责：
 *   对比高德地图二级时段（pending，confidence=0.55）与景区官方已核验时段（verified）。
 *   - 偏差 ≤ tolerance（默认30分钟）：标记为可自动采纳（matched_verified），记录入 matched-hours.json
 *   - 偏差 > tolerance：标记为争议时段（disputed），输出审核建议供 Admin 处理
 *
 * 用法：
 *   node scripts/verify-hours-crosscheck.mjs [--tolerance 30] [--verbose]
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const WORK_PATH = resolve(ROOT, "youpji", "data", "attractions", ".work.json");
const OUT_PATH = resolve(ROOT, "youpji", "data", "verified", "matched-hours.json");

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

  const args = process.argv.slice(2);
  let tolerance = 30;
  const tolIdx = args.indexOf("--tolerance");
  if (tolIdx !== -1 && args[tolIdx + 1]) {
    tolerance = parseInt(args[tolIdx + 1], 10) || 30;
  }
  const verbose = args.includes("--verbose") || true;

  const attractions = JSON.parse(readFileSync(WORK_PATH, "utf8"));
  console.log(`[营业时段交叉比对] 分析 ${attractions.length} 个景区 (容差阈值: ${tolerance}分钟)...`);

  let verifiedCount = 0;
  let crossChecked = 0;
  let matchedList = [];
  let discrepancies = [];

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

    const record = {
      name: a.name,
      city: a.city,
      level: a.level,
      official: `${a.opening_time}-${a.closing_time}`,
      amap: `${clockMatch[1]}:${clockMatch[2]}-${clockMatch[3]}:${clockMatch[4]}`,
      open_diff_min: openDiff,
      close_diff_min: closeDiff,
      amap_desc: desc
    };

    if (openDiff <= tolerance && closeDiff <= tolerance) {
      matchedList.push(record);
    } else {
      discrepancies.push(record);
    }
  }

  console.log(`\n=== 吻合时段清单 (偏差 ≤ ${tolerance}m: ${matchedList.length}条) ===`);
  for (const m of matchedList) {
    console.log(`  ✓ [吻合] ${m.name.padEnd(16)} (${m.city}) 官方[${m.official}] vs 高德[${m.amap}] (差: 开${m.open_diff_min}m, 闭${m.close_diff_min}m)`);
  }

  console.log(`\n=== 差异时段清单 (${discrepancies.length}条，需人工标定) ===`);
  for (const d of discrepancies) {
    console.log(`  ⚠ [差异] ${d.name.padEnd(16)} (${d.city}) 官方[${d.official}] vs 高德[${d.amap}] (差: 开${d.open_diff_min}m, 闭${d.close_diff_min}m)`);
  }

  mkdirSync(dirname(OUT_PATH), { recursive: true });
  writeFileSync(OUT_PATH, JSON.stringify(matchedList, null, 2), "utf8");
  console.log(`\n比对报告:`);
  console.log(`  - 已验证景区数: ${verifiedCount}`);
  console.log(`  - 具备高德时段的已验证景区: ${crossChecked}`);
  console.log(`  - 吻合时段数 (已写入 ${OUT_PATH}): ${matchedList.length}`);
  console.log(`  - 存在显著差异需人工审核: ${discrepancies.length}`);
}

run();
