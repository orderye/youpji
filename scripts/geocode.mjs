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
          longitude: Number(lng.toFixed(6)),
          latitude: Number(lat.toFixed(6)),
          amap_id: p.id,
          matched_name: p.name,
          address: p.address || "",
        };
      }
    }
  }
  return { ok: false, reason: "候选均无坐标" };
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

  const raw = JSON.parse(readFileSync(file, "utf8"));
  const rows = Array.isArray(raw) ? raw : raw.attractions;
  if (!Array.isArray(rows)) {
    console.error("输入应为 JSON 数组，或含 attractions 字段的对象");
    process.exit(2);
  }

  const needGeo = rows.filter(
    (a) => a.longitude === null || a.longitude === undefined
  );
  console.log(`\n坐标解析 · ${file}`);
  console.log("─".repeat(46));
  console.log(`总数          ${rows.length}`);
  console.log(`缺坐标        ${needGeo.length}`);
  console.log(`已有坐标      ${rows.length - needGeo.length}`);

  if (needGeo.length === 0) {
    console.log("\n无需解析。\n");
    return;
  }

  const key = process.env.AMAP_KEY;
  if (!key) {
    console.log(
      "\n未设置 AMAP_KEY，无法解析。\n" +
        "  说明：坐标是路线引擎的硬依赖（PostGIS 距离/就近查询），\n" +
        "  网页检索拿不到经纬度，必须用地图 API 取点。\n" +
        "  高德返回 GCJ-02，与 DESIGN §4.2 存储口径一致。\n"
    );
    process.exit(3);
  }

  const cache = loadCache();
  let hit = 0;
  let miss = 0;
  const failed = [];

  for (const a of needGeo) {
    const cacheKey = `${a.city ?? ""}|${a.name}`;
    let result = cache[cacheKey];

    if (!result) {
      await sleep(QPS_INTERVAL_MS);
      result = await queryAmap(key, a.name, a.city);
      cache[cacheKey] = result;
      miss++;
      if (!result.ok) failed.push({ name: a.name, city: a.city, reason: result.reason });
    } else {
      hit++;
    }

    if (result.ok) {
      a.longitude = result.longitude;
      a.latitude = result.latitude;
      a.coord_sys = "gcj02";
      a.coord_note = `高德 POI 搜索取点（poi_id=${result.amap_id}，匹配名「${result.matched_name}」）`;
      // 坐标是可溯源事实，但它是二级来源，不因坐标而提升票价/开放时间的验证等级
      if (a.source_type === "ugc" || !a.source_type) a.source_type = "map";
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
