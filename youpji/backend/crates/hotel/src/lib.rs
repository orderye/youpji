use common::error::ApiResult;
use common::paging::{Page, Paged};
use common::state::AppState;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct HotelRow {
    pub id: Uuid,
    pub name: String,
    pub brand: Option<String>,
    pub address: Option<String>,
    pub longitude: Option<f64>,
    pub latitude: Option<f64>,
    pub price_min: Option<i32>,
    pub price_max: Option<i32>,
    pub rating: Option<f64>,
    pub parking: bool,
    pub breakfast: bool,
    pub family_friendly: bool,
    pub city: Option<String>,
    pub district: Option<String>,
    pub booking_url: Option<String>,
    pub cover_image_url: Option<String>,
    pub verification_status: String,
}

// rust_decimal not in workspace — use f32 via text cast instead: redefine with Option<f32>
// We'll cast rating::float8 in SQL to avoid extra dep.

#[derive(Debug, Deserialize)]
pub struct ListQuery {
    pub city: Option<String>,
    pub lng: Option<f64>,
    pub lat: Option<f64>,
    pub radius_km: Option<f64>,
    #[serde(flatten)]
    pub page: Page,
}

pub async fn list(state: &AppState, q: ListQuery) -> ApiResult<Paged<HotelRow>> {
    let limit = q.page.limit();
    let offset = q.page.offset();
    let radius_m = q.radius_km.unwrap_or(15.0) * 1000.0;
    let rows = sqlx::query_as::<_, HotelRow>(
        r#"SELECT id, name, brand, address, longitude, latitude,
                  price_min, price_max, rating::float8 AS rating,
                  parking, breakfast, family_friendly, city, district, booking_url,
                  cover_image_url,
                  verification_status::text AS verification_status
           FROM hotels
           WHERE ($1::text IS NULL OR city = $1)
             AND ($2::float8 IS NULL OR longitude IS NULL OR ST_DWithin(
                   geog, ST_SetSRID(ST_MakePoint($3::float8, $4::float8), 4326)::geography, $5::float8
             ))
           ORDER BY price_min NULLS LAST
           LIMIT $6"#,
    )
    .bind(q.city)
    .bind(if q.lng.is_some() && q.lat.is_some() { q.lng } else { None })
    .bind(q.lng.unwrap_or(0.0))
    .bind(q.lat.unwrap_or(0.0))
    .bind(radius_m)
    .bind(limit)
    .bind(offset)
    .fetch_all(&state.pool)
    .await?;
    Ok(Paged::new(rows, &q.page))
}
