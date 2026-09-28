/**
 * 景区种子构建流水线：合并 → 校验 → 补坐标 → 复校验 → 只保留合规项 → 生成 SQL。
 *
 * 关卡（任一不通过即拒绝产出）：
 *   1. 事实校验    —— 复用 import-attractions.mjs 的规则（verified 必有 source_url 等）
 *   2. 坐标完整性  —— **无坐标不入库**。路线引擎的召回/就近/距离矩阵全依赖
 *                     PostGIS 经纬度；没坐标的景区进了库也进不了候选池，
 *                     反而会污染景点数量指标。
 *   3. 目标数量    —— 低于 100 时只告警，不阻断（铁律要求 100–300）
 *
 * 用法：
 *   node scripts/build-attraction-seed.mjs                  # 试跑，只出报告
 *   AMAP_KEY=xxx node scripts/build-attraction-seed.mjs      # 先补坐标再出 SQL
 *   AMAP_KEY=xxx node scripts/build-attraction-seed.mjs --out path.sql
 */
import { readFileSync, writeFileSync, readdirSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { spawnSync } from "child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_DIR = resolve(__dirname, "..", "youpji", "data", "attractions");
const SCRIPT_DIR = __dirname;

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

/**
 * 合并策略：政府名录做**价格权威**，逐个核验的批次做**增量信息**。
 *
 * 名录有官方票价但没有坐标/开放时间/分类评分；核验批次反之。
 * 按核心地名匹配后合并，两边信息都保留；核验批次里拿到官方双来源的
 * 记录会覆盖名录的 pending 状态（verified 要求票与时间同时有来源）。
 */
function loadAll(dir) {
  const files = readdirSync(dir)
    .filter((f) => f.endsWith(".json") && !f.startsWith("."))
    .sort();
  const registryFile = "gov-registry.json";
  const batches = [];
  let registry = [];

  for (const f of files) {
    const raw = JSON.parse(readFileSync(join(dir, f), "utf8"));
    const rows = Array.isArray(raw) ? raw : raw.attractions;
    if (!Array.isArray(rows)) continue;
    if (f === registryFile) {
      registry = rows;
    } else {
      batches.push({ file: f, rows });
    }
  }

  const byCore = new Map();
  for (const r of registry) {
    byCore.set(coreName(r.name), { ...r, _batch: registryFile });
  }

  let enriched = 0;
  const extra = [];
  for (const { file, rows } of batches) {
    let kept = 0;
    for (const r of rows) {
      const key = coreName(r.name);
      const base = byCore.get(key);
      if (!base) {
        extra.push({ ...r, _batch: file });
        kept++;
        continue;
      }
      // 合并：名录保留票价/等级/电话；核验批次补坐标/时间/分类/评分
      const mergedRow = {
        ...base,
        longitude: base.longitude ?? r.longitude,
        latitude: base.latitude ?? r.latitude,
        coord_sys: base.coord_sys ?? r.coord_sys,
        coord_note: r.coord_note || base.coord_note,
        opening_time: r.opening_time ?? base.opening_time,
        closing_time: r.closing_time ?? base.closing_time,
        category: r.category || base.category,
        description: r.description || base.description,
        recommended_duration_min:
          r.recommended_duration_min ?? base.recommended_duration_min,
        best_season: r.best_season || base.best_season,
        difficulty: r.difficulty ?? base.difficulty,
        family_score: r.family_score ?? base.family_score,
        elderly_score: r.elderly_score ?? base.elderly_score,
        photography_score: r.photography_score ?? base.photography_score,
        couple_score: r.couple_score ?? base.couple_score,
        // 核验批次若拿到官方双来源，其状态与来源优先
        verification_status:
          r.verification_status === "verified" ? "verified" : base.verification_status,
        source_url:
          r.verification_status === "verified" ? r.source_url : base.source_url,
        source_type:
          r.verification_status === "verified" ? r.source_type : base.source_type,
        confidence: Math.max(r.confidence ?? 0, base.confidence ?? 0),
        alias: r.alias || base.alias,
        district: r.district || base.district,
        note: [base.note, r.note].filter(Boolean).join(" ｜ "),
      };
      byCore.set(key, mergedRow);
      enriched++;
      kept++;
    }
    console.log(`  ${file}：${rows.length} 条，并入名录 ${kept} 条`);
  }

  const merged = [...byCore.values(), ...extra];
  console.log(
    `  ${registryFile}：${registry.length} 条（价格权威），其中 ${enriched} 条被核验数据补强`
  );
  console.log(`  名录未收录的核验记录：${extra.length} 条`);
  return { merged, fileCount: files.length };
}

function runValidator(file) {
  const r = spawnSync(
    process.execPath,
    [join(SCRIPT_DIR, "import-attractions.mjs"), file],
    { encoding: "utf8" }
  );
  return { ok: r.status === 0, output: r.stdout || "" };
}

function runGeocoder(file, outFile, limit) {
  const r = spawnSync(
    process.execPath,
    [
      join(SCRIPT_DIR, "geocode.mjs"),
      file,
      "--out",
      outFile,
      "--limit",
      String(limit),
    ],
    { encoding: "utf8", env: process.env }
  );
  return { ok: r.status === 0, output: r.stdout || "" };
}

// ---------------------------------------------------------------------------
// 坐标系归一化：WGS84 → GCJ-02
//
// 为什么必须做：DESIGN §4.2 要求全局统一 GCJ-02 且**禁止混用**。
// 高德 POI 接口返回 GCJ-02，OpenStreetMap/Nominatim 返回 WGS-84，
// 两者在中国境内相差约 300–600 米。混存会让：
//   1. PostGIS ST_DWithin 就近查询产生数百米误差；
//   2. 高德驾车矩阵收到错误坐标，路线时间整体偏移。
// 因此在入库前统一折算到 GCJ-02，并在 coord_note 保留原始坐标系与原值。
// ---------------------------------------------------------------------------
const GCJ_A = 6378245.0;
const GCJ_EE = 0.00669342162296594323;

function outOfChina(lng, lat) {
  return !(lng > 72.004 && lng < 137.8347 && lat > 0.8293 && lat < 55.8271);
}

function transformLat(x, y) {
  let ret =
    -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x));
  ret += ((20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0) / 3.0;
  ret += ((20.0 * Math.sin(y * Math.PI) + 40.0 * Math.sin((y / 3.0) * Math.PI)) * 2.0) / 3.0;
  ret += ((160.0 * Math.sin((y / 12.0) * Math.PI) + 320 * Math.sin((y * Math.PI) / 30.0)) * 2.0) / 3.0;
  return ret;
}

