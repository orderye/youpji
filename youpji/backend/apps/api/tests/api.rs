//! API 关键流程测试（阶段 6.2/6.3）。
//!
//! 覆盖范围：不需要数据库的路径（health / parse / 401 / 错误格式）。
//! 需要 Postgres+PostGIS 的端到端用例在本目录 `e2e_anshun.rs`，默认 `#[ignore]`。
use axum::body::Body;
use axum::http::{Request, StatusCode};
use common::state::Config;
use http_body_util::BodyExt;
use serde_json::{json, Value};
use tower::ServiceExt;

fn test_config() -> Config {
    Config {
        database_url: "postgres://youpji:youpji_dev@127.0.0.1:5433/youpji".into(),
        redis_url: "redis://127.0.0.1:6380".into(),
        bind: "127.0.0.1:0".into(),
        jwt_secret: "integration-test-secret".into(),
        ai_base_url: String::new(),
        ai_api_key: String::new(),
        ollama_url: "http://127.0.0.1:11434".into(),
        amap_key: String::new(),
        cors_origins: vec!["*".into()],
    }
}

fn test_app() -> axum::Router {
    let config = test_config();
    let state = api::lazy_state(config.clone());
    api::build_router(config, state)
}

async fn json_of(resp: axum::response::Response) -> Value {
    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    serde_json::from_slice(&bytes).unwrap_or(Value::Null)
}

#[tokio::test]
async fn health_returns_ok() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let v = json_of(resp).await;
    assert_eq!(v["ok"], true);
    assert_eq!(v["service"], "youpji-api");
}

#[tokio::test]
async fn parse_anshun_two_days_returns_structured_request() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/travel/parse")
                .header("content-type", "application/json")
                .body(Body::from(
                    json!({"text": "从贵阳出发去安顺玩两天，两个人，自驾，预算3000，看自然景观"})
                        .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let v = json_of(resp).await;
    assert_eq!(v["origin"], "贵阳");
    assert_eq!(v["destination"], "安顺");
    assert_eq!(v["days"], 2);
    assert_eq!(v["people"], 2);
    assert_eq!(v["budget"], 3000);
    assert_eq!(v["transport"], "self_drive");
    assert!(v["interests"]
        .as_array()
        .unwrap()
        .contains(&json!("nature")));
}

#[tokio::test]
async fn parse_huangguoshu_and_low_intensity_cases() {
    for (text, want_intensity) in [
        ("黄果树两日游", "medium"),
        ("从贵阳出发去黄果树玩两天，带老人少走路", "low"),
        ("龙宫两日游", "medium"),
    ] {
        let resp = test_app()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/v1/travel/parse")
                    .header("content-type", "application/json")
                    .body(Body::from(json!({"text": text}).to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(resp.status(), StatusCode::OK, "{text}");

        let v = json_of(resp).await;
        assert_eq!(v["destination"], "安顺", "{text}");
        assert_eq!(v["intensity"], want_intensity, "{text}");
    }
}

#[tokio::test]
async fn parse_invalid_date_returns_400_validation_error() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/travel/parse")
                .header("content-type", "application/json")
                .body(Body::from(
                    json!({"text": "10月40日去安顺两日游"}).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);
    let v = json_of(resp).await;
    assert_eq!(v["code"], "VALIDATION_ERROR");
    assert!(v["message"].as_str().unwrap().contains("invalid date"));
    assert!(v.get("details").is_some());
}

#[tokio::test]
async fn parse_invalid_budget_returns_422() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/travel/parse")
                .header("content-type", "application/json")
                .body(Body::from(json!({"text": "安顺两日游预算0"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNPROCESSABLE_ENTITY);
    let v = json_of(resp).await;
    assert_eq!(v["code"], "UNPROCESSABLE_ENTITY");
    assert!(v["message"].as_str().unwrap().contains("budget"));
}

#[tokio::test]
async fn parse_non_guizhou_destination_is_rejected() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/travel/parse")
                .header("content-type", "application/json")
                .body(Body::from(json!({"text": "大理两日游"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNPROCESSABLE_ENTITY);
    let v = json_of(resp).await;
    assert!(v["message"].as_str().unwrap().contains("Guizhou"));
}

#[tokio::test]
async fn protected_route_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/itineraries")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    let v = json_of(resp).await;
    assert_eq!(v["code"], "UNAUTHORIZED");
    assert!(v.get("details").is_some());
}

#[tokio::test]
async fn protected_route_with_tampered_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/preferences")
                .header("authorization", "Bearer aaa.bbb.ccc")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn parse_empty_text_is_400() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/travel/parse")
                .header("content-type", "application/json")
                .body(Body::from(json!({"text": "  "}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);
    assert_eq!(json_of(resp).await["code"], "VALIDATION_ERROR");
}

/// 行程详情默认私有：未登录必须 401，且不能触达 DB。
#[tokio::test]
async fn itinerary_detail_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/itineraries/00000000-0000-0000-0000-000000000001")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

/// 局部重规划同样需要鉴权：否则任何人都能凭 itinerary_id 改别人的行程。
#[tokio::test]
async fn replan_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/travel/replan")
                .header("content-type", "application/json")
                .body(Body::from(
                    json!({
                        "itinerary_id": "00000000-0000-0000-0000-000000000001",
                        "edit_op": {"type": "remove_item", "attraction_id": "00000000-0000-0000-0000-000000000002", "day_index": 1}
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}
