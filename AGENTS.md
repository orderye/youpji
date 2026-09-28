# AGENTS.md — 游迹工程约定

本文件是 AI 代理与开发者在本仓库工作的入口规则。完整产品方案见 `游迹 AI 旅游平台 V0.1 完整研发方案.md`，架构与数据设计细节见 `DESIGN.md`。两者冲突时：安全/合规 > DESIGN.md > 本文件 > 方案原文。

## 项目是什么

「游迹」= AI 个性化旅游规划 + 景区知识库 + 攻略聚合 + 行程落地执行。
核心理念：用户只说「在哪、去哪、玩多久、预算、喜欢什么」，系统产出**可直接执行**的结构化行程。

**项目不是**：大模型套壳聊天窗、攻略搬运站、纯地图工具。

## V0.1 铁律（不可突破）

1. **地域范围**：只做贵州。第一批 100–300 个高价值景区，完整数据优先于数量。
2. **第一条闭环**：贵阳 → 安顺（黄果树/龙宫/天龙屯堡）两日游。此链未跑通，不扩省、不堆功能。
3. **明确不做（V0.1）**：AR、社交、视频社区、直播、商城、导游交易、大规模酒店预订、多人协同。
4. **AI 不决定事实**：门票、开放时间、交通、天气、酒店价格、餐厅营业时间必须查库/查源并带验证状态，禁止由 LLM 直接断言。
5. **攻略不搬原文**：只存摘要 + 结构化提取 + 来源链接；小红书/马蜂窝等内容必须走「合法获取 → 摘要 → 提取 → 验证 → 索引」。
6. **API Key 只在后端**：Flutter/Web 一律不直连任何 LLM/第三方付费 API。
7. **行程必须结构化输出**：`/travel/plan` 返回 JSON（summary/days/budget/hotels/restaurants/routes/warnings），禁止以大段 Markdown 作为系统间契约。
8. **局部重规划**：用户修改单点（删景区、换餐厅）时只重算受影响的天/段，禁止整体重新生成。

## 技术栈（V0.1 已定，不得擅自替换）

| 模块 | 选型 |
|---|---|
| App | Flutter（Android / iOS / Web） |
| Web | Next.js（官网/落地页） |
| 管理端 | Web Admin |
| 后端 | Rust + Axum + SQLx + Tokio |
| 数据库 | PostgreSQL + PostGIS + pgvector |
| 缓存 | Redis |
| AI | 云端 LLM（复杂规划/对话）+ 本地 Ollama（清洗/分类/摘要/Embedding/批量），经统一 AI Gateway |
| 地图 | 高德/百度 |
| 部署 | Docker Compose；Mac 开发用 OrbStack |
| CI/CD | GitHub Actions |
| 对象存储 / CDN / 可观测 | S3 兼容存储 / CDN / OpenTelemetry + Prometheus + Grafana |

换任何一项前须先改 DESIGN.md 并说明理由。

## 仓库结构

```
youpji/
├── backend/          # Rust + Axum 单体起步（后续可拆 apps）
│   ├── apps/         # api / worker / scheduler
│   ├── crates/       # auth user attraction hotel restaurant
│   │                 # itinerary recommendation route content weather ai
│   ├── migrations/   # SQLx 迁移，只增不改历史
│   ├── configs/
│   └── docker/
├── frontend/         # Flutter
├── admin/            # 管理端
├── ai/               # RAG / embedding / Ollama 编排与数据管线
├── data/             # 贵州景区/酒店/餐厅/攻略种子与采集产物
├── deploy/           # docker-compose.yml 等
├── DESIGN.md         # 架构与设计约定（本仓库设计权威）
└── AGENTS.md         # 本文件
```

新建目录/服务前先确认是否属于 V0.1 范围。

## 分层与依赖方向

