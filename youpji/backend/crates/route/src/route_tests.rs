//! route 领域测试（阶段 6.1/6.3）：纯函数测试，不依赖数据库。
use super::*;
use chrono::NaiveDate;

fn sample_req() -> PlanRequest {
    PlanRequest {
        origin: "贵阳".into(),
        destination: "安顺".into(),
        start_date: NaiveDate::from_ymd_opt(2026, 10, 1).unwrap(),
        end_date: Some(NaiveDate::from_ymd_opt(2026, 10, 2).unwrap()),
        days: Some(2),
        people: 2,
        budget: 2000,
        transport: "self_drive".into(),
        interests: vec!["nature".into(), "history".into()],
        avoid: vec![],
        intensity: "medium".into(),
        mode: "standard".into(),
        lodging_tier: "standard".into(),
        natural_input: None,
    }
}

fn sample_candidate(name: &str) -> Candidate {
    Candidate {
        id: Uuid::now_v7(),
        name: name.into(),
        city: Some("安顺".into()),
        district: None,
        longitude: 105.7,
        latitude: 26.0,
        ticket_price: Some(160),
        opening_time: Some(NaiveTime::from_hms_opt(7, 0, 0).unwrap()),
        closing_time: Some(NaiveTime::from_hms_opt(18, 0, 0).unwrap()),
        recommended_duration_min: Some(240),
        difficulty: Some(2),
        family_score: 86,
        elderly_score: 70,
        photography_score: 92,
        couple_score: 90,
        popularity: 98,
        indoor: false,
        status: "open".into(),
        category: Some("自然景观/瀑布".into()),
        description: None,
        verification_status: "verified".into(),
        confidence: 0.92,
        source_url: Some("https://www.hgsly.cn".into()),
        tags: Some(vec!["nature".into()]),
    }
}

fn sample_item(item_type: &str, title: &str, hour: u32, ref_id: Option<Uuid>) -> PlanItem {
    PlanItem {
        item_type: item_type.into(),
        start_time: NaiveTime::from_hms_opt(hour, 0, 0).unwrap(),
        end_time: Some(NaiveTime::from_hms_opt(hour + 1, 0, 0).unwrap()),
        title: title.into(),
        location: None,
        longitude: None,
        latitude: None,
        ref_id,
        distance_km: None,
        duration_min: Some(60),
        cost: 100,
        reason: None,
        notice: None,
        score: None,
        candidate_source: None,
    }
}

/// 带坐标的节点，用于验证距离与车程重算。
#[allow(clippy::too_many_arguments)]
fn located_item(
    item_type: &str,
    title: &str,
    hour: u32,
    minute: u32,
    duration_min: i32,
    ref_id: Option<Uuid>,
    lng: Option<f64>,
    lat: Option<f64>,
) -> PlanItem {
    let start = NaiveTime::from_hms_opt(hour, minute, 0).unwrap();
    PlanItem {
        item_type: item_type.into(),
        start_time: start,
        end_time: Some(start + chrono::Duration::minutes(duration_min as i64)),
        title: title.into(),
        location: None,
        longitude: lng,
        latitude: lat,
        ref_id,
        distance_km: None,
        duration_min: Some(duration_min),
        cost: 100,
        reason: None,
        notice: None,
        score: None,
        candidate_source: None,
    }
}

#[test]
fn haversine_guiyang_anshun_about_90km() {
    let d = haversine_km((26.647, 106.630), (26.245, 105.932));
    assert!((70.0..=110.0).contains(&d), "dist={d}");
}

#[test]
fn haversine_same_point_is_zero() {
    assert!(haversine_km((26.0, 105.0), (26.0, 105.0)) < 0.001);
}

#[test]
fn score_prefers_matching_interests() {
    let req = sample_req();
    let nature = sample_candidate("黄果树瀑布");
    let mut other = sample_candidate("某商城");
    other.category = Some("购物/商城".into());
    other.tags = None;
    other.popularity = 98;
    let s_nature = score_candidate(&nature, &req, 10.0);
    let s_other = score_candidate(&other, &req, 10.0);
    assert!(s_nature > s_other, "{s_nature} vs {s_other}");
}

