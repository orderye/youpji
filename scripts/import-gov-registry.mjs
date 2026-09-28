/**
 * 贵州省人民政府「景点名录」导入器。
 *
 * 为什么换这条路：逐个景区找官网核验，命中率和 verified 比例都很低
 * （官网常把价目表做成图片，搜索通道随时限流）。
 * 省级政府门户有一份**结构化、带政府定价**的名录：
 *   https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/
 * 覆盖全省 532 家 A 级景区，含「是否收门票」与「门票价格（元）」字段，
 * 属 DESIGN §4.1 的一级来源（government）。
 *
 * 用法：
 *   node scripts/import-gov-registry.mjs                    # 拉取并解析
 *   node scripts/import-gov-registry.mjs --offline          # 用本地缓存解析
 *   node scripts/import-gov-registry.mjs --out youpji/data/attractions/gov-registry.json
 *
 * 票价解析规则（保守，不猜测）：
 *   - 名录标「否」或写「免费/无门票」→ 0
 *   - 「景区无门票，特许经营项目X元」→ 景区本体 0，备注保留特许项目价格
 *   - 其余取字段中**第一个数字**（对应成人/门票/旺季/单票等主档）
 *   - 原始字段全文写入 note，便于人工复核口径
 * 名录不含开放时间，因此这些记录一律 pending —— verified 要求票与时间双来源。
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REGISTRY_URL =
  "https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/";
const CACHE = resolve(__dirname, "..", ".gov-registry-cache.html");

const LEVEL_MAP = {
  AAAAA: "5A",
  AAAA: "4A",
  AAA: "3A",
  AA: "2A",
  A: "1A",
};

const CITY_PREFIX = /^(贵阳市|六盘水市|遵义市|安顺市|毕节市|铜仁市|黔东南州|黔南州|黔西南州)/;

/** 去掉市州前缀与「景区/旅游区」后缀，得到核心地名（用于去重与地理编码） */
function coreName(name) {
  return name
    .replace(CITY_PREFIX, "")
    .replace(
      /(国家级)?(旅游|风景|名胜)?(度假)?(景区|旅游区|风景区|风景名胜区|旅游景区|生态旅游区|文化旅游区)$/,
      ""
    )
    .replace(/[“”"']/g, "")
    .trim();
}

/** 按名称关键词归类（这是我方分类，不是外部事实） */
function inferCategory(name) {
  const n = name;
  if (/(溶洞|地下河|天坑|地缝)/.test(n)) return "自然景观/溶洞";
  if (/(苗寨|侗寨|村寨|民族|鼓楼|古村落)/.test(n)) return "民族村寨";
  if (/(古镇|古城|古村|书院|故居|祠堂|牌坊)/.test(n)) return "人文古镇";
  if (/(博物馆|纪念馆|陈列馆|展览馆|文化馆|艺术馆)/.test(n)) return "文化场馆/博物馆";
  if (/(草原|草场|花海|梯田|油菜花)/.test(n)) return "自然景观/花海草原";
  if (/(瀑布|大峡谷|峡谷|丹霞|喀斯特|峰林|溶洞群|山水|石林|天坑地缝)/.test(n))
    return "自然景观/山水";
  if (/(山|岭|雪山|避暑)/.test(n)) return "自然景观/山岳";
  if (/(湖|湿地|水库|水面|河)/.test(n)) return "自然景观/湖泊";
  if (/(森林|森林公园|植物园)/.test(n)) return "自然景观/森林";
  if (/(公园|广场)/.test(n)) return "自然景观/城市公园";
  if (/(温泉|度假|康养)/.test(n)) return "休闲度假";
  if (/(茶|酒|酒文化|酿)/.test(n)) return "人文古镇";
  return "自然景观/综合";
}

/** 规划参数默认值（我方参数，不需来源） */
function planDefaults(category) {
  const base = {
    "自然景观/溶洞": [55, 35, 75, 60, 180],
    民族村寨: [70, 60, 80, 75, 180],
    人文古镇: [65, 60, 75, 70, 150],
    "文化场馆/博物馆": [75, 70, 50, 60, 120],
    "自然景观/花海草原": [60, 40, 90, 70, 240],
    "自然景观/山水": [55, 35, 90, 70, 240],
    "自然景观/山岳": [55, 30, 85, 65, 300],
    "自然景观/湖泊": [65, 50, 75, 70, 150],
    "自然景观/森林": [60, 45, 70, 65, 180],
    "自然景观/城市公园": [75, 65, 60, 65, 120],
    休闲度假: [75, 60, 70, 75, 240],
    "自然景观/综合": [60, 45, 75, 65, 180],
  };
  const [fs, es, ps, cs, dur] = base[category] || base["自然景观/综合"];
  return { family_score: fs, elderly_score: es, photography_score: ps, couple_score: cs, recommended_duration_min: dur };
}

/** 票价解析：保守取主档数字，原文留痕 */
function parsePrice(paid, raw) {
  const s = (raw || "").trim();
  if (paid === "否" || /^免费$/.test(s)) return { price: 0, extra: "名录标注不收门票" };
  if (/景区无门票|景区本体免费|景区门票免费/.test(s)) {
    return { price: 0, extra: `景区本体免费，特许经营项目另收：${s}` };
  }
  if (!s || s === "无" || s === "/") return { price: null, extra: "名录未列票价" };
  const nums = s.match(/\d+(?:\.\d+)?/g);
  if (!nums) return { price: null, extra: `票价字段无法解析：${s}` };
  return { price: Math.round(Number(nums[0])), extra: `政府定价原文：${s}` };
}

function stripTags(html) {
  return html.replace(/<[^>]+>/g, "");
}

function parseRegistry(html) {
  const rows = html.match(/<tr[^>]*>[\s\S]*?<\/tr>/g) || [];
  const out = [];
  for (const r of rows) {
    const cells = [...r.matchAll(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/g)].map((m) =>
      stripTags(m[1]).replace(/\s+/g, " ").trim()
    );
    if (cells.length < 6) continue;
    if (cells[0] === "序号" || cells[2] === "旅游景区名称") continue;
    if (!/^\d+$/.test(cells[0])) continue;

    const [, city, rawName, rawLevel, phone, address, , paid, rawPrice, rawNote] = cells;
    const core = coreName(rawName);
    if (!core) continue;
    const category = inferCategory(core);
    const { price, extra } = parsePrice(paid, rawPrice);
    const pd = planDefaults(category);

    out.push({
      name: core,
      alias: null,
      city: city.replace(/[市州]$/, ""),
      district: null,
      longitude: null,
      latitude: null,
      coord_sys: null,
      coord_note: "待地理编码",
      category,
      level: LEVEL_MAP[rawLevel] || null,
      description: "",
      opening_time: null,
      closing_time: null,
      ticket_price: price,
      recommended_duration_min: pd.recommended_duration_min,
      best_season: "四季",
      difficulty: 2,
      family_score: pd.family_score,
      elderly_score: pd.elderly_score,
      photography_score: pd.photography_score,
      couple_score: pd.couple_score,
      source_url: REGISTRY_URL,
      source_type: "government",
      verification_status: "pending",
      confidence: 0.8,
      note: [extra, `名录原始名称：${rawName}`, `质量等级：${rawLevel}`, address ? `地址：${address}` : "", phone ? `咨询：${phone}` : "", rawNote || ""]
        .filter(Boolean)
        .join("；"),
    });
  }
  return out;
}

async function main() {
  const args = process.argv.slice(2);
  const offline = args.includes("--offline");
  const outIdx = args.indexOf("--out");
  const outPath =
    outIdx >= 0
      ? args[outIdx + 1]
      : resolve(__dirname, "..", "youpji", "data", "attractions", "gov-registry.json");

  let html;
  if (offline) {
    html = readFileSync(CACHE, "utf8");
    console.log("使用本地缓存解析");
  } else {
    const res = await fetch(REGISTRY_URL, {
      headers: { "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0 Safari/537.36" },
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) {
      console.error(`拉取失败 HTTP ${res.status}`);
      process.exit(1);
    }
    html = await res.text();
    if (!existsSync(dirname(CACHE))) mkdirSync(dirname(CACHE), { recursive: true });
    writeFileSync(CACHE, html, "utf8");
  }

  const recs = parseRegistry(html);
  const byCity = {};
  const withPrice = recs.filter((r) => r.ticket_price !== null).length;
  const free = recs.filter((r) => r.ticket_price === 0).length;
  const byLevel = {};
  for (const r of recs) {
    byCity[r.city] = (byCity[r.city] || 0) + 1;
    const k = r.level || "未定级";
    byLevel[k] = (byLevel[k] || 0) + 1;
  }

  console.log("\n贵州省人民政府景点名录导入");
  console.log("─".repeat(46));
  console.log(`来源          ${REGISTRY_URL}`);
  console.log(`解析景区数    ${recs.length}`);
  console.log(`有票价        ${withPrice}（免费 ${free}）`);
  console.log(`等级分布      ${JSON.stringify(byLevel)}`);
  console.log(`市州分布      ${JSON.stringify(byCity)}`);
  console.log(
    `\n注意：名录不含开放时间，这些记录一律 pending（verified 要求票与时间双来源）。`
  );
  console.log(`坐标待 scripts/geocode.mjs 补全（高德优先，回退 OSM）。\n`);

  writeFileSync(outPath, JSON.stringify(recs, null, 2), "utf8");
  console.log(`已写出 → ${outPath}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
