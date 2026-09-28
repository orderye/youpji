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
      `\n[阶段 1/4] 坐标补全 —— 缺失 ${missingBefore} 条，本轮处理 ${batch.length} 条` +
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
    console.log("\n[阶段 1/4] 坐标补全 —— 全部已有坐标");
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
  console.log("\n[阶段 1.5/4] 坐标系归一化");
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
  console.log("\n[阶段 2/4] 事实校验");
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

  // 阶段 3：坐标完整性关卡
  console.log("\n[阶段 3/4] 坐标完整性关卡");
  const usable = rows.filter(
    (a) => a.longitude != null && a.latitude != null && a.coord_sys === "gcj02"
  );
  const rejected = rows.filter(
    (a) => a.longitude == null || a.latitude == null || a.coord_sys !== "gcj02"
  );
  console.log(`  可入库      ${usable.length}`);
  console.log(`  无坐标剔除  ${rejected.length}`);
  if (rejected.length > 0) {
    const sample = rejected.slice(0, 8).map((a) => `${a.city ?? ""}${a.name}`);
    console.log(`  剔除样例    ${sample.join("、")}${rejected.length > 8 ? " …" : ""}`);
  }

  console.log("\n" + "─".repeat(46));
  console.log(`最终可入库    ${usable.length} 条`);
  console.log(`铁律目标      100–300 条`);
  if (usable.length < 100) {
    console.log(
      `⚠  距铁律下限还差 ${100 - usable.length} 条。` +
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

  const r = spawnSync(
    process.execPath,
    [
      join(SCRIPT_DIR, "import-attractions.mjs"),
      finalFile,
      "--out",
      outPath,
    ],
    { encoding: "utf8" }
  );
  if (r.status !== 0) {
    console.log(r.stdout || r.stderr);
    console.log("生成 SQL 失败：残留行未通过事实校验。\n");
    return;
  }
  console.log(`\n已生成 → ${outPath}（含 ${usable.length} 条，均已通过坐标与事实校验）\n`);
}

main();
