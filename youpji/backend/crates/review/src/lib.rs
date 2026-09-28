use common::error::{ApiError, ApiResult};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ReviewRow {
    pub id: Uuid,
    pub entity_type: String,
    pub entity_id: Uuid,
    pub field: Option<String>,
    pub proposed: serde_json::Value,
    pub current: Option<serde_json::Value>,
    pub source_type: String,
    pub source_url: Option<String>,
    pub status: String,
    pub reason: Option<String>,
    pub submitter_id: Option<Uuid>,
    pub reviewer_id: Option<Uuid>,
    pub reviewed_at: Option<chrono::DateTime<chrono::Utc>>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct HoursReviewRow {
    pub id: Uuid,
    pub attraction_id: Uuid,
    pub attraction_name: String,
    pub city: Option<String>,
    pub weekday: Option<i16>,
    pub season: Option<String>,
    pub open_time: chrono::NaiveTime,
    pub close_time: chrono::NaiveTime,
    pub note: Option<String>,
    pub source_type: String,
    pub source_url: Option<String>,
    pub source_time: Option<chrono::DateTime<chrono::Utc>>,
    pub last_verified: Option<chrono::DateTime<chrono::Utc>>,
    pub verification_status: String,
    pub confidence: f64,
}

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct AdminAuditRow {
    pub id: Uuid,
    pub admin_id: Uuid,
    pub admin_name: Option<String>,
    pub action: String,
    pub entity_type: Option<String>,
    pub entity_id: Option<Uuid>,
    pub detail: serde_json::Value,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, Default)]
#[serde(rename_all = "snake_case")]
pub struct DashboardStats {
    pub attractions_count: i64,
    pub attractions_verified: i64,
    pub attractions_pending: i64,
    pub attractions_disputed: i64,
    pub hotels_count: i64,
    pub restaurants_count: i64,
    pub pending_reviews_count: i64,
    pub pending_hours_count: i64,
    pub itineraries_count: i64,
    pub itineraries_recent_7d: i64,
    pub users_count: i64,
}

pub async fn log_audit(
    pool: &PgPool,
    admin_id: Uuid,
    action: &str,
    entity_type: Option<&str>,
    entity_id: Option<Uuid>,
    detail: serde_json::Value,
) -> ApiResult<()> {
    sqlx::query(
        r#"INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, detail, created_at)
           VALUES ($1, $2, $3, $4, $5, now())"#,
    )
    .bind(admin_id)
    .bind(action)
    .bind(entity_type)
    .bind(entity_id)
    .bind(detail)
    .execute(pool)
    .await?;
    Ok(())
}

pub async fn get_dashboard_stats(pool: &PgPool) -> ApiResult<DashboardStats> {
    let mut stats = DashboardStats::default();

    // 景区统计
    let row: (i64, i64, i64, i64) = sqlx::query_as(
        r#"SELECT
            count(*),
            count(*) FILTER (WHERE verification_status = 'verified'),
            count(*) FILTER (WHERE verification_status = 'pending'),
            count(*) FILTER (WHERE verification_status = 'disputed')
           FROM attractions"#,
    )
    .fetch_one(pool)
    .await?;
    stats.attractions_count = row.0;
    stats.attractions_verified = row.1;
    stats.attractions_pending = row.2;
    stats.attractions_disputed = row.3;

    // 酒店与餐厅统计
    stats.hotels_count = sqlx::query_scalar("SELECT count(*) FROM hotels")
        .fetch_one(pool)
        .await?;
    stats.restaurants_count = sqlx::query_scalar("SELECT count(*) FROM restaurants")
        .fetch_one(pool)
        .await?;

    // 待审核计数
    stats.pending_reviews_count =
        sqlx::query_scalar("SELECT count(*) FROM data_reviews WHERE status = 'pending'")
            .fetch_one(pool)
            .await?;
    stats.pending_hours_count = sqlx::query_scalar(
        "SELECT count(*) FROM attraction_hours WHERE verification_status = 'pending'",
    )
    .fetch_one(pool)
    .await?;

    // 行程统计
    stats.itineraries_count = sqlx::query_scalar("SELECT count(*) FROM itineraries")
        .fetch_one(pool)
        .await?;
    stats.itineraries_recent_7d = sqlx::query_scalar(
        "SELECT count(*) FROM itineraries WHERE created_at >= now() - INTERVAL '7 days'",
    )
    .fetch_one(pool)
    .await?;

    // 用户统计
    stats.users_count = sqlx::query_scalar("SELECT count(*) FROM users")
        .fetch_one(pool)
        .await?;

    Ok(stats)
}

