-- 游迹 V0.1 增量 schema（地市、景区、博物馆、饭店头图与多媒体字段扩展）
-- 约定：只追加，不修改 0001–0006 历史文件。

-- 1) 地市 destinations：添加头图字段（用于城市封面图与行政区宣传图）
ALTER TABLE destinations
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

-- 2) 景区与博物馆 attractions：添加封面头图字段（加速列表和详情页展示，无需每次额外连接 attraction_images）
ALTER TABLE attractions
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

-- 3) 餐饮饭店 restaurants：添加封面头图与相册图集
ALTER TABLE restaurants
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
  ADD COLUMN IF NOT EXISTS images JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 4) 住宿酒店 hotels：添加封面头图与相册图集
ALTER TABLE hotels
  ADD COLUMN IF NOT EXISTS cover_image_url TEXT,
  ADD COLUMN IF NOT EXISTS images JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 5) 字段说明注释
COMMENT ON COLUMN destinations.cover_image_url IS '地市/行政区封面宣传头图 URL';
COMMENT ON COLUMN attractions.cover_image_url IS '景区或博物馆核心封面头图 URL';
COMMENT ON COLUMN restaurants.cover_image_url IS '餐饮饭店门头或招牌菜封面大图 URL';
COMMENT ON COLUMN hotels.cover_image_url IS '住宿饭店外观或大堂封面大图 URL';
