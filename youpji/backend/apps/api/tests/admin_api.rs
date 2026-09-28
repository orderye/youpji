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
async fn admin_dashboard_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/dashboard")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_attractions_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/attractions")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_attraction_detail_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/attractions/00000000-0000-0000-0000-000000000001")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_attraction_patch_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("PATCH")
                .uri("/api/v1/admin/attractions/00000000-0000-0000-0000-000000000001")
                .header("content-type", "application/json")
                .body(Body::from(json!({"ticket_price": 100}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_attraction_verify_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/admin/attractions/00000000-0000-0000-0000-000000000001/verify")
                .header("content-type", "application/json")
                .body(Body::from(
                    json!({"source_url": "https://gov.cn"}).to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_hours_review_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/hours-review")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_hours_approve_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/admin/hours-review/00000000-0000-0000-0000-000000000001/approve")
                .header("content-type", "application/json")
                .body(Body::from(json!({"writeback": true}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_hours_reject_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/admin/hours-review/00000000-0000-0000-0000-000000000001/reject")
                .header("content-type", "application/json")
                .body(Body::from(json!({"reason": "不符合"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_data_reviews_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/data-reviews")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_data_review_approve_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/admin/data-reviews/00000000-0000-0000-0000-000000000001/approve")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_data_review_reject_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/admin/data-reviews/00000000-0000-0000-0000-000000000001/reject")
                .header("content-type", "application/json")
                .body(Body::from(json!({"reason": "信息不实"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_users_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/users")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_user_role_patch_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("PATCH")
                .uri("/api/v1/admin/users/00000000-0000-0000-0000-000000000001/role")
                .header("content-type", "application/json")
                .body(Body::from(json!({"role": "admin"}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_audit_logs_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/audit-logs")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_routes_with_tampered_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .uri("/api/v1/admin/dashboard")
                .header("authorization", "Bearer fake.tampered.token")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}

#[tokio::test]
async fn admin_hours_batch_adopt_without_token_is_401() {
    let resp = test_app()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/admin/hours-review/batch-adopt")
                .header("content-type", "application/json")
                .body(Body::from(json!({"hours_ids": []}).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(json_of(resp).await["code"], "UNAUTHORIZED");
}
