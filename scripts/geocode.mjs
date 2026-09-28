/**
 * 景区坐标解析器：用高德 POI 搜索按名称+城市取点，回填经纬度。
 *
 * 为什么必须走地图 API 而不是网页检索：
 * - 路线引擎的召回/就近/距离矩阵全依赖 PostGIS 经纬度，没坐标的景区对规划毫无用处；
 * - 实测网页检索几乎拿不到经纬度数值（官网页面普遍只给文字距离）；
 * - 高德返回的正是 **GCJ-02**，与 DESIGN §4.2「全局统一 GCJ-02」一致，可直接入库；
 * - 高德属二级来源（source_type = map），坐标本身可溯源到具体 POI id。
 *
 * 用法：
 *   AMAP_KEY=xxx node scripts/geocode.mjs data/attractions.json --out data/attractions.geo.json
 *   node scripts/geocode.mjs data/attractions.json          # 只看会命中多少，不写文件
 *
 * 只填补 coordinate 为 null 的记录；已有坐标的不会被覆盖。
 * 高德 POI 搜索配额有限，脚本带本地缓存与限速，重复运行不会重复消耗配额。
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { dirname, join } from "path";

const CACHE_PATH = join(".geocode-cache.json");
// 缓存版本：候选筛选规则变更时必须递增，否则会复用旧规则下的错误取点。
// v1→v2：高德改为「按类目+名称+省份择优选取」，且不再用 citylimit 硬限制。
const CACHE_VERSION = "v2";
const QPS_INTERVAL_MS = 400; // 高德 POI 搜索按 QPS 限速，取保守值
const NOMINATIM_INTERVAL_MS = 1100; // Nominatim 使用条款要求 ≤1 次/秒

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function loadCache() {
  if (!existsSync(CACHE_PATH)) return {};
  try {
    return JSON.parse(readFileSync(CACHE_PATH, "utf8"));
  } catch {
    return {};
  }
}

function saveCache(cache) {
  if (!existsSync(dirname(CACHE_PATH))) mkdirSync(dirname(CACHE_PATH), { recursive: true });
  writeFileSync(CACHE_PATH, JSON.stringify(cache, null, 2), "utf8");
}

/**
 * 高德对部分字段返回空数组 `[]`（JSON 里是数组），对景区普遍返回 cost="0"。
 * 统一收敛成 null，避免把「0 元」当成真实人均写进库里。
 */
function toNumOrNull(v, { zeroAsMissing = false } = {}) {
  if (v === null || v === undefined || v === "" || Array.isArray(v)) return null;
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0) return null;
  if (zeroAsMissing && n === 0) return null;
  return n;
}

/** 高德 POIs[].location = "lng,lat"（GCJ-02） */

/**
 * 明确不是景区本体的类目（typecode 前两位）。
 * 01 汽车服务 · 05 餐饮 · 06 购物 · 07 生活服务 · 09 医疗 · 10 住宿
 * 12 商务住宅 · 15 交通设施 · 17 公司企业 · 18 门址/出入口
 */
const POI_BLOCK_TYPE = new Set(["01", "05", "06", "07", "09", "10", "12", "15", "17", "18"]);

/** 名称里带这些词的几乎必然不是景区本体 */
const POI_BLOCK_NAME =
  /(停车场|停车位|服务区|收费站|公交站|地铁站|火车站|高铁站|汽车站|机场|码头|加油站|游客中心|游客服务|售票处|售票窗口|检票口|出入口|出入口|办公楼|产业园|工业园|小区|住宅|酒店|宾馆|民宿|餐厅|饭店|小吃|快餐|超市|商场|购物中心|派出所|银行|医院|学校)/;

/**
 * 在候选里择优，而不是无脑取 pois[0]。
 *
 * 为什么必须这样：实测 `keywords=黄果树风景区&city=贵阳&citylimit=true`
 * 返回的前 5 条**全是**「黄果树广场停车场(入口)」「黄果树大厦」
 * 「黄果树瀑韵天城」这类住宅与停车场，真正的景区根本不在前 5 名里。
 * 旧实现直接取 pois[0]，于是把停车场坐标写成了景区坐标。
 */
