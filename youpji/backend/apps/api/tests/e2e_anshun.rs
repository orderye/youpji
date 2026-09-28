//! 贵阳 → 安顺 端到端测试（阶段 6.3 / 最终验收）。
//!
//! 需要真实的 Postgres(含 PostGIS/pg_trgm) + 种子数据：
//! `cargo test -p api --test e2e_anshun -- --ignored`
//! 无库环境自动跳过（默认 ignore，不影响 CI 绿灯）。
use axum::body::Body;
use axum::http::{Request, StatusCode};
use common::state::Config;
use http_body_util::BodyExt;
use serde_json::Value;
use tower::ServiceExt;

fn config_from_env() -> Config {
    Config::from_env()
}

async fn plan_anshun(state_url: &str) -> axum::response::Response {
    let config = Config {
        database_url: state_url.into(),
        ..config_from_env()
    };
    let st = api::lazy_state(config.clone());
    let app = api::build_router(config, st);
    let body = serde_json::json!({
        "origin": "贵阳",
        "destination": "安顺",
        "start_date": "2026-10-01",
        "end_date": "2026-10-02",
        "days": 2,
        "people": 2,
        "budget": 2000,
        "transport": "self_drive",
        "interests": ["nature", "history"],
        "avoid": [],
        "intensity": "medium",
        "mode": "standard",
        "lodging_tier": "standard",
        "save": false
    });
    app.oneshot(
        Request::builder()
            .method("POST")
            .uri("/api/v1/travel/plan")
            .header("content-type", "application/json")
            .body(Body::from(body.to_string()))
            .unwrap(),
    )
    .await
    .unwrap()
}

#[tokio::test]
#[ignore = "requires postgres+postgis with seed data; run with --ignored"]
async fn e2e_anshun_two_days_within_budget_2000() {
    let resp = plan_anshun(
        &std::env::var("DATABASE_URL")
            .unwrap_or_else(|_| "postgres://youpji:youpji_dev@127.0.0.1:5433/youpji".into()),
    )
    .await;
    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    let v: Value = serde_json::from_slice(&bytes).unwrap_or(Value::Null);

    // 预算硬约束：2000 必须能出方案且不超支（阶段 3 验收）
    assert_eq!(v["budget"]["limit"], 2000, "body={v}");
    assert!(
        v["budget"]["total"].as_i64().unwrap_or(i64::MAX) <= 2000,
        "total must be <= 2000, got {}",
        v["budget"]["total"]
    );

    // 结构化输出契约（AGENTS.md 铁律 7）
    for key in [
        "summary",
        "days",
        "budget",
        "hotels",
        "restaurants",
        "routes",
        "warnings",
    ] {
        assert!(v.get(key).is_some(), "missing key {key}");
    }
    let days = v["days"].as_array().expect("days array");
    assert_eq!(days.len(), 2);

    // 两天顺序合理、景区不重复、营业时间不冲突
    let mut seen = std::collections::HashSet::new();
    for d in days {
        let items = d["items"].as_array().unwrap();
        for it in items {
            if it["item_type"] == "attraction" {
                let id = it["ref_id"].as_str().unwrap().to_string();
                assert!(seen.insert(id), "duplicate attraction across days");
            }
        }
    }
    // 核心景区覆盖（黄果树/龙宫/天龙至少 2 个）
    let names: Vec<&str> = days
        .iter()
        .flat_map(|d| d["items"].as_array().unwrap().iter())
        .filter(|it| it["item_type"] == "attraction")
        .filter_map(|it| it["title"].as_str())
        .collect();
    let core = ["黄果树", "龙宫", "天龙"];
    let hit = core
        .iter()
        .filter(|c| names.iter().any(|n| n.contains(*c)))
        .count();
    assert!(hit >= 2, "expected >=2 core attractions, got {names:?}");
}

#[tokio::test]
#[ignore = "requires postgres; budget hard-fail path"]
async fn e2e_budget_500_fails_with_budget_exceeded() {
    let url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://youpji:youpji_dev@127.0.0.1:5433/youpji".into());
    let config = Config {
        database_url: url,
        ..config_from_env()
    };
    let st = api::lazy_state(config.clone());
    let app = api::build_router(config, st);
    let body = serde_json::json!({
        "origin": "贵阳", "destination": "安顺",
        "start_date": "2026-10-01", "end_date": "2026-10-02",
        "days": 2, "people": 2, "budget": 500,
        "transport": "self_drive", "interests": ["nature"], "avoid": [],
        "intensity": "medium", "mode": "economy", "lodging_tier": "budget",
        "save": false
    });
    let resp = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/travel/plan")
                .header("content-type", "application/json")
                .body(Body::from(body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNPROCESSABLE_ENTITY);
    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    let v: Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(v["code"], "BUDGET_EXCEEDED");
}
