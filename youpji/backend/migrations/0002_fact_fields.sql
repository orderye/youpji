-- 游迹 V0.1 增量 schema（阶段 1：事实验证字段补齐）
-- 约定：只追加，不修改 0001_init.sql。

-- 1) transportation 补齐来源/置信度（阶段 1.2 要求的事实字段）
ALTER TABLE transportation
  ADD COLUMN IF NOT EXISTS status VARCHAR(16) NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS source_url TEXT,
  ADD COLUMN IF NOT EXISTS source_time TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5;

CREATE INDEX IF NOT EXISTS idx_transportation_od ON transportation(origin, destination);

-- 2) 酒店/餐厅补齐 source_time（其余事实字段已存在）
ALTER TABLE hotels
  ADD COLUMN IF NOT EXISTS source_time TIMESTAMPTZ;

ALTER TABLE restaurants
  ADD COLUMN IF NOT EXISTS source_time TIMESTAMPTZ;

-- 3) 景区补齐开关状态（阶段 3 候选过滤需要：剔除 closed）
ALTER TABLE attractions
  ADD COLUMN IF NOT EXISTS status VARCHAR(16) NOT NULL DEFAULT 'open';

-- 4) 事实校验规则（阶段 1.3）：不得把 unverified 当 verified 写入
CREATE OR REPLACE FUNCTION fact_status_check(
  p_status verification_status,
  p_source_url TEXT,
  p_confidence DOUBLE PRECISION
) RETURNS verification_status AS $$
BEGIN
  -- source_url 为空或置信度过低 -> 强制降级为 pending（事实不能当验证数据用）
  IF p_source_url IS NULL OR p_source_url = '' THEN
    RETURN 'pending'::verification_status;
  END IF;
  IF p_confidence IS NULL OR p_confidence < 0.7 THEN
    RETURN 'pending'::verification_status;
  END IF;
  IF p_status = 'verified' THEN
    RETURN 'verified'::verification_status;
  END IF;
  RETURN p_status;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 5) 票务/开放时间表补 source_url（票价与开放时间必须可追溯）
ALTER TABLE attraction_tickets
  ADD COLUMN IF NOT EXISTS source_url TEXT;

ALTER TABLE attraction_hours
  ADD COLUMN IF NOT EXISTS source_url TEXT;