function pickCandidate(pois, keyword, city) {
  const core = coreName(keyword);
  const cityShort = city ? String(city).replace(/市$/, "") : "";
  const pool = [];

  for (const p of pois) {
    if (!p.location || !/^[\d.]+,[\d.]+$/.test(p.location)) continue;
    const [lng, lat] = p.location.split(",").map(Number);
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) continue;

    const typecode = String(p.typecode || "");
    const name = String(p.name || "");
    if (POI_BLOCK_TYPE.has(typecode.slice(0, 2))) continue;
    if (POI_BLOCK_NAME.test(name)) continue;

    let score = 0;
    if (typecode.startsWith("110")) score += 50; // 风景名胜 / 公共设施
    if (name.includes(core)) score += 40;
    else if (core.includes(name) && name.length >= 2) score += 30;
    else if (core.length >= 2 && name.includes(core.slice(0, 2))) score += 10;
    if (cityShort && String(p.cityname || "").includes(cityShort)) score += 10;

    pool.push({ p, lng, lat, score, typecode });
  }
  if (pool.length === 0) return null;
  pool.sort((a, b) => b.score - a.score);
  return pool[0];
}

/**
 * 在候选里择优，但放宽「必须落在贵州」这一条。
 * 仅当严格模式下候选全被省份过滤掉时才启用，用于覆盖少数缺 adcode 的 POI。
 */
function pickCandidateRelaxed(pois, keyword, city) {
  const gz = { ...queryAmap._lastRes };
  return pickCandidate(
    (gz.pois || []).filter((p) => !String(p.adcode || "").startsWith("52")),
    keyword,
    city
  );
}

async function queryAmap(key, keyword, city) {
  const url =
    "https://restapi.amap.com/v3/place/text" +
    `?key=${encodeURIComponent(key)}` +
    `&keywords=${encodeURIComponent(keyword)}` +
    // 注意：这里**只用 city 加权、不加 citylimit**。
    // citylimit=true 会把不属于该市的真景区挤出结果集
    // （黄果树在安顺镇宁，用 city=贵阳 检索时结果里全是贵阳的停车场与住宅）。
    (city ? `&city=${encodeURIComponent(city)}` : "") +
    "&extensions=all&offset=15&page=1";

  const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!res.ok) return { ok: false, reason: `HTTP ${res.status}` };
  const data = await res.json();
  if (data.status !== "1") {
    return { ok: false, reason: `${data.info || "unknown"} (${data.infocode || "-"})` };
  }
  const pois = data.pois || [];
  if (pois.length === 0) return { ok: false, reason: "无匹配 POI" };

  queryAmap._lastRes = data;

  // 硬约束：必须落在贵州省（adcode 52xxxx）
  const gz = pois.filter((p) => String(p.adcode || "").startsWith("52"));
  let best = pickCandidate(gz, keyword, city);
  if (!best) best = pickCandidateRelaxed(pois, keyword, city);
  if (!best) return { ok: false, reason: `${pois.length} 条候选均被类目/名称过滤` };

  const { p, lng, lat } = best;
  const biz = p.biz_ext || {};
  return {
    ok: true,
    source: "amap",
    coord_sys: "gcj02",
    longitude: Number(lng.toFixed(6)),
    latitude: Number(lat.toFixed(6)),
    amap_id: p.id,
    matched_name: p.name,
    amap_typecode: p.typecode || null,
    adcode: p.adcode || null,
    // 事实类附加信息：高德属二级来源，入库一律 pending，不因坐标而提升验证等级
    hours_desc: biz.opentime2 || null,
    rating: toNumOrNull(biz.rating),
    // 高德对景区普遍返回 cost="0"（景区本身不按人均收费），视为未提供
    avg_cost: toNumOrNull(biz.cost, { zeroAsMissing: true }),
    tel: p.tel && p.tel !== "[]" ? p.tel : null,
  };
}

/** 去掉「景区/旅游区/风景名胜区/度假区」等后缀，只留核心地名用于检索 */
function coreName(name) {
  return String(name)
    .replace(/（[^）]*）/g, "")
    .replace(
      /(国家级)?(旅游|风景|名胜)?(度假)?(区|景区|风景区|风景名胜区|旅游区|公园|博物馆)$/,
      ""
    )
    .trim();
}

/** 明显不是景区本体的地物：高速服务区、收费站、车站等 */
const NON_ATTRACTION = /(高速|服务区|收费站|立交|车站|机场|码头|加油站)/;

const TOURISM_CLASSES = new Set([
  "tourism",
  "historic",
  "leisure",
  "natural",
  "amenity",
  "place",
]);

/**
 * OpenStreetMap Nominatim 回退源（**WGS-84**，无需 Key）。
 *
 * 实测：景区官网页面普遍不给经纬度，Nominatim 能在不少景区上取到点。
 * 但它**极易把同名地物当成景区**，实测踩到过：
 *   「黄果树」→ 黄果树, 沪昆高速, 镇宁（是高速服务区，不是瀑布景区）
 *   「龙宫」  → 龙宫, 沪昆高速, 镇宁（是服务区，不是龙宫溶洞景区）
 *   「黄果树风景区」→ 山东省临沂市皇山蔬菜水果批发市场（跨省错配）
 * 因此这里做三重过滤：行政区归属、类目、地物类型，任一不满足即丢弃该候选。
 * 返回 WGS-84，由 build-attraction-seed.mjs 折算为 GCJ-02 后再入库。
 */
