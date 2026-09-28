//! 调度器：天气拉取占位（无 Key 时跳过）
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
        .max_connections(2)
        .connect(&url)
        .await?;

    loop {
        let amap = std::env::var("AMAP_KEY").unwrap_or_default();
        if amap.is_empty() {
            tracing::info!("no AMAP_KEY, skip weather refresh");
        } else {
            tracing::info!("weather refresh stub (insert forecast here)");
        }
        let _ = &pool;
        tokio::time::sleep(Duration::from_secs(6 * 3600)).await;
    }
}
