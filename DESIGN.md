# DESIGN.md — 游迹架构与设计约定

本文件是游迹的**设计权威**：架构分层、数据模型、AI 边界、路线引擎、API 契约、后台与数据治理。产品范围与工作规则见 `AGENTS.md`；完整产品叙述见《游迹 AI 旅游平台 V0.1 完整研发方案》。

## 1. 系统总览

```text
用户（Flutter App / Web / Admin）
        │  HTTPS JSON
        ▼
┌─────────────────── Axum API (/api/v1) ───────────────────┐
│ auth · user · destination · attraction · hotel           │
│ restaurant · content · itinerary · route · weather · ai  │
└───────┬───────────────────┬───────────────────┬──────────┘
        │                   │                   │
        ▼                   ▼                   ▼
   PostgreSQL          AI Gateway          Redis
  + PostGIS            ┌────┴────┐        缓存/队列/限流
  + pgvector           ▼         ▼
   业务/地理/向量     云端 LLM   本地 Ollama
        ▲               规划/对话  清洗/分类/Embedding
        │
   Worker · Scheduler（采集、质检、天气、审核流）
        │
   外部：高德/百度地图 · 天气 API · 门票/官方源 · S3 存储
```

**八大系统边界**：① 用户 ② 旅游资源 ③ 攻略内容 ④ AI 规划 ⑤ 路线 ⑥ 实时旅行 ⑦ 推荐 ⑧ 商业化。V0.1 实现 ①–⑤ 的最小闭环 + ③ 只读摘要；⑥⑦⑧ 仅留 schema/接口占位，不做完整逻辑。

## 2. 产品核心闭环（设计约束一切模块）

```text
需求输入 → AI 需求结构化 → 景区候选池召回 → 路线算法
   → 景区+酒店+餐厅+门票 → AI 生成结构化行程 → 用户确认
   → 执行/实时调整 → 反馈 → 旅行画像 → 下次规划
```

任何新功能必须能回答：它挂在闭环的哪一环？挂不上则不属于 V0.1。

## 3. 目录与 Crate 设计

```text
youpji/
├── backend/
│   ├── apps/
│   │   ├── api/          # HTTP 入口，路由 + DTO 映射
│   │   ├── worker/       # 异步任务：采集、embedding、质检
│   │   └── scheduler/    # 定时：天气、数据巡检、过期提醒
│   ├── crates/
│   │   ├── auth/           # 登录、会话、RBAC（user/admin）
│   │   ├── user/           # 用户、偏好、travel_profile
│   │   ├── destination/    # 目的地（省/市/区层级）  ※ 从 attraction 中拆出
│   │   ├── attraction/     # 景区、标签、图片、 hours、tickets、园区路线
│   │   ├── hotel/          # 酒店/民宿
│   │   ├── restaurant/     # 餐厅/菜品
│   │   ├── content/        # 攻略、来源、chunks（RAG）
│   │   ├── itinerary/      # 行程、按天、节点、预算
│   │   ├── route/          # 距离矩阵、评分、排线、局部重规划
│   │   ├── recommendation/ # 召回与画像（V0.1 规则版）
│   │   ├── weather/        # 天气接入与缓存
│   │   ├── review/         # 审核队列、营业时段比对采纳、审计日志、仪表盘统计
│   │   ├── ai/             # AI Gateway、prompt、JSON schema、校验
│   │   └── common/         # 错误类型、ID、分页、时间、geo 类型
│   ├── migrations/
│   ├── configs/            # 分层配置：default → env → file
│   └── docker/
├── frontend/     # Flutter
├── admin/        # 管理端 SPA
├── ai/           # 离线数据管线（清洗→实体→标签→embedding）
├── data/         # 种子与采集产物（JSONL/CSV，可追溯 source）
└── deploy/       # docker-compose：postgres redis api worker admin web
```

依赖方向：`apps/* → crates/* → common`；领域 crate 互依只允许通过明确的窄接口（如 `itinerary → route`），禁止 `route → ai` 反向依赖。HTTP 框架类型不得泄漏进领域 crate 签名。

## 4. 数据模型约定

