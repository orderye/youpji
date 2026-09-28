use crate::error::{ApiError, ApiResult};
use crate::state::AppState;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::RwLock;

/// 内存限流回退表（IP/User Key -> (窗口起始时间, 请求计数)）
#[derive(Clone, Default)]
pub struct MemoryRateLimiter {
    table: Arc<RwLock<HashMap<String, (Instant, u32)>>>,
}

impl MemoryRateLimiter {
    pub fn new() -> Self {
        Self {
            table: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn check(&self, key: &str, max_requests: u32, window_secs: u64) -> ApiResult<()> {
        let mut map = self.table.write().await;
        let now = Instant::now();

        if let Some((start, count)) = map.get_mut(key) {
            if start.elapsed().as_secs() < window_secs {
                if *count >= max_requests {
                    return Err(ApiError::TooManyRequests(format!(
                        "rate limit exceeded: max {max_requests} requests per {window_secs}s"
                    )));
                }
                *count += 1;
                return Ok(());
            } else {
                *start = now;
                *count = 1;
                return Ok(());
            }
        }

        // 清理过期的条目，防止无界扩增
        if map.len() > 3000 {
            map.retain(|_, (start, _)| start.elapsed().as_secs() < window_secs);
        }

        map.insert(key.to_string(), (now, 1));
        Ok(())
    }
}

static GLOBAL_LIMITER: std::sync::OnceLock<MemoryRateLimiter> = std::sync::OnceLock::new();

fn get_global_limiter() -> &'static MemoryRateLimiter {
    GLOBAL_LIMITER.get_or_init(MemoryRateLimiter::new)
}

/// 统一限流检查（优先 Redis，降级内存）：
/// - max_requests: 窗口内最大请求数
/// - window_secs: 窗口秒数
pub async fn check_rate_limit(
    state: &AppState,
    key_prefix: &str,
    identifier: &str,
    max_requests: u32,
    window_secs: u64,
) -> ApiResult<()> {
    let full_key = format!("youpji:rl:{key_prefix}:{identifier}");

    if let Some(cm) = state.redis.as_ref() {
        let mut conn = cm.clone();
        let count_res: redis::RedisResult<u64> = redis::cmd("INCR")
            .arg(&full_key)
            .query_async(&mut conn)
            .await;

        if let Ok(count) = count_res {
            if count == 1 {
                let _: redis::RedisResult<()> = redis::cmd("EXPIRE")
                    .arg(&full_key)
                    .arg(window_secs)
                    .query_async(&mut conn)
                    .await;
            }
            if count > max_requests as u64 {
                return Err(ApiError::TooManyRequests(format!(
                    "rate limit exceeded: max {max_requests} requests per {window_secs}s"
                )));
            }
            return Ok(());
        }
    }

    // 内存回退
    get_global_limiter()
        .check(&full_key, max_requests, window_secs)
        .await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn memory_rate_limiter_allows_up_to_max() {
        let limiter = MemoryRateLimiter::new();
        let key = "test_user_1";
        assert!(limiter.check(key, 3, 60).await.is_ok());
        assert!(limiter.check(key, 3, 60).await.is_ok());
        assert!(limiter.check(key, 3, 60).await.is_ok());
        assert!(limiter.check(key, 3, 60).await.is_err());
    }
}
