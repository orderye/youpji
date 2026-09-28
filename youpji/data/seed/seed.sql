-- 游迹种子：贵州首批（安顺闭环 + 贵阳 + 黎平/雷山）
-- 坐标系 GCJ-02；source 均标注 official/platform 级

-- 标签词表
INSERT INTO tag_vocab (key, label) VALUES
  ('nature','自然景观'),('photo','摄影'),('family','亲子'),('couple','情侣'),
  ('elderly','老人'),('hiking','徒步'),('drive','自驾'),('history','历史文化'),
  ('food','美食'),('shopping','购物'),('night','夜游'),('waterfall','瀑布')
ON CONFLICT (key) DO NOTHING;

-- 目的地
INSERT INTO destinations (id, name, level, full_path, longitude, latitude, source_type, source_url, source_time, last_verified, verification_status, confidence) VALUES
  ('11111111-1111-1111-1111-111111111001','贵州','province','贵州',106.7135,26.5783,'government','https://www.guizhou.gov.cn', now(), now(), 'verified', 0.95),
  ('11111111-1111-1111-1111-111111111002','贵阳','city','贵州/贵阳',106.6302,26.6470,'government','https://www.guiyang.gov.cn', now(), now(), 'verified', 0.9),
  ('11111111-1111-1111-1111-111111111003','安顺','city','贵州/安顺',105.9322,26.2454,'government','https://www.anshun.gov.cn', now(), now(), 'verified', 0.9),
  ('11111111-1111-1111-1111-111111111004','黔东南','city','贵州/黔东南',107.9775,26.5834,'government','https://www.qdn.gov.cn', now(), now(), 'verified', 0.85),
  ('11111111-1111-1111-1111-111111111005','西秀','district','贵州/安顺/西秀',105.9769,26.2535,'government','https://www.anshun.gov.cn', now(), now(), 'verified', 0.85),
  ('11111111-1111-1111-1111-111111111006','镇宁','district','贵州/安顺/镇宁',105.7644,26.0646,'government','https://www.anshun.gov.cn', now(), now(), 'verified', 0.85)
ON CONFLICT (id) DO NOTHING;

-- 景区
INSERT INTO attractions (
  id, destination_id, name, alias, province, city, district, longitude, latitude,
  category, level, description, opening_time, closing_time, ticket_price,
  recommended_duration_min, best_season, difficulty,
  family_score, elderly_score, photography_score, couple_score,
  parking, transport, indoor, popularity,
  source_type, source_url, source_time, last_verified, verification_status, confidence
) VALUES
('22222222-2222-2222-2222-222222222001','11111111-1111-1111-1111-111111111003','黄果树瀑布','黄果树','贵州','安顺','镇宁',105.6789,25.9901,
 '自然景观/瀑布','5A','亚洲著名大瀑布，含天星桥、陡坡塘等联票景区。',NULL,NULL,160,
 240,'夏秋',2, 86,70,92,90,'景区停车场充足','贵阳/安顺客运+景区直通车',false,98,
 'official','https://www.hgsly.cn', now(), now(), 'verified', 0.92),

('22222222-2222-2222-2222-222222222002','11111111-1111-1111-1111-111111111003','龙宫','龙宫景区','贵州','安顺','西秀',105.7667,26.2667,
 '自然景观/溶洞','5A','以水溶洞、旱溶洞和龙门飞瀑著称的喀斯特景观。',NULL,NULL,150,
 180,'四季',2, 80,72,85,88,'有停车场','安顺市区约20km',false,85,
 'official','https://travel.qunar.com/p-oi6364108-longgongfengjingqu', now(), now(), 'pending', 0.65),
('22222222-2222-2222-2222-222222222003','11111111-1111-1111-1111-111111111003','天龙屯堡','天龙','贵州','安顺','平坝',106.0417,26.4167,
 '历史文化/古镇','4A','明代军屯后裔聚居地，保留地戏与石头建筑。',NULL,NULL,60,
 150,'四季',1, 78,75,80,82,'古镇停车场','安顺约20km',false,78,
 'official','https://www.tuniu.com/menpiao/9077', now(), now(), 'pending', 0.62),

('22222222-2222-2222-2222-222222222004','11111111-1111-1111-1111-111111111002','青岩古镇','青岩','贵州','贵阳','花溪',106.2644,26.3719,
 '历史文化/古镇','5A','贵阳南郊明清军事古镇，卤猪脚与状元蹄有名。',NULL,NULL,60,
 150,'四季',1, 82,80,78,85,'古镇停车场','贵阳地铁+接驳',false,90,
 'official',NULL, now(), now(), 'verified', 0.9),

('22222222-2222-2222-2222-222222222005','11111111-1111-1111-1111-111111111002','黔灵山公园','黔灵山','贵州','贵阳','云岩',106.7133,26.6222,
 '自然景观/城市公园','4A','市区山地公园，野生猕猴与弘福寺。',NULL,NULL,5,
 180,'四季',1, 85,78,70,75,'有停车场','公交/地铁',false,88,
 'official',NULL, now(), now(), 'verified', 0.9),