### 4.1 通用字段

所有可变资源表：

| 字段 | 说明 |
|---|---|
| `id` | 主键，对外 opaque（建议 UUID v7 或雪花） |
| `source_type` | `official \| government \| map \| platform \| ugc \| ai` |
| `source_url` | 原始出处 |
| `source_time` | 来源发布时间 |
| `last_verified` | 最近一次人工/流水线核验时间 |
| `verification_status` | `verified \| pending \| stale \| disputed \| unverified` |
| `confidence` | 0–1 或 `high/medium/low`，全局二选一，推荐数值 0–1 |
| `created_at` / `updated_at` | 必填 |

事实类字段（票价、开放时间、电话、营业时间）**禁止无来源裸写**；`unverified` 不得在 C 端当作确定事实展示（可进 `warnings`）。

### 4.2 地理

- 启用 **PostGIS**：`geography(Point, 4326)` 存经纬度；「附近 X km」用 `ST_DWithin`。
- 坐标系全局统一为 **GCJ-02**（国内地图源）；若入库源为 WGS84，入库时转换并记录 `coord_sys`。展示与路径规划必须同系，禁止混用。
- 行政区：`destinations` 树（省/市/区），景区外键指向叶子节点。

### 4.3 核心实体（与方案 §38–39 对齐）

**用户侧**

- `users` · `user_preferences` · `travel_profiles`（兴趣/强度/预算敏感度/节奏，0–100 分）
- `favorites` · `user_feedback`

**资源侧**

- `destinations`
- `attractions`：`name/alias`、行政区、`lng/lat`、`category`、`level`（如 5A）、`description`、`opening_time/closing_time`、`ticket_price`、`discount_info`、`recommended_duration`、`best_season`、`difficulty`、评分族 `family_score/elderly_score/photography_score/couple_score`、`parking/transport`
- `attraction_tags`：**受控词表**（自然景观/摄影/亲子/情侣/老人/徒步/自驾/历史文化/美食/购物/夜游…），每标签 0–100；禁止自由文本标签
- `attraction_images` · `attraction_hours`（可分日历/季节）· `attraction_tickets`（分人群票种）· `attraction_routes`（园区内游线与设施点位：停车/厕所/餐饮）
- `hotels` / `homestays` · `restaurants` + `restaurant_dishes` · `transportation`（班次/口岸）

**内容侧**

- `travel_sources`（来源与可信度）· `travel_contents`（摘要级正文）· `travel_content_chunks`（切块 + `embedding vector`，pgvector）
- 攻略主题枚举：`route | ticket | best_time | photo | parking | food | stay | pitfall | notice`

**行程侧**

- `itineraries` → `itinerary_days` → `itinerary_items`（节点：时间、地点、`distance`、`duration`、`cost`、`reason`、`notice`、`item_type=attraction|meal|hotel|transit|free`）
- `route_plans`（候选集、距离矩阵缓存、评分快照、算法版本 `algo_version`）
- `weather`（按目的地日粒度缓存）
- `recommendations`（占位）

关系保持：`User → TravelProfile/Preferences/Favorites/Itineraries → Days → Items`；`Destination → Attractions/Hotels/Restaurants/TravelContents`。

### 4.4 索引与扩展

- GIST：`attractions.lnglat`；GIN/向量索引：`travel_content_chunks.embedding`（HNSW 或 IVFFlat，数据量小用 HNSW）。
- 名称检索：`pg_trgm` on `name/alias`。
- 不在 V0.1 引入独立向量库；一切以 PostgreSQL 为准。

## 5. AI 边界（不可妥协）

```text
用户输入
  → LLM：需求结构化（严格 JSON schema，函数调用）
  → 代码：数据库召回候选景区/酒店/餐厅
  → 代码：路线算法（距离、时间窗、营业时间、预算、体力、优先级）
  → 代码：天气与门票实时校验
  → LLM：在已校验事实之上生成可读表述 + 建议文案
  → 结构化行程 JSON → 前端渲染
```