#[test]
fn score_penalizes_shopping_avoid() {
    let mut req = sample_req();
    req.avoid = vec!["shopping".into()];
    let mut c = sample_candidate("某商城");
    c.category = Some("购物".into());
    let penalized = score_candidate(&c, &req, 5.0);
    req.avoid = vec![];
    let plain = score_candidate(&c, &req, 5.0);
    assert!(penalized < plain);
}

#[test]
fn score_penalizes_far_distance() {
    let req = sample_req();
    let c = sample_candidate("黄果树瀑布");
    assert!(score_candidate(&c, &req, 5.0) > score_candidate(&c, &req, 100.0));
}

#[test]
fn opening_hours_fit_inside_window() {
    let open = NaiveTime::from_hms_opt(8, 0, 0).unwrap();
    let close = NaiveTime::from_hms_opt(18, 0, 0).unwrap();
    let arrive = NaiveTime::from_hms_opt(9, 30, 0).unwrap();
    assert!(fits_opening_hours(arrive, 240, Some(open), Some(close)));
}

#[test]
fn opening_hours_conflict_when_leave_after_close() {
    let open = NaiveTime::from_hms_opt(8, 0, 0).unwrap();
    let close = NaiveTime::from_hms_opt(12, 0, 0).unwrap();
    let arrive = NaiveTime::from_hms_opt(10, 0, 0).unwrap();
    assert!(!fits_opening_hours(arrive, 180, Some(open), Some(close)));
}

#[test]
fn opening_hours_conflict_when_arrive_before_open() {
    let open = NaiveTime::from_hms_opt(9, 0, 0).unwrap();
    let close = NaiveTime::from_hms_opt(18, 0, 0).unwrap();
    let arrive = NaiveTime::from_hms_opt(8, 0, 0).unwrap();
    assert!(!fits_opening_hours(arrive, 60, Some(open), Some(close)));
}

#[test]
fn missing_hours_fall_back_to_estimate_window() {
    let arrive = NaiveTime::from_hms_opt(9, 0, 0).unwrap();
    assert!(fits_opening_hours(arrive, 120, None, None));
    let late = NaiveTime::from_hms_opt(17, 30, 0).unwrap();
    assert!(!fits_opening_hours(late, 120, None, None));
}

#[test]
fn verified_candidate_fact_is_usable() {
    assert!(candidate_fact_usable(&sample_candidate("黄果树瀑布")));
}

#[test]
fn unverified_candidate_fact_is_not_usable() {
    let mut c = sample_candidate("龙宫");
    c.verification_status = "pending".into();
    c.source_url = None;
    c.confidence = 0.6;
    assert!(!candidate_fact_usable(&c));
}

#[test]
fn plan_error_codes_are_structured() {
    let e = PlanError::BudgetExceeded {
        limit: 2000,
        total: 2500,
    };
    assert_eq!(e.code(), "BUDGET_EXCEEDED");
    assert!(e.to_string().contains("BUDGET_EXCEEDED"));
    assert_eq!(
        PlanError::NoCandidates("安顺".into()).code(),
        "NO_CANDIDATES"
    );
    assert_eq!(
        PlanError::InvalidRequest("x".into()).code(),
        "INVALID_REQUEST"
    );
}

#[test]
fn days_between_counts_inclusive() {
    let a = NaiveDate::from_ymd_opt(2026, 10, 1).unwrap();
    let b = NaiveDate::from_ymd_opt(2026, 10, 2).unwrap();
    assert_eq!(days_between(a, b), 2);
    assert_eq!(days_between(a, a), 1);
}

#[test]
fn replan_remove_drops_attraction_and_its_transit() {
    let id = Uuid::now_v7();
    let day = DayPlan {
        day_index: 1,
        date: NaiveDate::from_ymd_opt(2026, 10, 1).unwrap(),
        title: "第 1 天".into(),
        items: vec![
            sample_item("free", "酒店早餐/出发准备", 9, None),
            sample_item("transit", "前往 黄果树瀑布", 9, Some(id)),
            sample_item("attraction", "黄果树瀑布", 10, Some(id)),
            sample_item("meal", "午餐", 12, None),
        ],
    };
    let out = replan_remove_day_item(&day, id, &sample_req());
    assert!(out.items.iter().all(|it| it.ref_id != Some(id)));
    assert!(out.items.iter().any(|it| it.item_type == "meal"));
}

