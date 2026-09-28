-- 游迹 V0.1 增量 schema（Admin 审核与审计日志）
-- 约定：只追加，不修改 0001–0004 历史文件。

-- 1) data_reviews 审核表补字段：
--    - reason: 审核理由或驳回说明
--    - submitter_id: 提交人（支持双人制与追溯谁提出了数据变更）
ALTER TABLE data_reviews
  ADD COLUMN IF NOT EXISTS reason TEXT,
  ADD COLUMN IF NOT EXISTS submitter_id UUID REFERENCES users(id);

-- 2) Admin 全量操作审计日志表（DESIGN.md §10）
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID NOT NULL REFERENCES users(id),
  action VARCHAR(64) NOT NULL,
  entity_type VARCHAR(32),
  entity_id UUID,
  detail JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_admin ON admin_audit_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON admin_audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON admin_audit_log(created_at DESC);
