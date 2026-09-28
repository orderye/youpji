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
