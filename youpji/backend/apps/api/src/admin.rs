use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, patch, post},
    Json, Router,
};
use common::error::{ApiError, ApiResult};
use common::paging::Paged;
use common::state::{AppState, SessionUser};
use serde::Deserialize;
use serde_json::{json, Value};
use uuid::Uuid;

pub fn admin_routes() -> Router<AppState> {
    Router::new()
        .route("/dashboard", get(admin_dashboard))
        .route("/attractions", get(admin_attractions_list))
        .route(
            "/attractions/{id}",
            get(admin_attraction_detail).patch(admin_attraction_patch),
        )
        .route("/attractions/{id}/verify", post(admin_attraction_verify))
        .route("/hours-review", get(admin_hours_review_list))
        .route("/hours-review/{id}/approve", post(admin_hours_approve))
        .route("/hours-review/{id}/reject", post(admin_hours_reject))
        .route("/data-reviews", get(admin_data_reviews_list))
        .route(
            "/data-reviews/{id}/approve",
            post(admin_data_review_approve),
        )
        .route("/data-reviews/{id}/reject", post(admin_data_review_reject))
        .route("/users", get(admin_users_list))
        .route("/users/{id}/role", patch(admin_user_role_patch))
        .route("/audit-logs", get(admin_audit_logs_list))
}

async fn require_admin_user(state: &AppState, headers: &HeaderMap) -> ApiResult<SessionUser> {
    let user = super::current_user(state, headers).await?;
    common::state::require_admin(&user)?;
    Ok(user)
}

async fn admin_dashboard(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> ApiResult<Json<review::DashboardStats>> {
    let _ = require_admin_user(&state, &headers).await?;
    let stats = review::get_dashboard_stats(&state.pool).await?;
    Ok(Json(stats))
}

async fn admin_attractions_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<attraction::AdminListQuery>,
) -> ApiResult<Json<Paged<attraction::AttractionRow>>> {
    let _ = require_admin_user(&state, &headers).await?;
    attraction::admin_list(&state, q).await.map(Json)
}

async fn admin_attraction_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<attraction::AttractionDetail>> {
    let _ = require_admin_user(&state, &headers).await?;
    attraction::detail(&state, id).await.map(Json)
}

async fn admin_attraction_patch(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(input): Json<attraction::AdminUpdateInput>,
) -> ApiResult<Json<Value>> {
    let admin = require_admin_user(&state, &headers).await?;
    attraction::admin_update(&state, id, input).await?;
    review::log_audit(
        &state.pool,
        admin.user_id,
        "update_attraction",
        Some("attraction"),
        Some(id),
        json!({"updated_by": admin.display_name}),
    )
    .await?;
    Ok(Json(json!({"ok": true, "id": id})))
}

async fn admin_attraction_verify(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(input): Json<attraction::AdminVerifyInput>,
) -> ApiResult<Json<Value>> {
    let admin = require_admin_user(&state, &headers).await?;
    let source_url = input.source_url.clone();
    attraction::admin_verify(&state, id, input).await?;
    review::log_audit(
        &state.pool,
        admin.user_id,
        "verify_attraction",
        Some("attraction"),
        Some(id),
        json!({"source_url": source_url}),
    )
    .await?;
    Ok(Json(json!({"ok": true, "id": id})))
}

#[derive(Debug, Deserialize)]
struct HoursQuery {
    status: Option<String>,
    limit: Option<i64>,
    offset: Option<i64>,
}

async fn admin_hours_review_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<HoursQuery>,
) -> ApiResult<Json<Vec<review::HoursReviewRow>>> {
    let _ = require_admin_user(&state, &headers).await?;
    let rows = review::list_hours_for_review(
        &state.pool,
        q.status.as_deref(),
        q.limit.unwrap_or(50),
        q.offset.unwrap_or(0),
    )
    .await?;
    Ok(Json(rows))
}

#[derive(Debug, Deserialize)]
struct ApproveHoursBody {
    writeback: Option<bool>,
}

async fn admin_hours_approve(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<Option<ApproveHoursBody>>,
) -> ApiResult<Json<Value>> {
    let admin = require_admin_user(&state, &headers).await?;
    let writeback = body.and_then(|b| b.writeback).unwrap_or(true);
    review::approve_hours(&state.pool, id, admin.user_id, writeback).await?;
    Ok(Json(json!({"ok": true, "id": id})))
}

#[derive(Debug, Deserialize)]
struct RejectBody {
    reason: String,
}

async fn admin_hours_reject(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<RejectBody>,
) -> ApiResult<Json<Value>> {
    let admin = require_admin_user(&state, &headers).await?;
    review::reject_hours(&state.pool, id, admin.user_id, body.reason).await?;
    Ok(Json(json!({"ok": true, "id": id})))
}

async fn admin_data_reviews_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<review::ReviewListQuery>,
) -> ApiResult<Json<Vec<review::ReviewRow>>> {
    let _ = require_admin_user(&state, &headers).await?;
    let rows = review::list_reviews(&state.pool, q).await?;
    Ok(Json(rows))
}

async fn admin_data_review_approve(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<Value>> {
    let admin = require_admin_user(&state, &headers).await?;
    review::approve_review(&state.pool, id, admin.user_id).await?;
    Ok(Json(json!({"ok": true, "id": id})))
}

async fn admin_data_review_reject(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<RejectBody>,
) -> ApiResult<Json<Value>> {
    let admin = require_admin_user(&state, &headers).await?;
    review::reject_review(&state.pool, id, admin.user_id, body.reason).await?;
    Ok(Json(json!({"ok": true, "id": id})))
}

#[derive(Debug, Deserialize)]
struct UserQuery {
    limit: Option<i64>,
    offset: Option<i64>,
}

async fn admin_users_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<UserQuery>,
) -> ApiResult<Json<Vec<user::UserAdminRow>>> {
    let _ = require_admin_user(&state, &headers).await?;
    let rows = user::admin_list_users(&state, q.limit.unwrap_or(50), q.offset.unwrap_or(0)).await?;
    Ok(Json(rows))
}

#[derive(Debug, Deserialize)]
struct RoleBody {
    role: String,
}

async fn admin_user_role_patch(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<RoleBody>,
) -> ApiResult<Json<Value>> {
    let admin = require_admin_user(&state, &headers).await?;
    if admin.user_id == id && body.role != "admin" {
        return Err(ApiError::BadRequest("cannot demote yourself".into()));
    }
    user::admin_update_role(&state, id, &body.role).await?;
    review::log_audit(
        &state.pool,
        admin.user_id,
        "change_role",
        Some("user"),
        Some(id),
        json!({"new_role": body.role}),
    )
    .await?;
    Ok(Json(json!({"ok": true, "id": id, "role": body.role})))
}

#[derive(Debug, Deserialize)]
struct AuditQuery {
    limit: Option<i64>,
}

async fn admin_audit_logs_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<AuditQuery>,
) -> ApiResult<Json<Vec<review::AdminAuditRow>>> {
    let _ = require_admin_user(&state, &headers).await?;
    let rows = review::list_audit_logs(&state.pool, q.limit.unwrap_or(50)).await?;
    Ok(Json(rows))
}
