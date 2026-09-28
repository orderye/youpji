#!/usr/bin/env node
/**
 * 核心景区核验导入脚本（第6轮：数据核验升级流水线）
 *
 * 职责：
 *   读取 youpji/data/verified/ 中的权威核验数据，
 *   合并回 youpji/data/attractions/gov-registry.json 与 anshun-guiyang.json，
 *   将核验通过的景区标记为 verified，设置 confidence ≥ 0.85 与有效 source_url。
 *
 * 用法：
 *   node scripts/verify-core-attractions.mjs
 */
import { readFileSync, writeFileSync, existsSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const VERIFIED_PATH = resolve(ROOT, "youpji", "data", "verified", "core-20-anshun-guiyang.json");
const REGISTRY_PATH = resolve(ROOT, "youpji", "data", "attractions", "gov-registry.json");
const AG_PATH = resolve(ROOT, "youpji", "data", "attractions", "anshun-guiyang.json");

const CORE_SUFFIX =
  /(国家级)?(旅游|风景|名胜)?(度假)?(景区|旅游区|风景区|风景名胜区|旅游景区|生态旅游区|文化旅游区)$/;
const CITY_PREFIX =
  /^(贵阳市|六盘水市|遵义市|安顺市|毕节市|铜仁市|黔东南州|黔南州|黔西南州)/;

function coreName(name) {
  return String(name || "")
    .replace(CITY_PREFIX, "")
    .replace(/[（(][^）)]*[）)]/g, "")
    .replace(/[“”"']/g, "")
    .replace(CORE_SUFFIX, "")
    .trim();
}

function run() {
  if (!existsSync(VERIFIED_PATH)) {
    console.error(`核验数据文件不存在: ${VERIFIED_PATH}`);
    process.exit(1);
  }

  const verifiedList = JSON.parse(readFileSync(VERIFIED_PATH, "utf8"));
  console.log(`[1/3] 读取核验清单: ${verifiedList.length} 条核心景区`);

  const registry = JSON.parse(readFileSync(REGISTRY_PATH, "utf8"));
  let regUpdated = 0;

  for (const v of verifiedList) {
    const vCore = v.core_name || coreName(v.name);
    const target = registry.find((r) => {
      const rCore = coreName(r.name);
      return r.name === v.name || rCore === vCore || (r.alias && coreName(r.alias) === vCore);
    });

    if (target) {
      target.ticket_price = v.ticket_price;
      target.opening_time = v.opening_time;
      target.closing_time = v.closing_time;
      target.source_type = v.source_type;
      target.source_url = v.source_url;
      target.confidence = v.confidence;
      target.verification_status = "verified";
      target.note = [target.note, v.note].filter(Boolean).join(" ｜ ");
      regUpdated++;
      console.log(`  ✓ 名录匹配升级: ${target.name} (${target.city}) -> verified [¥${v.ticket_price}, ${v.opening_time}-${v.closing_time}]`);
    } else {
      console.log(`  - 名录未精确匹配: ${v.name} (核心词: ${vCore})`);
    }
  }

  writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2), "utf8");
  console.log(`[2/3] gov-registry.json 已更新: ${regUpdated} 条升级为 verified`);

  // 同步更新 anshun-guiyang.json
  const agList = JSON.parse(readFileSync(AG_PATH, "utf8"));
  let agUpdated = 0;

  for (const v of verifiedList) {
    const vCore = v.core_name || coreName(v.name);
    const target = agList.find((r) => {
      const rCore = coreName(r.name);
      return r.name === v.name || rCore === vCore || (r.alias && coreName(r.alias) === vCore);
    });

    if (target) {
      target.ticket_price = v.ticket_price;
      target.opening_time = v.opening_time;
      target.closing_time = v.closing_time;
      target.source_type = v.source_type;
      target.source_url = v.source_url;
      target.confidence = v.confidence;
      target.verification_status = "verified";
      target.note = [target.note, v.note].filter(Boolean).join(" ｜ ");
      agUpdated++;
      console.log(`  ✓ 批次匹配升级: ${target.name} -> verified`);
    }
  }

  writeFileSync(AG_PATH, JSON.stringify(agList, null, 2), "utf8");
  console.log(`[3/3] anshun-guiyang.json 已更新: ${agUpdated} 条升级为 verified`);
  console.log(`\n核验导入完成！总计升级 ${regUpdated} 条名录记录与 ${agUpdated} 条核验批次记录。`);
}

run();
