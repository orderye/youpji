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

/** 高德 POIs[].location = "lng,lat"（GCJ-02） */
async function queryAmap(key, keyword, city) {
  const url =
    "https://restapi.amap.com/v3/place/text" +
    `?key=${encodeURIComponent(key)}` +
    `&keywords=${encodeURIComponent(keyword)}` +
    (city ? `&city=${encodeURIComponent(city)}&citylimit=true` : "") +
    "&extensions=base&offset=5&page=1";

  const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!res.ok) return { ok: false, reason: `HTTP ${res.status}` };
  const data = await res.json();
  if (data.status !== "1") {
    return { ok: false, reason: `${data.info || "unknown"} (${data.infocode || "-"})` };
  }
  const pois = data.pois || [];
  if (pois.length === 0) return { ok: false, reason: "无匹配 POI" };

  // 取第一个带有效坐标的候选
  for (const p of pois) {
    if (p.location && /^[\d.]+,[\d.]+$/.test(p.location)) {
      const [lng, lat] = p.location.split(",").map(Number);
      if (Number.isFinite(lng) && Number.isFinite(lat)) {
        return {
          ok: true,
          source: "amap",
          coord_sys: "gcj02",
          longitude: Number(lng.toFixed(6)),
          latitude: Number(lat.toFixed(6)),
          amap_id: p.id,
          matched_name: p.name,
        };
      }
    }
  }
  return { ok: false, reason: "候选均无坐标" };
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
  const cacheHas = (c, a) => Object.prototype.hasOwnProperty.call(c, `${a.city ?? ""}|${a.name}`);
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
    const cacheKey = `${a.city ?? ""}|${a.name}`;
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
          ? `高德 POI 搜索（poi_id=${result.amap_id}，匹配名「${result.matched_name}」）`
          : `OpenStreetMap Nominatim（${result.osm_type}/${result.osm_id}，匹配「${String(result.matched_name).slice(0, 60)}」）`;
      a.coord_note = `坐标来源：${via}`;
      // 坐标是可溯源事实，但属二级来源，不因坐标而提升票价/开放时间的验证等级
      if (!a.source_type || a.source_type === "ugc") a.source_type = "map";
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
