-- 游迹 V0.1 增量 schema（景区名称唯一约束）
-- 约定：只追加，不修改 0001_init.sql / 0002 / 0003。

-- 背景：0001 的 attractions 没有 name 唯一约束，导致
--   1. attractions.generated.sql 里的 ON CONFLICT DO NOTHING 完全是空转 ——
--      种子重复 apply 会静默插入重复景区；
--   2. scripts/import-attractions.mjs 生成的营业时段用
--      (SELECT id FROM attractions WHERE name = '...') 定位归属，
--      一旦重名，时段就会挂到多行上，
--      表现为「昨天能导入，今天重跑突然失败」——这是流水线最脆弱的一处依赖。
--
-- name 之所以能单独作唯一键：种子合并阶段已按 coreName（去掉
-- 「景区/旅游区/风景区」等后缀后的核心地名）全局去重，当前 566 条名录重名数为 0；
-- 且本项目 V0.1 只做贵州一省，不存在跨省同名景区需要靠 (name, city) 区分。

-- 1) 先自愈：Admin 手工录入或历史脏数据可能已产生重名。
--    每组保留「验证状态更好、同状态保留更新更晚」的一条，其余删除。
--    删除会级联 attraction_hours / attraction_tickets / attraction_tags
--    （均为 ON DELETE CASCADE）——这是有意的，重名行本来就没法被唯一引用，
--    保留它们只会让两套事实长期并存。
DO $$
DECLARE
  dup_groups INTEGER;
BEGIN
  SELECT count(*) INTO dup_groups FROM (
    SELECT name FROM attractions GROUP BY name HAVING count(*) > 1
  ) t;

  IF dup_groups > 0 THEN
    RAISE NOTICE '发现 % 组重名景区，按验证状态与更新时间保留其一', dup_groups;

    DELETE FROM attractions WHERE id IN (
      SELECT id FROM (
        SELECT id,
               row_number() OVER (
                 PARTITION BY name
                 ORDER BY
                   CASE verification_status
                     WHEN 'verified'  THEN 5
                     WHEN 'pending'   THEN 4
                     WHEN 'stale'     THEN 3
                     WHEN 'disputed'  THEN 2
                     ELSE 1
                   END DESC,
                   updated_at DESC,
                   id
               ) AS rn
        FROM attractions
      ) ranked
      WHERE rn > 1
    );
  END IF;
END $$;

-- 2) 补唯一约束：让种子里的 ON CONFLICT DO NOTHING 真正生效，
--    重复 apply 从「无限追加」变成幂等。
ALTER TABLE attractions
  ADD CONSTRAINT attractions_name_key UNIQUE (name);

-- 3) 补 alias 的模糊检索索引（0001:148 只建了 name 的 trgm 索引，
--    而别名正是「黄果树 → 黄果树风景名胜区」这类查询的检索入口）。
--    pg_trgm 扩展本身已由 0001_init.sql 创建，此处不再重复。
CREATE INDEX IF NOT EXISTS idx_attractions_alias_trgm
  ON attractions USING GIN (alias gin_trgm_ops);
