//! 用户画像与偏好
use common::error::ApiResult;
use common::state::AppState;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize, Serialize)]
pub struct PreferencesInput {
    pub interests: Vec<String>,
    pub avoid: Vec<String>,
    pub intensity: String,
    pub lodging_tier: String,
    pub budget_hint: Option<i32>,
}

pub async fn get_preferences(state: &AppState, user_id: Uuid) -> ApiResult<PreferencesInput> {
    let row = sqlx::query_as::<_, (Vec<String>, Vec<String>, String, String, Option<i32>)>(
        r#"SELECT interests, avoid, intensity, lodging_tier, budget_hint
           FROM user_preferences WHERE user_id = $1"#,
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await?;
    Ok(row
        .map(
            |(interests, avoid, intensity, lodging_tier, budget_hint)| PreferencesInput {
                interests,
                avoid,
                intensity,
                lodging_tier,
                budget_hint,
            },
        )
        .unwrap_or(PreferencesInput {
            interests: vec![],
            avoid: vec![],
            intensity: "medium".into(),
            lodging_tier: "standard".into(),
            budget_hint: None,
        }))
}

pub async fn upsert_preferences(
    state: &AppState,
    user_id: Uuid,
    input: PreferencesInput,
) -> ApiResult<()> {
    sqlx::query(
        r#"INSERT INTO user_preferences (user_id, interests, avoid, intensity, lodging_tier, budget_hint, updated_at)
           VALUES ($1,$2,$3,$4,$5,$6, now())
           ON CONFLICT (user_id) DO UPDATE SET
             interests = EXCLUDED.interests,
             avoid = EXCLUDED.avoid,
             intensity = EXCLUDED.intensity,
             lodging_tier = EXCLUDED.lodging_tier,
             budget_hint = EXCLUDED.budget_hint,
             updated_at = now()"#,
    )
    .bind(user_id)
    .bind(&input.interests)
    .bind(&input.avoid)
    .bind(&input.intensity)
    .bind(&input.lodging_tier)
    .bind(input.budget_hint)
    .execute(&state.pool)
    .await?;
    Ok(())
}
