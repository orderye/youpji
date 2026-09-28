//! API 层（Axum handlers + router 装配）。
//!
//! 分层约定：领域 crates 只依赖 `AppState`/`PgPool`，本文件负责 HTTP 细节。
//! 阶段 2/3/4/5 的边界都在这里收口：
//! - 请求先过 `ai::validate_request`（2.2/2.3）；
//! - `route::plan` 的 `PlanError` 映射成 `BUDGET_EXCEEDED` 等稳定错误码（3.5/5.2）；
//! - `travel/replan` 只接受结构化 `EditOp`，返回 changed/unchanged days + diff（4.1–4.3）；
//! - 认证用标准 JWT，plan/replan 支持 `Idempotency-Key`（5.1/5.4）。
use axum::{
    extract::{Path, Query, State},
    http::{header, HeaderMap, StatusCode},
    routing::{get, post},
    Json, Router,
};
use common::error::{ApiError, ApiResult};
use common::paging::Paged;
use common::state::{AppState, Config, SessionUser};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;
use uuid::Uuid;

pub mod admin;

/// 构造应用（阶段 6.2：集成测试复用同一 router）。
pub fn build_router(config: Config, state: AppState) -> Router {
    let cors = if config.cors_origins.iter().any(|o| o == "*") {
        CorsLayer::new()
            .allow_origin(Any)
            .allow_methods(Any)
            .allow_headers(Any)
    } else {
        let origins: Vec<_> = config
            .cors_origins
            .iter()
            .filter_map(|o| o.parse().ok())
            .collect();
        CorsLayer::new()
            .allow_origin(origins)
            .allow_methods(Any)
            .allow_headers(Any)
    };

    Router::new()
        .route("/health", get(health))
        .nest("/api/v1/admin", admin::admin_routes())
        .route("/api/v1/auth/register", post(auth_register))
        .route("/api/v1/auth/login", post(auth_login))
        .route("/api/v1/auth/me", get(auth_me).delete(auth_delete_me))
        .route("/api/v1/destinations", get(destinations_list))
        .route("/api/v1/attractions", get(attractions_list))
        .route("/api/v1/attractions/{id}", get(attraction_detail))
        .route("/api/v1/hotels", get(hotels_list))
        .route("/api/v1/restaurants", get(restaurants_list))
        .route("/api/v1/guides", get(guides_search))
        .route("/api/v1/guides/attraction/{id}", get(guides_by_attraction))
        .route("/api/v1/weather", get(weather_get))
        .route("/api/v1/travel/parse", post(travel_parse))
        .route("/api/v1/travel/plan", post(travel_plan))
        .route("/api/v1/travel/replan", post(travel_replan))
        .route("/api/v1/itineraries/{id}", get(itinerary_get))
        .route("/api/v1/itineraries/{id}/start", post(itinerary_start))
        .route(
            "/api/v1/itineraries/{id}/feedback",
            post(itinerary_feedback),
        )
        .route("/api/v1/itineraries", get(itinerary_list))
        .route("/api/v1/preferences", get(pref_get).put(pref_put))
        .route("/api/v1/recommendations", get(recos))
        .route("/api/v1/ai/chat", post(ai_chat_handler))
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

/// 进程入口（main.rs 调用）；集成测试不启动 HTTP，只复用 build_router。
pub async fn run() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info,tower_http=warn".into()),
        )
        .init();

    let config = Config::from_env();
    config
        .validate()
        .map_err(|e| anyhow::anyhow!("config validation failed: {e}"))?;
    let pool = sqlx::postgres::PgPoolOptions::new()
        .max_connections(10)
        .connect(&config.database_url)
        .await?;

    sqlx::migrate!("../../migrations").run(&pool).await?;

    let redis = match redis::Client::open(config.redis_url.as_str()) {
        Ok(c) => match redis::aio::ConnectionManager::new(c).await {
            Ok(cm) => Some(cm),
            Err(e) => {
                tracing::warn!(%e, "redis unavailable, running without cache");
                None
            }
        },
        Err(e) => {
            tracing::warn!(%e, "redis url invalid");
            None
        }
    };

    let http = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()?;
    let state = AppState {
        pool,
        redis,
        http,
        config: Arc::new(config.clone()),
        idempotency: Arc::new(RwLock::new(HashMap::new())),
    };

    let app = build_router(config.clone(), state);
    let bind = config.bind.clone();
    let listener = tokio::net::TcpListener::bind(&bind).await?;
    tracing::info!("api listening on {bind}");
    axum::serve(listener, app).await?;
    Ok(())
}

