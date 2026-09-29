use common::error::ApiResult;
use common::paging::{Page, Paged};
use common::state::AppState;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct RestaurantRow {
    pub id: Uuid,
    pub name: String,
    pub category: Option<String>,
    pub city: Option<String>,
    pub district: Option<String>,
    pub longitude: Option<f64>,
    pub latitude: Option<f64>,
    pub price_per_person: Option<i32>,
    pub rating: Option<f32>,
    pub signature_dishes: Option<Vec<String>>,
    pub opening_hours: Option<String>,
    pub parking: bool,
    pub local_specialty: bool,
    pub cover_image_url: Option<String>,
    pub verification_status: String,
}

#[derive(Debug, Deserialize)]
pub struct ListQuery {
    pub city: Option<String>,
    pub lng: Option<f64>,
    pub lat: Option<f64>,
    pub radius_km: Option<f64>,
    #[serde(flatten)]
    pub page: Page,
}

pub async fn list(state: &AppState, q: ListQuery) -> ApiResult<Paged<RestaurantRow>> {
    let limit = q.page.limit();
    let offset = q.page.offset();
    let radius_m = q.radius_km.unwrap_or(10.0) * 1000.0;
    let rows = sqlx::query_as::<_, RestaurantRow>(
        r#"SELECT id, name, category, city, district, longitude, latitude,
                  price_per_person, rating::float8 AS rating, signature_dishes,
                  opening_hours, parking, local_specialty,
                  cover_image_url,
                  verification_status::text AS verification_status
           FROM restaurants
           WHERE ($1::text IS NULL OR city = $1)
             AND ($2::float8 IS NULL OR longitude IS NULL OR ST_DWithin(
                   geog, ST_SetSRID(ST_MakePoint($3::float8, $4::float8), 4326)::geography, $5::float8
             ))
           ORDER BY rating DESC NULLS LAST
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
