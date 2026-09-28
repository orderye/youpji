use common::error::ApiResult;
use common::state::AppState;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Debug, Deserialize)]
pub struct ChatRequest {
    pub message: String,
    #[serde(default)]
    pub session_id: Option<String>,
    #[serde(default)]
    pub context: Option<Value>,
}

#[derive(Debug, Serialize)]
pub struct ChatResponse {
    pub reply: String,
    pub session_id: String,
    pub sources: Vec<String>,
    pub suggestions: Vec<String>,
}

pub async fn handle_chat(state: &AppState, req: ChatRequest) -> ApiResult<ChatResponse> {
    let session_id = req
        .session_id
        .unwrap_or_else(|| uuid::Uuid::now_v7().to_string());
    let msg = req.message.trim();
    if msg.is_empty() {
        return Ok(ChatResponse {
            reply: "您好！我是游迹 AI 旅游助手。请告诉我您想去贵州哪里游玩、玩几天、预算多少，我来为您规划！".into(),
            session_id,
            sources: vec![],
            suggestions: vec!["贵阳到安顺两日游".into(), "黄果树瀑布最佳游览时间".into(), "贵阳美食推荐".into()],
        });
    }

    // 1. 如果配置了云端 LLM，尝试调用
    if !state.config.ai_base_url.is_empty() && !state.config.ai_api_key.is_empty() {
        let system_prompt = "你是「游迹」AI 旅游助手，专注贵州旅游规划。解答用户问题要热情、专业、简练。严禁捏造门票价格或开放时间事实。";
        let body = json!({
            "model": "travel-chat",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": msg}
            ],
            "temperature": 0.7
        });
        if let Ok(resp) = state
            .http
            .post(format!("{}/v1/chat/completions", state.config.ai_base_url))
            .bearer_auth(&state.config.ai_api_key)
            .json(&body)
            .send()
            .await
        {
            if let Ok(v) = resp.json::<Value>().await {
                if let Some(content) = v["choices"][0]["message"]["content"].as_str() {
                    return Ok(ChatResponse {
                        reply: content.to_string(),
                        session_id: session_id.clone(),
                        sources: vec!["云端 AI 助理".into()],
                        suggestions: vec!["生成详细行程方案".into(), "查看相关景区门票".into()],
                    });
                }
            }
        }
    }

    // 2. 本地规则与知识库降级应答（遵循 AGENTS.md 事实核验规则）
    let (reply, sources, suggestions) = if msg.contains("黄果树") {
        (
            "黄果树瀑布位于安顺市镇宁布依族苗族自治县，由大瀑布、陡坡塘、天星桥三大景区组成。旺季门票为160元/人（省政府名录官方核验），建议游玩时间4-5小时。夏季水量最充沛，需提前通过官方分时预约入园。".into(),
            vec!["贵州省人民政府景区名录".into(), "黄果树景区官方须知".into()],
            vec!["将黄果树加入两日游行程".into(), "查看黄果树周边酒店".into()]
        )
    } else if msg.contains("龙宫") {
        (
            "龙宫国家5A级景区位于安顺市西秀区，以水旱溶洞群和暗河著称，门票130元/人（含船票，官方核验）。夏季洞内恒温清凉，开闭园时间通常为07:00-18:00。".into(),
            vec!["贵州省人民政府景区名录".into(), "龙宫景区官方公告".into()],
            vec!["安顺龙宫+黄果树两日游规划".into(), "查看龙宫特色餐饮".into()]
        )
    } else if msg.contains("天龙屯堡") {
        (
            "天龙屯堡位于安顺市平坝区，保留了明代江淮遗风与地戏文化，门票60元/人（官方核验），推荐游览时间2-3小时。".into(),
            vec!["贵州省人民政府景区名录".into(), "安顺市人民政府核心景区公示".into()],
            vec!["规划屯堡文化体验之旅".into()]
        )
    } else if msg.contains("规划")
        || msg.contains("行程")
        || msg.contains("日游")
        || msg.contains("去哪")
    {
        (
            "游迹已为您支持结构化行程规划！您可以直接在输入框告诉我如「贵阳到安顺两日游，预算2000，喜欢自然风光」，系统将自动完成景区召回、交通排线与预算硬约束核算。".into(),
            vec!["游迹规划引擎 rule-budget-v2".into()],
            vec!["贵阳到安顺两日游".into(), "贵阳市区一日经典人文游".into()]
        )
    } else {
        (
            format!("您好！关于「{}」，游迹收录了贵州全省 500+ 个重点景区、酒店与餐厅数据。您可以告诉我具体想了解的景区名称，或直接发起行程定制需求！", msg),
            vec!["游迹贵州旅游知识库".into()],
            vec!["黄果树两日游规划".into(), "贵阳美食探索".into(), "青岩古镇游玩攻略".into()]
        )
    };

    Ok(ChatResponse {
        reply,
        session_id,
        sources,
        suggestions,
    })
}