/// 测试辅助（阶段 6.2）：不建立真实连接，供无需 DB 的路由测试使用。
pub fn lazy_state(config: Config) -> AppState {
    let pool = sqlx::postgres::PgPoolOptions::new()
        .max_connections(1)
        .connect_lazy(&config.database_url)
        .expect("connect_lazy should not fail for a syntactically valid url");
    let http = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()
        .expect("http client");
    AppState {
        pool,
        redis: None,
        http,
        config: Arc::new(config),
        idempotency: Arc::new(RwLock::new(HashMap::new())),
    }
}

async fn health() -> Json<Value> {
    Json(json!({"ok": true, "service": "youpji-api", "version": "0.1.0"}))
}

fn bearer(headers: &HeaderMap) -> ApiResult<String> {
    headers
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.strip_prefix("Bearer "))
        .map(|s| s.to_string())
        .ok_or_else(|| ApiError::Unauthorized("missing bearer token".into()))
}

pub(crate) async fn current_user(state: &AppState, headers: &HeaderMap) -> ApiResult<SessionUser> {
    let token = bearer(headers)?;
    // 阶段 5.1：标准 JWT 校验（不再使用进程内 session 表）
    let (id, role) = auth::parse_token_with_secret(&state.config.jwt_secret, &token)?;
    let user = auth::me(state, id).await?;
    Ok(SessionUser {
        user_id: user.id,
        role: if user.role.is_empty() {
            role
        } else {
            user.role
        },
        display_name: user.display_name,
    })
}

/// 可选会话：无 Authorization 头 → Ok(None)；有但非法 → Err(401)。
/// 用于「不登录也能规划预览、登录才能保存」的接口。
async fn optional_user(state: &AppState, headers: &HeaderMap) -> ApiResult<Option<SessionUser>> {
    if headers.get(header::AUTHORIZATION).is_none() {
        return Ok(None);
    }
    current_user(state, headers).await.map(Some)
}

/// 幂等键（阶段 5.4）：plan / replan 支持 `Idempotency-Key`。
fn idempotency_key(headers: &HeaderMap, scope: &str) -> Option<String> {
    headers
        .get("idempotency-key")
        .and_then(|v| v.to_str().ok())
        .map(|k| k.trim().to_string())
        .filter(|k| !k.is_empty())
        .map(|k| format!("{scope}:{k}"))
}
async fn auth_register(
    State(state): State<AppState>,
    Json(input): Json<auth::RegisterInput>,
) -> ApiResult<Json<Value>> {
    let (user, token) = auth::register(&state, input).await?;
    Ok(Json(json!({"user": user, "token": token})))
}

async fn auth_login(
    State(state): State<AppState>,
    Json(input): Json<auth::LoginInput>,
) -> ApiResult<Json<Value>> {
    let (user, token) = auth::login(&state, input).await?;
    Ok(Json(json!({"user": user, "token": token})))
}

async fn auth_me(State(state): State<AppState>, headers: HeaderMap) -> ApiResult<Json<Value>> {
    let u = current_user(&state, &headers).await?;
    Ok(Json(json!(u)))
}

