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
    pub status: String,
    pub parking: Option<String>,
    pub transport: Option<String>,
    pub verification_status: String,
    pub confidence: f64,
    pub last_verified: Option<chrono::DateTime<chrono::Utc>>,
    pub source_type: String,
    pub source_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[sqlx(default)]
    pub distance_meters: Option<f64>,
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
    pub sort_by: Option<String>,
}

pub async fn list(state: &AppState, q: ListQuery) -> ApiResult<Paged<AttractionRow>> {
    let limit = q.page.limit();
    let offset = q.page.offset();
    let radius_m = q.radius_km.unwrap_or(50.0) * 1000.0;
    let sort_by = q.sort_by.unwrap_or_default();

    let rows: Vec<AttractionRow> = sqlx::query_as(
        r#"SELECT a.id, a.destination_id, a.name, a.alias, a.province, a.city, a.district,
                  a.longitude, a.latitude, a.category, a.level, a.description,
                  a.opening_time, a.closing_time, a.ticket_price, a.recommended_duration_min,
                  a.difficulty, a.family_score, a.elderly_score, a.photography_score,
                  a.couple_score, a.indoor, a.popularity, a.status, a.parking, a.transport,
                  a.verification_status::text AS verification_status, a.confidence,
                  a.last_verified, a.source_type::text AS source_type, a.source_url,
                  CASE WHEN $6::float8 IS NOT NULL THEN
                    ST_Distance(a.geog, ST_SetSRID(ST_MakePoint($7::float8, $8::float8), 4326)::geography)
                  ELSE NULL END AS distance_meters
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
           ORDER BY
             CASE WHEN $12::text = 'distance' AND $6::float8 IS NOT NULL THEN
               ST_Distance(a.geog, ST_SetSRID(ST_MakePoint($7::float8, $8::float8), 4326)::geography)
             ELSE NULL END ASC NULLS LAST,
             a.popularity DESC, a.name
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
    .bind(sort_by)
    .fetch_all(&state.pool)
    .await?;

    Ok(Paged::new(rows, &q.page))
}

pub async fn detail(state: &AppState, id: Uuid) -> ApiResult<AttractionDetail> {
    let base = sqlx::query_as::<_, AttractionRow>(
        r#"SELECT id, destination_id, name, alias, province, city, district,
                  longitude, latitude, category, level, description,
                  opening_time, closing_time, ticket_price, recommended_duration_min,
                  difficulty, family_score, elderly_score, photography_score,
                  couple_score, indoor, popularity, status, parking, transport,
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

#[derive(Debug, Deserialize)]
pub struct AdminListQuery {
    #[serde(flatten)]
    pub page: Page,
    pub city: Option<String>,
    pub category: Option<String>,
    pub level: Option<String>,
    pub verification_status: Option<String>,
    pub status: Option<String>,
    pub q: Option<String>,
}

pub async fn admin_list(state: &AppState, q: AdminListQuery) -> ApiResult<Paged<AttractionRow>> {
    let limit = q.page.limit();
    let offset = q.page.offset();

    let rows: Vec<AttractionRow> = sqlx::query_as(
        r#"SELECT a.id, a.destination_id, a.name, a.alias, a.province, a.city, a.district,
                  a.longitude, a.latitude, a.category, a.level, a.description,
                  a.opening_time, a.closing_time, a.ticket_price, a.recommended_duration_min,
                  a.difficulty, a.family_score, a.elderly_score, a.photography_score,
                  a.couple_score, a.indoor, a.popularity, a.status, a.parking, a.transport,
                  a.verification_status::text AS verification_status, a.confidence,
                  a.last_verified, a.source_type::text AS source_type, a.source_url
           FROM attractions a
           WHERE ($1::text IS NULL OR a.city = $1)
             AND ($2::text IS NULL OR a.category = $2)
             AND ($3::text IS NULL OR a.level = $3)
             AND ($4::text IS NULL OR a.verification_status::text = $4)
             AND ($5::text IS NULL OR a.status = $5)
             AND ($6::text IS NULL OR a.name ILIKE '%' || $6 || '%' OR COALESCE(a.alias,'') ILIKE '%' || $6 || '%')
           ORDER BY a.popularity DESC, a.name
           LIMIT $7 OFFSET $8"#,
    )
    .bind(&q.city)
    .bind(&q.category)
    .bind(&q.level)
    .bind(&q.verification_status)
    .bind(&q.status)
    .bind(&q.q)
    .bind(limit)
    .bind(offset)
    .fetch_all(&state.pool)
    .await?;

    Ok(Paged::new(rows, &q.page))
}

#[derive(Debug, Deserialize)]
pub struct AdminVerifyInput {
    pub verification_status: Option<String>,
    pub confidence: Option<f64>,
    pub source_url: Option<String>,
    pub source_type: Option<String>,
    pub ticket_price: Option<i32>,
    pub opening_time: Option<chrono::NaiveTime>,
    pub closing_time: Option<chrono::NaiveTime>,
}

pub async fn admin_verify(state: &AppState, id: Uuid, input: AdminVerifyInput) -> ApiResult<()> {
    let status = input
        .verification_status
        .unwrap_or_else(|| "verified".into());
    let confidence = input.confidence.unwrap_or(0.9);
    let source_type = input.source_type.unwrap_or_else(|| "official".into());

    let mut tx = state.pool.begin().await?;

    let exists: Option<Uuid> =
        sqlx::query_scalar("SELECT id FROM attractions WHERE id = $1 FOR UPDATE")
            .bind(id)
            .fetch_optional(&mut *tx)
            .await?;
    if exists.is_none() {
        return Err(ApiError::NotFound("attraction not found".into()));
    }

    sqlx::query(
        r#"UPDATE attractions
           SET verification_status = $1::verification_status,
               confidence = $2,
               source_type = $3::source_type,
               source_url = COALESCE($4, source_url),
               ticket_price = COALESCE($5, ticket_price),
               opening_time = COALESCE($6, opening_time),
               closing_time = COALESCE($7, closing_time),
               last_verified = now(),
               updated_at = now()
           WHERE id = $8"#,
    )
    .bind(&status)
    .bind(confidence)
    .bind(&source_type)
    .bind(&input.source_url)
    .bind(input.ticket_price)
    .bind(input.opening_time)
    .bind(input.closing_time)
    .bind(id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}

#[derive(Debug, Deserialize)]
pub struct AdminUpdateInput {
    pub name: Option<String>,
    pub alias: Option<String>,
    pub category: Option<String>,
    pub level: Option<String>,
    pub description: Option<String>,
    pub opening_time: Option<chrono::NaiveTime>,
    pub closing_time: Option<chrono::NaiveTime>,
    pub ticket_price: Option<i32>,
    pub status: Option<String>,
    pub longitude: Option<f64>,
    pub latitude: Option<f64>,
    pub parking: Option<String>,
    pub transport: Option<String>,
}

pub async fn admin_update(state: &AppState, id: Uuid, input: AdminUpdateInput) -> ApiResult<()> {
    let mut tx = state.pool.begin().await?;

    let exists: Option<Uuid> =
        sqlx::query_scalar("SELECT id FROM attractions WHERE id = $1 FOR UPDATE")
            .bind(id)
            .fetch_optional(&mut *tx)
            .await?;
    if exists.is_none() {
        return Err(ApiError::NotFound("attraction not found".into()));
    }

    sqlx::query(
        r#"UPDATE attractions
           SET name = COALESCE($1, name),
               alias = COALESCE($2, alias),
               category = COALESCE($3, category),
               level = COALESCE($4, level),
               description = COALESCE($5, description),
               opening_time = COALESCE($6, opening_time),
               closing_time = COALESCE($7, closing_time),
               ticket_price = COALESCE($8, ticket_price),
               status = COALESCE($9, status),
               longitude = COALESCE($10, longitude),
               latitude = COALESCE($11, latitude),
               parking = COALESCE($12, parking),
               transport = COALESCE($13, transport),
               updated_at = now()
           WHERE id = $14"#,
    )
    .bind(&input.name)
    .bind(&input.alias)
    .bind(&input.category)
    .bind(&input.level)
    .bind(&input.description)
    .bind(input.opening_time)
    .bind(input.closing_time)
    .bind(input.ticket_price)
    .bind(&input.status)
    .bind(input.longitude)
    .bind(input.latitude)
    .bind(&input.parking)
    .bind(&input.transport)
    .bind(id)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(())
}