```
前端(Flutter/Next/Admin)
  → HTTP API (Axum, /api/v1/*)
    → 领域 crates（auth/user/attraction/.../route/itinerary/ai）
      → PostgreSQL(PostGIS+pgvector) / Redis / AI Gateway / 外部地图与天气
```

- 领域 crates **不得**直接依赖 HTTP 框架细节；handler 放 api 层。
- 路线计算在 `route` crate，由算法负责；LLM 只做需求结构化与自然语言包装（见 DESIGN.md「AI 边界」）。
- Worker/Scheduler 与 API 共享 crates，不复制业务逻辑。

## 编码与数据约定

- **语言**：后端 Rust（edition 最新稳定）；SQL 迁移用 SQLx；前端 Dart/TypeScript。
- **命名**：API 路径 `kebab-case` 资源复数（`/api/v1/attractions`）；JSON 字段 `snake_case`；表名 `snake_case` 复数；Rust 模块 `snake_case`。
- **ID**：对内 UUID/大整数均可，对外暴露统一不透明 ID；经纬度 WGS84/GCJ-02 在 DESIGN.md 标明并全局一致。
- **每条可变旅游事实**必须带：`source_type`、`source_url`、`source_time`、`last_verified`、`verification_status`、`confidence`（见 DESIGN.md）。
- **来源分级**：一级（景区/政府/官方交通）> 二级（地图/酒店/餐饮平台）> 三级（社区/攻略）> 四级（AI 生成）。重要数据以一级来源为准。
- **重要数据变更走人工确认**：Worker 发现差异 → 进入后台审核 → 采纳后才覆盖。禁止无人审的自动覆盖门票/营业时间类字段。
- **用户隐私**：GPS、行程、收藏、旅行记录默认私有；日志与埋点不得输出精确轨迹明文。
- **Migrations**：已合并的迁移不改内容，只追加。

## AI 使用约定

- 统一经 `backend` 内 AI Gateway 调用；禁在客户端/前端携带模型 Key。
- Prompt 与结构化输出 schema 放在 `ai/` 或 `crates/ai`，带版本号；破坏性改 schema 需同步前端与 `/api/v1` 说明。
- 本地 Ollama 负责：数据清洗、分类、摘要、标签、实体识别、去重、Embedding、质检。
- 云端 LLM 负责：需求理解、复杂规划、最终方案表述、高质量对话。
- 所有模型输出中「事实类」字段入库前必须过校验/对源，否则只进 `warnings` 或标注 `verification_status = unverified`。

## 测试与验收

- 每个 PR/交付至少说明：改了什么、如何验证、是否触碰 V0.1 铁律。
- 后端：`cargo fmt && cargo clippy -- -D warnings && cargo test`（若工程已初始化）。
- 涉及行程逻辑必须有测试：候选过滤、预算硬约束、营业时间冲突、局部重规划不破坏其他天。
- **产品级验收**（MVP 五步，缺一不可）：
  1. 用户输入需求 2. 系统找到合适景区 3. 自动生成合理路线 4. 用户觉得方案能执行 5. 用户愿意再次使用。

## 版本节奏（做之前先看是否属于本阶段）

- **V0.1**：定位 → 景区 → AI 规划(1/3/7 日) → 地图 → 酒店 → 餐厅 → 攻略。
- **V0.2**：实时天气、实时重规划、画像、收藏、历史行程、预算管理。
- **V0.3**：实时旅行管家、语音、景区内导航、AI 语音导游、多人协同。
- **V0.4**：AR、相机识别、AI 视觉导游。
- **V1.0**：交易入口、佣金、B2B。

超出当前版本的诉求：先记录到 backlog，不在本版本实现。

## 文档维护

- 改架构、选型、数据契约、AI 边界 → 同步更新 `DESIGN.md`。
- 改产品范围/版本铁律 → 同步更新本文件与方案 md 的对应章节。
- 不要新建 `TODO.md`/`NOTES.md` 等平行约定文件；讨论结论沉淀进这两份。
