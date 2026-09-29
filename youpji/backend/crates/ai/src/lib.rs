//! AI Gateway：云端 LLM + 本地 Ollama；无 Key 时降级为纯算法 plan
//!
//! 职责边界（阶段 2.4）：
//! - LLM 只能：提取字段、解释行程、生成用户友好的说明文字；
//! - LLM 不能：直接声明事实、决定票价/营业时间/天气、绕过路线算法生成行程节点。
use common::state::AppState;
use route::PlanRequest;
use serde_json::Value;

pub mod chat;
pub mod request;
pub mod rules;

#[cfg(test)]
mod rules_tests;

pub use chat::{handle_chat, ChatRequest, ChatResponse};
pub use request::{validate_request, TransportMode};
pub use rules::parse_natural_text;

#[deprecated(note = "使用 rules::parse_natural_text 替代（阶段 2 拆分）")]
/// 从自然语言提取槽位（旧调用兼容：失败时回退默认请求）。
pub fn parse_natural(input: &str) -> PlanRequest {
    rules::parse_natural_text(input).unwrap_or_else(|_| PlanRequest {
        origin: "贵阳".into(),
        destination: "安顺".into(),
        start_date: chrono::Local::now().date_naive(),
        end_date: None,
        days: Some(2),
        people: 2,
        budget: 3000,
        transport: "self_drive".into(),
        interests: vec!["nature".into()],
        avoid: vec![],
        intensity: "medium".into(),
        mode: "standard".into(),
        lodging_tier: "standard".into(),
        natural_input: Some(input.to_string()),
    })
}

/// LLM 解析器（阶段 2.2 LlmParser）：只能提取字段，不能声明事实。
/// 无 Key / 调用失败返回 None → 调用方走规则解析。
pub async fn llm_parse(state: &AppState, input: &str) -> Option<Value> {
    if state.config.ai_base_url.is_empty() || state.config.ai_api_key.is_empty() {
        return None;
    }
    let body = serde_json::json!({
        "model": "travel-plan",
        "messages": [
            {"role": "system", "content": "你是旅游需求解析器。只输出 JSON：origin,destination,days,people,budget,transport,interests[],avoid[],intensity,mode。注意：budget 为所有出行人的总预算上限数值（如用户说明人均500且2人，则budget为1000；若说明总预算2000则为2000）。不要输出门票/时间/价格等事实。"},
            {"role": "user", "content": input}
        ],
        "temperature": 0
    });
    let resp = state
        .http
        .post(format!("{}/v1/chat/completions", state.config.ai_base_url))
        .bearer_auth(&state.config.ai_api_key)
        .json(&body)
        .send()
        .await
        .ok()?;
    let v: Value = resp.json().await.ok()?;
    let content = v["choices"][0]["message"]["content"].as_str()?;
    let trimmed = content
        .trim()
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```")
        .trim();
    serde_json::from_str::<Value>(trimmed).ok()
}

/// LLM 输出白名单合并（阶段 2.4）：只接受字段提取结果，
/// 事实类键（ticket_price/opening_hours/weather 等）一律丢弃，
/// 合并后仍需经过 validate_request 校验。
pub fn merge_llm(req: &mut PlanRequest, v: &Value) {
    // 明确拒绝事实类字段（即使 LLM 返回也不采信）
    for k in [
        "ticket_price",
        "opening_hours",
        "open_time",
        "close_time",
        "weather",
        "temperature",
        "hotel_price",
        "restaurant",
        "itinerary",
        "days_plan",
    ] {
        if !v[k].is_null() {
            tracing::warn!(key = k, "llm fact field rejected");
        }
    }
    if let Some(o) = v["origin"].as_str() {
        req.origin = o.into();
    }
    if let Some(d) = v["destination"].as_str() {
        req.destination = d.into();
    }
    if let Some(d) = v["days"].as_i64() {
        req.days = Some(d as i32);
        req.end_date = Some(req.start_date + chrono::Duration::days(d - 1));
    }
    if let Some(p) = v["people"].as_i64() {
        req.people = p as i32;
    }
    if let Some(b) = v["budget"].as_i64() {
        req.budget = b as i32;
    }
    if let Some(t) = v["transport"].as_str() {
        req.transport = t.into();
    }
    if let Some(arr) = v["interests"].as_array() {
        let xs: Vec<String> = arr
            .iter()
            .filter_map(|x| x.as_str().map(String::from))
            .collect();
        if !xs.is_empty() {
            req.interests = xs;
        }
    }
    if let Some(arr) = v["avoid"].as_array() {
        let xs: Vec<String> = arr
            .iter()
            .filter_map(|x| x.as_str().map(String::from))
            .collect();
        if !xs.is_empty() {
            req.avoid = xs;
        }
    }
    if let Some(m) = v["mode"].as_str() {
        req.mode = m.into();
    }
    if let Some(i) = v["intensity"].as_str() {
        req.intensity = i.into();
    }
}