#[test]
fn diff_detects_removed_added_updated() {
    let id = Uuid::now_v7();
    let before = vec![
        sample_item("attraction", "黄果树瀑布", 10, Some(id)),
        sample_item("meal", "午餐", 12, None),
    ];
    let mut after = vec![sample_item("meal", "午餐", 12, None)];
    after[0].cost = 200;
    let new_id = Uuid::now_v7();
    after.push(sample_item("attraction", "龙宫", 14, Some(new_id)));
    let diff = diff_day_items(&before, &after);
    assert_eq!(diff.removed.len(), 1);
    assert_eq!(diff.added.len(), 1);
    assert_eq!(diff.updated.len(), 1);
}

#[test]
fn diff_of_identical_days_is_empty() {
    let id = Uuid::now_v7();
    let items = vec![
        sample_item("attraction", "黄果树瀑布", 10, Some(id)),
        sample_item("meal", "午餐", 12, None),
    ];
    let diff = diff_day_items(&items, &items);
    assert!(diff.removed.is_empty() && diff.added.is_empty() && diff.updated.is_empty());
}

/// 时间轴重排：transit 的距离/车程必须按相邻带坐标节点重算，而不是沿用旧值。
#[test]
fn reflow_recomputes_transit_from_real_coordinates() {
    let (hotel_lng, hotel_lat) = (106.630, 26.647);
    let (a_lng, a_lat) = (105.670, 26.000);
    let (b_lng, b_lat) = (105.932, 26.245);

    let mut items = vec![
        located_item(
            "free",
            "酒店早餐",
            9,
            0,
            30,
            None,
            Some(hotel_lng),
            Some(hotel_lat),
        ),
        located_item(
            "transit",
            "前往 A",
            9,
            30,
            90,
            Some(Uuid::now_v7()),
            Some(a_lng),
            Some(a_lat),
        ),
        located_item(
            "attraction",
            "A",
            11,
            0,
            120,
            Some(Uuid::now_v7()),
            Some(a_lng),
            Some(a_lat),
        ),
        located_item(
            "transit",
            "前往 B",
            13,
            0,
            90,
            Some(Uuid::now_v7()),
            Some(b_lng),
            Some(b_lat),
        ),
        located_item(
            "attraction",
            "B",
            14,
            30,
            120,
            Some(Uuid::now_v7()),
            Some(b_lng),
            Some(b_lat),
        ),
        located_item("meal", "晚餐", 18, 30, 75, None, None, None),
    ];
    reflow_day_items(&mut items);

    let t_a = items.iter().find(|i| i.title == "前往 A").unwrap();
    let expected_a = travel_minutes_for(haversine_km((hotel_lat, hotel_lng), (a_lat, a_lng)));
    assert_eq!(t_a.duration_min, Some(expected_a));
    assert!(t_a.distance_km.unwrap() > 50.0, "贵阳→黄果树直线距离应显著");

    // 节点之间不留空洞：后一节点起点 == 前一节点终点
    for w in items.windows(2) {
        if let Some(end) = w[0].end_time {
            assert_eq!(
                w[1].start_time, end,
                "「{}」与「{}」之间出现时间空洞",
                w[0].title, w[1].title
            );
        }
    }
}