function transformLng(x, y) {
  let ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
  ret += ((20.0 * Math.sin(6.0 * x * Math.PI) + 20.0 * Math.sin(2.0 * x * Math.PI)) * 2.0) / 3.0;
  ret += ((20.0 * Math.sin(x * Math.PI) + 40.0 * Math.sin((x / 3.0) * Math.PI)) * 2.0) / 3.0;
  ret += ((150.0 * Math.sin((x / 12.0) * Math.PI) + 300.0 * Math.sin((x / 30.0) * Math.PI)) * 2.0) / 3.0;
  return ret;
}

function wgs84ToGcj02(lng, lat) {
  if (outOfChina(lng, lat)) return [lng, lat];
  let dLat = transformLat(lng - 105.0, lat - 35.0);
  let dLng = transformLng(lng - 105.0, lat - 35.0);
  const radLat = (lat / 180.0) * Math.PI;
  let magic = Math.sin(radLat);
  magic = 1 - GCJ_EE * magic * magic;
  const sqrtMagic = Math.sqrt(magic);
  dLat = (dLat * 180.0) / (((GCJ_A * (1 - GCJ_EE)) / (magic * sqrtMagic)) * Math.PI);
  dLng =
    (dLng * 180.0) / ((GCJ_A / sqrtMagic) * Math.cos(radLat) * Math.PI);
  return [lng + dLng, lat + dLat];
}

