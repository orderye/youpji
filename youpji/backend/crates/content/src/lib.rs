use common::error::ApiResult;
use common::state::AppState;
use serde::Serialize;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ContentRow {
    pub id: Uuid,
    pub attraction_id: Option<Uuid>,
    pub title: String,
    pub summary: String,
    pub topic: Option<String>,
    pub source_url: Option<String>,
    pub verification_status: String,
    pub confidence: f64,
}

pub async fn list_by_attraction(
    state: &AppState,
    attraction_id: Uuid,
    limit: i64,
) -> ApiResult<Vec<ContentRow>> {
    let rows = sqlx::query_as::<_, ContentRow>(
        r#"SELECT id, attraction_id, title, summary, topic::text AS topic,
                  source_url, verification_status::text AS verification_status, confidence
           FROM travel_contents
           WHERE attraction_id = $1
           ORDER BY confidence DESC, last_verified DESC NULLS LAST
           LIMIT $2"#,
    )
    .bind(attraction_id)
    .bind(limit.clamp(1, 50))
    .fetch_all(&state.pool)
    .await?;
    Ok(rows)
}

/// 简易关键词召回（V0.1 先 ILIKE，后续换 pgvector）
pub async fn search(state: &AppState, q: &str, limit: i64) -> ApiResult<Vec<ContentRow>> {
    let rows = sqlx::query_as::<_, ContentRow>(
        r#"SELECT id, attraction_id, title, summary, topic::text AS topic,
                  source_url, verification_status::text AS verification_status, confidence
           FROM travel_contents
           WHERE title ILIKE '%' || $1 || '%' OR summary ILIKE '%' || $1 || '%'
           ORDER BY confidence DESC
           LIMIT $2"#,
    )
    .bind(q)
    .bind(limit.clamp(1, 50))
    .fetch_all(&state.pool)
    .await?;
    Ok(rows)
}