/// 删除景区后，后续节点必须整体前移并闭合，不能留下原时刻的空窗。
#[test]
fn replan_remove_compacts_remaining_timeline() {
    let id_a = Uuid::now_v7();
    let id_b = Uuid::now_v7();
    let (hotel_lng, hotel_lat) = (106.630, 26.647);
    let (a_lng, a_lat) = (105.670, 26.000);
    let (b_lng, b_lat) = (105.932, 26.245);

    let day = DayPlan {
        day_index: 1,
        date: NaiveDate::from_ymd_opt(2026, 10, 1).unwrap(),
        title: "第 1 天".into(),
        items: vec![
            located_item(
                "free",
                "酒店早餐",
                9,
                0,
                30,
                None,
                Some(hotel_lng),
                Some(hotel_lat),
            ),
            located_item(
                "transit",
                "前往 A",
                9,
                30,
                90,
                Some(id_a),
                Some(a_lng),
                Some(a_lat),
            ),
            located_item(
                "attraction",
                "A",
                11,
                0,
                120,
                Some(id_a),
                Some(a_lng),
                Some(a_lat),
            ),
            located_item(
                "transit",
                "前往 B",
                13,
                0,
                90,
                Some(id_b),
                Some(b_lng),
                Some(b_lat),
            ),
            located_item(
                "attraction",
                "B",
                14,
                30,
                120,
                Some(id_b),
                Some(b_lng),
                Some(b_lat),
            ),
            located_item("meal", "晚餐", 18, 30, 75, None, None, None),
        ],
    };

    let before_b_start = day
        .items
        .iter()
        .find(|i| i.ref_id == Some(id_b) && i.item_type == "attraction")
        .unwrap()
        .start_time;

    let out = replan_remove_day_item(&day, id_a, &sample_req());
    assert!(out.items.iter().all(|i| i.ref_id != Some(id_a)));

    let after_b_start = out
        .items
        .iter()
        .find(|i| i.ref_id == Some(id_b) && i.item_type == "attraction")
        .unwrap()
        .start_time;
    assert!(
        after_b_start < before_b_start,
        "删除 A 后 B 应整体前移：{after_b_start:?} !< {before_b_start:?}"
    );

    for w in out.items.windows(2) {
        if let Some(end) = w[0].end_time {
            assert_eq!(w[1].start_time, end, "重排后仍有时间空洞");
        }
    }
}

// ---------- 管线阶段测试（纯函数，无需 DB） ----------

/// 构造候选：除坐标/票价/闭园时间外，其余字段给中性值。
fn cand(
    name: &str,
    lng: f64,
    lat: f64,
    ticket: Option<i32>,
    close: Option<NaiveTime>,
) -> Candidate {
    Candidate {
        id: Uuid::now_v7(),
        name: name.into(),
        city: Some("安顺".into()),
        district: None,
        longitude: lng,
        latitude: lat,
        ticket_price: ticket,
        opening_time: Some(NaiveTime::from_hms_opt(7, 0, 0).unwrap()),
        closing_time: close,
        recommended_duration_min: Some(120),
        difficulty: Some(2),
        family_score: 80,
        elderly_score: 70,
        photography_score: 90,
        couple_score: 80,
        popularity: 90,
        indoor: false,
        status: "open".into(),
        category: Some("自然景观/瀑布".into()),
        description: None,
        verification_status: "verified".into(),
        confidence: 0.92,
        source_url: Some("https://www.hgsly.cn".into()),
        tags: Some(vec!["nature".into()]),
    }
}

fn run_pack_day(req: &PlanRequest, scored: &[(f64, Candidate)], per_day: usize) -> DayPack {
    let mut used = std::collections::HashSet::new();
    pack_day(
        1,
        req.start_date,
        req,
        scored,
        per_day,
        &mut used,
        None,
        &std::collections::HashMap::new(),
        (26.0, 105.7),
        None,
        0,
    )
}

/// 每天装包数量受 intensity/per_day 约束，不得超量。
#[test]
fn pack_day_respects_per_day_cap() {
    let req = sample_req();
    let scored: Vec<(f64, Candidate)> = (0..5)
        .map(|i| {
            (
                100.0 - i as f64,
                cand(&format!("景区{i}"), 105.7, 26.0, Some(50), None),
            )
        })
        .collect();
    let pack = run_pack_day(&req, &scored, 2);
    let n = pack
        .day
        .items
        .iter()
        .filter(|i| i.item_type == "attraction")
        .count();
    assert_eq!(n, 2, "per_day=2 时不应塞入第 3 个景区");
}

/// 闭园时间冲突必须跳过并产生 warning，而不是硬塞进去。
#[test]
fn pack_day_skips_opening_hours_conflict() {
    let req = sample_req();
    // 坐标与起点重合 → 车程 0；stay=120，09:30 到达 → 11:30 离园，晚于 10:00 闭园
    let bad = (
        90.0,
        cand(
            "早闭园",
            105.7,
            26.0,
            Some(50),
            Some(NaiveTime::from_hms_opt(10, 0, 0).unwrap()),
        ),
    );
    let pack = run_pack_day(&req, &[bad], 3);
    assert!(pack.day.items.iter().all(|i| i.title != "早闭园"));
    assert!(pack
        .warnings
        .iter()
        .any(|w| w.code == "opening_hours_conflict"));
}