('22222222-2222-2222-2222-222222222006','11111111-1111-1111-1111-111111111004','西江千户苗寨','西江','贵州','黔东南','雷山',108.1711,26.4961,
 '历史文化/苗寨','4A','世界最大苗族聚居村寨，夜景与长桌宴。',NULL,NULL,90,
 240,'四季',1, 84,70,95,92,'景区停车场','凯里南站接驳',false,95,
 'official',NULL, now(), now(), 'verified', 0.9),

('22222222-2222-2222-2222-222222222007','11111111-1111-1111-1111-111111111002','贵州省博物馆','省博','贵州','贵阳','观山湖',106.6250,26.6350,
 '历史文化/博物馆','4A','贵州通史与民族文物常设展。室内馆。',NULL,NULL,0,
 120,'四季',0, 76,88,65,70,'地下停车场','地铁1号线',true,80,
 'official',NULL, now(), now(), 'verified', 0.93),

('22222222-2222-2222-2222-222222222008','11111111-1111-1111-1111-111111111003','格凸河','格凸河穿洞','贵州','安顺','紫云',106.1667,25.7500,
 '自然景观/峡谷','4A','蜘蛛人徒手攀崖表演与穿洞奇观。',NULL,NULL,100,
 240,'春夏',3, 70,55,88,80,'有停车场','安顺约1.5h',false,72,
 'official',NULL, now(), now(), 'verified', 0.84)
ON CONFLICT (id) DO NOTHING;

-- 标签
INSERT INTO attraction_tags (attraction_id, tag_key, score) VALUES
('22222222-2222-2222-2222-222222222001','nature',95),('22222222-2222-2222-2222-222222222001','photo',92),
('22222222-2222-2222-2222-222222222001','family',86),('22222222-2222-2222-2222-222222222001','drive',95),
('22222222-2222-2222-2222-222222222001','waterfall',98),('22222222-2222-2222-2222-222222222001','elderly',70),
('22222222-2222-2222-2222-222222222002','nature',90),('22222222-2222-2222-2222-222222222002','photo',85),
('22222222-2222-2222-2222-222222222003','history',92),('22222222-2222-2222-2222-222222222003','photo',80),
('22222222-2222-2222-2222-222222222004','history',94),('22222222-2222-2222-2222-222222222004','food',88),
('22222222-2222-2222-2222-222222222005','nature',88),('22222222-2222-2222-2222-222222222005','family',90),
('22222222-2222-2222-2222-222222222006','history',90),('22222222-2222-2222-2222-222222222006','night',95),
('22222222-2222-2222-2222-222222222007','history',95),('22222222-2222-2222-2222-222222222007','elderly',90),
('22222222-2222-2222-2222-222222222008','nature',93),('22222222-2222-2222-2222-222222222008','hiking',75)
ON CONFLICT DO NOTHING;

-- 票种
INSERT INTO attraction_tickets (attraction_id, name, price, eligibility, source_type, source_url, last_verified, verification_status) VALUES
('22222222-2222-2222-2222-222222222001','成人票',160,NULL,'official','https://www.hgsly.cn',now(),'verified'),
('22222222-2222-2222-2222-222222222001','学生票',90,'全日制学生','official','https://www.hgsly.cn',now(),'verified'),
('22222222-2222-2222-2222-222222222002','成人票',150,NULL,'official','https://travel.qunar.com/p-oi6364108-longgongfengjingqu',now(),'pending'),
('22222222-2222-2222-2222-222222222003','成人票',60,NULL,'official','https://www.tuniu.com/menpiao/9077',now(),'pending'),
('22222222-2222-2222-2222-222222222006','成人票',90,NULL,'official',NULL,now(),'pending')
ON CONFLICT DO NOTHING;

-- 开放时间
INSERT INTO attraction_hours (attraction_id, weekday, open_time, close_time, source_type, source_url, last_verified, verification_status) VALUES
('22222222-2222-2222-2222-222222222001',NULL,'07:00','18:00','official','https://www.hgsly.cn',now(),'verified'),
('22222222-2222-2222-2222-222222222002',NULL,'08:30','17:30','official','https://travel.qunar.com/p-oi6364108-longgongfengjingqu',now(),'pending'),
('22222222-2222-2222-2222-222222222003',NULL,'08:00','18:00','official','https://www.tuniu.com/menpiao/9077',now(),'pending'),
('22222222-2222-2222-2222-222222222004',NULL,'08:10','19:00','official',NULL,now(),'pending'),
('22222222-2222-2222-2222-222222222007',NULL,'09:00','17:00','official',NULL,now(),'pending');