| 允许 LLM 做 | 禁止 LLM 做 |
|---|---|
| 自然语言 → 结构化槽位 | 断言票价/开放时间/是否开放 |
| 在给定候选集内选择与措辞 | 凭空发明景区、餐厅、道路 |
| 总结攻略摘要、打标签（待校验） | 替代距离/时间窗计算 |
| 生成注意事项、欢迎语 | 绕过 schema 直接输出行程大段文字 |

**结构化输出契约**（`POST /api/v1/ai/travel-plan`）：

输入：`origin, destination, start_date, end_date|days, people, budget, transport, interests[], avoid[], intensity, lodging_tier`（自然语言入口先过解析器填同一结构）。

输出顶层键固定：

```json
{
  "summary": {},
  "days": [],
  "budget": {},
  "hotels": [],
  "restaurants": [],
  "routes": [],
  "warnings": []
}
```

- `budget` 必须可加总且受**硬约束** `budget_limit`；超限在生成阶段失败并返回可解释错误，不得静默超支。
- 预算单价来自 **DB 中已验证**的酒店 `price_min` / 餐厅 `price_per_person`；取不到已验证记录时回落档位估算，并在 `warnings` 返回 `budget_rate_estimated`（事实类字段不得无来源裸写）。
- 预算装不下时先**降级重排**再失败，阶梯为：原方案 → 每天景点数降到 ≤2 → 降为经济档住宿 → 每天 1 个景点 + 经济档；全部档位仍超限才返回 `BUDGET_EXCEEDED`。降级发生时返回 `warnings[].code = plan_degraded` 并说明调整内容。
- `warnings[]`：`{code, message, ref}`，承载 `unverified` 事实、天气风险、营业时间冲突、`distance_estimated`、`budget_rate_estimated`、`plan_degraded`。
- schema 版本放 `ai` crate；破坏性变更升 `/api/v1` 内版本或 `X-Plan-Schema-Version`。

**三种规划模式**（经济/标准/舒适）：同一算法不同权重与资源档位，**不是**简单价格系数放大；输出 `mode` 字段标明。

## 6. 路线引擎（`route` crate）

原则：**AI 管理解，算法管计算。**

```text
候选景区 → 过滤（区域/类别/差评/关闭） → 距离矩阵（高德驾车路网，Redis 缓存）
  → 硬约束：天数与时段、营业时间、交通方式、预算上限、强度上限
  → 软评分 Route Score：
      景观价值 + 兴趣匹配 + 景区质量 + 攻略热度 + 季节适合度 + 时间匹配
      − 距离成本 − 时间成本 − 预算成本 − 疲劳成本
  → 排线/局部搜索 → itinerary_days
```

- **距离口径**：优先走高德 `distance` 驾车矩阵（`type=1`），对 Top-N 候选一次性取矩阵，Redis 缓存 30 天；无 `AMAP_KEY` 或外部不可用时降级为「直线距离 × 1.3」，并在 `warnings` 返回 `distance_estimated`。直线距离不得作为里程对外呈现为实测值。
- 管线拆分为可独立测试的阶段：`recall → score → matrix → pack_day（按天装包）→ budget_check`。其中 `pack_day` / `compute_budget` / `reflow_day_items` 为**纯函数**，不依赖数据库。
- **V0.1**：规则 + 加权评分 + 贪心/2-opt 级优化；`algo_version` 写入 `route_plans`。
- **后续**：TSP/VRP + 时间窗；再往后 ML/RL。不得在 V0.1 直接上重型求解器。
- **局部重规划**：输入 `{itinerary_id, edit_op}`（删/换/移节点），只重算受影响 day 及跨天 transit；其余天 `itinerary_items` 不变；结果 diff 返回。
- **重规划必须重算时间轴**：删除或跨天搬运节点后，当天剩余节点的 `start_time/end_time` 与 transit 的 `distance_km/duration_min` 一律重算，不得沿用旧值留下时间空洞。
- 时间节点字段：`time, location, distance, duration, cost, reason, notice`（对应方案 §9）。

## 7. RAG 与攻略流水线

```text
来源(1–4级) → 合法获取 → 摘要 → 结构化提取 → 事实交叉验证
  → AI 分类/主题 → 来源链接回写 → travel_contents / chunks → pgvector
```