/// 门票预算不足时跳过并告警，且累计门票不得越过预算。
#[test]
fn pack_day_caps_tickets_at_budget() {
    let mut req = sample_req();
    req.budget = 100; // 仅够 1 张 50 元 × 2 人
    let scored: Vec<(f64, Candidate)> = (0..4)
        .map(|i| {
            (
                100.0 - i as f64,
                cand(&format!("景区{i}"), 105.7, 26.0, Some(50), None),
            )
        })
        .collect();
    let pack = run_pack_day(&req, &scored, 3);
    assert!(
        pack.ticket_total <= req.budget,
        "累计门票 {} 超出预算",
        pack.ticket_total
    );
    assert!(pack
        .warnings
        .iter()
        .any(|w| w.code == "ticket_budget_tight"));
}

/// 装包后时间轴必须单调、不重叠。
#[test]
fn pack_day_timeline_is_monotonic() {
    let req = sample_req();
    let scored: Vec<(f64, Candidate)> = (0..3)
        .map(|i| {
            (
                100.0 - i as f64,
                cand(
                    &format!("景区{i}"),
                    105.7 + i as f64 * 0.02,
                    26.0,
                    Some(50),
                    None,
                ),
            )
        })
        .collect();
    let pack = run_pack_day(&req, &scored, 3);
    for w in pack.day.items.windows(2) {
        if let Some(end) = w[0].end_time {
            assert!(
                w[1].start_time >= end,
                "节点重叠：{} → {}",
                w[0].title,
                w[1].title
            );
        }
    }
}

/// 预算硬约束：超限必须整体失败，且备用金不得把总额推过上限。
#[test]
fn compute_budget_is_hard_constraint() {
    let req = sample_req();
    let rates = BudgetRates::default_for(&req);

    // 预算充裕
    let ok = compute_budget(&req, 2, 640, 180.0, rates).unwrap();
    assert!(ok.total <= req.budget);
    assert!(ok.reserve >= 0);
    assert_eq!(
        ok.total,
        ok.tickets + ok.lodging + ok.food + ok.transport + ok.parking + ok.other + ok.reserve
    );

    // 门票本身就超预算 → 必须失败，不能静默截断
    let over = compute_budget(&req, 2, 999_999, 180.0, rates).unwrap_err();
    assert!(matches!(over, PlanError::BudgetExceeded { .. }));

    // 刚好卡住：备用金不得超过剩余空间
    let mut tight = sample_req();
    tight.budget = 2000;
    let b = compute_budget(&tight, 2, 0, 0.0, rates).unwrap();
    assert!(b.total <= tight.budget);
}

/// 住宿按房间数而非人数折算：2 人 1 间，3 人 2 间。
#[test]
fn lodging_scales_by_room_not_by_person() {
    let rates = BudgetRates::default_for(&sample_req());
    let two = sample_req();
    let mut three = sample_req();
    three.people = 3;
    three.budget = 100_000;

    let b2 = compute_budget(&two, 2, 0, 0.0, rates).unwrap();
    let b3 = compute_budget(&three, 2, 0, 0.0, rates).unwrap();
    assert_eq!(b2.lodging, rates.lodging_per_night * 2);
    assert_eq!(
        b3.lodging,
        rates.lodging_per_night * 2 * 2,
        "3 人应开 2 间房"
    );
}

// ---------- 降级阶梯与报价（阶段 3.5 / 步骤 5） ----------

fn no_quotes() -> PriceQuotes {
    PriceQuotes {
        lodging_per_night: None,
        food_per_person_day: None,
        verified: false,
    }
}

fn four_candidates() -> Vec<(f64, Candidate)> {
    (0..4)
        .map(|i| {
            (
                100.0 - i as f64,
                cand(&format!("景区{i}"), 105.7, 26.0, Some(160), None),
            )
        })
        .collect()
}