-- 酒店
INSERT INTO hotels (id, destination_id, name, brand, address, longitude, latitude, price_min, price_max, rating, parking, breakfast, family_friendly, city, district, source_type, source_url, source_time, last_verified, verification_status, confidence) VALUES
('33333333-3333-3333-3333-333333333001','11111111-1111-1111-1111-111111111003','安顺黄果树希尔顿欢朋酒店',NULL,'安顺市西秀区',105.9320,26.2450,380,560,4.7,true,true,true,'安顺','西秀','platform','https://www.hilton.com.cn',now(),now(),'pending',0.7),
('33333333-3333-3333-3333-333333333002','11111111-1111-1111-1111-111111111003','安顺古城亚朵酒店',NULL,'安顺市虹山湖路',105.9400,26.2550,320,450,4.6,true,true,false,'安顺','西秀','platform','https://www.atour.com',now(),now(),'pending',0.7),
('33333333-3333-3333-3333-333333333003','11111111-1111-1111-1111-111111111003','镇宁黄果树景区民宿',NULL,'镇宁县黄果树镇',105.6800,25.9900,180,320,4.4,true,false,true,'安顺','镇宁','ugc',NULL,now(),now(),'pending',0.55),
('33333333-3333-3333-3333-333333333004','11111111-1111-1111-1111-111111111002','贵阳观山湖安缦',NULL,'贵阳市观山湖区',106.6200,26.6400,900,1500,4.8,true,true,true,'贵阳','观山湖','platform','https://www.aman.com',now(),now(),'pending',0.7),
('33333333-3333-3333-3333-333333333005','11111111-1111-1111-1111-111111111002','贵阳喷水池智选假日',NULL,'贵阳市云岩区',106.7100,26.6500,280,400,4.5,true,true,false,'贵阳','云岩','platform','https://www.holidayinn.com',now(),now(),'pending',0.7)
ON CONFLICT (id) DO NOTHING;

-- 餐厅
INSERT INTO restaurants (id, destination_id, name, category, city, district, longitude, latitude, price_per_person, rating, signature_dishes, opening_hours, parking, local_specialty, source_type, source_url, source_time, last_verified, verification_status, confidence) VALUES
('44444444-4444-4444-4444-444444444001','11111111-1111-1111-1111-111111111003','安顺夺夺粉','小吃','安顺','西秀',105.9325,26.2470,25,4.6,'夺夺粉、剪粉','10:00-21:00',true,true,'platform','https://www.dianping.com/',now(),now(),'pending',0.6),
('44444444-4444-4444-4444-444444444002','11111111-1111-1111-1111-111111111003','旧州辣子鸡','中餐','安顺','西秀',105.9100,26.2600,55,4.5,'旧州辣子鸡','11:00-21:00',true,true,'platform','https://www.dianping.com/',now(),now(),'pending',0.6),
('44444444-4444-4444-4444-444444444003','11111111-1111-1111-1111-111111111003','黄果树景区农家菜','农家菜','安顺','镇宁',105.6795,25.9910,45,4.3,'瀑汁鱼、野菜','08:00-20:00',true,true,'ugc',NULL,now(),now(),'pending',0.55),
('44444444-4444-4444-4444-444444444004','11111111-1111-1111-1111-111111111002','青岩状元蹄','小吃','贵阳','花溪',106.2650,26.3725,20,4.7,'状元猪脚','09:00-22:00',false,true,'platform','https://www.dianping.com/',now(),now(),'pending',0.6),
('44444444-4444-4444-4444-444444444005','11111111-1111-1111-1111-111111111002','贵阳酸汤鱼','火锅','贵阳','云岩',106.7150,26.6480,70,4.6,'酸汤鱼、洋芋粑','11:00-22:00',true,true,'platform','https://www.dianping.com/',now(),now(),'pending',0.6)
ON CONFLICT (id) DO NOTHING;

-- 来源调和（阶段 1.3）：所有 source_url 为空但标 verified 的行，一律降回 pending，
-- 防止未验证事实被当成确定性事实写入行程。
UPDATE attractions SET verification_status = 'pending', confidence = LEAST(confidence, 0.69)
WHERE source_url IS NULL AND verification_status = 'verified';
UPDATE hotels SET verification_status = 'pending', confidence = LEAST(confidence, 0.69)
WHERE source_url IS NULL AND verification_status = 'verified';
UPDATE restaurants SET verification_status = 'pending', confidence = LEAST(confidence, 0.69)
WHERE source_url IS NULL AND verification_status = 'verified';
UPDATE destinations SET verification_status = 'pending', confidence = LEAST(confidence, 0.69)
WHERE source_url IS NULL AND verification_status = 'verified';