async fn auth_delete_me(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> ApiResult<Json<Value>> {
    let u = current_user(&state, &headers).await?;
    auth::delete_account(&state, u.user_id).await?;
    Ok(Json(json!({"ok": true, "deleted_user_id": u.user_id})))
}

async fn destinations_list(
    State(state): State<AppState>,
    Query(q): Query<destination::ListQuery>,
) -> ApiResult<Json<Paged<destination::Destination>>> {
    destination::list(&state, q).await.map(Json)
}

async fn attractions_list(
    State(state): State<AppState>,
    Query(q): Query<attraction::ListQuery>,
) -> ApiResult<Json<Paged<attraction::AttractionRow>>> {
    attraction::list(&state, q).await.map(Json)
}

async fn attraction_detail(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<attraction::AttractionDetail>> {
    attraction::detail(&state, id).await.map(Json)
}

async fn hotels_list(
    State(state): State<AppState>,
    Query(q): Query<hotel::ListQuery>,
) -> ApiResult<Json<Paged<hotel::HotelRow>>> {
    hotel::list(&state, q).await.map(Json)
}

async fn restaurants_list(
    State(state): State<AppState>,
    Query(q): Query<restaurant::ListQuery>,
) -> ApiResult<Json<Paged<restaurant::RestaurantRow>>> {
    restaurant::list(&state, q).await.map(Json)
}

#[derive(Deserialize)]
struct GuideQ {
    q: String,
    limit: Option<i64>,
}

async fn guides_search(
    State(state): State<AppState>,
    Query(q): Query<GuideQ>,
) -> ApiResult<Json<Vec<content::ContentRow>>> {
    content::search(&state, &q.q, q.limit.unwrap_or(20))
        .await
        .map(Json)
}

async fn guides_by_attraction(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Query(q): Query<GuideQ>,
) -> ApiResult<Json<Vec<content::ContentRow>>> {
    content::list_by_attraction(&state, id, q.limit.unwrap_or(20))
        .await
        .map(Json)
}

#[derive(Deserialize)]
struct WeatherQ {
    city: String,
    days: Option<i32>,
}

async fn weather_get(
    State(state): State<AppState>,
    Query(q): Query<WeatherQ>,
) -> ApiResult<Json<Vec<weather::WeatherRow>>> {
    Ok(Json(
        weather::forecast(&state, &q.city, q.days.unwrap_or(7)).await,
    ))
}

#[derive(Deserialize)]
struct RecoQ {
    city: Option<String>,
    limit: Option<i64>,
}

async fn recos(
    State(state): State<AppState>,
    Query(q): Query<RecoQ>,
) -> ApiResult<Json<Vec<recommendation::Recommended>>> {
    Ok(Json(
        recommendation::nearby_popular(&state, q.city.as_deref(), q.limit.unwrap_or(10)).await,
    ))
}

/// POST /travel/parse：RuleParser → RequestValidator（阶段 2 验收）。
async fn travel_parse(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(input): Json<Value>,
) -> ApiResult<Json<Value>> {
    let client_id = bearer(&headers).unwrap_or_else(|_| "anonymous_client".into());
    common::check_rate_limit(&state, "parse", &client_id, 60, 60).await?;
    let text = input["text"].as_str().unwrap_or_default();
    if text.trim().is_empty() {
        return Err(ApiError::BadRequest("text required".into()));
    }
    let req = ai::rules::RuleParser::new()
        .parse(text)
        .map_err(ApiError::BadRequest)?;
    ai::validate_request(&req).map_err(ApiError::Unprocessable)?;
    Ok(Json(serde_json::to_value(req).unwrap_or_default()))
}

#[derive(Deserialize)]
struct PlanBody {
    #[serde(flatten)]
    req: route::PlanRequest,
    save: Option<bool>,
}

async fn travel_plan(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(mut body): Json<PlanBody>,
) -> ApiResult<Json<Value>> {
    let client_id = bearer(&headers).unwrap_or_else(|_| "anonymous_client".into());
    common::check_rate_limit(&state, "plan", &client_id, 30, 60).await?;

    // 幂等（阶段 5.4）：同一 Idempotency-Key 不产生重复行程
    let idem = idempotency_key(&headers, "plan");
    if let Some(key) = &idem {
        if let Some(cached) = common::state::idempotency_get(&state, key).await {
            return Ok(Json(cached));
        }
    }

    // LLM 只做字段提取（事实类键在 merge_llm 中被拒绝）
    if let Some(text) = body.req.natural_input.clone() {
        if let Some(v) = ai::llm_parse(&state, &text).await {
            ai::merge_llm(&mut body.req, &v);
        }
    }

    // 统一校验（阶段 2.3）：含贵州地域范围
    if let Err(msg) = ai::validate_request(&body.req) {
        return Err(ApiError::Unprocessable(msg));
    }

    // 距离服务：有 AMAP_KEY 时走高德驾车路网矩阵（Redis 缓存 30 天），
    // 否则内部降级为直线距离×1.3 并在 warnings 标注，不影响规划可用性。
    let distances =
        route::DistanceService::new(&state.http, state.redis.as_ref(), &state.config.amap_key);
    let output = route::plan_with(&state.pool, &body.req, Some(&distances))
        .await
        .map_err(|e| ApiError::from_plan_error_code(e.code(), e.to_string()))?;

    // 归属只能来自 JWT：请求体不再接受 user_id（否则可把行程写进他人账号）。
    // 未登录可预览（save=false），保存则必须登录。
    let wants_save = body.save.unwrap_or(true);
    let session = optional_user(&state, &headers).await?;
    if wants_save && session.is_none() {
        return Err(ApiError::Unauthorized(
            "login required to save itinerary (or send save=false to preview)".into(),
        ));
    }

    let saved_id = if wants_save {
        Some(itinerary::save_plan(&state, session.map(|s| s.user_id), &body.req, &output).await?)
    } else {
        None
    };

    let resp = json!({
        "itinerary_id": saved_id,
        "summary": output.summary,
        "days": output.days,
        "budget": output.budget,
        "hotels": output.hotels,
        "restaurants": output.restaurants,
        "routes": output.routes,
        "warnings": output.warnings,
        "algo_version": output.algo_version,
    });

    if let Some(key) = idem {
        common::state::idempotency_put(&state, key, resp.clone()).await;
    }
    Ok(Json(resp))
}

/// POST /travel/replan（阶段 4.1）：只接受结构化 edit_op。
#[derive(Deserialize)]
struct ReplanBody {
    itinerary_id: Uuid,
    edit_op: itinerary::EditOp,
}

async fn travel_replan(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ReplanBody>,
) -> ApiResult<Json<Value>> {
    let client_id = bearer(&headers).unwrap_or_else(|_| "anonymous_client".into());
    common::check_rate_limit(&state, "replan", &client_id, 30, 60).await?;

    // 行程默认私有：必须登录且是归属人（或 admin），否则不得编辑
    let u = current_user(&state, &headers).await?;
    let owner = itinerary::owner_of(&state, body.itinerary_id).await?;
    itinerary::ensure_owner(owner, u.user_id, &u.role)?;

    let idem = idempotency_key(&headers, "replan");
    if let Some(key) = &idem {
        if let Some(cached) = common::state::idempotency_get(&state, key).await {
            return Ok(Json(cached));
        }
    }
    let result = itinerary::apply_edit(&state, body.itinerary_id, body.edit_op).await?;
    let resp = serde_json::to_value(&result).unwrap_or_default();
    if let Some(key) = idem {
        common::state::idempotency_put(&state, key, resp.clone()).await;
    }
    Ok(Json(resp))
}

async fn itinerary_start(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> ApiResult<Json<Value>> {
    let u = current_user(&state, &headers).await?;
    itinerary::start_itinerary(&state, id, u.user_id, &u.role).await?;
    Ok(Json(serde_json::json!({
        "ok": true,
        "id": id,
        "status": "in_progress"
    })))
}

async fn itinerary_feedback(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
    Json(input): Json<itinerary::FeedbackInput>,
) -> ApiResult<Json<Value>> {
    let u = current_user(&state, &headers).await?;
    let fid = itinerary::submit_feedback(&state, id, u.user_id, &u.role, input).await?;
    Ok(Json(serde_json::json!({
        "ok": true,
        "feedback_id": fid
    })))
}

async fn ai_chat_handler(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<ai::ChatRequest>,
) -> ApiResult<Json<ai::ChatResponse>> {
    let client_id = bearer(&headers).unwrap_or_else(|_| "anonymous_client".into());
    common::check_rate_limit(&state, "chat", &client_id, 30, 60).await?;
    ai::handle_chat(&state, req).await.map(Json)
}

async fn itinerary_get(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> ApiResult<Json<Value>> {
    let u = current_user(&state, &headers).await?;
    let d = itinerary::get(&state, id).await?;
    itinerary::ensure_owner(d.itinerary.user_id, u.user_id, &u.role)?;
    Ok(Json(serde_json::to_value(d).unwrap_or_default()))
}

async fn itinerary_list(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> ApiResult<Json<Vec<itinerary::ItineraryRow>>> {
    let u = current_user(&state, &headers).await?;
    itinerary::list_for_user(&state, u.user_id).await.map(Json)
}

async fn pref_get(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> ApiResult<Json<user::PreferencesInput>> {
    let u = current_user(&state, &headers).await?;
    user::get_preferences(&state, u.user_id).await.map(Json)
}

async fn pref_put(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(input): Json<user::PreferencesInput>,
) -> ApiResult<StatusCode> {
    let u = current_user(&state, &headers).await?;
    user::upsert_preferences(&state, u.user_id, input).await?;
    Ok(StatusCode::NO_CONTENT)
}
