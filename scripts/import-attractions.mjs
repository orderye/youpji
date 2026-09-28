/**
 * 景区数据导入校验器（AGENTS.md 铁律 4/5 的机械化执行）。
 *
 * 存在的理由：「AI 不决定事实」不能只靠自觉。把来源、验证状态、置信度
 * 的一致性写成可执行断言，采集结果不达标就进不了库、也进不了 seed.sql。
 *
 * 用法：
 *   node scripts/import-attractions.mjs data/attractions.json            # 只校验，打印报告
 *   node scripts/import-attractions.mjs data/attractions.json --out f.sql # 校验通过后生成 SQL
 *   DATABASE_URL=... node scripts/import-attractions.mjs data.json --apply  # 校验后直接入库
 *
 * 校验规则（任一 ERROR 即拒绝）：
 *   1. name 必填且不重复
 *   2. verification_status=verified ⇒ source_url 存在且为 http(s)、confidence ≥ 0.7
 *   3. ticket_price 或 opening_time 为 null 时，不允许标记为 verified
 *   4. confidence ∈ [0,1]
 *   5. 四个 *score ∈ [0,100] 整数；difficulty ∈ [1,5]
 *   6. 坐标必须在贵州省经纬度包围盒内，且经度 > 纬度（防 GCJ/WGS84 写反）
 *   7. recommended_duration_min ∈ [30, 720]
 */
import { readFileSync, writeFileSync, existsSync } from "fs";

const GUIZHOU_BBOX = { minLng: 103.6, maxLng: 109.6, minLat: 24.6, maxLat: 29.2 };

const SCORE_FIELDS = [
  "family_score",
  "elderly_score",
  "photography_score",
  "couple_score",
];

const REQUIRED = ["name", "city", "category"];
// 只有「外部事实字段」才要求 verified 必须齐备。
// recommended_duration_min / best_season / difficulty 是我方规划参数，由算法侧评估，
// 不要求来源，否则会反向逼出「为了标 verified 而编造季节」这类假数据。
const EXTERNAL_FACTS = ["ticket_price", "opening_time", "closing_time"];

const STATUSES = new Set([
  "verified",
  "pending",
  "stale",
  "disputed",
  "unverified",
]);
const SOURCE_TYPES = new Set([
  "official",
  "government",
  "map",
  "platform",
  "ugc",
  "ai",
]);

function validateOne(a, index, seen) {
  const errors = [];
  const warnings = [];
  const at = `[${index}] ${a?.name ?? "<无 name>"}`;

  if (!a || typeof a !== "object") {
    return { errors: [`${at}: 不是对象`], warnings };
  }

  for (const f of REQUIRED) {
    if (a[f] === undefined || a[f] === null || a[f] === "") {
      errors.push(`${at}: 缺少必填字段 ${f}`);
    }
  }
  if (a.name && seen.has(a.name)) {
    errors.push(`${at}: 名称重复`);
  }
  if (a.name) seen.add(a.name);

  // 2/3 事实可追溯性
  const status = a.verification_status;
  if (!STATUSES.has(status)) {
    errors.push(`${at}: verification_status 非法 "${status}"`);
  }
  if (a.source_type && !SOURCE_TYPES.has(a.source_type)) {
    errors.push(`${at}: source_type 非法 "${a.source_type}"`);
  }
  if (status === "verified") {
    if (!a.source_url || !/^https?:\/\//.test(a.source_url)) {
      errors.push(`${at}: 标记 verified 但缺少合法 source_url`);
    }
    if (typeof a.confidence !== "number" || a.confidence < 0.7) {
      errors.push(`${at}: 标记 verified 但 confidence 缺失或 < 0.7`);
    }
  }
  const missingFacts = EXTERNAL_FACTS.filter(
    (f) => a[f] === undefined || a[f] === null
  );
  if (missingFacts.length > 0 && status === "verified") {
    errors.push(
      `${at}: 标记 verified 但事实字段缺失 → ${missingFacts.join(", ")}`
    );
  }
  if (missingFacts.length > 0) {
    warnings.push(`${at}: 事实字段缺失 → ${missingFacts.join(", ")}`);
  }

  // 4 置信度
  if (
    a.confidence !== undefined &&
    a.confidence !== null &&
    (typeof a.confidence !== "number" ||
      a.confidence < 0 ||
      a.confidence > 1)
  ) {
    errors.push(`${at}: confidence 必须在 [0,1]`);
  }

  // 5 评分
  for (const f of SCORE_FIELDS) {
    const v = a[f];
    if (v === undefined || v === null) continue;
    if (!Number.isInteger(v) || v < 0 || v > 100) {
      errors.push(`${at}: ${f} 必须是 0-100 整数，实际 ${v}`);
    }
  }
  if (a.difficulty !== undefined && a.difficulty !== null) {
    if (!Number.isInteger(a.difficulty) || a.difficulty < 1 || a.difficulty > 5) {
      errors.push(`${at}: difficulty 必须是 1-5 整数，实际 ${a.difficulty}`);
    }
  }

  // 6 坐标
  const { longitude, latitude } = a;
  if (longitude === null || longitude === undefined) {
    warnings.push(`${at}: 缺坐标`);
  } else {
    const inBox =
      longitude >= GUIZHOU_BBOX.minLng &&
      longitude <= GUIZHOU_BBOX.maxLng &&
      latitude >= GUIZHOU_BBOX.minLat &&
      latitude <= GUIZHOU_BBOX.maxLat;
    if (!inBox) {
      errors.push(
        `${at}: 坐标 (${longitude}, ${latitude}) 不在贵州范围内`
      );
    }
    if (longitude <= latitude) {
      errors.push(
        `${at}: 疑似经纬度写反 (lng=${longitude}, lat=${latitude})`
      );
    }
  }

  // 7 游玩时长
  if (
    a.recommended_duration_min !== undefined &&
    a.recommended_duration_min !== null &&
    (a.recommended_duration_min < 30 || a.recommended_duration_min > 720)
  ) {
    errors.push(
      `${at}: recommended_duration_min 应在 30-720，实际 ${a.recommended_duration_min}`
    );
  }

  return { errors, warnings };
}