- 检索：用户问题与「景区+主题+人群」组合 → embedding 相似 + 结构化过滤（景区 ID、主题）→ Top-k 进 LLM。
- 交叉验证：官方 > 地图 > 多攻略 > 住宿餐饮 > AI；冲突进 `verification_status=disputed`，C 端展示需人工或降级文案。
- 不做平台全文镜像；chunk 必须能回溯 `source_url`。

## 8. API 设计

- 前缀 `/api/v1`；REST 资源复数；错误体统一 `{code, message, details?}`；分页 `?page=&page_size=` 或 cursor，项目内统一一种（推荐 cursor + `next_cursor`）。
- 认证：`Authorization: Bearer`；admin 单独 role，不与 C 端共用权限。
- 规划相关（方案 §40–41 对齐）：

```text
POST /api/v1/auth/login
GET  /api/v1/destinations · /destinations/:id
GET  /api/v1/attractions · /attractions/:id
GET  /api/v1/hotels · /restaurants
POST /api/v1/travel/plan          # 全新规划
POST /api/v1/travel/replan        # 局部重规划
GET  /api/v1/itineraries/:id
POST /api/v1/itineraries/:id/start
POST /api/v1/itineraries/:id/feedback
GET  /api/v1/weather
POST /api/v1/ai/chat              # 通用助手；行程入口仍走 plan
```

- 幂等：`plan/replan` 支持 `Idempotency-Key`（V0.1 实现：24h TTL 键值缓存，
  Redis 可用时优先 Redis，否则进程内降级；相同 key 返回同一响应体，不重复落行程）。
- 只读接口充分利用 Redis（TTL：静态资料长、天气短、票价中）。

### 8.1 统一错误信封（V0.1 落地实现）

所有非 2xx 响应形如：

```json
{ "code": "<STABLE_UPPER_SNAKE>", "message": "人类可读", "details": {} }
```

| HTTP | code |
|---|---|
| 400 | `VALIDATION_ERROR` |
| 401 | `UNAUTHORIZED` |
| 403 | `FORBIDDEN` |
| 404 | `NOT_FOUND` |
| 409 | `CONFLICT` |
| 422 | `UNPROCESSABLE_ENTITY`；预算硬约束失败为 `BUDGET_EXCEEDED` |
| 429 | `RATE_LIMITED` |
| 500 | `INTERNAL_ERROR` |

### 8.2 分页（cursor）

列表接口统一 `?limit=20&cursor=xxx` → `{ "items": [], "next_cursor": "xxx|null" }`；
cursor 对调用方不透明（V0.1 为偏移编码，后续可换 keyset 而不改契约）；
过渡期兼容 `?page=&page_size=`。

### 8.3 认证与重规划契约

- 认证：HS256 JWT（`sub/role/iat/exp`），密钥 `JWT_SECRET`；无进程内 session 表。
- `APP_ENV=production` 时启动自检强制：JWT_SECRET 非默认值且长度 ≥32、CORS 不得为 `*`，否则拒绝启动。
- **行程默认私有**：`GET /api/v1/itineraries/:id` 与 `POST /api/v1/travel/replan` 必须携带有效 JWT，且行程归属人等于当前用户（或 role=admin），否则 `403 FORBIDDEN`。
- `POST /api/v1/travel/plan` 的归属人**只从 JWT 推导**，请求体不接受 `user_id`；未登录可 `save=false` 预览，`save=true`（默认）需登录，否则 `401`。
- `POST /api/v1/travel/replan` 只接受结构化编辑操作
  `edit_op ∈ {remove_item, replace_restaurant, move_item_to_day, replace_hotel, reorder_day}`；
  响应必须含 `changed_days` / `unchanged_days` / `diff` / `warnings`；
  除数据源变化或全局参数变更外，禁止整体重生成。