fn fallback(
    req: &PlanRequest,
    scored: &[(f64, Candidate)],
    quotes: &PriceQuotes,
) -> Result<(ScheduleResult, usize), PlanError> {
    schedule_with_fallback(
        req,
        2,
        scored,
        None,
        &std::collections::HashMap::new(),
        (26.0, 105.7),
        quotes,
    )
}

/// 阶梯必须逐级收紧，最后一档是「每天 1 个景点 + 经济档」。
#[test]
fn relaxation_ladder_tightens_progressively() {
    let req = sample_req();
    let ladder = Relaxation::ladder(&req);
    assert_eq!(ladder.len(), 4);
    assert_eq!(ladder[0].per_day, None, "第一档保持用户强度");
    assert_eq!(ladder[0].mode_override, None);
    assert_eq!(ladder[3].per_day, Some(1));
    assert_eq!(ladder[3].mode_override, Some("economy"));
    for w in ladder.windows(2) {
        let prev = w[0].per_day.unwrap_or(99);
        let cur = w[1].per_day.unwrap_or(99);
        assert!(cur <= prev, "每日景点数不得回升");
    }
}

/// 核心产品行为：预算偏紧时应**降级出方案**，而不是只回一个 BUDGET_EXCEEDED。
#[test]
fn tight_budget_degrades_instead_of_failing() {
    let mut req = sample_req();
    req.budget = 1800; // 原方案（4 个景点 + 标准住宿）装不下

    let (res, level) = fallback(&req, &four_candidates(), &no_quotes()).expect("应降级出可行方案");
    assert!(level > 0, "第一档装不下，应发生降级，实际 level={level}");
    assert!(res.budget.total <= req.budget);
    let attractions = res
        .days
        .iter()
        .flat_map(|d| d.items.iter())
        .filter(|i| i.item_type == "attraction")
        .count();
    assert!(attractions >= 1, "降级后仍应保留可执行的景点");
}

/// 连最省的一档都装不下时，才允许失败（硬约束不妥协）。
#[test]
fn impossible_budget_still_fails() {
    let mut req = sample_req();
    req.budget = 200; // 连门票+住宿都不够
    let err = fallback(&req, &four_candidates(), &no_quotes()).unwrap_err();
    assert!(matches!(err, PlanError::BudgetExceeded { .. }));
}

/// 预算充裕时不应触发降级。
#[test]
fn roomy_budget_uses_first_ladder_rung() {
    let mut req = sample_req();
    req.budget = 5000;
    let (res, level) = fallback(&req, &four_candidates(), &no_quotes()).unwrap();
    assert_eq!(level, 0, "预算充裕时应直接用原方案");
    assert!(res.budget.total <= req.budget);
}

/// 2000 元两日游是产品的基准场景：装不下原方案时也应降级出可执行行程。
#[test]
fn baseline_2000_budget_two_days_still_plans() {
    let req = sample_req(); // budget = 2000, 2 天 2 人自驾
    let (res, _level) = fallback(&req, &four_candidates(), &no_quotes())
        .expect("2000 元两日游必须能产出方案，而不是直接失败");
    assert!(res.budget.total <= req.budget);
    assert_eq!(res.days.len(), 2);
}

/// DB 真实报价应覆盖档位估算。
#[test]
fn verified_quotes_override_default_rates() {
    let req = sample_req();
    let quotes = PriceQuotes {
        lodging_per_night: Some(520),
        food_per_person_day: Some(90),
        verified: true,
    };
    let rates = BudgetRates::default_for(&req).with_quotes(&quotes, None);
    assert_eq!(rates.lodging_per_night, 520);
    assert_eq!(rates.food_per_person_day, 90);

    // 经济档按比例下调，但仍是源自真实报价的数字
    let eco = BudgetRates::default_for(&req).with_quotes(&quotes, Some("economy"));
    assert!(eco.lodging_per_night < 520 && eco.lodging_per_night >= 60);
    assert!(eco.food_per_person_day < 90);
}

/// 没有已验证报价时必须落回档位估算，且不改变硬约束。
#[test]
fn missing_quotes_fall_back_to_tier_defaults() {
    let req = sample_req();
    let rates = BudgetRates::default_for(&req).with_quotes(&no_quotes(), None);
    assert_eq!(rates.lodging_per_night, 180);
    assert_eq!(rates.food_per_person_day, 60);
}