-- 交通：贵阳 ↔ 安顺（阶段 1.1）
-- 注意：transportation 表在 0001 只有 source_type/last_verified/verification_status，
-- source_url/source_time/confidence/status 由 0002_fact_fields.sql 追加。
INSERT INTO transportation (origin, destination, mode, duration_min, distance_km, price, note, source_type, source_url, source_time, last_verified, verification_status, confidence, status) VALUES
-- 贵阳北 → 安顺西 高铁/动车：约29–50分钟，二等座 ¥45–56（来源：gaotie.com.cn 时刻表页，票价为铁路公布全票价，浮动以购票日为准）
('贵阳','安顺','rail',40,101.0,56,'贵阳北→安顺西，G/C/D 次约29–50分钟，二等座¥45–56','platform','https://www.gaotie.com.cn/lieche/guiyangbei-anshunxi.html',now(),now(),'pending',0.65,'open'),
-- 安顺西 → 贵阳北（返程，对称记录）
('安顺','贵阳','rail',40,101.0,56,'安顺西→贵阳北，G/C/D 次约29–50分钟，二等座¥45–56','platform','https://www.gaotie.com.cn/lieche/guiyangbei-anshunxi.html',now(),now(),'pending',0.65,'open'),
-- 贵阳 → 安顺 自驾：约 88.35 km / 1.3h，油费约¥53 + 路桥费约¥40（来源：车主手册路线页）
('贵阳','安顺','self_drive',78,88.35,93,'贵阳→安顺自驾约88.35km/1.3h，油费约¥53+路桥费约¥40（估算，车型/路况浮动）','platform','https://www.icauto.com.cn/route/348_351.html',now(),now(),'pending',0.65,'open'),
-- 安顺 → 贵阳（返程，对称记录）
('安顺','贵阳','self_drive',78,88.35,93,'安顺→贵阳自驾约88.35km/1.3h，油费约¥53+路桥费约¥40（估算，车型/路况浮动）','platform','https://www.icauto.com.cn/route/348_351.html',now(),now(),'pending',0.65,'open')
ON CONFLICT DO NOTHING;

-- 攻略来源与内容
INSERT INTO travel_sources (id, source_type, name, url, trust_tier) VALUES
('55555555-5555-5555-5555-555555555001','official','黄果树景区官网','https://www.hgsly.cn',1),
('55555555-5555-5555-5555-555555555002','ugc','游客经验汇总',NULL,3)
ON CONFLICT (id) DO NOTHING;

INSERT INTO travel_contents (id, source_id, attraction_id, title, summary, topic, source_url, last_verified, verification_status, confidence) VALUES
('66666666-6666-6666-6666-666666666001','55555555-5555-5555-5555-555555555001','22222222-2222-2222-2222-222222222001',
 '黄果树怎么玩：路线与拍照','建议先陡坡塘，再天星桥，最后大瀑布；雨季水量大更震撼，备雨衣。天星桥下半段精华别错过。',
 'route','https://www.hgsly.cn',now(),'verified',0.9),
('66666666-6666-6666-6666-666666666002','55555555-5555-5555-5555-555555555001','22222222-2222-2222-2222-222222222001',
 '黄果树门票与开放时间','成人票160元含三个小景区联票口径以官网为准；开放约07:00-18:00，旺季建议8点前入园。',
 'ticket',NULL,now(),'verified',0.92),
('66666666-6666-6666-6666-666666666003','55555555-5555-5555-5555-555555555002','22222222-2222-2222-2222-222222222001',
 '带老人怎么逛黄果树','老人可少走天星桥上段，优先大瀑布观景台与电梯；全程约4-5小时，中间休息两次。',
 'notice',NULL,now(),'pending',0.75),
('66666666-6666-6666-6666-666666666004','55555555-5555-5555-5555-555555555002','22222222-2222-2222-2222-222222222004',
 '青岩古镇避坑','主街商业化较重，可拐入背街石巷；猪脚选本地人排队的店；下午光线适合拍照。',
 'pitfall',NULL,now(),'pending',0.7),
('66666666-6666-6666-6666-666666666005','55555555-5555-5555-5555-555555555002','22222222-2222-2222-2222-222222222006',
 '西江夜景与长桌宴','下午进寨避开最晒，晚上观景台看万家灯火；长桌宴可提前订；苗服体验在古街。',
 'best_time',NULL,now(),'pending',0.72)
ON CONFLICT (id) DO NOTHING;

-- chunks（embedding 稍后由 ai 管线回填）
INSERT INTO travel_content_chunks (id, content_id, chunk_index, text) VALUES
('77777777-7777-7777-7777-777777777001','66666666-6666-6666-6666-666666666001',0,'黄果树建议先陡坡塘再天星桥最后大瀑布，雨季水量大备雨衣。'),
('77777777-7777-7777-7777-777777777002','66666666-6666-6666-6666-666666666002',0,'黄果树成人票160元，开放约07:00-18:00，旺季建议8点前入园。'),
('77777777-7777-7777-7777-777777777003','66666666-6666-6666-6666-666666666003',0,'带老人可少走天星桥上段，优先大瀑布观景台与电梯，全程4-5小时。'),
('77777777-7777-7777-7777-777777777004','66666666-6666-6666-6666-666666666004',0,'青岩古镇可拐背街石巷，猪脚选本地人排队店。'),
('77777777-7777-7777-7777-777777777005','66666666-6666-6666-6666-666666666005',0,'西江下午进寨，晚上观景台看灯火，长桌宴可提前订。')
ON CONFLICT DO NOTHING;

-- 管理员（开发默认密码 admin123 的散列由 API register 生成；此处直接插 hash 占位）
INSERT INTO users (id, phone, email, password_hash, display_name, role) VALUES
('99999999-9999-9999-9999-999999999001','13800000000','admin@youpji.local',
 -- password: admin123  —— 与 auth crate 算法一致的开发占位，首次可走 API 重置
 'x6a0f5e2c1b8d4a7','admin')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 贵州其余 6 个市/州（行政区划，非景区事实）
