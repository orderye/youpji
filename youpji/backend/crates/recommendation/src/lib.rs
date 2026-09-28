//! 推荐：V0.1 规则版（标签分 + 画像占位）
use common::state::AppState;
use serde::Serialize;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct Recommended {
    pub id: Uuid,
    pub name: String,
    pub score: f64,
}

pub async fn nearby_popular(state: &AppState, city: Option<&str>, limit: i64) -> Vec<Recommended> {
    let rows: Vec<Recommended> = sqlx::query_as(
        r#"SELECT id, name, (popularity::float8 * 0.5 + family_score::float8 * 0.5) AS score
           FROM attractions
           WHERE ($1::text IS NULL OR city = $1)
           ORDER BY popularity DESC
           LIMIT $2"#,
    )
    .bind(city)
    .bind(limit.clamp(1, 50))
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();
    rows
}
