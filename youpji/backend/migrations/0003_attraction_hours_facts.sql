-- 游迹 V0.1 增量 schema（阶段 2.5：营业时段候选行入库）
-- 约定：只追加，不修改 0001_init.sql / 0002_fact_fields.sql。

-- 1) attraction_hours 补齐 AGENTS.md 要求的两个事实字段。
--    0001 只给了 source_type/last_verified/verification_status，
--    0002 补了 source_url，仍缺 source_time 与 confidence，
--    导致 fact_status_check() 无法作用于营业时段 —— 二级来源的高德营业时间
--    会被无约束地写成 verified。这里补齐后，
--    「map 来源 / confidence<0.7 不得标 verified」才有数据库层兜底。
ALTER TABLE attraction_hours
  ADD COLUMN IF NOT EXISTS source_time TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5;

-- 2) 营业时段防重：高德同一景区同一时段可能因多轮采集重复写入。
--    0001 的表没有唯一约束，配合 INSERT ... ON CONFLICT DO NOTHING 实际不生效。
--    索引包含 open_time/close_time，只去掉**完全重复**的行；
--    若只按 (attraction_id, weekday, season) 去重，会把同一季节下的
--    不同开放区间（例如分段营业）误判为重复而丢弃。
--
--    注意：attractions 表本身**没有 name 唯一约束**，
--    故 attractions.generated.sql 里的 ON CONFLICT DO NOTHING 同样是空转，
--    重复 apply 会插入重复景区。此问题不在本迁移范围内，另行处理。
CREATE UNIQUE INDEX IF NOT EXISTS uq_attraction_hours_slot
  ON attraction_hours (
    attraction_id,
    COALESCE(weekday, -1),
    COALESCE(season, ''),
    open_time,
    close_time
  );

-- 3) 支撑「候选时段 vs 官方时段」的巡检查询：按状态与过期时间找待核验/陈旧项。
CREATE INDEX IF NOT EXISTS idx_attraction_hours_review
  ON attraction_hours (verification_status, source_type);