-- 说明：本批为行政区中心坐标，来源标注省级行政区划口径，
-- 但未经人工核验，统一落 pending，交 Admin 审核流复核后再改 verified。
-- ============================================================
INSERT INTO destinations (id, name, level, full_path, longitude, latitude, source_type, source_url, source_time, last_verified, verification_status, confidence) VALUES
  ('11111111-1111-1111-1111-111111111007','六盘水','city','贵州/六盘水',104.8467,26.5844,'government','https://www.gzlk.gov.cn', now(), NULL, 'pending', 0.6),
  ('11111111-1111-1111-1111-111111111008','遵义','city','贵州/遵义',106.9373,27.7066,'government','https://www.zunyi.gov.cn', now(), NULL, 'pending', 0.6),
  ('11111111-1111-1111-1111-111111111009','毕节','city','贵州/毕节',105.2850,27.3017,'government','https://www.bijie.gov.cn', now(), NULL, 'pending', 0.6),
  ('11111111-1111-1111-1111-111111111010','铜仁','city','贵州/铜仁',109.1913,27.7183,'government','https://www.tongren.gov.cn', now(), NULL, 'pending', 0.6),
  ('11111111-1111-1111-1111-111111111011','黔西南','city','贵州/黔西南',104.8979,25.0881,'government','https://www.qxn.gov.cn', now(), NULL, 'pending', 0.6),
  ('11111111-1111-1111-1111-111111111012','黔南','city','贵州/黔南',107.5172,26.2582,'government','https://www.qn.gov.cn', now(), NULL, 'pending', 0.6)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 景区数据（自动生成，请勿手工编辑）
