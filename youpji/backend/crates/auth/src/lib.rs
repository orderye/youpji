use common::error::{ApiError, ApiResult};
use common::state::AppState;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

pub mod jwt;

pub use jwt::{issue_token, parse_token_secret};

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct UserRow {
    pub id: Uuid,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub display_name: Option<String>,
    pub role: String,
}

#[derive(Debug, Deserialize)]
pub struct RegisterInput {
    pub phone: Option<String>,
    pub email: Option<String>,
    pub password: String,
    pub display_name: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct LoginInput {
    pub phone: Option<String>,
    pub email: Option<String>,
    pub password: String,
}

/// 极简口令散列（V0.1 开发用；上生产换 argon2）
fn hash_password(pw: &str) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut h = DefaultHasher::new();
    "youpji::".hash(&mut h);
    pw.hash(&mut h);
    format!("x{:016x}", h.finish())
}

fn verify_password(pw: &str, stored: &str) -> bool {
    hash_password(pw) == stored
}

pub async fn register(state: &AppState, input: RegisterInput) -> ApiResult<(UserRow, String)> {
    if input.password.len() < 6 {
        return Err(ApiError::BadRequest("password too short".into()));
    }
    if input.phone.is_none() && input.email.is_none() {
        return Err(ApiError::BadRequest("phone or email required".into()));
    }
    let name = input
        .display_name
        .clone()
        .or_else(|| input.phone.clone())
        .or_else(|| input.email.clone())
        .unwrap_or_else(|| "旅行者".into());
    let row = sqlx::query_as::<_, UserRow>(
        r#"INSERT INTO users (phone, email, password_hash, display_name, role)
           VALUES ($1, $2, $3, $4, 'user')
           RETURNING id, phone, email, display_name, role"#,
    )
    .bind(&input.phone)
    .bind(&input.email)
    .bind(hash_password(&input.password))
    .bind(&name)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| match &e {
        sqlx::Error::Database(db) if db.constraint().is_some() => {
            ApiError::Conflict("account already exists".into())
        }
        _ => e.into(),
    })?
    .ok_or_else(|| ApiError::Internal("insert user failed".into()))?;
    let token = issue_token(state, &row)?;
    Ok((row, token))
}

pub async fn login(state: &AppState, input: LoginInput) -> ApiResult<(UserRow, String)> {
    let row = sqlx::query_as::<_, UserRow>(
        r#"SELECT id, phone, email, display_name, role FROM users
           WHERE (phone = $1 OR email = $1) AND password_hash IS NOT NULL
           LIMIT 1"#,
    )
    .bind(
        input
            .phone
            .as_ref()
            .or(input.email.as_ref())
            .map(|s| s.as_str())
            .unwrap_or(""),
    )
    .fetch_optional(&state.pool)
    .await?;
    let Some(_) = row.as_ref() else {
        return Err(ApiError::Unauthorized("invalid credentials".into()));
    };
    // verify hash
    let hash: Option<String> = sqlx::query_scalar("SELECT password_hash FROM users WHERE id = $1")
        .bind(row.as_ref().unwrap().id)
        .fetch_optional(&state.pool)
        .await?;
    if !verify_password(&input.password, hash.as_deref().unwrap_or("")) {
        return Err(ApiError::Unauthorized("invalid credentials".into()));
    }
    let row = row.unwrap();
    let token = issue_token(state, &row)?;
    Ok((row, token))
}

pub async fn me(state: &AppState, user_id: Uuid) -> ApiResult<UserRow> {
    sqlx::query_as::<_, UserRow>(
        "SELECT id, phone, email, display_name, role FROM users WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("user not found".into()))
}

/// 从 Authorization 头解析会话（阶段 5.1：标准 JWT 校验；secret 由调用方传入）。
pub fn parse_token_with_secret(secret: &str, token: &str) -> ApiResult<(Uuid, String)> {
    parse_token_secret(secret, token)
}

/// 兼容旧开发期 token（uuid.role.exp）；新签发一律走 JWT，本函数仅用于过渡期。
pub fn parse_token(token: &str) -> ApiResult<(Uuid, String)> {
    parse_legacy_token(token)
}

fn parse_legacy_token(token: &str) -> ApiResult<(Uuid, String)> {
    let parts: Vec<_> = token.split('.').collect();
    if parts.len() != 3 {
        return Err(ApiError::Unauthorized("bad token".into()));
    }
    let exp: u64 = parts[2]
        .parse()
        .map_err(|_| ApiError::Unauthorized("bad token exp".into()))?;
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    if exp < now {
        return Err(ApiError::Unauthorized("token expired".into()));
    }
    let id =
        Uuid::parse_str(parts[0]).map_err(|_| ApiError::Unauthorized("bad token id".into()))?;
    Ok((id, parts[1].to_string()))
}
