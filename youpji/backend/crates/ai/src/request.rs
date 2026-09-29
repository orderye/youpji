//! 请求校验器（阶段 2.2 RequestValidator / 阶段 2.3）。
//! 统一验证规划请求的所有字段；V0.1 只接受贵州范围目的地。
use route::PlanRequest;

pub const ALLOWED_INTERESTS: &[&str] = &[
    "nature",
    "history",
    "food",
    "photography",
    "museum",
    "family",
    "couple",
    "elderly",
    "hiking",
    "drive",
    "night",
    "shopping",
    // 前端中文标签兼容支持
    "自然风光",
    "历史文化",
    "文博场馆",
    "博物院",
    "博物馆",
    "喀斯特溶洞",
    "特色美食",
    "古镇古寨",
    "亲子休闲",
];

pub const ALLOWED_AVOID: &[&str] = &["shopping", "high_intensity", "night", "hiking"];

pub const ALLOWED_TRANSPORTS: &[&str] = &["self_drive", "drive", "transit", "walk"];

pub const ALLOWED_MODES: &[&str] = &["economy", "standard", "comfort"];

pub const ALLOWED_INTENSITY: &[&str] = &["low", "medium", "high"];

/// V0.1 只做贵州：目的地必须命中贵州范围关键词。
pub const GUIZHOU_SCOPE: &[&str] = &[
    "贵州",
    "贵阳",
    "安顺",
    "黄果树",
    "龙宫",
    "屯堡",
    "青岩",
    "黔灵",
    "西江",
    "黔东南",
    "遵义",
    "镇宁",
    "西秀",
    "平坝",
    "凯里",
    "雷山",
    "格凸",
    "观山湖",
    "省博",
    "博物",
    "文博",
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransportMode {
    SelfDrive,
    Drive,
    Transit,
    Walk,
}

impl TransportMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::SelfDrive => "self_drive",
            Self::Drive => "drive",
            Self::Transit => "transit",
            Self::Walk => "walk",
        }
    }
}

/// 统一验证所有字段；不合法返回人类可读原因（API 层映射为 422）。
pub fn validate_request(req: &PlanRequest) -> Result<(), String> {
    if req.origin.trim().is_empty() {
        return Err("origin must not be empty".into());
    }
    if req.destination.trim().is_empty() {
        return Err("destination must not be empty".into());
    }
    // V0.1 地域铁律：只做贵州
    if !GUIZHOU_SCOPE.iter().any(|k| req.destination.contains(k)) {
        return Err(format!(
            "destination '{}' is out of V0.1 scope (Guizhou only)",
            req.destination
        ));
    }
    if let Some(end) = req.end_date {
        if end < req.start_date {
            return Err("start_date must be before end_date".into());
        }
        if let Some(days) = req.days {
            let actual = (end - req.start_date).num_days() + 1;
            if actual != days as i64 {
                return Err(format!(
                    "days ({days}) does not match start_date..end_date ({actual} days)"
                ));
            }
        }
    } else if let Some(days) = req.days {
        if !(1..=30).contains(&days) {
            return Err("days must be between 1 and 30".into());
        }
    }
    if req.people < 1 {
        return Err("people must be greater than 0".into());
    }
    if req.budget <= 0 {
        return Err("budget must be greater than 0".into());
    }
    if !ALLOWED_TRANSPORTS.contains(&req.transport.as_str()) {
        return Err(format!("unsupported transport: {}", req.transport));
    }
    if !ALLOWED_MODES.contains(&req.mode.as_str()) {
        return Err(format!("unsupported mode: {}", req.mode));
    }
    if !ALLOWED_INTENSITY.contains(&req.intensity.as_str()) {
        return Err(format!("unsupported intensity: {}", req.intensity));
    }
    for tag in req.interests.iter().chain(req.avoid.iter()) {
        if !ALLOWED_INTERESTS.contains(&tag.as_str()) && !ALLOWED_AVOID.contains(&tag.as_str()) {
            return Err(format!("unsupported tag: {tag}"));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;

    fn base_req() -> PlanRequest {
        PlanRequest {
            origin: "贵阳".into(),
            destination: "安顺".into(),
            start_date: NaiveDate::from_ymd_opt(2026, 10, 1).unwrap(),
            end_date: Some(NaiveDate::from_ymd_opt(2026, 10, 2).unwrap()),
            days: Some(2),
            people: 2,
            budget: 2000,
            transport: "self_drive".into(),
            interests: vec!["nature".into()],
            avoid: vec![],
            intensity: "medium".into(),
            mode: "standard".into(),
            lodging_tier: "standard".into(),
            natural_input: None,
        }
    }

    #[test]
    fn valid_anshun_two_day_request_passes() {
        assert!(validate_request(&base_req()).is_ok());
    }

    #[test]
    fn empty_origin_or_destination_rejected() {
        let mut r = base_req();
        r.origin = " ".into();
        assert!(validate_request(&r).is_err());
        let mut r = base_req();
        r.destination = String::new();
        assert!(validate_request(&r).is_err());
    }

    #[test]
    fn end_before_start_rejected() {
        let mut r = base_req();
        r.end_date = Some(NaiveDate::from_ymd_opt(2026, 9, 30).unwrap());
        let err = validate_request(&r).unwrap_err();
        assert!(err.contains("start_date must be before end_date"));
    }

    #[test]
    fn days_mismatch_rejected() {
        let mut r = base_req();
        r.days = Some(3);
        assert!(validate_request(&r).is_err());
    }

    #[test]
    fn invalid_people_and_budget_rejected() {
        let mut r = base_req();
        r.people = 0;
        assert!(validate_request(&r).is_err());
        let mut r = base_req();
        r.budget = 0;
        assert!(validate_request(&r).is_err());
        let mut r = base_req();
        r.budget = -100;
        assert!(validate_request(&r).is_err());
    }

    #[test]
    fn invalid_enums_rejected() {
        let mut r = base_req();
        r.transport = "teleport".into();
        assert!(validate_request(&r).is_err());
        let mut r = base_req();
        r.mode = "luxury".into();
        assert!(validate_request(&r).is_err());
        let mut r = base_req();
        r.intensity = "extreme".into();
        assert!(validate_request(&r).is_err());
        let mut r = base_req();
        r.interests = vec!["bungee".into()];
        assert!(validate_request(&r).is_err());
    }

    #[test]
    fn non_guizhou_destination_rejected() {
        let mut r = base_req();
        r.destination = "云南".into();
        let err = validate_request(&r).unwrap_err();
        assert!(err.contains("Guizhou"));
    }
}