- 编辑操作在**单事务**内完成：任一步失败整体回滚，不留「节点已删、顺序未重排」的半成品。
- `remove_item` 传 `attraction_id`（可传 `attractions.id` 或 `itinerary_items.id`），连带删除其进出 transit；禁止用名称字符串匹配节点。
- 编辑后按桶重算预算并**复核硬约束**：总额超过 `budget_limit` 时返回 `422 BUDGET_EXCEEDED` 且不落库。

**`reorder_day`（用户指定当天顺序）**

- 允许用户指定某一天内景区的**优先前缀**：`ordered_attraction_ids` 按期望顺序排列，未列出的景区按 `Route Score` 降序补在其后。
- 只支持「锁定前缀」，不支持完整置换顺序：用户可把想去的项提到前面，但不能让低分景区整体压过高分项，否则 `Route Score` 失效、行程质量失控。
- 实现复用 `route::pack_day` 纯函数——把候选遍历序由「评分降序」换成「用户序在前」，时间轴、营业时间校验、预算累计**全部重新推导**，不做字段级覆盖。
- 重排**只作用于 `day_index` 指定的那一天**，`unchanged_days` 必须包含其余所有天（铁律 8 的直接落点）。
- 重排后仍受全部硬约束约束：排到 18:00 后的项跳过并给 `opening_hours_conflict`；装不下预算按 §5 阶梯降级，仍超限才 `422 BUDGET_EXCEEDED`。
  即**用户能定序，但不能定出违规行程**。
- 餐厅/酒店/交通段节点不接受拖拽，不参与 `ordered_attraction_ids`。

### 8.4 行程执行与反馈契约

- **行程开始**：`POST /api/v1/itineraries/:id/start`
  - 鉴权：必须登录且仅限行程本人（或 admin）。
  - 动作：将 `itineraries.status` 由 `draft`/`confirmed` 推进至 `active`（兼容 `in_progress`），记录实际执行状态。
- **行程反馈**：`POST /api/v1/itineraries/:id/feedback`
  - 请求体：`{ "rating": 1..5, "comment": "...", "images": [...] }`
  - 动作：向 `user_feedback` 写入用户对行程的体验评分与反馈建议（支持附图数组），用于推荐模型调优。

### 8.5 AI 智能对话契约（`POST /api/v1/ai/chat`）

- **AI 边界铁律落点**：用户旅行咨询与问答入口。支持云端 LLM 代理转发与本地事实规则降级引擎。
- 输入：`{ "message": "...", "session_id": "...", "context": {} }`
- 响应：`{ "reply": "...", "session_id": "...", "suggestions": [...], "sources": [...] }`
- **铁律硬约束**：回答中涉及票价、营业时间等事实字段，必须经过系统事实校验或带来源标注；对于未验证实体，系统在 `sources` 中标明参考来源，禁止由大模型凭空断言。

### 8.6 账号注销契约（`DELETE /api/v1/auth/me`）

- 鉴权：必须携带有效 JWT 证明本人身份。
- 防误删确认：必须携带 `?confirm=DELETE` 查询参数或请求体 `{"confirm":"DELETE"}`，否则返回 `400 BAD_REQUEST`。
- 级联清理：在单事务内注销账号并物理清理/匿名化该用户的行程、收藏、偏好与个人轨迹数据，满足个保法与 GDPR 合规硬要求。

## 9. 后台与数据治理

### 9.1 管理端架构与接口（`apps/api/src/admin.rs` & `crates/review`）

管理端采用轻量 SPA（挂载于 `/admin/`），所有管理路由挂在 `/api/v1/admin/*`，强制校验管理员权限（`role = 'admin'`，否则 `403 FORBIDDEN`）。