let nominatimBlockedUntil = 0;

async function queryNominatim(keyword, city) {
  // 被限流时先退避，避免把 429 当成「无结果」写进缓存
  const waitMs = nominatimBlockedUntil - Date.now();
  if (waitMs > 0) {
    await sleep(Math.min(waitMs, 60000));
  }
  const tried = [];
  for (const q of [keyword, `${keyword} ${city}`, coreName(keyword)]) {
    const url =
      "https://nominatim.openstreetmap.org/search" +
      `?q=${encodeURIComponent(q)}` +
      "&format=jsonv2&limit=8&countrycodes=cn&addressdetails=0";

    let data;
    try {
      const res = await fetch(url, {
        headers: { "User-Agent": "youpji-data-collector/0.1 (tourism seed import)" },
        signal: AbortSignal.timeout(12000),
      });
      if (res.status === 429) {
        // Nominatim 限流：整体封顶冷却，本次不再继续试其他关键词
        nominatimBlockedUntil = Date.now() + 10 * 60 * 1000;
        return {
          ok: false,
          reason: "Nominatim 限流(429)，已冷却 10 分钟；批量补坐标请配置 AMAP_KEY",
        };
      }
      if (!res.ok) {
        tried.push(`${q} → HTTP ${res.status}`);
        continue;
      }
      data = await res.json();
    } catch (e) {
      tried.push(`${q} → ${e.message}`);
      continue;
    }
    if (!Array.isArray(data) || data.length === 0) {
      tried.push(`${q} → 无结果`);
      continue;
    }

    for (const p of data) {
      const lng = Number(p.lon);
      const lat = Number(p.lat);
      const display = p.display_name || "";
      const lngLatOk = Number.isFinite(lng) && Number.isFinite(lat);
      if (!lngLatOk) continue;
      // ① 行政区归属：必须落在贵州，且尽量命中目标城市
      if (!display.includes("贵州")) {
        tried.push(`${q} → 非贵州(${display.slice(0, 30)})`);
        continue;
      }
      if (city && !display.includes(city)) {
        tried.push(`${q} → 非${city}(${display.slice(0, 30)})`);
        continue;
      }
      // ② 地物类型：高速服务区、收费站之类一律拒绝
      if (NON_ATTRACTION.test(display)) {
        tried.push(`${q} → 非景区地物(${display.slice(0, 40)})`);
        continue;
      }
      // ③ 类目：旅游/历史/休闲/自然/场馆
      if (p.class && !TOURISM_CLASSES.has(p.class)) {
        tried.push(`${q} → 类目${p.class}`);
        continue;
      }
      return {
        ok: true,
        source: "osm",
        coord_sys: "wgs84",
        longitude: Number(lng.toFixed(6)),
        latitude: Number(lat.toFixed(6)),
        osm_type: p.osm_type,
        osm_id: p.osm_id,
        osm_class: p.class,
        matched_name: display,
      };
    }
    tried.push(`${q} → ${data.length} 条候选均被过滤`);
  }
  return { ok: false, reason: tried.slice(0, 3).join(" / ") || "无匹配" };
}

/** 高德优先（GCJ-02），无 Key 或未命中时回退 OSM（WGS-84）。 */
async function resolvePoint(key, keyword, city) {
  if (key) {
    await sleep(QPS_INTERVAL_MS);
    const r = await queryAmap(key, keyword, city);
    if (r.ok) return r;
  }
  await sleep(NOMINATIM_INTERVAL_MS);
  return queryNominatim(keyword, city);
}

