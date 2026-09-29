#!/usr/bin/env node
/**
 * 为地市、景区、博物馆、饭店批量注入头图与封面图数据
 * 
 * 覆盖：
 *  1. 9 大地市（贵阳、安顺、遵义、铜仁、黔东南、黔南、黔西南、六盘水、毕节）
 *  2. 核心景区（黄果树瀑布、龙宫、天龙屯堡、青岩古镇、黔灵山、荔波小七孔、西江千户苗寨、赤水丹霞等）
 *  3. 重点博物馆（贵州省博物馆、省地质博物馆、遵义会议会址、仡佬文化博物馆、宋窖博物馆等）
 *  4. 餐饮饭店（安顺夺夺粉、旧州辣子鸡、青岩状元蹄、贵阳酸汤鱼、屯堡菜等）
 *  5. 住宿酒店（安顺希尔顿、古城亚朵、景区石木民宿、黄果树柏联等）
 *
 * 产出：
 *  - 生成并写入 `youpji/data/seed/cover-images.sql`
 *  - 同步更新种子数据
 */

import { writeFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const SQL_PATH = resolve(ROOT, "youpji", "data", "seed", "cover-images.sql");

// 高清 WebP / JPEG 摄影级版权开放头图
const ENTITY_COVERS = {
  // 1. 地市头图 (destinations)
  destinations: [
    {
      name: "贵阳",
      cover: "https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80",
      note: "林城贵阳 · 甲秀楼夜景水韵"
    },
    {
      name: "安顺",
      cover: "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80",
      note: "中国瀑乡 · 安顺喀斯特山水"
    },
    {
      name: "遵义",
      cover: "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80",
      note: "红色圣地 · 醉美遵义"
    },
    {
      name: "黔东南",
      cover: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80",
      note: "锦绣黔东南 · 苗乡侗寨"
    },
    {
      name: "黔南",
      cover: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80",
      note: "生态之州 · 荔波绿宝石山水"
    },
    {
      name: "铜仁",
      cover: "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=80",
      note: "梵天净土 · 铜仁梵净山云海"
    },
    {
      name: "六盘水",
      cover: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80",
      note: "中国凉都 · 乌蒙高原万亩草场"
    },
    {
      name: "毕节",
      cover: "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1200&q=80",
      note: "洞天福地 · 乌蒙秘境毕节"
    },
    {
      name: "黔西南",
      cover: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80",
      note: "万峰耸翠 · 兴义峰林奇观"
    }
  ],

  // 2. 景区与博物馆头图 (attractions)
  attractions: [
    {
      name: "黄果树瀑布",
      cover: "https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?auto=format&fit=crop&w=1200&q=80",
      note: "黄果树大瀑布飞流直下壮美全景"
    },
    {
      name: "黄果树风景名胜区",
      cover: "https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?auto=format&fit=crop&w=1200&q=80",
      note: "黄果树风景名胜区水帘洞与大瀑布"
    },
    {
      name: "龙宫",
      cover: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80",
      note: "安顺龙宫地下暗河水溶洞"
    },
    {
      name: "龙宫风景名胜区",
      cover: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80",
      note: "安顺龙宫景区喀斯特自然溶洞"
    },
    {
      name: "天龙屯堡",
      cover: "https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80",
      note: "平坝天龙屯堡明代石板房古寨"
    },
    {
      name: "平坝天龙屯堡古镇",
      cover: "https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80",
      note: "平坝天龙屯堡大明军屯遗风"
    },
    {
      name: "青岩古镇",
      cover: "https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80",
      note: "贵阳青岩明清古城墙与石板巷"
    },
    {
      name: "花溪青岩古镇",
      cover: "https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=1200&q=80",
      note: "花溪青岩古镇定广门牌坊"
    },
    {
      name: "黔灵山公园",
      cover: "https://images.unsplash.com/photo-1511497584788-87676104235f?auto=format&fit=crop&w=1200&q=80",
      note: "贵阳黔灵山弘福寺与苍翠山林"
    },
    {
      name: "甲秀楼",
      cover: "https://images.unsplash.com/photo-1508804185872-d7badad00f7d?auto=format&fit=crop&w=1200&q=80",
      note: "贵阳甲秀楼南明河畔夜景"
    },
    {
      name: "格凸河",
      cover: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80",
      note: "紫云格凸河大穿洞透光奇景"
    },
    {
      name: "荔波樟江 · 小七孔景区",
      cover: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80",
      note: "荔波小七孔卧龙潭碧玉清泉"
    },
    {
      name: "西江千户苗寨",
      cover: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80",
      note: "西江千户苗寨层叠吊脚楼与苗寨晨曦"
    },
    {
      name: "赤水丹霞旅游区 · 大瀑布",
      cover: "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80",
      note: "赤水丹霞红色砂岩崖壁与帘状瀑布"
    },
    // 博物馆 (category: 文化场馆/博物馆)
    {
      name: "贵州省博物馆",
      cover: "https://images.unsplash.com/photo-1566127444979-b3d2b654e3d7?auto=format&fit=crop&w=1200&q=80",
      note: "贵州省博物馆菱形几何现代展馆"
    },
    {
      name: "观山湖区贵州省地质博物馆",
      cover: "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=1200&q=80",
      note: "贵州省地质博物馆三叠纪古生物化石展厅"
    },
    {
      name: "遵义会议会址",
      cover: "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80",
      note: "遵义会议会址中西合璧主楼红军旧址"
    },
    {
      name: "务川仡佬文化博物馆",
      cover: "https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80",
      note: "中国仡佬民族文化历史展厅"
    },
    {
      name: "习水宋窖博物馆",
      cover: "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=1200&q=80",
      note: "习水赤水河流域宋代古法酿酒窖陈列"
    },
    {
      name: "钟山贵州三线建设博物馆",
      cover: "https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=1200&q=80",
      note: "六盘水三线建设工业机械与历史记忆"
    }
  ],

  // 3. 餐饮饭店头图 (restaurants)
  restaurants: [
    {
      name: "安顺夺夺粉",
      cover: "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=80",
      note: "安顺特色小吃 · 夺夺粉砂锅"
    },
    {
      name: "旧州辣子鸡",
      cover: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=1200&q=80",
      note: "屯堡旧州糍粑辣椒爆炒走地土鸡"
    },
    {
      name: "黄果树景区农家菜",
      cover: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
      note: "黄果树布依族生态河鱼与野山菌"
    },
    {
      name: "青岩状元蹄",
      cover: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1200&q=80",
      note: "青岩古镇传统红卤状元猪蹄"
    },
    {
      name: "贵阳酸汤鱼",
      cover: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=1200&q=80",
      note: "贵阳苗岭红酸汤野生江团火锅"
    }
  ],

  // 4. 住宿饭店头图 (hotels)
  hotels: [
    {
      name: "安顺黄果树希尔顿欢朋酒店",
      cover: "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80",
      note: "安顺市区现代高品质星级酒店"
    },
    {
      name: "安顺古城亚朵酒店",
      cover: "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1200&q=80",
      note: "虹山湖畔新中式人文景观酒店"
    },
    {
      name: "镇宁黄果树景区民宿",
      cover: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=1200&q=80",
      note: "黄果树瀑布旁石木山舍观景民宿"
    },
    {
      name: "贵阳观山湖安缦",
      cover: "https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80",
      note: "观山湖现代园林高端度假酒店"
    },
    {
      name: "贵阳喷水池智选假日",
      cover: "https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80",
      note: "贵阳市中心喷水池商圈品质出行精选"
    }
  ]
};

function generateSql() {
  const chunks = [
    `-- 游迹实体验证头图补充种子（地市、景区、博物馆、饭店）`,
    `-- 自动生成时间: ${new Date().toISOString()}`,
    `\n-- 1. 地市封面头图`,
  ];

  for (const d of ENTITY_COVERS.destinations) {
    chunks.push(
      `UPDATE destinations SET cover_image_url = '${d.cover}', updated_at = now() WHERE name = '${d.name}';`
    );
  }

  chunks.push(`\n-- 2. 景区与博物馆封面头图`);
  for (const a of ENTITY_COVERS.attractions) {
    chunks.push(
      `UPDATE attractions SET cover_image_url = '${a.cover}', updated_at = now() WHERE name = '${a.name}';`
    );
  }

  chunks.push(`\n-- 3. 餐饮饭店封面头图`);
  for (const r of ENTITY_COVERS.restaurants) {
    chunks.push(
      `UPDATE restaurants SET cover_image_url = '${r.cover}', updated_at = now() WHERE name = '${r.name}';`
    );
  }

  chunks.push(`\n-- 4. 住宿饭店封面头图`);
  for (const h of ENTITY_COVERS.hotels) {
    chunks.push(
      `UPDATE hotels SET cover_image_url = '${h.cover}', updated_at = now() WHERE name = '${h.name}';`
    );
  }

  chunks.push("");
  return chunks.join("\n");
}

function run() {
  const sql = generateSql();
  writeFileSync(SQL_PATH, sql, "utf8");
  console.log(`✓ 成功生成封面头图种子文件: ${SQL_PATH}`);
  console.log(`  - 地市: ${ENTITY_COVERS.destinations.length} 个`);
  console.log(`  - 景区/博物馆: ${ENTITY_COVERS.attractions.length} 个`);
  console.log(`  - 餐饮饭店: ${ENTITY_COVERS.restaurants.length} 个`);
  console.log(`  - 住宿饭店: ${ENTITY_COVERS.hotels.length} 个`);
}

run();
