use crate::error::{ApiError, ApiResult};
use sqlx::PgPool;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::RwLock;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub redis: Option<redis::aio::ConnectionManager>,
    pub http: reqwest::Client,
    pub config: Arc<Config>,
    /// 幂等键缓存（阶段 5.4）：Idempotency-Key → (写入时间, 已返回的响应 JSON)。
    /// 优先走 Redis（多实例），Redis 不可用时降级为进程内缓存。
    pub idempotency: Arc<RwLock<HashMap<String, (Instant, serde_json::Value)>>>,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub database_url: String,
    pub redis_url: String,
    pub bind: String,
    pub jwt_secret: String,
    pub ai_base_url: String,
    pub ai_api_key: String,
    pub ollama_url: String,
    pub amap_key: String,
    pub cors_origins: Vec<String>,
}

impl Config {
    pub fn from_env() -> Self {
        dotenvy::dotenv().ok();
        let get = |k: &str, d: &str| std::env::var(k).unwrap_or_else(|_| d.to_string());
        Self {
            database_url: get(
                "DATABASE_URL",
                "postgres://youpji:youpji_dev@127.0.0.1:5433/youpji",
            ),
            redis_url: get("REDIS_URL", "redis://127.0.0.1:6380"),
            bind: get("BIND", "0.0.0.0:8081"),
            jwt_secret: get("JWT_SECRET", WEAK_JWT_SECRET),
            ai_base_url: get("AI_BASE_URL", ""),
            ai_api_key: get("AI_API_KEY", ""),
            ollama_url: get("OLLAMA_URL", "http://127.0.0.1:11434"),
            amap_key: get("AMAP_KEY", ""),
            cors_origins: get("CORS_ORIGINS", "*")
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect(),
        }
    }

    /// 启动自检：开发环境放行默认弱密钥；`APP_ENV=production` 时强制要求强密钥与非通配 CORS。
    ///
    /// 目的：避免生产环境静默使用 `dev-secret-change-me` 签发可伪造的 token。
    pub fn validate(&self) -> Result<(), String> {
        let app_env = std::env::var("APP_ENV").unwrap_or_else(|_| "development".into());
        if !app_env.eq_ignore_ascii_case("production") {
            return Ok(());
        }
        if self.jwt_secret == WEAK_JWT_SECRET || self.jwt_secret.len() < 32 {
            return Err(
                "APP_ENV=production requires JWT_SECRET to be set to a strong value (>=32 chars)"
                    .into(),
            );
        }
        if self.cors_origins.iter().any(|o| o == "*") {
            return Err("APP_ENV=production forbids CORS_ORIGINS=*; list explicit origins".into());
        }
        Ok(())
    }
}

/// 仅供本地开发；生产环境由 `Config::validate` 拒绝。
pub const WEAK_JWT_SECRET: &str = "dev-secret-change-me";

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct SessionUser {
    pub user_id: uuid::Uuid,
    pub role: String,
    pub display_name: Option<String>,
}

/// 幂等键 TTL：24h。
pub const IDEMPOTENCY_TTL_SECS: u64 = 24 * 3600;
/// 进程内降级缓存的容量上限：超出后淘汰最旧条目，避免无界增长。
const IDEMPOTENCY_MAX_ENTRIES: usize = 2000;
const REDIS_IDEM_PREFIX: &str = "youpji:idem:";

/// 读取幂等缓存。**优先 Redis**（多实例一致），不可用时降级进程内。
pub async fn idempotency_get(state: &AppState, key: &str) -> Option<serde_json::Value> {
    if let Some(cm) = state.redis.as_ref() {
        let mut conn = cm.clone();
        let hit: Option<Vec<u8>> = redis::cmd("GET")
            .arg(format!("{REDIS_IDEM_PREFIX}{key}"))
            .query_async(&mut conn)
            .await
            .ok()
            .flatten();
        match hit {
            Some(bytes) => match serde_json::from_slice(&bytes) {
                Ok(v) => return Some(v),
                Err(e) => tracing::warn!(%e, "idempotency cache payload corrupt, ignoring"),
            },
            None => return None,
        }
    }
    let map = state.idempotency.read().await;
    let (at, v) = map.get(key)?;
    if at.elapsed().as_secs() > IDEMPOTENCY_TTL_SECS {
        return None;
    }
    Some(v.clone())
}

/// 写入幂等缓存。Redis 可用则写 Redis；无论是否成功，都再写一份进程内降级副本。
pub async fn idempotency_put(state: &AppState, key: String, value: serde_json::Value) {
    if let Some(cm) = state.redis.as_ref() {
        let mut conn = cm.clone();
        let payload = match serde_json::to_vec(&value) {
            Ok(p) => p,
            Err(e) => {
                tracing::warn!(%e, "serialize idempotency payload failed");
                return;
            }
        };
        let res: redis::RedisResult<()> = redis::cmd("SET")
            .arg(format!("{REDIS_IDEM_PREFIX}{key}"))
            .arg(payload)
            .arg("EX")
            .arg(IDEMPOTENCY_TTL_SECS)
            .query_async(&mut conn)
            .await;
        if let Err(e) = res {
            tracing::warn!(%e, "redis idempotency write failed, falling back to memory");
        }
    }

    let mut map = state.idempotency.write().await;
    map.retain(|_, (at, _)| at.elapsed().as_secs() <= IDEMPOTENCY_TTL_SECS);
    if map.len() >= IDEMPOTENCY_MAX_ENTRIES {
        // 淘汰最旧一条，保证容量有界
        if let Some(oldest) = map
            .iter()
            .min_by_key(|(_, (at, _))| *at)
            .map(|(k, _)| k.clone())
        {
            map.remove(&oldest);
        }
    }
    map.insert(key, (Instant::now(), value));
}

pub fn require_admin(user: &SessionUser) -> ApiResult<()> {
    if user.role == "admin" {
        Ok(())
    } else {
        Err(ApiError::Forbidden("admin only".into()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cfg(secret: &str, cors: &[&str]) -> Config {
        Config {
            database_url: String::new(),
            redis_url: String::new(),
            bind: String::new(),
            jwt_secret: secret.into(),
            ai_base_url: String::new(),
            ai_api_key: String::new(),
            ollama_url: String::new(),
            amap_key: String::new(),
            cors_origins: cors.iter().map(|s| (*s).to_string()).collect(),
        }
    }

    /// 单测试内串行切换 APP_ENV，避免并行测试互相污染环境变量。
    #[test]
    fn validate_blocks_weak_secret_in_production_only() {
        let strong = "a-strong-production-secret-value-32chars";

        std::env::set_var("APP_ENV", "development");
        assert!(cfg(WEAK_JWT_SECRET, &["*"]).validate().is_ok());

        std::env::set_var("APP_ENV", "production");
        // 默认弱密钥 → 拒绝
        assert!(cfg(WEAK_JWT_SECRET, &["https://a.cn"]).validate().is_err());
        // 自定义但过短 → 拒绝
        assert!(cfg("short-secret", &["https://a.cn"]).validate().is_err());
        // 强密钥 + 通配 CORS → 仍拒绝
        assert!(cfg(strong, &["*"]).validate().is_err());
        // 强密钥 + 显式来源 → 放行
        assert!(cfg(strong, &["https://a.cn", "https://b.cn"])
            .validate()
            .is_ok());

        std::env::remove_var("APP_ENV");
    }
}
