use common::error::ApiResult;
use common::paging::{Page, Paged};
use common::state::AppState;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct Destination {
    pub id: Uuid,
    pub parent_id: Option<Uuid>,
    pub name: String,
    pub level: String,
    pub full_path: Option<String>,
    pub longitude: Option<f64>,
    pub latitude: Option<f64>,
    pub cover_image_url: Option<String>,
    pub verification_status: String,
    pub confidence: f64,
}

#[derive(Debug, Deserialize)]
pub struct ListQuery {
    #[serde(flatten)]
    pub page: Page,
    pub parent_id: Option<Uuid>,
    pub q: Option<String>,
    pub level: Option<String>,
}

pub async fn list(state: &AppState, q: ListQuery) -> ApiResult<Paged<Destination>> {
    let limit = q.page.limit();
    let offset = q.page.offset();
    let parent_id = q.parent_id;
    let level = q.level;
    let keyword = q.q;

    let rows: Vec<Destination> = sqlx::query_as(
        r#"SELECT id, parent_id, name, level::text AS level, full_path, longitude, latitude,
                  cover_image_url,
                  verification_status::text AS verification_status, confidence
           FROM destinations
           WHERE ($1::uuid IS NULL OR parent_id = $1)
             AND ($2::text IS NULL OR level::text = $2)
             AND ($3::text IS NULL OR name ILIKE '%' || $3 || '%')
           ORDER BY level, name
           LIMIT $4 OFFSET $5"#,
    )
    .bind(parent_id)
    .bind(level)
    .bind(keyword)
    .bind(limit)
    .bind(offset)
    .fetch_all(&state.pool)
    .await?;

    // 阶段 5.3：统一 cursor 分页
    Ok(Paged::new(rows, &q.page))
}