#[derive(Debug, Deserialize)]
pub struct ReviewListQuery {
    pub status: Option<String>,
    pub entity_type: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

pub async fn list_reviews(pool: &PgPool, q: ReviewListQuery) -> ApiResult<Vec<ReviewRow>> {
    let limit = q.limit.unwrap_or(50).clamp(1, 100);
    let offset = q.offset.unwrap_or(0).max(0);
    let status_filter = q.status.as_deref().unwrap_or("pending");

    let rows: Vec<ReviewRow> = sqlx::query_as(
        r#"SELECT id, entity_type, entity_id, field, proposed, current,
                  source_type::text AS source_type, source_url, status::text AS status,
                  reason, submitter_id, reviewer_id, reviewed_at, created_at
           FROM data_reviews
           WHERE ($1 = '' OR status::text = $1)
             AND ($2::text IS NULL OR entity_type = $2)
           ORDER BY created_at DESC
           LIMIT $3 OFFSET $4"#,
    )
    .bind(status_filter)
    .bind(&q.entity_type)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

#[derive(Debug)]
pub struct CreateReviewInput<'a> {
    pub submitter_id: Option<Uuid>,
    pub entity_type: &'a str,
    pub entity_id: Uuid,
    pub field: Option<&'a str>,
    pub proposed: serde_json::Value,
    pub current: Option<serde_json::Value>,
    pub source_type: &'a str,
    pub source_url: Option<&'a str>,
    pub reason: Option<&'a str>,
}

pub async fn create_review(pool: &PgPool, input: CreateReviewInput<'_>) -> ApiResult<Uuid> {
    let id: Uuid = sqlx::query_scalar(
        r#"INSERT INTO data_reviews (
            entity_type, entity_id, field, proposed, current,
            source_type, source_url, status, reason, submitter_id, created_at
           ) VALUES (
            $1, $2, $3, $4, $5,
            $6::source_type, $7, 'pending', $8, $9, now()
           ) RETURNING id"#,
    )
    .bind(input.entity_type)
    .bind(input.entity_id)
    .bind(input.field)
    .bind(input.proposed)
    .bind(input.current)
    .bind(input.source_type)
    .bind(input.source_url)
    .bind(input.reason)
    .bind(input.submitter_id)
    .fetch_one(pool)
    .await?;

    Ok(id)
}

