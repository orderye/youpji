# 游迹 V0.1

游迹是面向贵州的 AI 个性化旅游规划平台。当前仓库的开发重点是第一条产品闭环：

```text
贵阳 → 安顺（黄果树 / 龙宫 / 天龙屯堡）两日游
```

## 目录

```text
游迹/
├── youpji/           # 代码根目录
│   ├── backend/      # Rust workspace（apps/ + crates/ + migrations/）
│   ├── data/         # 种子与数据管线产物
│   ├── deploy/       # Docker Compose（postgres redis api worker scheduler web admin）
│   ├── frontend/     # Flutter（尚未初始化）
│   ├── admin/        # 管理端 SPA（尚未初始化）
│   └── ai/           # 离线数据管线（尚未初始化）
├── scripts/          # Node 脚本
├── Docs/             # 项目执行方案与设计文档
├── .github/          # CI（fmt/clippy/test + 迁移校验 + 镜像构建）
├── DESIGN.md         # 架构与设计约定
├── AGENTS.md         # 工程约定
└── package.json      # 数据脚本入口
```

## 环境要求

- Rust stable
- Docker / OrbStack
- PostgreSQL + PostGIS + pgvector
- Redis
- Node.js 18+
- 可选：Ollama、高德 API Key、云端 LLM API

## 启动开发环境

```bash
cd /Volumes/aigo\ S7\ Med/项目/游迹/youpji/deploy
docker compose up -d
```

编排文件已合并为单个 `docker-compose.yml`，服务名固定为
`postgres redis api worker scheduler web admin`。前端产物目录（`frontend/out`、`admin/dist`）
尚未生成，默认不启动；需要时显式开 profile：

```bash
docker compose --profile web --profile admin up -d
```

## 运行后端

```bash
cd /Volumes/aigo\ S7\ Med/项目/游迹/youpji/backend
cargo run -p api
```

后端启动时会自动执行迁移。开发环境默认监听：

```text
http://127.0.0.1:8081
```

健康检查：

```bash
curl http://127.0.0.1:8081/health
```

## 导入种子数据

必须先设置目标数据库：

```bash
cd /Volumes/aigo\ S7\ Med/项目/游迹
DATABASE_URL='postgres://youpji:youpji_dev@127.0.0.1:5433/youpji' \
  npm run seed
```

种子 SQL 位于：

```text
youpji/data/seed/seed.sql
```

## 规划接口

```text
POST /api/v1/travel/parse
POST /api/v1/travel/plan
POST /api/v1/travel/replan
GET  /api/v1/itineraries/{id}
```

示例：

```bash
curl -X POST http://127.0.0.1:8081/api/v1/travel/plan \
  -H 'Content-Type: application/json' \
  -d '{
    "origin": "贵阳",
    "destination": "安顺",
    "start_date": "2026-10-01",
    "days": 2,
    "people": 2,
    "budget": 2000,
    "transport": "self_drive",
    "interests": ["nature", "history"],
    "avoid": [],
    "intensity": "medium",
    "mode": "standard",
    "lodging_tier": "standard"
  }'
```

## 认证、分页与幂等（阶段 5）

- 认证：标准 JWT（HS256，`JWT_SECRET` 签名），`Authorization: Bearer <token>`；
  未登录访问受保护接口返回 `401 {"code":"UNAUTHORIZED",...}`。
- **行程默认私有**：`GET /api/v1/itineraries/{id}` 与 `POST /api/v1/travel/replan`
  必须携带 token 且为行程归属人（或 admin），否则 `403`。
- `POST /api/v1/travel/plan` 的归属人只从 JWT 推导，请求体不接受 `user_id`；
  未登录可加 `"save": false` 预览，默认 `save=true` 则需登录。
- `APP_ENV=production` 时启动自检会拒绝弱 `JWT_SECRET`（默认值或 <32 字符）与 `CORS_ORIGINS=*`。
- 统一错误格式（所有 400/401/403/404/409/422/500）：

```json
{ "code": "VALIDATION_ERROR", "message": "start_date must be before end_date", "details": {} }
```

  预算超支为硬约束，`POST /api/v1/travel/plan` 返回 `422` + `"code": "BUDGET_EXCEEDED"`。
  但预算偏紧时系统会先**降级重排**（减少每日景点 → 经济档住宿 → 每天 1 个景点），
  全部档位都装不下才返回 `BUDGET_EXCEEDED`，并在 `warnings` 里带 `plan_degraded`。
- 列表接口统一 cursor 分页：`?limit=20&cursor=xxx` → `{ "items": [], "next_cursor": "xxx" }`
  （仍兼容旧的 `?page=&page_size=`）。
- 写接口幂等：`POST /api/v1/travel/plan`、`POST /api/v1/travel/replan` 支持
  `Idempotency-Key` 头；相同 key 24h 内返回同一份响应，不产生重复行程。
  优先走 Redis（多实例一致），Redis 不可用时降级为进程内缓存。

行程质量提示（`warnings`）

| code | 含义 |
|---|---|
| `unverified_fact` | 票价/开放时间为估算，以景区当日公示为准 |
| `distance_estimated` | 未接入高德路网，里程与车程按直线距离×1.3 估算 |
| `budget_rate_estimated` | 未取到已验证的住宿/餐饮价格，预算按档位估算 |
| `plan_degraded` | 原方案超预算，已自动降级调整 |
| `opening_hours_conflict` | 到达时间与营业时间冲突，该景点已跳过 |

配置 `AMAP_KEY` 后，里程与车程改用高德驾车路网矩阵（Redis 缓存 30 天），
`distance_estimated` 不再出现。

局部重规划（阶段 4）只接受结构化 `edit_op`，且只返回受影响天的 diff：

```bash
curl -X POST http://127.0.0.1:8081/api/v1/travel/replan \
  -H 'Content-Type: application/json' -H 'Idempotency-Key: demo-1' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"itinerary_id":"<uuid>","edit_op":{"type":"remove_item","attraction_id":"<uuid>","day_index":1}}'
```

响应包含 `changed_days` / `unchanged_days` / `diff` / `warnings`（阶段 4.2）。
编辑全程单事务，删除或跨天搬运后会重算当天时间轴，不留时间空洞。

## 检查命令

```bash
cd /Volumes/aigo\ S7\ Med/项目/游迹/youpji/backend
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace --all-targets          # 领域/解析/JWT/错误码/分页 + API 关键流程（默认跑）
cargo test -p api --test e2e_anshun -- --ignored   # 贵阳→安顺端到端（需要 PostGIS 库 + 种子数据）
```

测试分布（阶段 6.4）：纯函数/领域测试 ≥ 20（route/ai/common/auth/paging/facts），
API 关键流程测试 9 个（health/parse×5/401×2/错误格式），贵阳→安顺 e2e 2 个（默认 `#[ignore]`）。

## 当前边界

V0.1 只做贵州、只做第一条两日游闭环，不扩展外省、预订、社交、实时管家、AR、交易或多人协同。

**环境已知阻塞**：本机 Homebrew PostgreSQL 17（5432）未安装 `postgis`/`vector`
（只有 `pg_trgm`），也没有 `youpji` 库；因此迁移/种子/端到端验收需先启动
`deploy/docker-compose.yml`（OrbStack，PG 在 **5433**）。若要直接用本机 PG，
需先 `brew install postgis pgvector` 并把 `DATABASE_URL` 改成 `127.0.0.1:5432`。

方案详情见：

```text
Docs/游迹 V0.1 落地执行方案.md
```