-- 生成命令：npm run attractions:build
-- 票价来源：贵州省人民政府「景点名录」https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/
--         （一级政府来源，532 家 A 级景区，含是否收门票与政府定价）
-- 坐标：OSM/Nominatim WGS-84 → 流水线折算为 GCJ-02（DESIGN §4.2 全局统一 GCJ-02）
-- 开放时间：政府名录不含该字段，故多数记录落 pending；排线时以 08:00-18:00 兜底并告警
-- 关卡：verified 须票与时间双来源；无坐标不入库；坐标系无法判定不入库
-- 数量：48 条（名录 532 条中 48 条已取得坐标）
-- ============================================================
-- 自动生成，请勿手工编辑
-- 来源：scripts/import-attractions.mjs 校验通过后输出
-- 规则：verified 必有 source_url 且 confidence ≥ 0.7；事实缺失一律落 pending/unverified
INSERT INTO attractions (
  name, alias, city, district, longitude, latitude, category, level, description,
  opening_time, closing_time, ticket_price, recommended_duration_min, best_season,
  difficulty, family_score, elderly_score, photography_score, couple_score,
  source_type, source_url, last_verified, verification_status, confidence
) VALUES
  ('赤水丹霞', '赤水丹霞', '遵义', '赤水', 105.744471, 28.356266, '自然景观/丹霞', '5A', '', NULL, NULL, 180, 480, '夏秋', 4, 55, 30, 90, 70, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('赤水丙安古镇', '丙安古镇', '遵义', '赤水', 105.823617, 28.471616, '人文古镇', '4A', '', NULL, NULL, 10, 120, '秋', 2, 55, 40, 80, 65, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.8),
  ('汇川海龙屯', '海龙屯', '遵义', '汇川', 106.819958, 27.809255, '历史遗迹', '4A', '', NULL, NULL, 65, 150, '秋', 3, 50, 40, 70, 55, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('习水土城古镇', '土城古镇', '遵义', '习水', 106.006248, 28.27297, '红色人文', '4A', '', NULL, NULL, 0, 120, '秋', 2, 55, 45, 70, 60, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.8),
  ('赤水四洞沟', '四洞沟', '遵义', '赤水', 105.649376, 28.459148, '自然景观/瀑布峡谷', '4A', '', NULL, NULL, 75, 180, '夏', 3, 55, 35, 85, 70, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('仁怀茅台酒镇', '茅台酒镇', '遵义', '仁怀', 106.366169, 27.84047, '人文古镇', '4A', '', NULL, NULL, 0, 180, '全年', 2, 55, 50, 70, 70, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.8),
  ('绥阳双河洞', '双河洞', '遵义', '绥阳', 107.279289, 28.239989, '自然景观/溶洞', '4A', '', NULL, NULL, 130, 180, '夏', 3, 55, 35, 75, 65, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('仁怀茅台中国酒文化城', '中国酒文化城', '遵义', '仁怀', 106.372481, 27.851876, '人文展馆', '4A', '', NULL, NULL, 60, 120, '全年', 1, 60, 60, 60, 60, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('新蒲水上大天门旅游景区（云门囤景区）', '云门囤', '遵义', '新蒲新区', 107.326356, 27.661134, '自然景观/山水', '4A', '', NULL, NULL, 40, 150, '夏', 3, 55, 35, 80, 70, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('汇川娄山关', '娄山关', '遵义', '汇川', 106.85742, 28.02275, '红色人文', '4A', '', NULL, NULL, 0, 90, '秋', 2, 50, 45, 75, 55, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.8),
  ('遵义会议会址', '遵义会议会址', '遵义', '红花岗', 106.919902, 27.687963, '红色人文', '4A', '', '08:30', '21:00', 0, 150, '全年', 1, 70, 65, 60, 60, 'official', 'https://www.zunyihy.cn/n167/index.html', now(), 'verified', 0.95),
  ('百里杜鹃', '百里杜鹃', '毕节', '百里杜鹃管理区', 105.934779, 27.175818, '自然景观/花海', '5A', '', NULL, NULL, 130, 420, '春', 3, 65, 45, 95, 75, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('织金洞', '织金洞', '毕节', '织金', 105.90073, 26.769706, '自然景观/溶洞', '5A', '', '08:30', '17:00', 110, 180, '全年', 3, 60, 40, 85, 70, 'official', 'https://www.zjdgeopark.com/cn/document/785.html', now(), 'verified', 0.95),
  ('大方奢香古镇', '奢香古镇', '毕节', '大方', 105.605438, 27.187098, '人文古镇', '4A', '', NULL, NULL, 0, 120, '全年', 1, 60, 55, 70, 65, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.8),
  ('赫章阿西里西韭菜坪', '韭菜坪', '毕节', '赫章', 104.695753, 26.848933, '自然景观/草原', '4A', '', NULL, NULL, 40, 180, '夏', 3, 55, 35, 80, 65, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('赫章阿西里西二台坡', '二台坡', '毕节', '赫章', 104.86403, 27.012074, '自然景观/草原', '4A', '', NULL, NULL, 20, 150, '夏', 2, 55, 40, 75, 60, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('七星关鸡鸣三省', '鸡鸣三省', '毕节', '七星关', 105.309699, 27.702577, '自然景观/峡谷', '4A', '', NULL, NULL, 20, 120, '秋', 2, 55, 40, 75, 60, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.85),
  ('梵净山', '梵净山西线', '铜仁', '印江', 108.696317, 27.915959, '自然景观/山岳', '5A', '梵净山西线徒步登山入口，官方明确无索道。', '06:30', NULL, 3, 600, '春秋', 5, 15, 5, 88, 60, 'government', 'https://www.guizhou.gov.cn/ztzl/wzgz/yzgz/jdml/', NULL, 'pending', 0.8),
  ('兴义万峰林', '万峰林', '黔西南', '兴义', 104.926075, 24.971762, '自然景观/喀斯特峰林', '5A', '中国锥状喀斯特最典型的发育代表区，峰林与布依村寨田坝相间。', '08:00', '18:00', 70, 300, '春秋', 2, 80, 75, 90, 78, 'official', 'https://www.wanfenglin.cn/piaowuxinxi.html', now(), 'verified', 0.9),
  ('黄果树瀑布景区', '黄果树', '安顺', '镇宁', 105.669501, 25.989091, '自然景观/瀑布', '5A', '以大瀑布、陡坡塘瀑布群、天星桥三片区组成的世界级喀斯特瀑布群', '06:30', '18:30', 160, 300, '夏秋', 3, 70, 40, 95, 80, 'official', 'https://www.hgscn.com/hgs/jqgg/202607/20260709_07479175.shtml', NULL, 'pending', 0.75),
  ('旧州古镇', '旧州', '安顺', '西秀', 106.141053, 26.248915, '历史文化/古镇', '4A', '安顺州古治府所在，2008年入选中国第四批历史文化名镇', NULL, NULL, NULL, 120, '春秋', 1, 55, 65, 65, 60, 'government', 'https://www.anshun.gov.cn/ztzl/rdzt/aswlxhj/360ddj/hxjq/202607/t20260727_90663501.html', NULL, 'unverified', 0.4),
  ('青岩古镇', '青岩', '贵阳', '花溪', 106.687033, 26.330432, '历史文化/古镇', '5A', '始建于明洪武年间的军事屯堡古镇，明清古建筑群保存完整', '08:30', '17:00', 10, 150, '春秋', 1, 70, 60, 75, 70, 'platform', 'https://m.gy.bendibao.com/mip/65209.shtm', NULL, 'pending', 0.6),
  ('天河潭旅游度假区', '天河潭', '贵阳', '花溪', 106.577286, 26.437085, '自然景观/喀斯特', '4A', '喀斯特山水与隐士文化结合的度假区，含天河潭、水车、水幕秀', '08:30', '18:00', NULL, 180, '夏秋', 2, 75, 50, 70, 75, 'platform', 'https://m.gy.bendibao.com/mip/65692.shtm', NULL, 'pending', 0.55),
  ('贵州省博物馆', '贵博', '贵阳', '观山湖', 106.64264, 26.647556, '文化场馆/博物馆', NULL, '贵州省文化和旅游厅所属综合性博物馆，藏品8万余件', '09:00', '17:00', 0, 150, '四季', 1, 75, 70, 45, 60, 'official', 'https://www.gzmuseum.com/gbgg/202208/460.html', now(), 'verified', 0.9),
  ('甲秀楼（翠微园）', '甲秀楼', '贵阳', '南明', 106.719706, 26.57142, '历史文化/古建筑', NULL, '南明河畔的明代三层木楼，与翠微园、浮玉桥组成甲秀景区', '09:00', '18:00', 0, 60, '四季', 1, 70, 70, 85, 80, 'government', 'https://www.guiyang.gov.cn/zwgk/zwgkxwdt/zwgkxwdtjrgy/202510/t20251011_88684779.html', NULL, 'pending', 0.65),
  ('黔灵山公园', '黔灵山', '贵阳', '云岩', 106.694088, 26.598021, '自然景观/城市公园', NULL, '贵阳市区大型山体公园，含动物园与大熊猫馆，猕猴群栖', NULL, NULL, 0, 180, '春秋', 2, 80, 65, 60, 65, 'platform', 'https://m.gy.bendibao.com/mip/78755.shtm', NULL, 'pending', 0.45),
  ('鲍家屯', '鲍家屯', '安顺', '西秀', 106.12274, 26.327391, '历史文化/屯堡', NULL, '安顺市政府核心景区栏目收录的屯堡村落', NULL, NULL, NULL, 90, '春秋', 1, 45, 60, 60, 50, 'government', 'https://www.anshun.gov.cn/ztzl/rdzt/aswlxhj/360ddj/hxjq/202607/t20260727_90663501.html', NULL, 'unverified', 0.25),
  ('乌蒙大草原景区', '乌蒙大草原', '六盘水', '盘州', 104.611807, 26.156169, '自然景观/高山草原', '4A', '海拔2000-2857米的西南最大天然草场，四季皆可游。', '08:00', '20:00', NULL, 300, '夏', 3, 65, 35, 88, 72, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029534.html', NULL, 'pending', 0.85),
  ('妥乐古银杏旅游景区', '妥乐古银杏', '六盘水', '盘州', 104.55199, 25.607063, '自然景观/古银杏群落', '4A', '1450余株千年古银杏集中成片，秋日金黄村落景观。', '08:30', '17:30', 30, 210, '秋', 2, 72, 60, 90, 78, 'official', 'https://tuoleguyinxing.com/?type=text&S_id=42&lang=cn', now(), 'verified', 0.92),
  ('梅花山旅游景区', '梅花山', '六盘水', '钟山', 104.731631, 26.615467, '自然景观/山地度假区', '4A', '含国际滑雪场与9.91公里同路径山地索道，四季皆宜。', '09:00', '17:00', NULL, 300, '冬', 3, 70, 45, 80, 65, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029547.html', NULL, 'pending', 0.85),
  ('玉舍森林旅游景区', '玉舍森林公园', '六盘水', '水城', 104.802859, 26.450764, '自然景观/森林公园', '4A', '面积34平方公里的天然氧吧，含中国纬度最低滑雪场。', '09:00', '20:00', NULL, 240, '冬', 3, 68, 50, 75, 62, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029540.html', NULL, 'pending', 0.82),
  ('明湖国家湿地公园', '明湖湿地公园', '六盘水', '钟山', 104.76397, 26.590876, '自然景观/城市湿地', '3A', '贵州首个国家级湿地公园，中心城区城市绿肺，全天免费。', '00:00', '23:59', 0, 120, '夏', 1, 85, 80, 60, 70, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029544.html', now(), 'verified', 0.88),
  ('贵州三线建设博物馆', '三线建设博物馆', '六盘水', '钟山', 104.878208, 26.57441, '人文历史/博物馆', '4A', '展示三线建设历史的室内场馆，紧邻水城古镇。', '09:00', '17:00', NULL, 90, '秋', 1, 80, 78, 45, 58, 'government', 'https://www.gzlps.gov.cn/rdzt/lpslyfw/mlcx/jdml_5973303/lyjd/202411/t20241106_86029548.html', NULL, 'pending', 0.83),
  ('北盘江大桥（都格北盘江第一桥）观景点', '北盘江大桥', '六盘水', '水城', 104.679085, 26.384446, '地标/工程景观', NULL, '桥面距谷底565.4米的世界第一高桥，观景台俯瞰云贵大裂谷。', NULL, NULL, NULL, 90, '秋', 2, 55, 30, 92, 68, 'map', NULL, NULL, 'unverified', 0.5),
  ('水城古镇', '水城古镇', '六盘水', '钟山', 104.877708, 26.573711, '人文古镇', NULL, '始建雍正十年的古镇，保留三线建设苏式建筑遗存。', NULL, NULL, NULL, 150, '夏', 1, 78, 72, 65, 72, 'map', NULL, NULL, 'unverified', 0.45),
  ('荔波小七孔景区', '小七孔', '黔南', '荔波', 107.715577, 25.260352, '自然景观/喀斯特', '5A', '樟江景区喀斯特湖泊群，68级跌水瀑布与68级碧潭', '08:00', '16:00', 120, 300, '夏', 3, 70, 45, 95, 80, 'platform', 'https://gy.bendibao.com/tour/2023417/65383.shtm', NULL, 'pending', 0.8),
  ('西江千户苗寨', '西江', '黔东南', '雷山', 108.174467, 26.49218, '民族村寨', '4A', '雷公山麓最大苗族聚居村寨，吊脚楼依山层叠、白水河穿寨', '07:00', '01:00', NULL, 360, '四季', 2, 75, 60, 90, 85, 'platform', 'https://you.ctrip.com/sight/leishan2345/44302.html', NULL, 'pending', 0.7),
  ('肇兴侗寨', '肇兴', '黔东南', '黎平', 109.174519, 25.905566, '民族村寨', '4A', '侗乡第一寨，五座鼓楼与风雨桥构成侗族村寨代表景观', NULL, NULL, 80, 180, '四季', 1, 70, 75, 85, 80, 'platform', 'http://m.gy.bendibao.com/tour/67236.shtm', NULL, 'pending', 0.75),
  ('岜沙苗寨', '岜沙', '黔东南', '从江', 108.874765, 25.72667, '民族村寨', '4A', '被称为中国最后一个枪手部落，保留镰刀剃头与火枪队列', '08:30', '18:00', 60, 180, '秋', 2, 65, 55, 80, 72, 'platform', 'https://gs.ctrip.com/html5/you/sight/congjiang2344/44294.html', NULL, 'pending', 0.7),
  ('占里侗寨', '占里', '黔东南', '从江', 108.921996, 25.847411, '民族村寨', NULL, '从江境内规模较大的侗族村寨，鼓楼与侗族歌舞集中', NULL, NULL, 0, 120, '四季', 1, 60, 70, 72, 68, 'platform', 'https://gs.ctrip.com/html5/you/sight/congjiang2344/1417311.html', NULL, 'pending', 0.7),
  ('黄岗侗寨', '黄岗', '黔东南', '黎平', 108.984184, 25.92259, '民族村寨', NULL, '黎平双江镇侗寨，商业化程度低，寨内步道适合徒步', NULL, NULL, 0, 120, '四季', 1, 62, 68, 70, 66, 'platform', 'https://gs.ctrip.com/html5/you/sight/liping1346/136058.html', NULL, 'pending', 0.7),
  ('雷公山国家森林公园', '雷公山', '黔东南', '雷山', 108.164842, 26.361629, '自然景观/森林', '4A', '苗岭主峰原始森林，高山峡谷与云海为主景观', '08:00', '18:00', NULL, 420, '夏', 4, 45, 30, 78, 60, 'platform', 'https://gs.ctrip.com/html5/you/sight/leishan2345/21917.html', NULL, 'pending', 0.7),
  ('加榜梯田', '加榜', '黔东南', '从江', 108.571454, 25.595816, '自然景观/梯田', '4A', '从江高山峡谷中的连片梯田，观景公路可近距离穿行', NULL, NULL, NULL, 240, '秋', 3, 55, 38, 92, 70, 'platform', 'https://you.ctrip.com/destinationsite/sight/congjiang2344/132880-traffic.html', NULL, 'pending', 0.65),
  ('堂安侗寨', '堂安', '黔东南', '黎平', 109.215852, 25.901177, '民族村寨', NULL, '肇兴侗寨群旁的山地侗寨，梯田与鼓楼组合景观', NULL, NULL, NULL, 150, '四季', 2, 58, 60, 78, 70, 'platform', 'https://you.ctrip.com/sight/liping1346/145631.html', NULL, 'pending', 0.55),
  ('瑶山古寨', '瑶山古寨', '黔南', '荔波', 107.777138, 25.236142, '民族村寨', '4A', '白裤瑶族聚居地，毗邻小七孔，含瑶族文化展演', '08:30', '21:30', 50, 180, '四季', 1, 70, 68, 76, 72, 'platform', 'https://gs.ctrip.com/html5/you/sight/libo659/141396.html', NULL, 'pending', 0.7),
  ('水春河景区', '水春河', '黔南', '荔波', 107.924887, 25.468502, '自然景观/峡谷漂流', NULL, '樟江支流峡谷河段，清凉漂流与亲水项目为主', '07:30', '17:00', NULL, 180, '夏', 2, 65, 45, 72, 74, 'platform', 'https://gs.ctrip.com/html5/you/sight/libo659/144189251.html', NULL, 'pending', 0.6),
  ('马岭河峡谷风景名胜区', '马岭河峡谷', '黔西南', '兴义', 104.956847, 25.135696, '自然景观/峡谷', '4A', '兴义城东北的地缝型喀斯特峡谷，谷内瀑布群密集。', NULL, NULL, NULL, 240, '夏秋', 4, 55, 30, 88, 72, 'official', 'https://www.wanfenglin.com/malinghedaxiagu/898.html', NULL, 'unverified', 0.3),
  ('万峰湖景区', '万峰湖', '黔西南', '兴义', 104.863727, 24.732744, '自然景观/湖泊', NULL, '天生桥水电站形成的高原人工淡水湖，中国第一大人工湖。', NULL, NULL, NULL, 180, '春秋', 1, 65, 70, 78, 70, 'official', 'https://www.wanfenglin.com/wanfenghu/417.html', NULL, 'unverified', 0.3)
ON CONFLICT DO NOTHING;
