//! 规则解析器：无外部依赖时的确定性降级方案（阶段 2.2 RuleParser）。
//! 只做字段提取，不做事实断言；门票/时间/天气等事实一律留给路线算法查库。
use chrono::{Duration, Local, NaiveDate};
use route::PlanRequest;

#[derive(Debug, Clone, Default)]
pub struct RuleParser;

impl RuleParser {
    pub fn new() -> Self {
        Self
    }

    /// 解析自然语言 -> 结构化请求。非法日期/预算由 validate_request 拒绝。
    pub fn parse(&self, input: &str) -> Result<PlanRequest, String> {
        parse_natural_text(input)
    }
}

pub fn parse_natural_text(input: &str) -> Result<PlanRequest, String> {
    let input = input.trim();
    if input.is_empty() {
        return Err("text required".into());
    }

    let mut origin = "贵阳".to_string();
    if let Some((byte_idx, _)) = input.char_indices().find(|(_, c)| *c == '从') {
        let after_from = &input[byte_idx + '从'.len_utf8()..];
        if let Some((rel_idx, _)) = after_from.match_indices("出发").next() {
            let o = after_from[..rel_idx].trim().to_string();
            if !o.is_empty() {
                origin = o;
            }
        }
    }

    // 目的地优先级：景点关键词 > 市/州 > 出发地兜底（避免「从贵阳去黄果树」误判为贵阳）
    let mut destination = String::new();
    for key in [
        "黄果树",
        "龙宫",
        "天龙屯堡",
        "安顺",
        "西江",
        "黔东南",
        "青岩",
        "遵义",
        "云南",
        "大理",
        "贵阳",
    ] {
        if input.contains(key) {
            destination = key.to_string();
            if matches!(key, "黄果树" | "龙宫" | "天龙屯堡") {
                destination = "安顺".into();
            }
            break;
        }
    }
    if destination.is_empty() {
        destination = "安顺".into();
    }

    let days = [
        "7天", "三天", "3天", "两天", "2天", "一天", "1天", "五天", "5天", "四天", "4天",
    ]
    .iter()
    .filter(|d| input.contains(**d))
    .map(|d| match *d {
        "一天" | "1天" => 1,
        "两天" | "2天" => 2,
        "三天" | "3天" => 3,
        "四天" | "4天" => 4,
        "五天" | "5天" => 5,
        _ => 7,
    })
    .next()
    .unwrap_or(2);

    // 预算（支持 0/负数写法以便校验拒绝）
    let mut budget = 3000;
    if let Some(pos) = input.find("预算") {
        let rest = &input[pos + "预算".len()..];
        budget = extract_int_after(rest).unwrap_or(3000);
    } else if let Some(pos) = input.find("不超过") {
        let rest = &input[pos + "不超过".len()..];
        budget = extract_int_after(rest).unwrap_or(3000);
    }

    let people = if input.contains("一个人")
        || input.contains("1人")
        || input.contains("独自")
        || input.contains("单独")
    {
        1
    } else if input.contains("两个人") || input.contains("2人") || input.contains("两人") {
        2
    } else if input.contains("三个人") || input.contains("3人") {
        3
    } else if input.contains("四个人") || input.contains("4人") {
        4
    } else {
        2
    };

    let transport = if input.contains("自驾") || input.contains("开车") {
        "self_drive".into()
    } else if input.contains("高铁") || input.contains("火车") {
        "transit".into()
    } else {
        "self_drive".into()
    };

    let mut interests = vec![];
    if input.contains("自然") || input.contains("风景") || input.contains("瀑布") {
        interests.push("nature".into());
    }
    if input.contains("美食") || input.contains("吃") || input.contains("贵州菜") {
        interests.push("food".into());
    }
    if input.contains("摄影") || input.contains("拍照") {
        interests.push("photography".into());
    }
    if input.contains("历史") || input.contains("古镇") || input.contains("文化") {
        interests.push("history".into());
    }
    if interests.is_empty() {
        interests.push("nature".into());
        interests.push("food".into());
    }

    let mut avoid = vec![];
    if input.contains("购物") {
        avoid.push("shopping".into());
    }
    if input.contains("太累") || input.contains("不要太累") || input.contains("轻松") {
        avoid.push("high_intensity".into());
    }

    let intensity = if avoid.contains(&"high_intensity".to_string())
        || input.contains("少走路")
        || input.contains("带老人")
    {
        "low".into()
    } else {
        "medium".into()
    };

    let mode: String = if input.contains("穷游") || input.contains("经济") {
        "economy"
    } else if input.contains("舒适") || input.contains("高品质") {
        "comfort"
    } else {
        "standard"
    }
    .into();

    // 显式日期（可选）：支持 YYYY-MM-DD / M月D日；非法日期直接报错（阶段 2.3）
    let today = Local::now().date_naive();
    let start = match extract_date_from(input, today)? {
        Some(d) => d,
        None => today + Duration::days(3),
    };

    Ok(PlanRequest {
        origin,
        destination,
        start_date: start,
        end_date: Some(start + Duration::days(days as i64 - 1)),
        days: Some(days),
        people,
        budget,
        transport,
        interests,
        avoid,
        intensity,
        mode: mode.clone(),
        lodging_tier: match mode.as_str() {
            "economy" => "budget",
            "comfort" => "premium",
            _ => "standard",
        }
        .into(),
        natural_input: Some(input.to_string()),
    })
}

