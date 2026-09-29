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

-- 6) 核心种子实体初始头图注入（闭环与核心地标）
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵阳';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '安顺';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '遵义';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黔东南';

UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name IN ('黄果树瀑布', '黄果树风景名胜区');
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name IN ('龙宫', '龙宫风景名胜区');
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name IN ('天龙屯堡', '平坝天龙屯堡古镇');
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name IN ('青岩古镇', '花溪青岩古镇');
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1511497584788-87676104235f?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黔灵山公园';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '甲秀楼';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1566127444979-b3d2b654e3d7?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵州省博物馆';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '观山湖区贵州省地质博物馆';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '遵义会议会址';

UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '安顺夺夺粉';
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '旧州辣子鸡';
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黄果树景区农家菜';
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '青岩状元蹄';
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵阳酸汤鱼';

UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '安顺黄果树希尔顿欢朋酒店';
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '安顺古城亚朵酒店';
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '镇宁黄果树景区民宿';
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵阳观山湖安缦';
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵阳喷水池智选假日';