function sqlLiteral(v) {
  if (v === null || v === undefined) return "NULL";
  if (typeof v === "number") return String(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  return `'${String(v).replace(/'/g, "''")}'`;
}

/**
 * PostgreSQL 数组字面量。
 *
 * 0001 里 `best_season` 是 TEXT[]，而普通 sqlLiteral 会输出 '四季'，
 * PostgreSQL 报 `malformed array literal: "四季"` —— 直接让整个种子导入失败。
 * 数据里存的是「夏秋」这类**合并写法**，这里保持原样放进单元素数组：
 *   '夏秋' → {'夏秋'}
 * 真要拆成多元素应在采集侧用分隔符规范化，而不是在 SQL 生成时猜。
 */
function sqlArrayLiteral(v) {
  if (v === null || v === undefined || v === "") return "NULL";
  const items = Array.isArray(v) ? v : [v];
  const clean = items.filter((x) => x !== null && x !== undefined && x !== "");
  if (clean.length === 0) return "NULL";
  return `ARRAY[${clean.map((x) => sqlLiteral(x)).join(", ")}]`;
}

function toSql(rows) {
  const cols = [
    "name",
    "alias",
    "city",
    "district",
    "longitude",
    "latitude",
    "category",
    "level",
    "description",
    "opening_time",
    "closing_time",
    "ticket_price",
    "recommended_duration_min",
    "best_season",
    "difficulty",
    "family_score",
    "elderly_score",
    "photography_score",
    "couple_score",
    "source_type",
    "source_url",
    "last_verified",
    "verification_status",
    "confidence",
  ];
  const lines = rows.map((a) => {
    const values = cols.map((c) => {
      if (c === "last_verified") {
        return a.verification_status === "verified" ? "now()" : "NULL";
      }
      if (c === "source_type") return sqlLiteral(a.source_type || "platform");
      if (c === "verification_status") {
        return sqlLiteral(a.verification_status || "unverified");
      }
      if (c === "confidence") return sqlLiteral(a.confidence ?? 0.5);
      if (["longitude", "latitude"].includes(c)) {
        return a[c] === null || a[c] === undefined ? "NULL" : sqlLiteral(a[c]);
      }
      if (c === "difficulty") return sqlLiteral(a.difficulty ?? 3);
      if (c === "best_season") return sqlArrayLiteral(a.best_season);
      for (const s of SCORE_FIELDS) {
        if (c === s) return sqlLiteral(a[s] ?? 50);
      }
      return sqlLiteral(a[c] ?? null);
    });
    return `  (${values.join(", ")})`;
  });

  return `-- 自动生成，请勿手工编辑
-- 来源：scripts/import-attractions.mjs 校验通过后输出
-- 规则：verified 必有 source_url 且 confidence ≥ 0.7；事实缺失一律落 pending/unverified
INSERT INTO attractions (
  name, alias, city, district, longitude, latitude, category, level, description,
  opening_time, closing_time, ticket_price, recommended_duration_min, best_season,
  difficulty, family_score, elderly_score, photography_score, couple_score,
  source_type, source_url, last_verified, verification_status, confidence
) VALUES
${lines.join(",\n")}
ON CONFLICT DO NOTHING;
`;
}

/**
 * 生成营业时段 INSERT。
 *
 * 三条纪律（AGENTS.md 铁律 4 + migrations/0003 的 fact_status_check）：
 *   1. 高德属二级来源 → 一律 source_type='map' / verification_status='pending'；
 *   2. confidence 固定 0.55，低于 0.7 阈值，数据库侧也无法被误升为 verified；
 *   3. 归属靠 (SELECT id FROM attractions WHERE name=...)。
 *
 * 为什么用 `SELECT ... FROM (VALUES ...) WHERE attraction_id IS NOT NULL`：
 * 子查询查不到景区时返回 NULL，而 attraction_id 是 NOT NULL 外键 ——
 * 直接 INSERT ... VALUES 会让**整条语句**因空值违规中止，
 * 连带已能匹配的行也一起回滚。改成过滤式 SELECT 后，
 * 匹配不上的行被安静跳过，不会拖垮整个种子导入。
 */
function hoursToSql(hoursRows) {
  if (!hoursRows || hoursRows.length === 0) return "";
  const valueBlocks = hoursRows.map((h) =>
    [
      `(SELECT id FROM attractions WHERE name = ${sqlLiteral(h.name)})`,
      h.weekday === null || h.weekday === undefined ? "NULL" : String(h.weekday),
      sqlLiteral(h.season ?? null),
      sqlLiteral(h.open_time),
      sqlLiteral(h.close_time),
      sqlLiteral(h.note ?? null),
      sqlLiteral(h.source_type || "map"),
      sqlLiteral(h.source_url ?? null),
      sqlLiteral(h.last_verified ?? null),
      sqlLiteral(h.verification_status || "pending"),
      sqlLiteral(h.confidence ?? 0.55),
    ].join(", ")
  );

  return `
-- 营业时段（高德 POI 二级来源，pending 待人工核验）
-- season 形如「9月1日-11月30日」「9月-11月」「节假日:春节」，NULL 表示全年
-- weekday 0-6（0=周日），NULL 表示每天；停止售票/最晚入园等约束写在 note
-- WHERE 守卫：景区未入库时该行被跳过，而不是让整条 INSERT 失败
INSERT INTO attraction_hours (
  attraction_id, weekday, season, open_time, close_time, note,
  source_type, source_url, last_verified, verification_status, confidence
)
SELECT
  v.attraction_id,
  v.weekday::smallint,
  v.season,
  -- 必须显式 cast：VALUES 里的 '07:00' 在 SELECT 语境下会被解析成 text
  -- （没有目标列来驱动类型推导），不转换则报
  -- "column open_time is of type time without time zone but expression is of type text"
  v.open_time::time,
  v.close_time::time,
  v.note,
  v.source_type::source_type,
  v.source_url,
  v.last_verified::timestamptz,
  v.verification_status::verification_status,
  v.confidence::double precision
FROM (VALUES
${valueBlocks.map((b) => `    (${b})`).join(",\n")}
) AS v (
  attraction_id, weekday, season, open_time, close_time, note,
  source_type, source_url, last_verified, verification_status, confidence
)
WHERE v.attraction_id IS NOT NULL
ON CONFLICT DO NOTHING;
`;
}

async function main() {
  const args = process.argv.slice(2);
  const path = args.find((a) => !a.startsWith("--"));
  if (!path) {
    console.error("用法: node scripts/import-attractions.mjs <json> [--out f.sql] [--apply]");
    process.exit(2);
  }
  const out = args.includes("--out") ? args[args.indexOf("--out") + 1] : null;
  const apply = args.includes("--apply");

  const raw = JSON.parse(readFileSync(path, "utf8"));
  const rows = Array.isArray(raw) ? raw : raw.attractions;
  if (!Array.isArray(rows)) {
    console.error("输入应为 JSON 数组，或含 attractions 字段的对象");
    process.exit(2);
  }

  const seen = new Set();
  const allErrors = [];
  const allWarnings = [];
  rows.forEach((a, i) => {
    const r = validateOne(a, i, seen);
    allErrors.push(...r.errors);
    allWarnings.push(...r.warnings);
  });

  // 营业时段：独立校验，且必须能对上已入库的景区名（否则是孤儿行）
  const hoursIdx = args.indexOf("--hours");
  let hoursRows = [];
  if (hoursIdx >= 0) {
    const hp = args[hoursIdx + 1];
    if (hp && existsSync(hp)) {
      hoursRows = JSON.parse(readFileSync(hp, "utf8"));
    }
  }
  const names = new Set(rows.map((a) => a.name));
  const orphanHours = hoursRows.filter((h) => !names.has(h.name));
  hoursRows = hoursRows.filter((h) => names.has(h.name));
  for (const [i, h] of hoursRows.entries()) {
    const at = `[hours ${i}] ${h.name}`;
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(String(h.open_time))) {
      allErrors.push(`${at}: open_time 非法 "${h.open_time}"`);
    }
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(String(h.close_time))) {
      allErrors.push(`${at}: close_time 非法 "${h.close_time}"`);
    }
    if (h.close_time <= h.open_time && !(h.open_time === "00:00" && h.close_time === "23:59")) {
      allWarnings.push(`${at}: 闭园早于开园（跨夜场？）${h.open_time}-${h.close_time}`);
    }
    if (h.weekday !== null && h.weekday !== undefined && (h.weekday < 0 || h.weekday > 6)) {
      allErrors.push(`${at}: weekday 必须在 0-6，实际 ${h.weekday}`);
    }
    if (!SOURCE_TYPES.has(h.source_type)) {
      allErrors.push(`${at}: source_type 非法 "${h.source_type}"`);
    }
    // 二级来源不得标 verified：fact_status_check 会降级，但这里先拦住，避免噪音
    if (h.verification_status === "verified" && (h.source_type === "map" || h.confidence < 0.7)) {
      allErrors.push(
        `${at}: map 来源或 confidence<0.7 不允许标 verified（二级来源）`
      );
    }
  }

  const byStatus = {};
  for (const a of rows) {
    const s = a.verification_status || "unverified";
    byStatus[s] = (byStatus[s] || 0) + 1;
  }
  const withTicket = rows.filter((a) => a.ticket_price != null).length;
  const withHours = rows.filter(
    (a) => a.opening_time != null && a.closing_time != null
  ).length;

  console.log(`\n景区数据校验报告 · ${path}`);
  console.log("─".repeat(46));
  console.log(`总数            ${rows.length}`);
  console.log(`目标            100 （铁律要求 100–300）`);
  console.log(`verified        ${byStatus.verified || 0}`);
  console.log(`pending         ${byStatus.pending || 0}`);
  console.log(`unverified      ${byStatus.unverified || 0}`);
  console.log(`有票价          ${withTicket}/${rows.length}`);
  console.log(`有完整营业时间  ${withHours}/${rows.length}`);
  if (hoursRows.length > 0 || orphanHours.length > 0) {
    const withSeason = hoursRows.filter((h) => h.season).length;
    console.log(
      `营业时段行      ${hoursRows.length}（含季节区间 ${withSeason}）` +
        (orphanHours.length ? `，跳过孤儿 ${orphanHours.length}` : "")
    );
  }

  if (allWarnings.length) {
    console.log(`\n警告 ${allWarnings.length} 条（不阻断）:`);
    for (const w of allWarnings.slice(0, 15)) console.log(`  · ${w}`);
    if (allWarnings.length > 15) {
      console.log(`  · …另有 ${allWarnings.length - 15} 条`);
    }
  }

  if (allErrors.length) {
    console.log(`\n错误 ${allErrors.length} 条（阻断入库）:`);
    for (const e of allErrors.slice(0, 25)) console.log(`  ✗ ${e}`);
    if (allErrors.length > 25) {
      console.log(`  ✗ …另有 ${allErrors.length - 25} 条`);
    }
    console.log("\n结果：校验未通过，拒绝生成 SQL / 入库。\n");
    process.exit(1);
  }

  console.log("\n结果：校验通过。\n");

  if (out) {
    writeFileSync(out, toSql(rows) + hoursToSql(hoursRows), "utf8");
    console.log(`已生成 SQL → ${out}`);
  }

  if (apply) {
    const { Pool } = await import("pg");
    const conn = process.env.DATABASE_URL;
    if (!conn) {
      console.error("--apply 需要 DATABASE_URL");
      process.exit(1);
    }
    const pool = new Pool({ connectionString: conn });
    await pool.query(toSql(rows));
    console.log(`已写入 ${rows.length} 条到数据库`);
    await pool.end();
  }
}

main();