/// 提取紧随关键字后的整数（允许前导负号，非法写法返回 None）。
pub(crate) fn extract_int_after(s: &str) -> Option<i32> {
    let s = s.trim_start_matches([' ', '：', ':', '是', '为', '大', '约']);
    let mut end = 0;
    for (i, c) in s.char_indices() {
        if c == '-' && i == 0 {
            end = 1;
            continue;
        }
        if c.is_ascii_digit() {
            end = i + c.len_utf8();
        } else {
            break;
        }
    }
    if end == 0 {
        return None;
    }
    s[..end].parse::<i32>().ok()
}

/// 提取显式日期。返回 Ok(None) 表示无显式日期 → 调用方走默认。
pub(crate) fn extract_date_from(
    input: &str,
    today: NaiveDate,
) -> Result<Option<NaiveDate>, String> {
    let chars: Vec<char> = input.chars().collect();
    for i in 0..chars.len().saturating_sub(9) {
        let slice: String = chars[i..i + 10].iter().collect();
        if slice.len() == 10
            && slice.chars().nth(4) == Some('-')
            && slice.chars().nth(7) == Some('-')
        {
            match NaiveDate::parse_from_str(&slice, "%Y-%m-%d") {
                Ok(d) => return Ok(Some(d)),
                Err(_) => return Err(format!("invalid date: {slice}")),
            }
        }
    }
    let mut search = input;
    while let Some(pos) = search.find('月') {
        let before = &search[..pos];
        let after = &search[pos + '月'.len_utf8()..];
        let month_digits: String = before
            .chars()
            .rev()
            .take_while(|c| c.is_ascii_digit())
            .collect::<String>()
            .chars()
            .rev()
            .collect();
        let day_digits: String = after.chars().take_while(|c| c.is_ascii_digit()).collect();
        if !month_digits.is_empty() && !day_digits.is_empty() {
            let month: u32 = month_digits.parse().unwrap_or(0);
            let day: u32 = day_digits.parse().unwrap_or(0);
            let mut year: i32 = today.format("%Y").to_string().parse().unwrap_or(2026);
            match NaiveDate::from_ymd_opt(year, month, day) {
                Some(d) => {
                    if d < today {
                        year += 1;
                        if let Some(d2) = NaiveDate::from_ymd_opt(year, month, day) {
                            return Ok(Some(d2));
                        }
                    }
                    return Ok(Some(d));
                }
                None => return Err(format!("invalid date: {month}月{day}日")),
            }
        }
        search = &search[pos + '月'.len_utf8()..];
    }
    Ok(None)
}
