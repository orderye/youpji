#!/usr/bin/env node
/**
 * 批量采纳吻合营业时段脚本（Phase 7 工作线 ②：营业时段数据源源提纯）
 *
 * 职责：
 *   读取 `youpji/data/verified/matched-hours.json` 中比对吻合的 19 条时段记录，
 *   在 `youpji/data/seed/attractions.generated.sql` 中将其对应的营业时段由
 *   `pending` 升级为 `verified` (confidence=0.85, source_type=official)，
 *   达成从候选池提纯到生产事实。
 *
 * 用法：
 *   node scripts/batch-adopt-matched-hours.mjs
 */
import { readFileSync, writeFileSync, existsSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const MATCHED_PATH = resolve(ROOT, "youpji", "data", "verified", "matched-hours.json");
const SQL_PATH = resolve(ROOT, "youpji", "data", "seed", "attractions.generated.sql");

function run() {
  if (!existsSync(MATCHED_PATH)) {
    console.error(`吻合清单文件不存在: ${MATCHED_PATH}`);
    process.exit(1);
  }
  if (!existsSync(SQL_PATH)) {
    console.error(`种子文件不存在: ${SQL_PATH}`);
    process.exit(1);
  }

  const matched = JSON.parse(readFileSync(MATCHED_PATH, "utf8"));
  console.log(`[批量采纳营业时段] 准备采纳 ${matched.length} 条吻合时段...`);

  const sql = readFileSync(SQL_PATH, "utf8");
  const lines = sql.split("\n");
  const matchedNames = new Set(matched.map((m) => m.name));
  const adoptedByName = new Map();

  const newLines = lines.map((line) => {
    for (const name of matchedNames) {
      if (
        line.includes(`WHERE name = '${name}')`) &&
        line.includes("'map'") &&
        line.includes("'pending'")
      ) {
        adoptedByName.set(name, (adoptedByName.get(name) || 0) + 1);
        return line
          .replace("'map'", "'official'")
          .replace("NULL, 'pending'", `'2026-09-29 00:00:00+08', 'verified'`)
          .replace(", 0.55)", ", 0.85)");
      }
    }
    return line;
  });

  for (const [name, count] of adoptedByName.entries()) {
    console.log(`  ✓ 成功采纳: ${name.padEnd(20)} (${count} 行时段已升级为 verified)`);
  }

  const totalAdopted = Array.from(adoptedByName.values()).reduce((a, b) => a + b, 0);
  writeFileSync(SQL_PATH, newLines.join("\n"), "utf8");
  console.log(`\n采纳完成！共更新 ${totalAdopted} 行营业时段记录为 verified。已写回 ${SQL_PATH}\n`);
}

run();
