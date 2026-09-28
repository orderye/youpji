//! 路线引擎：AI 管理解，算法管计算（DESIGN.md §6）
use chrono::{Duration, NaiveDate, NaiveTime, Timelike};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

pub mod distance;
pub use distance::{DistanceService, DistanceSource};

pub const ALGO_VERSION: &str = "rule-budget-v2";

/// 规划失败（阶段 3.5）：预算是硬约束，超支必须整体失败，不能静默超支。
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum PlanError {
    #[error("BUDGET_EXCEEDED: estimated {total} exceeds budget limit {limit}")]
    BudgetExceeded { limit: i32, total: i32 },
    #[error("NO_CANDIDATES: no open attractions for destination '{0}'")]
    NoCandidates(String),
    #[error("INVALID_REQUEST: {0}")]
    InvalidRequest(String),
}

impl PlanError {
    pub fn code(&self) -> &'static str {
        match self {
            Self::BudgetExceeded { .. } => "BUDGET_EXCEEDED",
            Self::NoCandidates(_) => "NO_CANDIDATES",
            Self::InvalidRequest(_) => "INVALID_REQUEST",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlanRequest {
    pub origin: String,
    pub destination: String,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub days: Option<i32>,
    pub people: i32,
    pub budget: i32,
    pub transport: String,
    pub interests: Vec<String>,
    pub avoid: Vec<String>,
    pub intensity: String,
    pub mode: String,
    pub lodging_tier: String,
    pub natural_input: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct Warning {
    pub code: String,
    pub message: String,
    pub r#ref: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct BudgetBreakdown {
    pub limit: i32,
    pub transport: i32,
    pub lodging: i32,
    pub tickets: i32,
    pub food: i32,
    pub parking: i32,
    pub other: i32,
    pub reserve: i32,
    pub total: i32,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct DayPlan {
    pub day_index: i32,
    pub date: NaiveDate,
    pub title: String,
    pub items: Vec<PlanItem>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct PlanItem {
    pub item_type: String,
    pub start_time: NaiveTime,
    pub end_time: Option<NaiveTime>,
    pub title: String,
    pub location: Option<String>,
    pub longitude: Option<f64>,
    pub latitude: Option<f64>,
    pub ref_id: Option<Uuid>,
    pub distance_km: Option<f64>,
    pub duration_min: Option<i32>,
    pub cost: i32,
    pub reason: Option<String>,
    pub notice: Option<String>,
    /// 候选评分（阶段 3.3：输出保留 score/reason/candidate_source）
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub score: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub candidate_source: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct PlanSummary {
    pub title: String,
    pub origin: String,
    pub destination: String,
    pub days: i32,
    pub people: i32,
    pub mode: String,
    pub total_distance_km: f64,
    pub drive_hours: f64,
    pub ticket_cost: i32,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct PlanOutput {
    pub summary: PlanSummary,
    pub days: Vec<DayPlan>,
    pub budget: BudgetBreakdown,
    pub hotels: Vec<Uuid>,
    pub restaurants: Vec<Uuid>,
    pub routes: serde_json::Value,
    pub warnings: Vec<Warning>,
    pub algo_version: &'static str,
}

#[derive(Debug, FromRow, Clone)]
pub struct Candidate {
    pub id: Uuid,
    pub name: String,
    pub city: Option<String>,
    pub district: Option<String>,
    pub longitude: f64,
    pub latitude: f64,
    pub ticket_price: Option<i32>,
    pub opening_time: Option<NaiveTime>,
    pub closing_time: Option<NaiveTime>,
    pub recommended_duration_min: Option<i32>,
    pub difficulty: Option<i16>,
    pub family_score: i16,
    pub elderly_score: i16,
    pub photography_score: i16,
    pub couple_score: i16,
    pub popularity: i32,
    pub indoor: bool,
    pub status: String,
    pub category: Option<String>,
    pub description: Option<String>,
    pub verification_status: String,
    pub confidence: f64,
    pub source_url: Option<String>,
    pub tags: Option<Vec<String>>,
}

/// 事实可用性：阶段 1.3 —— 门票/开放时间等只有已验证事实才能进入确定性字段。
pub fn candidate_fact_usable(c: &Candidate) -> bool {
    common::is_fact_usable(
        &c.verification_status,
        c.source_url.as_deref(),
        c.confidence,
    )
}

fn fact_estimate_warning(c: &Candidate) -> Option<Warning> {
    if candidate_fact_usable(c) {
        return None;
    }
    Some(Warning {
        code: "unverified_fact".into(),
        message: format!(
            "「{}」的票价/开放时间为估算（status={}，置信度{:.2}），以景区官方当日公示为准",
            c.name, c.verification_status, c.confidence
        ),
        r#ref: Some(c.id.to_string()),
    })
}

/// 简化 haversine（km）
pub fn haversine_km(a: (f64, f64), b: (f64, f64)) -> f64 {
    let r = 6371.0;
    let d_lat = (b.0 - a.0).to_radians();
    let d_lon = (b.1 - a.1).to_radians();
    let lat1 = a.0.to_radians();
    let lat2 = b.0.to_radians();
    let h = (d_lat / 2.0).sin().powi(2) + lat1.cos() * lat2.cos() * (d_lon / 2.0).sin().powi(2);
    2.0 * r * h.sqrt().asin()
}

/// 距离 → 车程（分钟）。规划与重排共用同一套口径，避免两处不一致。
pub fn travel_minutes_for(dist_km: f64) -> i32 {
    if dist_km < 5.0 {
        15
    } else if dist_km < 30.0 {
        45
    } else if dist_km < 80.0 {
        90
    } else {
        150
    }
}

pub fn round1(v: f64) -> f64 {
    (v * 10.0).round() / 10.0
}

pub fn score_candidate(c: &Candidate, req: &PlanRequest, dist_to_city: f64) -> f64 {
    let mut score = 0.0;
    score += c.popularity as f64 * 0.35;
    score += c.photography_score as f64 * 0.1;
    score += c.family_score as f64 * 0.1;

    let interests = &req.interests;
    if interests.iter().any(|i| i == "nature") {
        if let Some(cat) = &c.category {
            if cat.contains("自然") || cat.contains("瀑布") || cat.contains("山水") {
                score += 25.0;
            }
        }
        if let Some(tags) = &c.tags {
            if tags.iter().any(|t| t.contains("自然")) {
                score += 15.0;
            }
        }
    }
    if interests.iter().any(|i| i == "history") {
        if let Some(cat) = &c.category {
            if cat.contains("历史")
                || cat.contains("古镇")
                || cat.contains("文化")
                || cat.contains("屯堡")
            {
                score += 25.0;
            }
        }
    }
    if interests.iter().any(|i| i == "photography") {
        score += c.photography_score as f64 * 0.2;
    }
    if interests.iter().any(|i| i == "food") {
        // 靠近城市中心略加分（后续接餐厅）
        score += 5.0;
    }

    // 排斥
    if req.avoid.iter().any(|a| a == "shopping") {
        if let Some(cat) = &c.category {
            if cat.contains("购物") || cat.contains("商城") {
                score -= 50.0;
            }
        }
    }
    if req.avoid.iter().any(|a| a == "high_intensity") || req.intensity == "low" {
        if let Some(d) = c.difficulty_level() {
            if d > 3 {
                score -= 20.0;
            }
        }
        score += 10.0 * (c.elderly_score as f64 / 100.0);
    }

    // 距离成本
    score -= dist_to_city * 1.5;
    score
}

impl Candidate {
    fn difficulty_level(&self) -> Option<i32> {
        self.difficulty.map(|d| d as i32)
    }
}

/// 召唤候选（阶段 3.1/3.2）：目的地关键词 → destinations 表 → 召回关联景区。
/// 无硬编码城市分支；仅保留贵州范围；剔除 closed；景区不重复由装包阶段保证。
pub async fn recall_candidates(
    pool: &sqlx::PgPool,
    destination: &str,
    _avoid_hl: &[String],
) -> anyhow::Result<Vec<Candidate>> {
    let dest_ids = resolve_destination_ids(pool, destination).await?;
    let rows: Vec<Candidate> = sqlx::query_as(
        r#"SELECT a.id, a.name, a.city, a.district, a.longitude, a.latitude, a.ticket_price,
                  a.opening_time, a.closing_time,
                  a.recommended_duration_min, a.difficulty,
                  a.family_score, a.elderly_score,
                  a.photography_score, a.couple_score, a.popularity, a.indoor,
                  a.status, a.category, a.description,
                  a.verification_status::text AS verification_status,
                  a.confidence, a.source_url,
                  array_agg(t.tag_key) FILTER (WHERE t.tag_key IS NOT NULL) AS tags
           FROM attractions a
           LEFT JOIN attraction_tags t ON t.attraction_id = a.id
           WHERE a.province = '贵州'
             AND a.status <> 'closed'
             AND a.verification_status <> 'disputed'
             AND (
               cardinality($1::uuid[]) = 0
               OR a.destination_id = ANY($1::uuid[])
               OR EXISTS (
                 SELECT 1 FROM destinations d
                 WHERE d.id = a.destination_id
                   AND ($2 = '' OR d.name ILIKE '%' || $2 || '%'
                        OR d.full_path ILIKE '%' || $2 || '%'
                        OR $2 ILIKE '%' || d.name || '%')
               )
               OR a.city ILIKE '%' || $2 || '%'
               OR a.district ILIKE '%' || $2 || '%'
               OR a.name ILIKE '%' || $2 || '%'
               OR (a.alias IS NOT NULL AND a.alias ILIKE '%' || $2 || '%')
             )
           GROUP BY a.id
           ORDER BY a.popularity DESC
           LIMIT 60"#,
    )
    .bind(&dest_ids)
    .bind(destination)
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

/// 目的地关键词 → destinations.id（阶段 3.1：移除 route 内部硬编码城市分支）。
/// 未命中任何目的地时返回空 vec → 调用方走名称/城市模糊召回并给出警告。
async fn resolve_destination_ids(
    pool: &sqlx::PgPool,
    destination: &str,
) -> anyhow::Result<Vec<Uuid>> {
    if destination.trim().is_empty() {
        return Ok(vec![]);
    }
    let ids: Vec<Uuid> = sqlx::query_scalar(
        r#"SELECT d.id FROM destinations d
           WHERE d.name ILIKE '%' || $1 || '%'
              OR d.full_path ILIKE '%' || $1 || '%'
              OR $1 ILIKE '%' || d.name || '%'
           LIMIT 12"#,
    )
    .bind(destination)
    .fetch_all(pool)
    .await?;
    Ok(ids)
}

pub async fn recall_by_cities(
    pool: &sqlx::PgPool,
    cities: &[String],
) -> anyhow::Result<Vec<Candidate>> {
    let rows: Vec<Candidate> = sqlx::query_as(
        r#"SELECT a.id, a.name, a.city, a.district, a.longitude, a.latitude, a.ticket_price,
                  a.opening_time, a.closing_time,
                  a.recommended_duration_min, a.difficulty,
                  a.family_score, a.elderly_score,
                  a.photography_score, a.couple_score, a.popularity, a.indoor,
                  a.status, a.category, a.description,
                  a.verification_status::text AS verification_status,
                  a.confidence, a.source_url,
                  array_agg(t.tag_key) FILTER (WHERE t.tag_key IS NOT NULL) AS tags
           FROM attractions a
           LEFT JOIN attraction_tags t ON t.attraction_id = a.id
           WHERE a.province = '贵州'
             AND a.status <> 'closed'
             AND (cardinality($1::text[]) = 0 OR a.city = ANY($1::text[]))
           GROUP BY a.id
           ORDER BY a.popularity DESC
           LIMIT 80"#,
    )
    .bind(cities)
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

pub async fn hotels_near(
    pool: &sqlx::PgPool,
    lng: f64,
    lat: f64,
    limit: i64,
) -> anyhow::Result<Vec<Uuid>> {
    let ids: Vec<Uuid> = sqlx::query_scalar(
        r#"SELECT id FROM hotels
           WHERE longitude IS NOT NULL
           ORDER BY geog <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
           LIMIT $3"#,
    )
    .bind(lng)
    .bind(lat)
    .bind(limit)
    .fetch_all(pool)
    .await?;
    Ok(ids)
}

pub async fn restaurants_near(
    pool: &sqlx::PgPool,
    lng: f64,
    lat: f64,
    limit: i64,
) -> anyhow::Result<Vec<Uuid>> {
    let ids: Vec<Uuid> = sqlx::query_scalar(
        r#"SELECT id FROM restaurants
           WHERE longitude IS NOT NULL
           ORDER BY geog <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
           LIMIT $3"#,
    )
    .bind(lng)
    .bind(lat)
    .bind(limit)
    .fetch_all(pool)
    .await?;
    Ok(ids)
}

/// 规划输入轻量校验（阶段 2.3 在 API/解析层做全量校验，这里做算法侧兜底）。
fn validate_plan_input(req: &PlanRequest) -> Result<(), PlanError> {
    if req.origin.trim().is_empty() || req.destination.trim().is_empty() {
        return Err(PlanError::InvalidRequest(
            "origin/destination required".into(),
        ));
    }
    if req.people < 1 {
        return Err(PlanError::InvalidRequest("people must be >= 1".into()));
    }
    if req.budget <= 0 {
        return Err(PlanError::InvalidRequest("budget must be > 0".into()));
    }
    Ok(())
}

/// 营业时间检查（阶段 3.4）：到达+游览必须落在 [open, close] 内。
/// 事实缺失（open/close 为空）→ 视为估算 08:00–18:00，并由调用方打 unverified 警告。
pub(crate) fn fits_opening_hours(
    arrive: NaiveTime,
    stay_min: i32,
    open: Option<NaiveTime>,
    close: Option<NaiveTime>,
) -> bool {
    let open = open.unwrap_or_else(|| NaiveTime::from_hms_opt(8, 0, 0).unwrap());
    let close = close.unwrap_or_else(|| NaiveTime::from_hms_opt(18, 0, 0).unwrap());
    if arrive < open {
        return false;
    }
    let leave = arrive + Duration::minutes(stay_min as i64);
    leave <= close
}

fn days_between(start: NaiveDate, end: NaiveDate) -> i32 {
    let d = (end - start).num_days() as i32 + 1;
    d.max(1)
}

/// 主排线：过滤 → 评分 → 贪心按天装包 → 时间轴（阶段 3）。
/// 返回 Result<_, PlanError>：预算是硬约束，超支返回 BUDGET_EXCEEDED。
pub async fn plan(pool: &sqlx::PgPool, req: &PlanRequest) -> Result<PlanOutput, PlanError> {
    plan_with(pool, req, None).await
}

/// 同 `plan`，但带距离服务：提供后按真实驾车路网计算车程与里程。
///
/// 距离服务不可用（无 AMAP_KEY / 外部超时）时自动降级为直线距离×绕行系数，
/// 并在 `warnings` 中标注 `distance_estimated`，避免把估算里程当成实测值。
pub async fn plan_with(
    pool: &sqlx::PgPool,
    req: &PlanRequest,
    distances: Option<&DistanceService<'_>>,
) -> Result<PlanOutput, PlanError> {
    validate_plan_input(req)?;
    let mut warnings: Vec<Warning> = vec![];
    let end = req.end_date.unwrap_or_else(|| {
        req.start_date + Duration::days(req.days.unwrap_or(2).max(1) as i64 - 1)
    });
    let n_days = days_between(req.start_date, end);

    let candidates = recall_candidates(pool, &req.destination, &req.avoid)
        .await
        .map_err(|e| PlanError::InvalidRequest(e.to_string()))?;

    if candidates.is_empty() {
        return Err(PlanError::NoCandidates(req.destination.clone()));
    }

    // 主城市锚点
    let anchor: (f64, f64) = candidates
        .iter()
        .max_by_key(|c| c.popularity)
        .map(|c| (c.latitude, c.longitude))
        .unwrap_or((26.647, 106.630));

    let mut scored: Vec<(f64, Candidate)> = candidates
        .into_iter()
        .map(|c| {
            let d = haversine_km(anchor, (c.latitude, c.longitude));
            (score_candidate(&c, req, d), c)
        })
        .collect();
    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap());

    // 距离矩阵：只对最有可能入选的 Top-N 建矩阵，避免为全部候选打满外部 API。
    // points[0] 固定为主城市锚点，其余按分数序，保证矩阵与候选的稳定映射。
    let mut matrix_points: Vec<(f64, f64)> = vec![anchor];
    let mut index_of: std::collections::HashMap<Uuid, usize> = std::collections::HashMap::new();
    for (_, c) in scored.iter() {
        if matrix_points.len() >= distance::MAX_MATRIX_POINTS {
            break;
        }
        index_of.insert(c.id, matrix_points.len());
        matrix_points.push((c.longitude, c.latitude));
    }
    let matrix = match distances {
        Some(svc) if svc.enabled() => Some(svc.matrix(&matrix_points).await),
        _ => None,
    };
    let using_real_roads = matrix
        .as_ref()
        .is_some_and(|m| m.source == DistanceSource::Road);
    if !using_real_roads {
        warnings.push(Warning {
            code: "distance_estimated".into(),
            message: "未接入高德路网，里程与车程按直线距离×1.3 估算，实际耗时可能更长".into(),
            r#ref: None,
        });
    }

    // 住宿/餐饮单价：优先取 DB 中**已验证**的价格，取不到才回落到档位估算。
    // 事实类字段不允许无来源裸写（DESIGN §4.1），故只采信通过事实校验的记录。
    let quotes = load_price_quotes(pool, anchor).await;
    if !quotes.verified {
        warnings.push(Warning {
            code: "budget_rate_estimated".into(),
            message: "未取到已验证的住宿/餐饮价格，预算按档位估算，仅供参考".into(),
            r#ref: None,
        });
    }

    // 酒店/餐厅推荐属于 IO，与降级重试无关，只取一次
    let all_hotels = hotels_near(pool, anchor.1, anchor.0, 3)
        .await
        .map_err(|e| PlanError::InvalidRequest(e.to_string()))?;
    let all_rest = restaurants_near(pool, anchor.1, anchor.0, 5)
        .await
        .map_err(|e| PlanError::InvalidRequest(e.to_string()))?;

    // 预算装不下时按阶梯降级重排，而不是直接丢一个错误给用户（阶段 3.5）
    let (schedule, relax_level) = schedule_with_fallback(
        req,
        n_days,
        &scored,
        matrix.as_ref(),
        &index_of,
        anchor,
        &quotes,
    )?;
    if relax_level > 0 {
        let relax = Relaxation::ladder(req)[relax_level];
        warnings.push(Warning {
            code: "plan_degraded".into(),
            message: format!(
                "原方案超出预算，已自动调整为：每天至多 {} 个景点、住宿档位 {}",
                relax.per_day.unwrap_or_else(|| default_per_day(req)),
                relax.mode_override.unwrap_or("standard")
            ),
            r#ref: None,
        });
    }
    let ScheduleResult {
        days,
        ticket_total,
        total_dist,
        budget,
        warnings: day_warnings,
    } = schedule;
    warnings.extend(day_warnings);
    let drive_hours = total_dist / 50.0; // ~50km/h 平均
    let title = format!(
        "{}{}日{}",
        req.destination,
        n_days,
        if matches!(req.transport.as_str(), "self_drive" | "drive") {
            "自驾"
        } else {
            "行程"
        }
    );

    let total_distance_km = round1(total_dist);
    let summary = PlanSummary {
        title,
        origin: req.origin.clone(),
        destination: req.destination.clone(),
        days: n_days,
        people: req.people,
        mode: req.mode.clone(),
        total_distance_km,
        drive_hours: round1(drive_hours),
        ticket_cost: ticket_total,
        notes: vec![
            "票价与开放时间以景区官方当日公示为准".into(),
            "行程可单点重排，无需整单重生成".into(),
        ],
    };

    Ok(PlanOutput {
        summary,
        days,
        budget,
        hotels: all_hotels,
        restaurants: all_rest,
        routes: serde_json::json!({
            "origin": req.origin,
            "destination": req.destination,
            "mode": req.transport,
            "total_distance_km": total_distance_km,
        }),
        warnings,
        algo_version: ALGO_VERSION,
    })
}

/// 预算单价（阶段 3.5）。当前为经验档位，与重构前口径一致；
/// 步骤 5 起由 DB 已验证价格构造。
#[derive(Debug, Clone, Copy)]
pub struct BudgetRates {
    /// 每间每晚住宿
    pub lodging_per_night: i32,
    /// 每间房入住人数
    pub people_per_room: i32,
    /// 每人每天餐饮
    pub food_per_person_day: i32,
    /// 公共交通：每人每天
    pub transit_per_person_day: i32,
    /// 自驾：每天固定成本
    pub drive_fixed_day: i32,
    /// 其他交通方式：每天固定成本
    pub other_transport_day: i32,
    /// 自驾每天停车
    pub parking_per_day: i32,
    /// 每天其他杂项
    pub other_per_day: i32,
    /// 自驾每公里成本（元）
    pub per_km_drive: f64,
    /// 备用金比例
    pub reserve_ratio: f64,
}

impl BudgetRates {
    /// 按 mode 给出的默认档位。
    pub fn default_for(req: &PlanRequest) -> Self {
        Self {
            lodging_per_night: match req.mode.as_str() {
                "economy" => 100,
                "comfort" => 320,
                _ => 180,
            },
            people_per_room: 2,
            food_per_person_day: 60,
            transit_per_person_day: 40,
            drive_fixed_day: 100,
            other_transport_day: 60,
            parking_per_day: 30,
            other_per_day: 50,
            per_km_drive: 0.8,
            reserve_ratio: 0.1,
        }
    }
}

/// 预算硬约束（纯函数，可单测）。
///
/// 规则：先算固定项之和；已超预算直接 `BUDGET_EXCEEDED`；
/// 未超则按比例取备用金，并保证 `total <= budget_limit`。
pub fn compute_budget(
    req: &PlanRequest,
    n_days: i32,
    ticket_total: i32,
    total_dist: f64,
    rates: BudgetRates,
) -> Result<BudgetBreakdown, PlanError> {
    let nights = n_days.max(1);
    let people = req.people.max(1);
    let self_drive = matches!(req.transport.as_str(), "self_drive" | "drive");

    let rooms = (people as usize).div_ceil(rates.people_per_room.max(1) as usize) as i32;
    let lodging = rates.lodging_per_night * nights * rooms;
    let food = rates.food_per_person_day * n_days * people;
    let transport_cost = if self_drive {
        (total_dist * rates.per_km_drive) as i32 + rates.drive_fixed_day * n_days
    } else if req.transport == "transit" {
        rates.transit_per_person_day * n_days * people
    } else {
        rates.other_transport_day * n_days
    };
    let parking = if self_drive {
        rates.parking_per_day * n_days
    } else {
        0
    };
    let other = rates.other_per_day * n_days;

    let fixed = ticket_total + lodging + food + transport_cost + parking + other;
    let slack = req.budget - fixed;
    if req.budget > 0 && slack < 0 {
        return Err(PlanError::BudgetExceeded {
            limit: req.budget,
            total: fixed,
        });
    }
    let reserve = ((req.budget as f64 * rates.reserve_ratio) as i32)
        .max(0)
        .min(slack.max(0));
    let total = fixed + reserve;
    if req.budget > 0 && total > req.budget {
        return Err(PlanError::BudgetExceeded {
            limit: req.budget,
            total,
        });
    }

    Ok(BudgetBreakdown {
        limit: req.budget,
        transport: transport_cost,
        lodging,
        tickets: ticket_total,
        food,
        parking,
        other,
        reserve,
        total,
    })
}

/// 局部重规划：删除某景区节点及其进出 transit，并**顺延/提前**当天后续时间轴。
///
/// 实现要点（DESIGN §6）：
/// 1. transit 可能在 attraction 之前（前往）或之后（离开），两者都要删；
/// 2. 删除后必须重算当天剩余节点的 start/end，否则时间轴会出现空洞；
/// 3. transit 的 distance/duration 依赖被删节点的重算，不能沿用旧值。
pub fn replan_remove_day_item(day: &DayPlan, remove_ref: Uuid, _req: &PlanRequest) -> DayPlan {
    let mut items: Vec<PlanItem> = Vec::new();
    let mut i = 0;
    while i < day.items.len() {
        let it = &day.items[i];
        let is_target_attr = it.ref_id == Some(remove_ref) && it.item_type == "attraction";
        let is_target_transit = it.ref_id == Some(remove_ref) && it.item_type == "transit";
        if is_target_attr || is_target_transit {
            // 删 attraction 时，紧随其后的 transit（离开该景区）一并删除
            i += 1;
            if is_target_attr {
                if let Some(next) = day.items.get(i) {
                    if next.item_type == "transit" {
                        i += 1;
                    }
                }
            }
            continue;
        }
        items.push(it.clone());
        i += 1;
    }
    reflow_day_items(&mut items);
    DayPlan {
        day_index: day.day_index,
        date: day.date,
        title: day.title.clone(),
        items,
    }
}

/// 按顺序重算一天的时间轴：transit 的距离/车程由相邻带坐标节点重新计算，
/// 各节点 start_time/end_time 顺次衔接，删除节点后不留空洞、不重叠。
///
/// 纯函数：不做 IO，便于单测；DB 侧由 itinerary crate 负责持久化。
pub fn reflow_day_items(items: &mut [PlanItem]) {
    if items.is_empty() {
        return;
    }
    // ① 相邻带坐标节点之间的直线距离（km）
    let mut dists: Vec<Option<f64>> = vec![None; items.len()];
    let mut prev: Option<(f64, f64)> = None;
    for (i, it) in items.iter().enumerate() {
        if let (Some(lng), Some(lat)) = (it.longitude, it.latitude) {
            if let Some(p) = prev {
                dists[i] = Some(haversine_km(p, (lat, lng)));
            }
            prev = Some((lat, lng));
        }
    }

    // ② 从当天首节点时间起顺次重排
    let day_start = items[0].start_time;
    let mut cursor = day_start;
    for (i, it) in items.iter_mut().enumerate() {
        let dist = dists[i];
        if let Some(d) = dist {
            it.distance_km = Some(round1(d));
        }
        // 交通段独占车程；其余节点紧随其后，时长沿用自身 duration_min
        if it.item_type == "transit" {
            let travel = dist.map(travel_minutes_for).unwrap_or(0);
            it.start_time = cursor;
            it.duration_min = Some(travel);
            it.end_time = Some(cursor + Duration::minutes(travel as i64));
        } else {
            let dur = it.duration_min.unwrap_or(60).max(0) as i64;
            it.start_time = cursor;
            it.end_time = if it.end_time.is_some() {
                Some(cursor + Duration::minutes(dur))
            } else {
                None
            };
        }
        cursor = it.end_time.unwrap_or(it.start_time);
    }
}

/// 局部重规划 diff（阶段 4.2）：比较两版 day items，返回 removed/added/updated。
#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct DayDiff {
    pub removed: Vec<String>,
    pub added: Vec<String>,
    pub updated: Vec<String>,
}

pub fn diff_day_items(before: &[PlanItem], after: &[PlanItem]) -> DayDiff {
    use std::collections::HashMap;
    let key = |it: &PlanItem| -> String {
        match it.ref_id {
            Some(id) => format!("{}:{id}", it.item_type),
            None => format!("{}:{}:{:?}", it.item_type, it.title, it.start_time),
        }
    };
    let before_map: HashMap<String, &PlanItem> = before.iter().map(|it| (key(it), it)).collect();
    let after_map: HashMap<String, &PlanItem> = after.iter().map(|it| (key(it), it)).collect();
    let mut diff = DayDiff::default();
    for k in before_map.keys() {
        if !after_map.contains_key(k) {
            diff.removed.push(k.clone());
        }
    }
    for k in after_map.keys() {
        if !before_map.contains_key(k) {
            diff.added.push(k.clone());
        }
    }
    for (k, b) in &before_map {
        if let Some(a) = after_map.get(k) {
            if b.start_time != a.start_time
                || b.end_time != a.end_time
                || b.cost != a.cost
                || b.title != a.title
            {
                diff.updated.push((*k).clone());
            }
        }
    }
    diff
}

#[cfg(test)]
mod route_tests;

/// 一天的装包结果（阶段 3.4/3.5）。
#[derive(Debug, Clone)]
pub struct DayPack {
    pub day: DayPlan,
    /// 累计门票花费（含本日增量）
    pub ticket_total: i32,
    /// 本日新增里程（km）
    pub dist_km: f64,
    /// 本日最后落点坐标，作为下一天的起点
    pub last_xy: (f64, f64),
    /// 本日最后落点在距离矩阵中的下标
    pub last_idx: Option<usize>,
    pub warnings: Vec<Warning>,
}

/// 按天装包（纯函数，无 IO）：过滤 → 硬约束 → 时间轴 → 补三餐与住宿。
///
/// 这是排线管线里最容易出错的一段（营业时间、预算、时间窗互相牵制），
/// 独立成纯函数后可直接用合成候选做单测，无需数据库。
#[allow(clippy::too_many_arguments)]
pub fn pack_day(
    day_index: i32,
    date: NaiveDate,
    req: &PlanRequest,
    scored: &[(f64, Candidate)],
    per_day: usize,
    used: &mut std::collections::HashSet<Uuid>,
    matrix: Option<&distance::Matrix>,
    index_of: &std::collections::HashMap<Uuid, usize>,
    from_xy: (f64, f64),
    from_idx: Option<usize>,
    ticket_so_far: i32,
) -> DayPack {
    let mut items: Vec<PlanItem> = vec![];
    let mut day_title = String::new();
    let mut day_picked = 0usize;
    let mut cursor = NaiveTime::from_hms_opt(9, 0, 0).unwrap();
    let mut ticket_total = ticket_so_far;
    let mut dist_km = 0.0f64;
    let mut current = from_xy;
    let mut current_idx = from_idx;
    let mut warnings: Vec<Warning> = vec![];

    // 早餐/酒店出发
    items.push(PlanItem {
        item_type: "free".into(),
        start_time: cursor,
        end_time: Some(NaiveTime::from_hms_opt(9, 30, 0).unwrap()),
        title: "酒店早餐/出发准备".into(),
        location: Some(req.origin.clone()),
        longitude: None,
        latitude: None,
        ref_id: None,
        distance_km: None,
        duration_min: Some(30),
        cost: 0,
        reason: None,
        notice: None,
        score: None,
        candidate_source: None,
    });
    cursor = NaiveTime::from_hms_opt(9, 30, 0).unwrap();

    for (score, c) in scored.iter() {
        if day_picked >= per_day {
            break;
        }
        if !used.insert(c.id) {
            continue;
        }
        if *score < 30.0 {
            used.remove(&c.id);
            continue;
        }
        // 车程/里程：优先真实驾车路网（锚点为矩阵 0 号点）
        let to_idx = index_of.get(&c.id).copied();
        let (dist, travel_min) = match (matrix, current_idx, to_idx) {
            (Some(m), Some(f), Some(t)) => (m.km[f][t], m.minutes[f][t]),
            _ => {
                let d =
                    distance::estimated_road_km(haversine_km(current, (c.latitude, c.longitude)));
                (d, travel_minutes_for(d))
            }
        };
        // 预算粗过滤（阶段 3.5：硬约束前置）
        let price = c.ticket_price.unwrap_or(0) * req.people.max(1);
        if ticket_total + price > req.budget && req.budget > 0 {
            warnings.push(Warning {
                code: "ticket_budget_tight".into(),
                message: format!("门票预算紧张，已跳过「{}」", c.name),
                r#ref: Some(c.id.to_string()),
            });
            used.remove(&c.id);
            continue;
        }
        // 未验证事实 → 只进 warnings，不进确定性字段（阶段 1.3）
        if let Some(w) = fact_estimate_warning(c) {
            warnings.push(w);
        }

        let arrive = cursor + Duration::minutes(travel_min as i64);
        if arrive.hour() >= 18 {
            // 太晚不塞新景区
            used.remove(&c.id);
            continue;
        }
        // 营业时间冲突检查（阶段 3.4）：到达+游览必须落在开放时间内
        let stay = c.recommended_duration_min.unwrap_or(120).clamp(60, 300);
        if !fits_opening_hours(arrive, stay, c.opening_time, c.closing_time) {
            warnings.push(Warning {
                code: "opening_hours_conflict".into(),
                message: format!(
                    "「{}」开放时间冲突，已跳过（到达 {}）",
                    c.name,
                    arrive.format("%H:%M")
                ),
                r#ref: Some(c.id.to_string()),
            });
            used.remove(&c.id);
            continue;
        }

        items.push(PlanItem {
            item_type: "transit".into(),
            start_time: cursor,
            end_time: Some(arrive),
            title: format!("前往 {}", c.name),
            location: c.city.clone(),
            longitude: Some(c.longitude),
            latitude: Some(c.latitude),
            ref_id: Some(c.id),
            distance_km: Some(round1(dist)),
            duration_min: Some(travel_min),
            cost: 0,
            reason: None,
            notice: None,
            score: None,
            candidate_source: None,
        });
        dist_km += dist;

        let leave = arrive + Duration::minutes(stay as i64);
        // 票价按人数折算（阶段 3.5：硬约束需要真实总票价）
        let cost = c.ticket_price.unwrap_or(0) * req.people.max(1);
        ticket_total += cost;

        items.push(PlanItem {
            item_type: "attraction".into(),
            start_time: arrive,
            end_time: Some(leave),
            title: c.name.clone(),
            location: c.city.clone().or_else(|| Some(c.name.clone())),
            longitude: Some(c.longitude),
            latitude: Some(c.latitude),
            ref_id: Some(c.id),
            distance_km: None,
            duration_min: Some(stay),
            cost,
            reason: Some(format!("匹配分 {:.0}；适合你的兴趣标签", score)),
            notice: c.description.as_ref().map(|d| {
                let mut s = d.clone();
                if s.len() > 80 {
                    s.truncate(80);
                    s.push('…');
                }
                s
            }),
            score: Some(round1(*score)),
            candidate_source: Some("destination_recall".into()),
        });
        current = (c.latitude, c.longitude);
        current_idx = to_idx.or(current_idx);
        cursor = leave;
        day_picked += 1;
        if day_title.is_empty() {
            day_title = c.name.clone();
        }

        // 午餐
        if cursor.hour() >= 12 && cursor.hour() < 14 {
            let lunch_end = cursor + Duration::minutes(60);
            items.push(PlanItem {
                item_type: "meal".into(),
                start_time: cursor,
                end_time: Some(lunch_end),
                title: "午餐".into(),
                location: c.city.clone(),
                longitude: Some(c.longitude),
                latitude: Some(c.latitude),
                ref_id: None,
                distance_km: None,
                duration_min: Some(60),
                cost: 40 * req.people.max(1),
                reason: None,
                notice: None,
                score: None,
                candidate_source: None,
            });
            cursor = lunch_end;
        }
    }

    // 晚餐 + 自由活动
    if cursor.hour() < 19 {
        let dinner = NaiveTime::from_hms_opt(18, 30, 0).unwrap().max(cursor);
        let dend = dinner + Duration::minutes(75);
        items.push(PlanItem {
            item_type: "meal".into(),
            start_time: dinner,
            end_time: Some(dend),
            title: "晚餐".into(),
            location: Some(req.destination.clone()),
            longitude: None,
            latitude: None,
            ref_id: None,
            distance_km: None,
            duration_min: Some(75),
            cost: 60 * req.people.max(1),
            reason: None,
            notice: None,
            score: None,
            candidate_source: None,
        });
        items.push(PlanItem {
            item_type: "free".into(),
            start_time: dend,
            end_time: Some(NaiveTime::from_hms_opt(21, 30, 0).unwrap()),
            title: "古城夜游/休息".into(),
            location: None,
            longitude: None,
            latitude: None,
            ref_id: None,
            distance_km: None,
            duration_min: Some(120),
            cost: 0,
            reason: None,
            notice: None,
            score: None,
            candidate_source: None,
        });
    }

    items.push(PlanItem {
        item_type: "hotel".into(),
        start_time: NaiveTime::from_hms_opt(21, 30, 0).unwrap(),
        end_time: None,
        title: "入住酒店".into(),
        location: Some(req.destination.clone()),
        longitude: None,
        latitude: None,
        ref_id: None,
        distance_km: None,
        duration_min: None,
        cost: 0,
        reason: None,
        notice: None,
        score: None,
        candidate_source: None,
    });

    // 重新排序：按 start_time（NaiveTime 实现 Ord）
    items.sort_by_key(|i| i.start_time);

    DayPack {
        day: DayPlan {
            day_index,
            date,
            title: if day_title.is_empty() {
                format!("{} · 第 {} 天", req.destination, day_index)
            } else {
                format!("第 {} 天 · {}", day_index, day_title)
            },
            items,
        },
        ticket_total,
        dist_km,
        last_xy: current,
        last_idx: current_idx,
        warnings,
    }
}

/// 每天默认装几个景区（强度档）。
pub fn default_per_day(req: &PlanRequest) -> usize {
    match req.intensity.as_str() {
        "low" => 2,
        _ => 3,
    }
}

/// 降级策略一档：限制每日景点数 / 覆盖住宿档位。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Relaxation {
    pub per_day: Option<usize>,
    pub mode_override: Option<&'static str>,
}

impl Relaxation {
    /// 由宽松到严格逐级尝试；只有全部失败才返回 BUDGET_EXCEEDED。
    pub fn ladder(req: &PlanRequest) -> Vec<Relaxation> {
        let base = default_per_day(req);
        vec![
            Relaxation {
                per_day: None,
                mode_override: None,
            },
            Relaxation {
                per_day: Some(base.min(2)),
                mode_override: None,
            },
            Relaxation {
                per_day: Some(base.min(2)),
                mode_override: Some("economy"),
            },
            Relaxation {
                per_day: Some(1),
                mode_override: Some("economy"),
            },
        ]
    }
}

/// 一轮装包 + 预算校验的结果。
#[derive(Debug, Clone)]
pub struct ScheduleResult {
    pub days: Vec<DayPlan>,
    pub ticket_total: i32,
    pub total_dist: f64,
    pub budget: BudgetBreakdown,
    pub warnings: Vec<Warning>,
}

/// 按给定降级档位装包并校验预算。纯计算，不做 IO。
#[allow(clippy::too_many_arguments)]
fn schedule_days(
    req: &PlanRequest,
    n_days: i32,
    scored: &[(f64, Candidate)],
    matrix: Option<&distance::Matrix>,
    index_of: &std::collections::HashMap<Uuid, usize>,
    anchor: (f64, f64),
    relax: Relaxation,
    rates: BudgetRates,
) -> Result<ScheduleResult, PlanError> {
    let per_day = relax.per_day.unwrap_or_else(|| default_per_day(req));
    let mut used = std::collections::HashSet::new();
    let mut days: Vec<DayPlan> = Vec::new();
    let mut ticket_total = 0i32;
    let mut total_dist = 0.0f64;
    let mut warnings: Vec<Warning> = vec![];
    let mut current = anchor;
    let mut current_idx: Option<usize> = Some(0);

    for d in 0..n_days {
        let date = req.start_date + Duration::days(d as i64);
        let pack = pack_day(
            d + 1,
            date,
            req,
            scored,
            per_day,
            &mut used,
            matrix,
            index_of,
            current,
            current_idx,
            ticket_total,
        );
        warnings.extend(pack.warnings);
        days.push(pack.day);
        ticket_total = pack.ticket_total;
        total_dist += pack.dist_km;
        current = pack.last_xy;
        current_idx = pack.last_idx;
    }

    let budget = compute_budget(req, n_days, ticket_total, total_dist, rates)?;
    Ok(ScheduleResult {
        days,
        ticket_total,
        total_dist,
        budget,
        warnings,
    })
}

/// 从 DB 读取住宿/餐饮报价，只采信通过事实校验的记录（DESIGN §4.1）。
pub struct PriceQuotes {
    pub lodging_per_night: Option<i32>,
    pub food_per_person_day: Option<i32>,
    /// 两项是否都拿到了可用报价
    pub verified: bool,
}

pub async fn load_price_quotes(pool: &sqlx::PgPool, anchor: (f64, f64)) -> PriceQuotes {
    let hotels: Vec<(Option<i32>, String, Option<String>, f64)> = sqlx::query_as(
        r#"SELECT price_min, verification_status::text, source_url, confidence
           FROM hotels
           WHERE longitude IS NOT NULL AND price_min IS NOT NULL
           ORDER BY geog <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
           LIMIT 5"#,
    )
    .bind(anchor.1)
    .bind(anchor.0)
    .fetch_all(pool)
    .await
    .unwrap_or_default();

    let lodging_per_night = hotels
        .into_iter()
        .find(|(_, s, u, c)| common::is_fact_usable(s, u.as_deref(), *c))
        .and_then(|(p, ..)| p);

    let rests: Vec<(Option<i32>, String, Option<String>, f64)> = sqlx::query_as(
        r#"SELECT price_per_person, verification_status::text, source_url, confidence
           FROM restaurants
           WHERE longitude IS NOT NULL AND price_per_person IS NOT NULL
           ORDER BY geog <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
           LIMIT 5"#,
    )
    .bind(anchor.1)
    .bind(anchor.0)
    .fetch_all(pool)
    .await
    .unwrap_or_default();

    let food_per_person_day = rests
        .into_iter()
        .find(|(_, s, u, c)| common::is_fact_usable(s, u.as_deref(), *c))
        .and_then(|(p, ..)| p);

    PriceQuotes {
        lodging_per_night,
        food_per_person_day,
        verified: lodging_per_night.is_some() && food_per_person_day.is_some(),
    }
}

impl BudgetRates {
    /// 用 DB 报价覆盖档位估算；`mode_override = economy` 时按经济档比例下调，
    /// 保证降级后的数字仍源自真实报价，而不是拍脑袋的另一个常数。
    pub fn with_quotes(self, q: &PriceQuotes, mode_override: Option<&str>) -> Self {
        let mut r = self;
        if mode_override == Some("economy") {
            r.lodging_per_night = match q.lodging_per_night {
                Some(p) => ((p as f64 * ECONOMY_LODGING_RATIO).round() as i32).max(60),
                None => 100,
            };
            if let Some(p) = q.food_per_person_day {
                r.food_per_person_day = ((p as f64 * ECONOMY_LODGING_RATIO).round() as i32).max(20);
            }
            return r;
        }
        if let Some(p) = q.lodging_per_night {
            r.lodging_per_night = p;
        }
        if let Some(p) = q.food_per_person_day {
            r.food_per_person_day = p;
        }
        r
    }
}

/// 经济档相对标准档的住宿/餐饮比例（100/180），用于把真实报价折算到经济档。
const ECONOMY_LODGING_RATIO: f64 = 100.0 / 180.0;

/// 按降级阶梯尝试装包，返回**第一档可行**的结果与其档位序号。
/// 全部档位都超预算才返回 `BUDGET_EXCEEDED`（DESIGN §3.5 硬约束不妥协，但先尽力给出可执行方案）。
#[allow(clippy::too_many_arguments)]
pub fn schedule_with_fallback(
    req: &PlanRequest,
    n_days: i32,
    scored: &[(f64, Candidate)],
    matrix: Option<&distance::Matrix>,
    index_of: &std::collections::HashMap<Uuid, usize>,
    anchor: (f64, f64),
    quotes: &PriceQuotes,
) -> Result<(ScheduleResult, usize), PlanError> {
    let mut last: Option<PlanError> = None;
    for (level, relax) in Relaxation::ladder(req).into_iter().enumerate() {
        let rates = BudgetRates::default_for(req).with_quotes(quotes, relax.mode_override);
        match schedule_days(req, n_days, scored, matrix, index_of, anchor, relax, rates) {
            Ok(s) => return Ok((s, level)),
            Err(e @ PlanError::BudgetExceeded { .. }) => last = Some(e),
            Err(e) => return Err(e),
        }
    }
    Err(last.unwrap_or(PlanError::BudgetExceeded {
        limit: req.budget,
        total: 0,
    }))
}
