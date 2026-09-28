use common::error::{ApiError, ApiResult};
use common::paging::{Page, Paged};
use common::state::AppState;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct AttractionRow {
    pub id: Uuid,
    pub destination_id: Option<Uuid>,
    pub name: String,
    pub alias: Option<String>,
    pub province: String,
    pub city: Option<String>,
    pub district: Option<String>,
    pub longitude: f64,
    pub latitude: f64,
    pub category: Option<String>,
    pub level: Option<String>,
    pub description: Option<String>,
    pub opening_time: Option<chrono::NaiveTime>,
    pub closing_time: Option<chrono::NaiveTime>,
    pub ticket_price: Option<i32>,
    pub recommended_duration_min: Option<i32>,
    pub difficulty: Option<i16>,
    pub family_score: i16,
    pub elderly_score: i16,
    pub photography_score: i16,
    pub couple_score: i16,
    pub indoor: bool,
    pub popularity: i32,
    pub parking: Option<String>,
    pub transport: Option<String>,
    pub verification_status: String,
    pub confidence: f64,
    pub last_verified: Option<chrono::DateTime<chrono::Utc>>,
    pub source_type: String,
    pub source_url: Option<String>,
}

#[derive(Debug, FromRow, Serialize)]
pub struct TagRow {
    pub tag_key: String,
    pub label: Option<String>,
    pub score: i16,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct AttractionDetail {
    #[serde(flatten)]
    pub base: AttractionRow,
    pub tags: Vec<TagRow>,
    pub tickets: Vec<TicketRow>,
    pub hours: Vec<HoursRow>,
    pub guides: Vec<GuideRow>,
}

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct TicketRow {
    pub id: Uuid,
    pub name: String,
    pub price: i32,
    pub eligibility: Option<String>,
    pub verification_status: String,
}

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct HoursRow {
    pub weekday: Option<i16>,
    pub open_time: chrono::NaiveTime,
    pub close_time: chrono::NaiveTime,
    pub note: Option<String>,
    pub verification_status: String,
}

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct GuideRow {
    pub id: Uuid,
    pub title: String,
    pub summary: String,
    pub topic: Option<String>,
    pub verification_status: String,
    pub source_url: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ListQuery {
    #[serde(flatten)]
    pub page: Page,
    pub city: Option<String>,
    pub category: Option<String>,
    pub destination_id: Option<Uuid>,
    pub tag: Option<String>,
    pub q: Option<String>,
    /// 起点经纬度（gcj02），附近搜索
    pub lng: Option<f64>,
    pub lat: Option<f64>,
    pub radius_km: Option<f64>,
}

pub async fn list(state: &AppState, q: ListQuery) -> ApiResult<Paged<AttractionRow>> {
    let limit = q.page.limit();
    let offset = q.page.offset();
    let radius_m = q.radius_km.unwrap_or(50.0) * 1000.0;

    let rows: Vec<AttractionRow> = sqlx::query_as(
        r#"SELECT a.id, a.destination_id, a.name, a.alias, a.province, a.city, a.district,
                  a.longitude, a.latitude, a.category, a.level, a.description,
                  a.opening_time, a.closing_time, a.ticket_price, a.recommended_duration_min,
                  a.difficulty, a.family_score, a.elderly_score, a.photography_score,
                  a.couple_score, a.indoor, a.popularity, a.parking, a.transport,
                  a.verification_status::text AS verification_status, a.confidence,
                  a.last_verified, a.source_type::text AS source_type, a.source_url
           FROM attractions a
           WHERE ($1::text IS NULL OR a.city = $1)
             AND ($2::text IS NULL OR a.category = $2)
             AND ($3::uuid IS NULL OR a.destination_id = $3)
             AND ($4::text IS NULL OR a.name ILIKE '%' || $4 || '%' OR COALESCE(a.alias,'') ILIKE '%' || $4 || '%')
             AND ($5::uuid IS NULL OR EXISTS (
                   SELECT 1 FROM attraction_tags t WHERE t.attraction_id = a.id AND t.tag_key = $5::text
             ))
             AND ($6::float8 IS NULL OR ST_DWithin(
                   a.geog, ST_SetSRID(ST_MakePoint($7::float8, $8::float8), 4326)::geography, $9::float8
             ))
           ORDER BY a.popularity DESC, a.name
           LIMIT $10 OFFSET $11"#,
    )
    .bind(&q.city)
    .bind(&q.category)
    .bind(q.destination_id)
    .bind(&q.q)
    .bind(&q.tag)
    .bind(if q.lng.is_some() && q.lat.is_some() { q.lng } else { None })
    .bind(q.lng.unwrap_or(0.0))
    .bind(q.lat.unwrap_or(0.0))
    .bind(radius_m)
    .bind(limit)
    .bind(offset)
    .fetch_all(&state.pool)
    .await?;

    // tag filter uses tag_key — if caller passed Chinese label, map it
    // (simplified: already bound as text; seed uses keys)

    Ok(Paged::new(rows, &q.page))
}

pub async fn detail(state: &AppState, id: Uuid) -> ApiResult<AttractionDetail> {
    let base = sqlx::query_as::<_, AttractionRow>(
        r#"SELECT id, destination_id, name, alias, province, city, district,
                  longitude, latitude, category, level, description,
                  opening_time, closing_time, ticket_price, recommended_duration_min,
                  difficulty, family_score, elderly_score, photography_score,
                  couple_score, indoor, popularity, parking, transport,
                  verification_status::text AS verification_status, confidence,
                  last_verified, source_type::text AS source_type, source_url
           FROM attractions WHERE id = $1"#,
    )
    .bind(id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("attraction not found".into()))?;

    let tags = sqlx::query_as::<_, TagRow>(
        r#"SELECT t.tag_key, v.label, t.score
           FROM attraction_tags t
           LEFT JOIN tag_vocab v ON v.key = t.tag_key
           WHERE t.attraction_id = $1
           ORDER BY t.score DESC"#,
    )
    .bind(id)
    .fetch_all(&state.pool)
    .await?;

    let tickets = sqlx::query_as::<_, TicketRow>(
        r#"SELECT id, name, price, eligibility, verification_status::text AS verification_status
           FROM attraction_tickets WHERE attraction_id = $1 ORDER BY price"#,
    )
    .bind(id)
    .fetch_all(&state.pool)
    .await?;

    let hours = sqlx::query_as::<_, HoursRow>(
        r#"SELECT weekday, open_time, close_time, note, verification_status::text AS verification_status
           FROM attraction_hours WHERE attraction_id = $1
           ORDER BY COALESCE(weekday, 7)"#,
    )
    .bind(id)
    .fetch_all(&state.pool)
    .await?;

    let guides = sqlx::query_as::<_, GuideRow>(
        r#"SELECT id, title, summary, topic::text AS topic,
                  verification_status::text AS verification_status, source_url
           FROM travel_contents
           WHERE attraction_id = $1
           ORDER BY last_verified DESC NULLS LAST
           LIMIT 8"#,
    )
    .bind(id)
    .fetch_all(&state.pool)
    .await?;

    Ok(AttractionDetail {
        base,
        tags,
        tickets,
        hours,
        guides,
    })
}
