-- 自动生成，请勿手工编辑
-- 来源：scripts/import-attractions.mjs 校验通过后输出
-- 规则：verified 必有 source_url 且 confidence ≥ 0.7；事实缺失一律落 pending/unverified
INSERT INTO attractions (
  name, alias, city, district, longitude, latitude, category, level, description,
  opening_time, closing_time, ticket_price, recommended_duration_min, best_season,
  difficulty, family_score, elderly_score, photography_score, couple_score,
  source_type, source_url, last_verified, verification_status, confidence
) VALUES
  ('乌蒙大草原景区', '乌蒙大草原', '六盘水', '盘州', 104.611807, 26.156169, '自然景观/高山草原', '4A', '海拔2000-2857米的西南最大天然草场，四季皆可游。', '08:00', '20:00', NULL, 300, '夏', 3, 65, 35, 88, 72, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029534.html', NULL, 'pending', 0.85),
  ('妥乐古银杏旅游景区', '妥乐古银杏', '六盘水', '盘州', 104.55199, 25.607063, '自然景观/古银杏群落', '4A', '1450余株千年古银杏集中成片，秋日金黄村落景观。', '08:30', '17:30', 30, 210, '秋', 2, 72, 60, 90, 78, 'official', 'https://tuoleguyinxing.com/?type=text&S_id=42&lang=cn', now(), 'verified', 0.92),
  ('梅花山旅游景区', '梅花山', '六盘水', '钟山', 104.731631, 26.615467, '自然景观/山地度假区', '4A', '含国际滑雪场与9.91公里同路径山地索道，四季皆宜。', '09:00', '17:00', NULL, 300, '冬', 3, 70, 45, 80, 65, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029547.html', NULL, 'pending', 0.85),
  ('玉舍森林旅游景区', '玉舍森林公园', '六盘水', '水城', 104.802859, 26.450764, '自然景观/森林公园', '4A', '面积34平方公里的天然氧吧，含中国纬度最低滑雪场。', '09:00', '20:00', NULL, 240, '冬', 3, 68, 50, 75, 62, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029540.html', NULL, 'pending', 0.82),
  ('明湖国家湿地公园', '明湖湿地公园', '六盘水', '钟山', 104.76397, 26.590876, '自然景观/城市湿地', '3A', '贵州首个国家级湿地公园，中心城区城市绿肺，全天免费。', '00:00', '23:59', 0, 120, '夏', 1, 85, 80, 60, 70, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029544.html', now(), 'verified', 0.88),
  ('贵州三线建设博物馆', '三线建设博物馆', '六盘水', '钟山', 104.878208, 26.57441, '人文历史/博物馆', '4A', '展示三线建设历史的室内场馆，紧邻水城古镇。', '09:00', '17:00', NULL, 90, '秋', 1, 80, 78, 45, 58, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029548.html', NULL, 'pending', 0.83),
  ('北盘江大桥（都格北盘江第一桥）观景点', '北盘江大桥', '六盘水', '水城', 104.679085, 26.384446, '地标/工程景观', NULL, '桥面距谷底565.4米的世界第一高桥，观景台俯瞰云贵大裂谷。', NULL, NULL, NULL, 90, '秋', 2, 55, 30, 92, 68, 'map', NULL, NULL, 'unverified', 0.5),
  ('水城古镇', '水城古镇', '六盘水', '钟山', 104.877708, 26.573711, '人文古镇', NULL, '始建雍正十年的古镇，保留三线建设苏式建筑遗存。', NULL, NULL, NULL, 150, '夏', 1, 78, 72, 65, 72, 'map', NULL, NULL, 'unverified', 0.45)
ON CONFLICT DO NOTHING;