function haversineKm(aLng, aLat, bLng, bLat) {
  const R = 6371.0;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((aLat * Math.PI) / 180) *
      Math.cos((bLat * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// ---------------------------------------------------------------------------
// 阶段 2.5：营业时间抽取（高德 opentime2 文本 → attraction_hours 行）
//
// 为什么单独解析而不是直接写 attractions.opening_time：
//   1. 高德返回的是**自由文本**，形如
//      「9月1日至11月30日 07:00-18:30开放(16:00停止售票,17:00停止入园)；
//        12月1日至次年2月28日 07:30-18:00开放(...)」
//      同一景区有淡旺季差异（梵净山还有春节与东西线差异），
//      attractions 表的单一 opening_time/closing_time 根本表达不了，
//      只有 attraction_hours(weekday, season) 能装下。
//   2. 高德是**二级来源**，按铁律 4 与 migrations/0002 的 fact_status_check，
//      这些行必须落 pending + confidence<0.7，不允许标 verified。
//   3. 只**追加**候选行，不覆盖核验批次里已有的官方开放时间。
// ---------------------------------------------------------------------------

/** 「周一至周日」/「周一至周五」→ weekday 列表；无星期描述返回 null（=每天） */
const CN_WEEK = { 一: 1, 二: 2, 三: 3, 四: 4, 五: 5, 六: 6, 日: 0, 天: 0 };

function parseWeekdays(text) {
  if (!text) return null;
  // 覆盖全周一律折叠成 null（schema 约定 null = 每天），
  // 否则「周一至周日 09:00-17:00」会被摊成 7 行完全相同的记录。
  if (/周一至周日|周一至周六|周日至周六|周日至周一|全天|每天|每日/.test(text)) {
    return null;
  }
  const m = /周([一二三四五六日天])至周([一二三四五六日天])/.exec(text);
  if (m) {
    const from = CN_WEEK[m[1]];
    const to = CN_WEEK[m[2]];
    const out = [];
    for (let d = from; ; d = (d + 1) % 7) {
      out.push(d);
      if (d === to) break;
      if (out.length > 7) break;
    }
    return out.length >= 7 ? null : out;
  }
  const single = /周([一二三四五六日天])(?!至)/.exec(text);
  if (single) return [CN_WEEK[single[1]]];
  return null;
}

/** 抽出季节/日期区间描述，如「9月1日至11月30日」「1/1-12/31」「节假日:春节」 */
function parseSeason(text) {
  if (!text) return null;
  // 高德会在跨年区间写「12月1日至次年2月28日」，中间插了「次年」会打断正则
  const nextYear = /(\d{1,2})月(\d{1,2})日至次年(\d{1,2})月(\d{1,2})日/.exec(text);
  if (nextYear) {
    return `${nextYear[1]}月${nextYear[2]}日-${nextYear[3]}月${nextYear[4]}日`.slice(0, 32);
  }
  const full = /(\d{1,2})月(\d{1,2})日至(\d{1,2})月(\d{1,2})日/.exec(text);
  if (full) {
    return `${full[1]}月${full[2]}日-${full[3]}月${full[4]}日`.slice(0, 32);
  }
  const slash = /(\d{1,2})\/(\d{1,2})\s*[-–~至]\s*(\d{1,2})\/(\d{1,2})/.exec(text);
  if (slash) {
    return `${slash[1]}/${slash[2]}-${slash[3]}/${slash[4]}`.slice(0, 32);
  }
  const months = /(\d{1,2})月(?:(\d{1,2})日)?至(\d{1,2})月(?:(\d{1,2})日)?/.exec(text);
  if (months) {
    return `${months[1]}月-${months[3]}月`.slice(0, 32);
  }
  const holiday = /(春节|国庆节?|元旦|中秋|端午节?|清明)/.exec(text);
  if (holiday) return `节假日:${holiday[1]}`.slice(0, 32);
  return null; // 无日期区间 → 全年
}

/** 抽出本段的开门/关门时间；拿不到返回 null */
function parseClock(text) {
  // 优先取「开放」前最近的一段时间，其次取本段第一个时间区间
  const withOpen = /开放/.test(text);
  const re = /(\d{1,2}):(\d{2})\s*[-–~]\s*(\d{1,2}):(\d{2})/g;
  const all = [...text.matchAll(re)];
  if (all.length === 0) return null;
  const pick = withOpen ? all[0] : all[0];
  const [, h1, m1, h2, m2] = pick;
  const open = `${h1.padStart(2, "0")}:${m1}`;
  const close = `${h2.padStart(2, "0")}:${m2}`;
  // 24:00 不是合法 TIME，PG 会拒绝；归一到 23:59 并在 note 说明
  const closeSafe = close === "24:00" ? "23:59" : close;
  return { open, close: closeSafe, midnight: close === "24:00" };
}

/** 把「停止售票/最晚入园」等附加约束从正文里摘出来做 note */
function extractNote(seg) {
  const notes = [];
  const KW = "停止售票|停止入园|最晚进入|最晚售票|最晚入园|停止检票";
  // 先把开门/关门区间剥掉，否则「07:30-18:00 最晚进入17:00」里的 18:00
  // 会被误当成「18:00最晚进入」——那是闭园时间，不是最晚入园时间。
  const rest = seg.replace(/\d{1,2}:\d{2}\s*[-–~]\s*\d{1,2}:\d{2}/g, " ");
  // 时间既可能在关键字前（「16:00停止售票」），
  // 也在关键字后（「最晚进入17:00」），两种写法都要认
  for (const m of rest.matchAll(new RegExp(`(\\d{1,2}:\\d{2})\\s*(${KW})`, "g"))) {
    notes.push(`${m[1]}${m[2]}`);
  }
  for (const m of rest.matchAll(new RegExp(`(${KW})\\s*(\\d{1,2}:\\d{2})`, "g"))) {
    notes.push(`${m[2]}${m[1]}`);
  }
  if (/全天/.test(seg)) notes.push("全天开放");
  return notes.length ? [...new Set(notes)].join("；") : null;
}

/**
 * 解析单条景区的 opentime2 文本。
 * 返回 [{ weekday, season, open_time, close_time, note, raw }]，无法解析时返回 []。
 */
function parseHoursDesc(desc) {
  if (!desc || typeof desc !== "string") return [];
  const out = [];
  // 高德用全角分号分隔时段；个别条目用中文分号/换行混排
  const segments = desc
    .split(/[；;\n]/)
    .map((s) => s.trim())
    .filter((s) => /\d{1,2}:\d{2}/.test(s));

  for (const seg of segments) {
    const clock = parseClock(seg);
    if (!clock) continue;
    const weekdays = parseWeekdays(seg);
    const season = parseSeason(seg);
    const note = extractNote(seg);
    const base = {
      open_time: clock.open,
      close_time: clock.close,
      season,
      note: [note, clock.midnight ? "原文 24:00 已归一为 23:59" : null]
        .filter(Boolean)
        .join("；") || null,
      raw: seg,
    };
    if (weekdays === null) {
      out.push({ ...base, weekday: null });
    } else {
      for (const wd of weekdays) out.push({ ...base, weekday: wd });
    }
  }
  // 去重（同一 weekday+season 出现多次时保留首条）
  const seen = new Set();
  return out.filter((h) => {
    const k = `${h.weekday}|${h.season}|${h.open_time}|${h.close_time}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

/**
 * 阶段 2.5 入口：把 amap_biz.hours_desc 摊平成 attraction_hours 候选行。
 * 高德为二级来源 → source_type='map'、verification_status='pending'、confidence=0.55
 * （故意低于 fact_status_check 的 0.7 阈值，确保数据库侧也不会被升级为 verified）。
 */
function extractHours(rows) {
  const hoursRows = [];
  let parsed = 0;
  let skipped = 0;
  for (const a of rows) {
    const biz = a.amap_biz;
    if (!biz || !biz.hours_desc) continue;
    const segs = parseHoursDesc(biz.hours_desc);
    if (segs.length === 0) {
      skipped++;
      continue;
    }
    parsed++;
    a.hours_source = "amap";
    for (const h of segs) {
      hoursRows.push({
        name: a.name,
        weekday: h.weekday,
        season: h.season,
        open_time: h.open_time,
        close_time: h.close_time,
        note: h.note,
        raw: h.raw,
        source_type: "map",
        source_url: biz.source_url,
        source_time: a.source_time || null,
        last_verified: null,
        verification_status: "pending",
        confidence: 0.55,
      });
    }
  }
  return { hoursRows, parsed, skipped };
}

/** 推断记录声明的坐标系：显式 coord_sys 优先，其次从 coord_note 文本推断 */
function declaredCoordSys(a) {
  const explicit = (a.coord_sys || "").toLowerCase().replace(/[-_\s]/g, "");
  if (explicit) return explicit;
  const note = (a.coord_note || "").toLowerCase();
  if (/gcj[-_ ]?0?2/.test(note)) return "gcj02";
  if (/wgs[-_ ]?84/.test(note) || /nominatim|openstreetmap|\bosm\b/.test(note)) {
    return "wgs84";
  }
  return "";
}

/**
 * 把所有非 GCJ-02 的坐标折算到 GCJ-02。
 * 返回 { converted, unknown }：unknown 是**坐标系无法判定**的记录，
 * 这类记录一律不折算也不入库（DESIGN §4.2 禁止混用，宁缺毋滥）。
 */
function normalizeCoords(rows) {
  let converted = 0;
  const unknown = [];
  for (const a of rows) {
    if (a.longitude == null || a.latitude == null) continue;
    const sys = declaredCoordSys(a);
    if (sys === "gcj02" || sys === "gcj-02") {
      a.coord_sys = "gcj02";
      continue;
    }
    if (!sys) {
      // 无法判定来源坐标系 —— 标出来并在后续坐标关卡剔除
      a.coord_sys = "unknown";
      unknown.push(a);
      continue;
    }
    // 明确为 WGS-84 等其他坐标系 → 折算
    const [lng, lat] = wgs84ToGcj02(a.longitude, a.latitude);
    const shift = haversineKm(a.longitude, a.latitude, lng, lat);
    a.coord_note =
      `${a.coord_note || ""}｜入库前由 ${sys.toUpperCase()} 折算为 GCJ-02` +
      `（原值 ${a.longitude},${a.latitude} → ${lng.toFixed(6)},${lat.toFixed(6)}，偏移 ${shift.toFixed(3)} km）`;
    a.longitude = Number(lng.toFixed(6));
    a.latitude = Number(lat.toFixed(6));
    a.coord_sys = "gcj02";
    converted++;
  }
  return { converted, unknown };
}

// ---------------------------------------------------------------------------
// 阶段 4：数量关卡
//
// 铁律原文是「第一批 100–300 个高价值景区」，那是**上线首批口径**。
// 数据管线要维护的是**全省可用池**，两者不是一回事：先用池子把数据补全、
// 把待核验项攒够，再由 Admin 按高价值挑选进入首批。
// 因此上限默认放开（999），下限仍是硬告警。
// 真要出「首批」时用 `MAX_ATTRACTIONS=300` 复跑即可。
// ---------------------------------------------------------------------------
const MIN_ATTRACTIONS = 100;
const MAX_ATTRACTIONS = Number(process.env.MAX_ATTRACTIONS || 999);
const LEVEL_RANK = { "5A": 0, "4A": 1, "3A": 2, "2A": 3, "1A": 4 };

function completeness(a) {
  return (
    (a.ticket_price != null ? 1 : 0) +
    (a.opening_time != null ? 1 : 0) +
    (a.amap_biz?.rating != null ? 1 : 0) +
    (a.recommended_duration_min != null ? 1 : 0) +
    (a.category ? 1 : 0)
  );
}

function applyQuantityGate(usable) {
  if (usable.length <= MAX_ATTRACTIONS) return { kept: usable, dropped: [], gate: "未触发" };

  const ranked = [...usable].sort((a, b) => {
    const la = LEVEL_RANK[a.level] ?? 9;
    const lb = LEVEL_RANK[b.level] ?? 9;
    if (la !== lb) return la - lb;
    const ra = a.amap_biz?.rating ?? -1;
    const rb = b.amap_biz?.rating ?? -1;
    if (ra !== rb) return rb - ra;
    const ca = completeness(a);
    const cb = completeness(b);
    if (ca !== cb) return cb - ca;
    return String(a.name).localeCompare(String(b.name), "zh");
  });

  const kept = ranked.slice(0, MAX_ATTRACTIONS);
  const keptSet = new Set(kept.map((a) => a));
  const dropped = usable.filter((a) => !keptSet.has(a));
  return { kept, dropped, gate: `已按高价值排序截断至 ${MAX_ATTRACTIONS}` };
}

function main() {
  const args = process.argv.slice(2);
  const outIdx = args.indexOf("--out");
  const outPath =
    outIdx >= 0 ? args[outIdx + 1] : "youpji/data/seed/attractions.generated.sql";
  const dryRun = !args.includes("--emit");

  console.log("\n景区种子构建流水线");
  console.log("═".repeat(46));

  const { merged, fileCount } = loadAll(DATA_DIR);
  if (merged.length === 0) {
    console.log("\ndata/attractions 下没有可合并的 JSON，结束。\n");
    return;
  }
  console.log(`\n合并完成：${fileCount} 个批次，共 ${merged.length} 条`);

  // 阶段 1：补坐标
  const workFile = join(DATA_DIR, ".work.json");
  writeFileSync(workFile, JSON.stringify(merged, null, 2), "utf8");

  // Nominatim 使用条款限制约 1 请求/秒，全量 500+ 条需半小时以上。
  // 因此按 **5A→4A→3A** 优先级分批补全：顶级景区先拿到坐标，
  // 剩下的留给后续增量运行（已补全的会写回源文件，不会重复消耗配额）。
  const LIMIT = Number(process.env.GEOCODE_LIMIT || 120);
  const RANK = { "5A": 0, "4A": 1, "3A": 2, "2A": 3, "1A": 4 };
  const missing = merged.filter((a) => a.longitude == null);
  missing.sort(
    (a, b) => (RANK[a.level] ?? 9) - (RANK[b.level] ?? 9) || (b.confidence ?? 0) - (a.confidence ?? 0)
  );
  const missingBefore = missing.length;
  if (missingBefore > 0) {
    const batch = missing.slice(0, LIMIT);
    console.log(
      `\n[阶段 1/5] 坐标补全 —— 缺失 ${missingBefore} 条，本轮处理 ${batch.length} 条` +
        `（按 5A→4A→3A 优先；剩余 ${missingBefore - batch.length} 条留待后续增量运行）`
    );
    merged.length = 0;
    merged.push(...missing.filter((a) => !batch.includes(a)));
    merged.push(...batch);
    // geocode 内部自带策略：有 AMAP_KEY 走高德（GCJ-02），否则回退
    // OpenStreetMap Nominatim（WGS-84），二者都会标注 coord_sys 供归一化判断。
    const g = runGeocoder(workFile, workFile, LIMIT);
    console.log(g.output.split("\n").map((l) => "  " + l).join("\n"));
  } else {
    console.log("\n[阶段 1/5] 坐标补全 —— 全部已有坐标");
  }

  const rows = JSON.parse(readFileSync(workFile, "utf8"));

  // 把补全到的坐标写回各自批次源文件：让坐标成为可审计、可入 git 的数据，
  // 而不是每次重跑都重新查询（结果不会随临时文件一起消失）。
  if (missingBefore > 0) {
    const byBatch = new Map();
    for (const a of rows) {
      if (!a._batch) continue;
      if (!byBatch.has(a._batch)) byBatch.set(a._batch, []);
      byBatch.get(a._batch).push(a);
    }
    for (const [file, list] of byBatch) {
      writeFileSync(
        join(DATA_DIR, file),
        JSON.stringify(list.map(({ _batch, ...rest }) => rest), null, 2),
        "utf8"
      );
    }
    console.log(`  坐标已写回 ${byBatch.size} 个批次源文件`);
  }

  // 阶段 1.5：坐标系归一化（WGS-84 → GCJ-02），DESIGN §4.2 要求全局统一
  console.log("\n[阶段 1.5/5] 坐标系归一化");
  const mixed = rows.filter(
    (a) => a.coord_sys && !/^gcj-?0?2$/i.test(a.coord_sys) && a.longitude != null
  );
  if (mixed.length > 0) {
    console.log(
      `  检出 ${mixed.length} 条非 GCJ-02 坐标（${[
        ...new Set(mixed.map((a) => a.coord_sys)),
      ].join(", ")}），正在折算…`
    );
  }
  const { converted, unknown } = normalizeCoords(rows);
  console.log(
    converted > 0
      ? `  已折算 ${converted} 条为 GCJ-02（原值与偏移量记录在 coord_note）`
      : "  无需折算，全部已是 GCJ-02"
  );
  if (unknown.length > 0) {
    console.log(
      `  ⚠ ${unknown.length} 条坐标系无法判定，将被坐标关卡剔除：${unknown
        .map((a) => a.name)
        .join("、")}`
    );
  }
  writeFileSync(workFile, JSON.stringify(rows, null, 2), "utf8");

  // 阶段 2：事实校验
  console.log("\n[阶段 2/5] 事实校验");
  const v = runValidator(workFile);
  if (!v.ok) {
    console.log("  校验未通过，列出问题：");
    const errLine = v.output.indexOf("错误");
    console.log(
      (errLine >= 0 ? v.output.slice(errLine) : v.output)
        .split("\n")
        .slice(0, 20)
        .map((l) => "  " + l)
        .join("\n")
    );
  } else {
    const m = v.output.match(/verified\s+(\d+)/);
    const p = v.output.match(/pending\s+(\d+)/);
    const u = v.output.match(/unverified\s+(\d+)/);
    console.log(
      `  通过 · verified=${m?.[1] ?? 0} pending=${p?.[1] ?? 0} unverified=${u?.[1] ?? 0}`
    );
  }

  // 阶段 2.5：营业时间抽取（高德 opentime2 → attraction_hours 候选行）
  console.log("\n[阶段 2.5/5] 营业时间抽取");
  const { hoursRows, parsed, skipped } = extractHours(rows);
  const hoursFile = join(DATA_DIR, ".hours.json");
  if (hoursRows.length > 0) {
    writeFileSync(hoursFile, JSON.stringify(hoursRows, null, 2), "utf8");
    const seasons = new Set(hoursRows.map((h) => h.season).filter(Boolean));
    console.log(
      `  从 ${parsed} 个景区解析出 ${hoursRows.length} 条时段（${skipped} 条文本无法解析）`
    );
    console.log(`  季节区间：${[...seasons].slice(0, 8).join("、") || "无（全年）"}`);
    console.log(
      `  一律 source_type=map / verification_status=pending / confidence=0.55` +
        `（二级来源，不覆盖官方开放时间）`
    );
  } else {
    writeFileSync(hoursFile, "[]", "utf8");
    console.log(`  无可用营业时间文本（${skipped} 条尝试解析但失败）`);
  }

  // 阶段 3：坐标完整性关卡
  console.log("\n[阶段 3/5] 坐标完整性关卡");
  const withCoord = rows.filter(
    (a) => a.longitude != null && a.latitude != null && a.coord_sys === "gcj02"
  );
  const rejected = rows.filter(
    (a) => a.longitude == null || a.latitude == null || a.coord_sys !== "gcj02"
  );
  console.log(`  可入库      ${withCoord.length}`);
  console.log(`  无坐标剔除  ${rejected.length}`);
  if (rejected.length > 0) {
    const sample = rejected.slice(0, 8).map((a) => `${a.city ?? ""}${a.name}`);
    console.log(`  剔除样例    ${sample.join("、")}${rejected.length > 8 ? " …" : ""}`);
  }

  // 阶段 4：数量关卡（全省可用池；首批口径用 MAX_ATTRACTIONS=300 复跑）
  console.log("\n[阶段 4/5] 数量关卡");
  const { kept: usable, dropped, gate } = applyQuantityGate(withCoord);
  console.log(`  下限告警    ${MIN_ATTRACTIONS} 条`);
  console.log(`  池上限      ${MAX_ATTRACTIONS} 条（env MAX_ATTRACTIONS 可调）`);
  console.log(`  关卡        ${gate}`);
  if (dropped.length > 0) {
    const byLevel = {};
    for (const a of dropped) {
      const k = a.level || "未定级";
      byLevel[k] = (byLevel[k] || 0) + 1;
    }
    const keptLevel = {};
    for (const a of usable) {
      const k = a.level || "未定级";
      keptLevel[k] = (keptLevel[k] || 0) + 1;
    }
    console.log(`  保留分布    ${Object.entries(keptLevel).map(([k, v]) => `${k}:${v}`).join(" ")}`);
    console.log(
      `  截断掉      ${dropped.length} 条（${Object.entries(byLevel)
        .map(([k, v]) => `${k}:${v}`)
        .join(" ")}）`
    );
    console.log(`  截断样例    ${dropped.slice(0, 8).map((a) => a.name).join("、")} …`);
  }

  console.log("\n" + "─".repeat(46));
  console.log(`全省可用池    ${usable.length} 条`);
  console.log(
    `首批口径      ${MIN_ATTRACTIONS}–300 条 → MAX_ATTRACTIONS=300 npm run attractions:build`
  );
  if (usable.length < MIN_ATTRACTIONS) {
    console.log(
      `⚠  距铁律下限还差 ${MIN_ATTRACTIONS - usable.length} 条。` +
        (process.env.AMAP_KEY
          ? "已提供 AMAP_KEY，缺口来自事实核验而非坐标。"
          : "配置 AMAP_KEY 后可自动补全坐标，缺口会显著收窄。")
    );
  }
  if (usable.length === 0) {
    console.log("\n没有任何带坐标的记录，本次不产出 SQL。\n");
    return;
  }

  if (dryRun) {
    console.log("\n试跑模式：未写文件。加 --emit 生成 SQL。\n");
    return;
  }

  // 只把通过坐标关卡的行交给 SQL 生成器，避免把关卡结果又放回去
  const finalFile = join(DATA_DIR, ".final.json");
  writeFileSync(finalFile, JSON.stringify(usable, null, 2), "utf8");

  // 营业时间同样只保留通过坐标关卡的景区，避免 hours 指向未入库的记录
  const usableNames = new Set(usable.map((a) => a.name));
  const usableHours = hoursRows.filter((h) => usableNames.has(h.name));
  writeFileSync(join(DATA_DIR, ".hours.final.json"), JSON.stringify(usableHours, null, 2), "utf8");

  const r = spawnSync(
    process.execPath,
    [
      join(SCRIPT_DIR, "import-attractions.mjs"),
      finalFile,
      "--out",
      outPath,
      "--hours",
      join(DATA_DIR, ".hours.final.json"),
    ],
    { encoding: "utf8" }
  );
  if (r.status !== 0) {
    console.log(r.stdout || r.stderr);
    console.log("生成 SQL 失败：残留行未通过事实校验。\n");
    return;
  }
  console.log(`\n已生成 → ${outPath}`);
  console.log(
    `  景区 ${usable.length} 条` +
      (usableHours.length > 0 ? ` · 营业时段 ${usableHours.length} 条（pending）` : "")
  );
  console.log("");
}

main();