pub async fn approve_review(pool: &PgPool, review_id: Uuid, reviewer_id: Uuid) -> ApiResult<()> {
    let mut tx = pool.begin().await?;

    let review = sqlx::query_as::<_, ReviewRow>(
        r#"SELECT id, entity_type, entity_id, field, proposed, current,
                  source_type::text AS source_type, source_url, status::text AS status,
                  reason, submitter_id, reviewer_id, reviewed_at, created_at
           FROM data_reviews WHERE id = $1 FOR UPDATE"#,
    )
    .bind(review_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| ApiError::NotFound("review not found".into()))?;

    if review.status != "pending" {
        return Err(ApiError::BadRequest(format!(
            "review is already in {} status",
            review.status
        )));
    }

    // 根据 entity_type 写入更新
    match review.entity_type.as_str() {
        "attraction" => {
            // 支持单字段或全对象 proposed
            if let Some(field_name) = &review.field {
                let val_str = match &review.proposed {
                    serde_json::Value::String(s) => s.clone(),
                    serde_json::Value::Number(n) => n.to_string(),
                    other => other.to_string(),
                };
                match field_name.as_str() {
                    "ticket_price" => {
                        let price = review.proposed.as_i64().map(|p| p as i32);
                        sqlx::query(
                            r#"UPDATE attractions SET ticket_price = $1, last_verified = now(),
                               verification_status = 'verified', confidence = 0.85, updated_at = now()
                               WHERE id = $2"#,
                        )
                        .bind(price)
                        .bind(review.entity_id)
                        .execute(&mut *tx)
                        .await?;
                    }
                    "opening_time" => {
                        if let Some(t_str) = review.proposed.as_str() {
                            let t = chrono::NaiveTime::parse_from_str(t_str, "%H:%M:%S")
                                .or_else(|_| chrono::NaiveTime::parse_from_str(t_str, "%H:%M"))
                                .ok();
                            sqlx::query(
                                r#"UPDATE attractions SET opening_time = $1, last_verified = now(),
                                   confidence = 0.85, updated_at = now()
                                   WHERE id = $2"#,
                            )
                            .bind(t)
                            .bind(review.entity_id)
                            .execute(&mut *tx)
                            .await?;
                        }
                    }
                    "closing_time" => {
                        if let Some(t_str) = review.proposed.as_str() {
                            let t = chrono::NaiveTime::parse_from_str(t_str, "%H:%M:%S")
                                .or_else(|_| chrono::NaiveTime::parse_from_str(t_str, "%H:%M"))
                                .ok();
                            sqlx::query(
                                r#"UPDATE attractions SET closing_time = $1, last_verified = now(),
                                   confidence = 0.85, updated_at = now()
                                   WHERE id = $2"#,
                            )
                            .bind(t)
                            .bind(review.entity_id)
                            .execute(&mut *tx)
                            .await?;
                        }
                    }
                    "status" => {
                        sqlx::query(
                            "UPDATE attractions SET status = $1, updated_at = now() WHERE id = $2",
                        )
                        .bind(&val_str)
                        .bind(review.entity_id)
                        .execute(&mut *tx)
                        .await?;
                    }
                    _ => {
                        tracing::warn!(field = %field_name, "generic field update on attraction not explicitly handled");
                    }
                }
            } else if let Some(map) = review.proposed.as_object() {
                // 对象级更新
                for (k, v) in map {
                    if k == "ticket_price" {
                        let p = v.as_i64().map(|p| p as i32);
                        sqlx::query("UPDATE attractions SET ticket_price = $1 WHERE id = $2")
                            .bind(p)
                            .bind(review.entity_id)
                            .execute(&mut *tx)
                            .await?;
                    } else if k == "status" {
                        if let Some(s) = v.as_str() {
                            sqlx::query("UPDATE attractions SET status = $1 WHERE id = $2")
                                .bind(s)
                                .bind(review.entity_id)
                                .execute(&mut *tx)
                                .await?;
                        }
                    }
                }
                sqlx::query(
                    r#"UPDATE attractions SET last_verified = now(), verification_status = 'verified',
                       confidence = 0.85, updated_at = now() WHERE id = $1"#,
                )
                .bind(review.entity_id)
                .execute(&mut *tx)
                .await?;
            }
        }
        "attraction_hours" => {
            sqlx::query(
                r#"UPDATE attraction_hours SET verification_status = 'verified',
                   confidence = 0.85, last_verified = now() WHERE id = $1"#,
            )
            .bind(review.entity_id)
            .execute(&mut *tx)
            .await?;
        }
        _ => {}
    }

    // 标记 review 已采纳
    sqlx::query(
        r#"UPDATE data_reviews
           SET status = 'verified', reviewer_id = $1, reviewed_at = now()
           WHERE id = $2"#,
    )
    .bind(reviewer_id)
    .bind(review_id)
    .execute(&mut *tx)
    .await?;

    // 写审计日志
    sqlx::query(
        r#"INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, detail, created_at)
           VALUES ($1, 'approve_review', $2, $3, $4, now())"#,
    )
    .bind(reviewer_id)
    .bind(&review.entity_type)
    .bind(review.entity_id)
    .bind(serde_json::json!({
        "review_id": review_id,
        "proposed": review.proposed
    }))
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

pub async fn reject_review(
    pool: &PgPool,
    review_id: Uuid,
    reviewer_id: Uuid,
    reason: String,
) -> ApiResult<()> {
    let mut tx = pool.begin().await?;

    let review = sqlx::query_as::<_, ReviewRow>(
        r#"SELECT id, entity_type, entity_id, field, proposed, current,
                  source_type::text AS source_type, source_url, status::text AS status,
                  reason, submitter_id, reviewer_id, reviewed_at, created_at
           FROM data_reviews WHERE id = $1 FOR UPDATE"#,
    )
    .bind(review_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| ApiError::NotFound("review not found".into()))?;

    if review.status != "pending" {
        return Err(ApiError::BadRequest(format!(
            "review is already in {} status",
            review.status
        )));
    }

    sqlx::query(
        r#"UPDATE data_reviews
           SET status = 'disputed', reviewer_id = $1, reviewed_at = now(), reason = $2
           WHERE id = $3"#,
    )
    .bind(reviewer_id)
    .bind(&reason)
    .bind(review_id)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        r#"INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, detail, created_at)
           VALUES ($1, 'reject_review', $2, $3, $4, now())"#,
    )
    .bind(reviewer_id)
    .bind(&review.entity_type)
    .bind(review.entity_id)
    .bind(serde_json::json!({
        "review_id": review_id,
        "reason": reason
    }))
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

pub async fn list_hours_for_review(
    pool: &PgPool,
    status: Option<&str>,
    limit: i64,
    offset: i64,
) -> ApiResult<Vec<HoursReviewRow>> {
    let st = status.unwrap_or("pending");
    let rows: Vec<HoursReviewRow> = sqlx::query_as(
        r#"SELECT h.id, h.attraction_id, a.name AS attraction_name, a.city,
                  h.weekday, h.season, h.open_time, h.close_time, h.note,
                  h.source_type::text AS source_type, h.source_url, h.source_time,
                  h.last_verified, h.verification_status::text AS verification_status,
                  h.confidence
           FROM attraction_hours h
           JOIN attractions a ON a.id = h.attraction_id
           WHERE ($1 = '' OR h.verification_status::text = $1)
           ORDER BY a.popularity DESC, h.weekday NULLS FIRST
           LIMIT $2 OFFSET $3"#,
    )
    .bind(st)
    .bind(limit.clamp(1, 100))
    .bind(offset.max(0))
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

pub async fn approve_hours(
    pool: &PgPool,
    hours_id: Uuid,
    admin_id: Uuid,
    writeback: bool,
) -> ApiResult<()> {
    let mut tx = pool.begin().await?;

    let row = sqlx::query_as::<_, (Uuid, chrono::NaiveTime, chrono::NaiveTime)>(
        r#"SELECT attraction_id, open_time, close_time
           FROM attraction_hours WHERE id = $1 FOR UPDATE"#,
    )
    .bind(hours_id)
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| ApiError::NotFound("attraction_hours not found".into()))?;

    let (attraction_id, open_time, close_time) = row;

    sqlx::query(
        r#"UPDATE attraction_hours
           SET verification_status = 'verified', confidence = 0.85, last_verified = now()
           WHERE id = $1"#,
    )
    .bind(hours_id)
    .execute(&mut *tx)
    .await?;

    if writeback {
        sqlx::query(
            r#"UPDATE attractions
               SET opening_time = $1, closing_time = $2, last_verified = now(), updated_at = now()
               WHERE id = $3"#,
        )
        .bind(open_time)
        .bind(close_time)
        .bind(attraction_id)
        .execute(&mut *tx)
        .await?;
    }

    sqlx::query(
        r#"INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, detail, created_at)
           VALUES ($1, 'approve_hours', 'attraction_hours', $2, $3, now())"#,
    )
    .bind(admin_id)
    .bind(hours_id)
    .bind(serde_json::json!({
        "attraction_id": attraction_id,
        "writeback": writeback,
        "open_time": open_time.to_string(),
        "close_time": close_time.to_string()
    }))
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

pub async fn reject_hours(
    pool: &PgPool,
    hours_id: Uuid,
    admin_id: Uuid,
    reason: String,
) -> ApiResult<()> {
    let mut tx = pool.begin().await?;

    let exists: Option<Uuid> =
        sqlx::query_scalar("SELECT id FROM attraction_hours WHERE id = $1 FOR UPDATE")
            .bind(hours_id)
            .fetch_optional(&mut *tx)
            .await?;

    if exists.is_none() {
        return Err(ApiError::NotFound("attraction_hours not found".into()));
    }

    sqlx::query(
        r#"UPDATE attraction_hours
           SET verification_status = 'disputed', note = COALESCE(note, '') || ' [驳回: ' || $2 || ']'
           WHERE id = $1"#,
    )
    .bind(hours_id)
    .bind(&reason)
    .execute(&mut *tx)
    .await?;

    sqlx::query(
        r#"INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, detail, created_at)
           VALUES ($1, 'reject_hours', 'attraction_hours', $2, $3, now())"#,
    )
    .bind(admin_id)
    .bind(hours_id)
    .bind(serde_json::json!({ "reason": reason }))
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

pub async fn list_audit_logs(pool: &PgPool, limit: i64) -> ApiResult<Vec<AdminAuditRow>> {
    let rows: Vec<AdminAuditRow> = sqlx::query_as(
        r#"SELECT l.id, l.admin_id, u.display_name AS admin_name, l.action,
                  l.entity_type, l.entity_id, l.detail, l.created_at
           FROM admin_audit_log l
           LEFT JOIN users u ON u.id = l.admin_id
           ORDER BY l.created_at DESC
           LIMIT $1"#,
    )
    .bind(limit.clamp(1, 100))
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BatchAdoptResult {
    pub total: usize,
    pub adopted: usize,
    pub failed_ids: Vec<Uuid>,
}

pub async fn batch_approve_hours(
    pool: &PgPool,
    hours_ids: &[Uuid],
    admin_id: Uuid,
    writeback: bool,
) -> ApiResult<BatchAdoptResult> {
    let mut adopted = 0;
    let mut failed_ids = Vec::new();

    for &id in hours_ids {
        match approve_hours(pool, id, admin_id, writeback).await {
            Ok(()) => adopted += 1,
            Err(e) => {
                tracing::warn!(id = %id, error = %e, "batch approve hours failed for item");
                failed_ids.push(id);
            }
        }
    }

    Ok(BatchAdoptResult {
        total: hours_ids.len(),
        adopted,
        failed_ids,
    })
}
