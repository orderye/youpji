-- 游迹实体验证头图补充种子（地市、景区、博物馆、饭店）
-- 自动生成时间: 2026-09-29T06:23:56.559Z

-- 1. 地市封面头图
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵阳';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '安顺';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '遵义';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黔东南';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黔南';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '铜仁';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '六盘水';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '毕节';
UPDATE destinations SET cover_image_url = 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黔西南';

-- 2. 景区与博物馆封面头图
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黄果树瀑布';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黄果树风景名胜区';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '龙宫';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '龙宫风景名胜区';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '天龙屯堡';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '平坝天龙屯堡古镇';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '青岩古镇';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '花溪青岩古镇';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1511497584788-87676104235f?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黔灵山公园';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '甲秀楼';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '格凸河';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '荔波樟江 · 小七孔景区';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '西江千户苗寨';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '赤水丹霞旅游区 · 大瀑布';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1566127444979-b3d2b654e3d7?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵州省博物馆';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '观山湖区贵州省地质博物馆';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '遵义会议会址';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '务川仡佬文化博物馆';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '习水宋窖博物馆';
UPDATE attractions SET cover_image_url = 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '钟山贵州三线建设博物馆';

-- 3. 餐饮饭店封面头图
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '安顺夺夺粉';
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '旧州辣子鸡';
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '黄果树景区农家菜';
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '青岩状元蹄';
UPDATE restaurants SET cover_image_url = 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵阳酸汤鱼';

-- 4. 住宿饭店封面头图
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '安顺黄果树希尔顿欢朋酒店';
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '安顺古城亚朵酒店';
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '镇宁黄果树景区民宿';
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵阳观山湖安缦';
UPDATE hotels SET cover_image_url = 'https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80', updated_at = now() WHERE name = '贵阳喷水池智选假日';