async function main() {
  const args = process.argv.slice(2);
  const file = args.find((a) => !a.startsWith("--"));
  if (!file) {
    console.error("用法: AMAP_KEY=xxx node scripts/geocode.mjs <json> [--out out.json]");
    process.exit(2);
  }
  const outIdx = args.indexOf("--out");
  const outPath = outIdx >= 0 ? args[outIdx + 1] : null;
  const limitIdx = args.indexOf("--limit");
  const limit = limitIdx >= 0 ? Number(args[limitIdx + 1]) : Infinity;

  const raw = JSON.parse(readFileSync(file, "utf8"));
  const rows = Array.isArray(raw) ? raw : raw.attractions;
  if (!Array.isArray(rows)) {
    console.error("输入应为 JSON 数组，或含 attractions 字段的对象");
    process.exit(2);
  }

  const allMissing = rows.filter(
    (a) => a.longitude === null || a.longitude === undefined
  );
  // --limit 限制本轮实际联网查询的条数（已缓存的仍全部回填）
  const cache0 = loadCache();
  const cacheKeyOf = (a) => `${CACHE_VERSION}|${a.city ?? ""}|${a.name}`;
  const cacheHas = (c, a) => Object.prototype.hasOwnProperty.call(c, cacheKeyOf(a));
  const needGeo = limit === 0
    ? []
    : [
        ...allMissing.filter((a) => cacheHas(cache0, a)),
        ...allMissing.filter((a) => !cacheHas(cache0, a)),
      ].slice(0, limit);
  const deferred = allMissing.length - needGeo.length;
  if (deferred > 0) {
    console.log(`本轮查询 ${needGeo.length} 条，其余 ${deferred} 条留待后续增量运行`);
  }
  console.log(`\n坐标解析 · ${file}`);
  console.log("─".repeat(46));
  console.log(`总数          ${rows.length}`);
  console.log(`缺坐标        ${allMissing.length}`);
  console.log(`已有坐标      ${rows.length - allMissing.length}`);

  if (needGeo.length === 0) {
    console.log("\n无需解析。\n");
    return;
  }

  const key = process.env.AMAP_KEY;
  if (!key) {
    console.log(
      "  未设置 AMAP_KEY，将回退到 OpenStreetMap Nominatim（WGS-84，\n" +
        "  随后由流水线折算为 GCJ-02）。Nominatim 精度低于高德，\n" +
        "  配置 AMAP_KEY 可显著提高命中率。\n"
    );
  }

  const cache = loadCache();
  let hit = 0;
  let miss = 0;
  const failed = [];

  for (const a of needGeo) {
    const cacheKey = cacheKeyOf(a);
    let result = cache[cacheKey];

    if (!result) {
      result = await resolvePoint(key, a.name, a.city);
      cache[cacheKey] = result;
      miss++;
      saveCache(cache); // 增量落盘：批量任务被中断也不丢已完成部分
      if (!result.ok) failed.push({ name: a.name, city: a.city, reason: result.reason });
    } else {
      hit++;
    }

    if (result.ok) {
      a.longitude = result.longitude;
      a.latitude = result.latitude;
      a.coord_sys = result.coord_sys;
      const via =
        result.source === "amap"
          ? `高德 POI 搜索（poi_id=${result.amap_id}，匹配名「${result.matched_name}」` +
            `${result.amap_typecode ? `，typecode=${result.amap_typecode}` : ""}）`
          : `OpenStreetMap Nominatim（${result.osm_type}/${result.osm_id}，匹配「${String(result.matched_name).slice(0, 60)}」）`;
      a.coord_note = `坐标来源：${via}`;
      // 坐标是可溯源事实，但属二级来源，不因坐标而提升票价/开放时间的验证等级
      if (!a.source_type || a.source_type === "ugc") a.source_type = "map";

      // 高德顺带返回的营业时间/评分/人均/电话。
      // 只作为**候选线索**随行携带：由 build-attraction-seed.mjs 统一抽取成
      // attraction_hours 行，落 pending —— 不直接覆盖既有官方开放时间。
      if (result.source === "amap" && (result.hours_desc || result.rating)) {
        a.amap_biz = {
          poi_id: result.amap_id,
          hours_desc: result.hours_desc ?? null,
          rating: result.rating ?? null,
          avg_cost: result.avg_cost ?? null,
          tel: result.tel ?? null,
          source_url: `https://www.amap.com/place/${result.amap_id}`,
        };
      }
    }
  }

  saveCache(cache);

  const resolved = needGeo.filter(
    (a) => a.longitude !== null && a.longitude !== undefined
  ).length;

  console.log(`缓存命中      ${hit}`);
  console.log(`本次查询      ${miss}`);
  console.log(`成功取点      ${resolved}/${needGeo.length}`);
  if (failed.length) {
    console.log(`\n未命中 ${failed.length} 条（需人工补坐标或换关键词）:`);
    for (const f of failed.slice(0, 20)) {
      console.log(`  · ${f.city ?? ""} ${f.name} —— ${f.reason}`);
    }
    if (failed.length > 20) console.log(`  · …另有 ${failed.length - 20} 条`);
  }

  if (outPath) {
    writeFileSync(outPath, JSON.stringify(rows, null, 2), "utf8");
    console.log(`\n已写出 → ${outPath}`);
  }
  console.log("");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
