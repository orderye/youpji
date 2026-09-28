//! 数据巡检 Worker（V0.1：骨架 + 过期数据标记）
use std::time::Duration;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(std::env::var("RUST_LOG").unwrap_or_else(|_| "info".into()))
        .init();
    dotenvy::dotenv().ok();
    let url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://youpji:youpji_dev@127.0.0.1:5433/youpji".into());
    let pool = sqlx::postgres::PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await?;

    loop {
        tracing::info!("worker tick: mark stale facts > 180d");
        let n = sqlx::query_scalar::<sqlx::Postgres, i32>(
            r#"UPDATE attractions
               SET verification_status = 'stale'
               WHERE verification_status = 'verified'
                 AND last_verified < now() - interval '180 days'
               RETURNING 1"#,
        )
        .fetch_all(&pool)
        .await?
        .len() as i64;
        if n > 0 {
            tracing::warn!(count = n, "marked attractions stale");
        }
        // 待审核队列计数
        let pending: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM data_reviews WHERE status = 'pending'")
                .fetch_one(&pool)
                .await
                .unwrap_or(0);
        tracing::info!(pending, "reviews pending");
        tokio::time::sleep(Duration::from_secs(3600)).await;
    }
}