| 路由 | 方法 | 作用 |
|---|---|---|
| `/admin/dashboard` | GET | 仪表盘关键指标（总景区数、已核验数、待审营业时段数、总行程数、活跃用户数） |
| `/admin/attractions` | GET | 景区管理列表（支持 `city`, `level`, `status`, `name` 检索与分页） |
| `/admin/attractions/:id/verify` | POST | 景区快速核验/驳回（更新 `verification_status`、`confidence` 并留审计） |
| `/admin/attractions/:id` | PUT | 景区核心事实修改（名称、票价、开放时间、等级、描述等） |
| `/admin/hours-review` | GET | 营业时段候选审核列表（聚合官方时段与高德二级候选时段进行差异比对） |
| `/admin/hours-review/batch-adopt` | POST | 批量采纳营业时段候选（一次性升级多个吻合候选，写回主表并记录审计） |
| `/admin/hours-review/:id/approve` | POST | 采纳高德营业时段（将候选升级为 `verified`，同时同步回 `attractions` 表） |
| `/admin/hours-review/:id/reject` | POST | 驳回营业时段候选 |
| `/admin/reviews` | GET | 通用数据审核队列 |
| `/admin/reviews/:id/approve` | POST | 采纳审核项并自动合并入库 |
| `/admin/reviews/:id/reject` | POST | 驳回审核项 |
| `/admin/users` | GET | 用户管理列表（支持分页与角色筛选） |
| `/admin/users/:id/role` | PUT | 用户角色调整（`user` / `admin`），禁止降级自身 |
| `/admin/audit-logs` | GET | 管理员全量审计日志检索（操作人、动作、资源、变更快照、IP） |

### 9.2 数据巡检与 Worker 任务（`apps/worker/src/main.rs`）

- **超期巡检 (`run_stale_check`)**：每 24h 扫描核验时间超过 90 天的可变事实，自动将 `verified` 降级为 `stale`，提示人工或定时爬虫复查。
- **孤儿清理 (`run_orphan_cleanup`)**：自动清理软删除遗留或未绑定有效景区的孤立时段/标签行。
- **审核流**：`高德/采集发现差异 → pending → Admin人工比对采纳/驳回 → verified 升级`，全流程触发审计日志，严禁未经核对自动覆盖门票与营业时间。

## 10. 安全与隐私

- **密钥治理**：Key、连接串仅存后端环境变量或密钥系统；生产环境拒绝默认密钥与通配 CORS。
- **用户隐私**：GPS、行程、收藏、反馈默认仅本人可见；支持 `DELETE /api/v1/auth/me` 物理注销清理。
- **分级限流（`crates/common/src/rate_limit.rs`）**：
  - 基于 Redis 令牌桶算法，在 Redis 故障或离线时平滑降级为进程内 DashMap 内存限流。
  - 限流配额：AI 规划（5 次/分/用户或IP）、AI 会话（10 次/分）、通用接口（60 次/分）。
  - 超限响应：统一返回 HTTP 429 与 `{ "code": "RATE_LIMITED", "message": "请求过于频繁，请稍后再试" }`，附带 `Retry-After: 60`。
- **全量审计日志**：
  - `admin_audit_log` 数据表记录所有 Admin 级写操作（`operator_id`, `action`, `resource_type`, `resource_id`, `changes_json`, `ip`），不可被修改或覆写。

## 11. 非功能约定

- 单次 `plan` 目标 P95 < 5s（缓存距离矩阵命中时）；未命中依赖地图 API 时降级为异步任务 + 轮询（V0.1 可同步等待，超时返回 `202`+job 概形仅在确有必要时引入）。
- 时间一律 UTC 存储，展示按目的地时区（贵州 `Asia/Shanghai`）。
- 日志：OpenTelemetry trace id 贯穿 API → AI Gateway → DB。

## 12. 环境

| 环境 | 组成 |
|---|---|
| 本地开发 | Mac + OrbStack：Postgres(+PostGIS+pgvector) Redis Ollama api worker admin |
| CI | GitHub Actions：fmt/clippy/test + 迁移校验 + 镜像构建 |
| 生产（第一阶段） | 单 VPS/小集群：api worker postgres redis；AI 走云 API 或 Tailscale 回源本地 Ollama |

`deploy/docker-compose.yml` 服务名固定：`postgres redis api worker web admin`。

## 13. 变更纪律

1. 选型变更、实体增删、API 契约变更、AI schema 变更 → **先改本文件**再写代码。
2. 版本范围变化 → 同步 `AGENTS.md` 铁律章节。
3. 本文件保持「约定」密度：只写已定决策与硬约束；可探索方案进 PR 描述，不进本文件。
