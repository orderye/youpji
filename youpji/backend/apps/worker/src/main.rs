//! 数据巡检 Worker（V0.1：过期数据标记、孤儿数据清理与数据质量核验）
use sqlx::PgPool;
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

    tracing::info!("youpji worker starting, interval=3600s");

    loop {
        run_worker_cycle(&pool).await;
        tokio::time::sleep(Duration::from_secs(3600)).await;
    }
}

pub async fn run_stale_check(pool: &PgPool, days: i64) -> Result<i64, sqlx::Error> {
    let mut total = 0;

    // 1. 景区事实过期核验（默认 90 天未核对即标记为 stale）
    let n = sqlx::query(
        r#"UPDATE attractions
           SET verification_status = 'stale', updated_at = now()
           WHERE verification_status = 'verified'
             AND last_verified < now() - ($1 || ' days')::interval"#,
    )
    .bind(days.to_string())
    .execute(pool)
    .await?
    .rows_affected() as i64;
    total += n;

    // 2. 营业时段过期核验
    let n_hours = sqlx::query(
        r#"UPDATE attraction_hours
           SET verification_status = 'stale'
           WHERE verification_status = 'verified'
             AND last_verified < now() - ($1 || ' days')::interval"#,
    )
    .bind(days.to_string())
    .execute(pool)
    .await?
    .rows_affected() as i64;
    total += n_hours;

    Ok(total)
}

pub async fn run_orphan_cleanup(pool: &PgPool) -> Result<i64, sqlx::Error> {
    let mut cleaned = 0;

    // 清理无对应景区的营业时段
    let n1 = sqlx::query(
        r#"DELETE FROM attraction_hours h
           WHERE NOT EXISTS (SELECT 1 FROM attractions a WHERE a.id = h.attraction_id)"#,
    )
    .execute(pool)
    .await?
    .rows_affected() as i64;
    cleaned += n1;

    // 清理无对应景区的门票
    let n2 = sqlx::query(
        r#"DELETE FROM attraction_tickets t
           WHERE NOT EXISTS (SELECT 1 FROM attractions a WHERE a.id = t.attraction_id)"#,
    )
    .execute(pool)
    .await?
    .rows_affected() as i64;
    cleaned += n2;

    Ok(cleaned)
}

pub async fn run_worker_cycle(pool: &PgPool) {
    tracing::info!("worker cycle started");

    match run_stale_check(pool, 90).await {
        Ok(count) if count > 0 => tracing::warn!(count, "marked records stale (>90d)"),
        Ok(_) => tracing::info!("stale check passed, no expired facts"),
        Err(e) => tracing::error!(%e, "stale check error"),
    }

    match run_orphan_cleanup(pool).await {
        Ok(count) if count > 0 => tracing::warn!(count, "cleaned orphan records"),
        Ok(_) => tracing::info!("orphan cleanup passed"),
        Err(e) => tracing::error!(%e, "orphan cleanup error"),
    }

    let pending: i64 =
        sqlx::query_scalar("SELECT count(*) FROM data_reviews WHERE status = 'pending'")
            .fetch_one(pool)
            .await
            .unwrap_or(0);
    let pending_hours: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM attraction_hours WHERE verification_status = 'pending'",
    )
    .fetch_one(pool)
    .await
    .unwrap_or(0);

    tracing::info!(
        pending_reviews = pending,
        pending_hours,
        "review queue metrics"
    );
}
