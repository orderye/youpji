-- 游迹 V0.1 增量 schema（Phase 7 架构健壮性与外键完整性修复）
-- 约定：只追加，不修改 0001–0005 历史文件。

-- 1) user_feedback 表增强：
--    - images: 存放反馈附图 URL 数组
--    - 外键约束: 关联 itineraries(id)
ALTER TABLE user_feedback
  ADD COLUMN IF NOT EXISTS images JSONB NOT NULL DEFAULT '[]'::jsonb;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_user_feedback_itinerary'
  ) THEN
    ALTER TABLE user_feedback
      ADD CONSTRAINT fk_user_feedback_itinerary
      FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 2) itinerary_status 枚举兼容增强：
--    添加 'in_progress' 兼容项，确保无论使用 'active' 还是 'in_progress' 均可在数据库正常流转
ALTER TYPE itinerary_status ADD VALUE IF NOT EXISTS 'in_progress';
