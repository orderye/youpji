//! 天气：V0.1 只读 DB 缓存；无外部 Key 时返回占位
use common::state::AppState;
use serde::Serialize;
use sqlx::FromRow;

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct WeatherRow {
    pub city: String,
    pub date: chrono::NaiveDate,
    pub temp_min: Option<i16>,
    pub temp_max: Option<i16>,
    pub precip_prob: Option<i16>,
    pub description: Option<String>,
}

pub async fn forecast(state: &AppState, city: &str, days: i32) -> Vec<WeatherRow> {
    sqlx::query_as::<_, WeatherRow>(
        r#"SELECT city, date, temp_min, temp_max, precip_prob, description
           FROM weather WHERE city = $1 AND date >= CURRENT_DATE
           ORDER BY date LIMIT $2"#,
    )
    .bind(city)
    .bind(days.clamp(1, 15))
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default()
}
