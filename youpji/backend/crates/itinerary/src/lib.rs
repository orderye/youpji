use common::error::{ApiError, ApiResult};
use common::state::AppState;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

pub use route::{PlanOutput, PlanRequest};

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ItineraryRow {
    pub id: Uuid,
    pub user_id: Option<Uuid>,
    pub title: String,
    pub origin: Option<String>,
    pub destination: Option<String>,
    pub start_date: chrono::NaiveDate,
    pub end_date: chrono::NaiveDate,
    pub people: i16,
    pub budget_limit: Option<i32>,
    pub transport: String,
    pub interests: Vec<String>,
    pub avoid: Vec<String>,
    pub intensity: String,
    pub mode: String,
    pub lodging_tier: String,
    pub status: String,
    pub summary: serde_json::Value,
    pub budget: serde_json::Value,
    pub warnings: serde_json::Value,
    pub algo_version: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct DayRow {
    pub id: Uuid,
    pub day_index: i16,
    pub date: chrono::NaiveDate,
    pub title: Option<String>,
}

#[derive(Debug, FromRow, Serialize, Clone)]
#[serde(rename_all = "snake_case")]
pub struct ItemRow {
    pub id: Uuid,
    pub day_id: Uuid,
    pub sort_order: i32,
    pub item_type: String,
    pub start_time: Option<chrono::NaiveTime>,
    pub end_time: Option<chrono::NaiveTime>,
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
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ItineraryDetail {
    pub itinerary: ItineraryRow,
    pub days: Vec<(DayRow, Vec<ItemRow>)>,
}

pub async fn save_plan(
    state: &AppState,
    user_id: Option<Uuid>,
    req: &PlanRequest,
    output: &PlanOutput,
) -> ApiResult<Uuid> {
    let end = req.end_date.unwrap_or_else(|| {
        req.start_date + chrono::Duration::days(req.days.unwrap_or(2).max(1) as i64 - 1)
    });
    let mut tx = state.pool.begin().await?;
    let id: Uuid = sqlx::query_scalar(
        r#"INSERT INTO itineraries (
            user_id, title, origin, destination, start_date, end_date, people,
            budget_limit, transport, interests, avoid, intensity, mode, lodging_tier,
            status, summary, budget, warnings, natural_input, algo_version
           ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,'confirmed',
            $15,$16,$17,$18,$19)
           RETURNING id"#,
    )
    .bind(user_id)
    .bind(&output.summary.title)
    .bind(&req.origin)
    .bind(&req.destination)
    .bind(req.start_date)
    .bind(end)
    .bind(req.people as i16)
    .bind(req.budget)
    .bind(&req.transport)
    .bind(&req.interests)
    .bind(&req.avoid)
    .bind(&req.intensity)
    .bind(&req.mode)
    .bind(&req.lodging_tier)
    .bind(serde_json::to_value(&output.summary).unwrap_or_default())
    .bind(serde_json::to_value(&output.budget).unwrap_or_default())
    .bind(serde_json::to_value(&output.warnings).unwrap_or_default())
    .bind(&req.natural_input)
    .bind(output.algo_version)
    .fetch_one(&mut *tx)
    .await?;

    for day in &output.days {
        let day_id: Uuid = sqlx::query_scalar(
            r#"INSERT INTO itinerary_days (itinerary_id, day_index, date, title)
               VALUES ($1,$2,$3,$4) RETURNING id"#,
        )
        .bind(id)
        .bind(day.day_index as i16)
        .bind(day.date)
        .bind(&day.title)
        .fetch_one(&mut *tx)
        .await?;

        for (i, item) in day.items.iter().enumerate() {
            sqlx::query(
                r#"INSERT INTO itinerary_items (
                    day_id, sort_order, item_type, start_time, end_time, title,
                    location, longitude, latitude, ref_id, distance_km, duration_min,
                    cost, reason, notice
                   ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)"#,
            )
            .bind(day_id)
            .bind(i as i32)
            .bind(&item.item_type)
            .bind(item.start_time)
            .bind(item.end_time)
            .bind(&item.title)
            .bind(&item.location)
            .bind(item.longitude)
            .bind(item.latitude)
            .bind(item.ref_id)
            .bind(item.distance_km)
            .bind(item.duration_min)
            .bind(item.cost)
            .bind(&item.reason)
            .bind(&item.notice)
            .execute(&mut *tx)
            .await?;
        }
    }

    sqlx::query(
        r#"INSERT INTO route_plans (itinerary_id, algo_version, candidates, score_snapshot)
           VALUES ($1,$2,$3,$4)"#,
    )
    .bind(id)
    .bind(output.algo_version)
    .bind(serde_json::json!([]))
    .bind(serde_json::to_value(&output.summary).unwrap_or_default())
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;
    Ok(id)
}

pub async fn get(state: &AppState, id: Uuid) -> ApiResult<ItineraryDetail> {
    let itinerary = sqlx::query_as::<_, ItineraryRow>(
        r#"SELECT id, user_id, title, origin, destination, start_date, end_date, people,
                  budget_limit, transport, interests, avoid, intensity, mode, lodging_tier,
                  status::text AS status, summary, budget, warnings, algo_version, created_at
           FROM itineraries WHERE id = $1"#,
    )
    .bind(id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("itinerary not found".into()))?;

    let days = sqlx::query_as::<_, DayRow>(
        r#"SELECT id, day_index, date, title FROM itinerary_days
           WHERE itinerary_id = $1 ORDER BY day_index"#,
    )
    .bind(id)
    .fetch_all(&state.pool)
    .await?;

    let mut out = Vec::new();
    for day in days {
        let items = sqlx::query_as::<_, ItemRow>(
            r#"SELECT id, day_id, sort_order, item_type::text AS item_type, start_time, end_time,
                      title, location, longitude, latitude, ref_id, distance_km, duration_min,
                      cost, reason, notice
               FROM itinerary_items WHERE day_id = $1 ORDER BY sort_order"#,
        )
        .bind(day.id)
        .fetch_all(&state.pool)
        .await?;
        out.push((day, items));
    }

    Ok(ItineraryDetail {
        itinerary,
        days: out,
    })
}

pub async fn list_for_user(state: &AppState, user_id: Uuid) -> ApiResult<Vec<ItineraryRow>> {
    let rows = sqlx::query_as::<_, ItineraryRow>(
        r#"SELECT id, user_id, title, origin, destination, start_date, end_date, people,
                  budget_limit, transport, interests, avoid, intensity, mode, lodging_tier,
                  status::text AS status, summary, budget, warnings, algo_version, created_at
           FROM itineraries WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50"#,
    )
    .bind(user_id)
    .fetch_all(&state.pool)
    .await?;
    Ok(rows)
}

/// 兼容入口：字段名统一为 attraction_id，同时接受旧的 item_id。
#[derive(Debug, Deserialize)]
pub struct ReplanRemoveInput {
    pub day_index: i32,
    #[serde(alias = "item_id")]
    pub attraction_id: Uuid,
    pub reason: Option<String>,
}

/// 编辑操作（阶段 4.1）：V0.1 只支持 remove_item / replace_restaurant /
/// move_item_to_day / replace_hotel；全局参数变更走整体重规划，不走此通道。
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum EditOp {
    /// 删除某天的景区节点（连带其进出 transit），并重排当天时间轴。
    /// 传景点 ID（attractions.id）或该节点自身 ID 均可。
    RemoveItem {
        #[serde(alias = "item_id")]
        attraction_id: Uuid,
        day_index: i32,
    },
    /// 替换某天的餐厅节点（原位替换 title/ref/费用）
    ReplaceRestaurant {
        item_id: Uuid,
        day_index: i32,
        restaurant_id: Uuid,
    },
    /// 把某节点搬到另一天（保持相对顺序，两天时间轴各自重排）
    MoveItemToDay {
        item_id: Uuid,
        day_index: i32,
        to_day_index: i32,
    },
    /// 替换某天的酒店节点（原位替换 title/ref/费用）
    ReplaceHotel {
        item_id: Uuid,
        day_index: i32,
        hotel_id: Uuid,
    },
}

/// 局部重规划结果（阶段 4.2）：必须返回 changed/unchanged days 与 diff。
#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ReplanResult {
    pub itinerary_id: Uuid,
    pub changed_days: Vec<i32>,
    pub unchanged_days: Vec<i32>,
    pub diff: serde_json::Value,
    pub warnings: serde_json::Value,
    pub detail: ItineraryDetail,
}

/// 兼容旧调用形态；实际入口是 `apply_edit`。
pub async fn replan_remove(
    state: &AppState,
    itinerary_id: Uuid,
    input: ReplanRemoveInput,
) -> ApiResult<ItineraryDetail> {
    let out = apply_edit(
        state,
        itinerary_id,
        EditOp::RemoveItem {
            attraction_id: input.attraction_id,
            day_index: input.day_index,
        },
    )
    .await?;
    Ok(out.detail)
}

/// 归属校验（AGENTS 隐私约定：行程默认仅本人可见，admin 例外）。
pub fn ensure_owner(owner: Option<Uuid>, user_id: Uuid, role: &str) -> ApiResult<()> {
    if role == "admin" {
        return Ok(());
    }
    match owner {
        Some(o) if o == user_id => Ok(()),
        _ => Err(ApiError::Forbidden("not your itinerary".into())),
    }
}

/// 只取归属人，避免鉴权时把整份行程与所有节点拉出来。
pub async fn owner_of(state: &AppState, id: Uuid) -> ApiResult<Option<Uuid>> {
    let row: Option<Option<Uuid>> =
        sqlx::query_scalar("SELECT user_id FROM itineraries WHERE id = $1")
            .bind(id)
            .fetch_optional(&state.pool)
            .await?;
    row.ok_or_else(|| ApiError::NotFound("itinerary not found".into()))
}

/// 预算分桶增减：编辑只改受影响的桶，total 由各桶现算，不再靠「扣减 total」的模糊修补。
#[derive(Debug, Default, Clone, Copy)]
struct BudgetDelta {
    tickets: i64,
    lodging: i64,
    food: i64,
    transport: i64,
}

impl BudgetDelta {
    fn apply_to(&self, budget: &mut serde_json::Value) {
        let Some(obj) = budget.as_object_mut() else {
            return;
        };
        for (k, d) in [
            ("tickets", self.tickets),
            ("lodging", self.lodging),
            ("food", self.food),
            ("transport", self.transport),
        ] {
            let cur = obj.get(k).and_then(|v| v.as_i64()).unwrap_or(0);
            obj.insert(k.into(), serde_json::json!((cur + d).max(0)));
        }
        for k in ["parking", "other", "reserve"] {
            let cur = obj.get(k).and_then(|v| v.as_i64()).unwrap_or(0);
            obj.insert(k.into(), serde_json::json!(cur.max(0)));
        }
        let get = |o: &serde_json::Map<String, serde_json::Value>, k: &str| -> i64 {
            o.get(k).and_then(|v| v.as_i64()).unwrap_or(0)
        };
        let total: i64 = [
            "transport",
            "lodging",
            "tickets",
            "food",
            "parking",
            "other",
            "reserve",
        ]
        .iter()
        .map(|k| get(obj, k))
        .sum();
        obj.insert("total".into(), serde_json::json!(total));
        obj.insert("limit".into(), serde_json::json!(get(obj, "limit")));
    }
}

/// 读取某天节点（事务内）。
async fn items_of_day(conn: &mut sqlx::PgConnection, day_id: Uuid) -> ApiResult<Vec<ItemRow>> {
    Ok(sqlx::query_as::<_, ItemRow>(
        r#"SELECT id, day_id, sort_order, item_type::text AS item_type, start_time, end_time,
                  title, location, longitude, latitude, ref_id, distance_km, duration_min,
                  cost, reason, notice
           FROM itinerary_items WHERE day_id = $1 ORDER BY sort_order"#,
    )
    .bind(day_id)
    .fetch_all(&mut *conn)
    .await?)
}

const DEFAULT_DAY_START: chrono::NaiveTime = chrono::NaiveTime::from_hms_opt(9, 0, 0).unwrap();

fn row_to_plan_item(r: &ItemRow) -> route::PlanItem {
    route::PlanItem {
        item_type: r.item_type.clone(),
        start_time: r.start_time.unwrap_or(DEFAULT_DAY_START),
        end_time: r.end_time,
        title: r.title.clone(),
        location: r.location.clone(),
        longitude: r.longitude,
        latitude: r.latitude,
        ref_id: r.ref_id,
        distance_km: r.distance_km,
        duration_min: r.duration_min,
        cost: r.cost,
        reason: r.reason.clone(),
        notice: r.notice.clone(),
        score: None,
        candidate_source: None,
    }
}

/// 重排一天：交给 `route::reflow_day_items` 重算时间轴与车程，再回写节点。
///
/// sort_order 分两阶段写（先全部置负再定序），否则会撞 `UNIQUE(day_id, sort_order)`。
async fn reflow_and_persist(
    conn: &mut sqlx::PgConnection,
    day_id: Uuid,
    rows: &mut [ItemRow],
) -> ApiResult<()> {
    let mut plan_items: Vec<route::PlanItem> = rows.iter().map(row_to_plan_item).collect();
    route::reflow_day_items(&mut plan_items);
    for (row, it) in rows.iter_mut().zip(plan_items.iter()) {
        row.start_time = Some(it.start_time);
        row.end_time = it.end_time;
        row.distance_km = it.distance_km;
        row.duration_min = it.duration_min;
    }

    sqlx::query("UPDATE itinerary_items SET sort_order = -sort_order - 1 WHERE day_id = $1")
        .bind(day_id)
        .execute(&mut *conn)
        .await?;
    for (i, r) in rows.iter().enumerate() {
        sqlx::query(
            r#"UPDATE itinerary_items
               SET sort_order = $1, start_time = $2, end_time = $3,
                   distance_km = $4, duration_min = $5
               WHERE id = $6"#,
        )
        .bind(i as i32)
        .bind(r.start_time)
        .bind(r.end_time)
        .bind(r.distance_km)
        .bind(r.duration_min)
        .bind(r.id)
        .execute(&mut *conn)
        .await?;
    }
    Ok(())
}

/// 局部重规划入口（阶段 4.1–4.3）：只重算受影响的天/段，
/// 除数据源变化或全局参数变更外，禁止整体重生成。
///
/// 事务边界：全部读写在单个事务内完成，任一步失败整体回滚，
/// 杜绝「节点已删、顺序未重排」的半成品状态。
/// 预算硬约束在编辑后**重新校验**：编辑导致超支 → 422 BUDGET_EXCEEDED 且不落库。
pub async fn apply_edit(
    state: &AppState,
    itinerary_id: Uuid,
    op: EditOp,
) -> ApiResult<ReplanResult> {
    let before = get(state, itinerary_id).await?;

    let (day_index, to_day_index) = match &op {
        EditOp::RemoveItem { day_index, .. } => (*day_index, None),
        EditOp::ReplaceRestaurant { day_index, .. } => (*day_index, None),
        EditOp::MoveItemToDay {
            day_index,
            to_day_index,
            ..
        } => (*day_index, Some(*to_day_index)),
        EditOp::ReplaceHotel { day_index, .. } => (*day_index, None),
    };

    let day_id = day_id_of(&before, day_index)?;
    let to_day_id = match to_day_index {
        Some(t) if t != day_index => Some(day_id_of(&before, t)?),
        Some(_) => return Err(ApiError::BadRequest("to_day_index equals day_index".into())),
        None => None,
    };

    let mut tx = state.pool.begin().await?;
    let people = before.itinerary.people as i32;
    let budget_limit: Option<i32> =
        sqlx::query_scalar("SELECT budget_limit FROM itineraries WHERE id = $1")
            .bind(itinerary_id)
            .fetch_one(&mut *tx)
            .await?;

    let mut diff = serde_json::json!({"removed": [], "added": [], "updated": []});
    let mut op_warnings: Vec<serde_json::Value> = vec![];
    let mut delta = BudgetDelta::default();

    match op {
        EditOp::RemoveItem { attraction_id, .. } => {
            apply_remove(
                &mut tx,
                day_id,
                attraction_id,
                &mut diff,
                &mut op_warnings,
                &mut delta,
            )
            .await?;
        }
        EditOp::ReplaceRestaurant {
            item_id,
            restaurant_id,
            ..
        } => {
            apply_replace_restaurant(
                &mut tx,
                day_id,
                item_id,
                restaurant_id,
                people,
                &mut diff,
                &mut op_warnings,
                &mut delta,
            )
            .await?;
        }
        EditOp::MoveItemToDay { item_id, .. } => {
            let target = to_day_id.expect("to_day_index 已在上面校验");
            apply_move_item(
                &mut tx,
                day_id,
                target,
                item_id,
                &mut diff,
                &mut op_warnings,
            )
            .await?;
        }
        EditOp::ReplaceHotel {
            item_id, hotel_id, ..
        } => {
            apply_replace_hotel(
                &mut tx,
                day_id,
                item_id,
                hotel_id,
                people,
                &mut diff,
                &mut op_warnings,
                &mut delta,
            )
            .await?;
        }
    }

    // 预算：按桶增减 → 重算 total → 硬约束复核（超支则整体回滚）
    let mut budget: serde_json::Value =
        sqlx::query_scalar("SELECT budget FROM itineraries WHERE id = $1")
            .bind(itinerary_id)
            .fetch_one(&mut *tx)
            .await?;
    delta.apply_to(&mut budget);
    let total = budget.get("total").and_then(|v| v.as_i64()).unwrap_or(0);
    if let Some(limit) = budget_limit {
        if total > limit as i64 {
            // 事务随返回值一起丢弃 → 回滚，本次编辑不落库
            return Err(ApiError::BudgetExceeded(format!(
                "BUDGET_EXCEEDED: edit raises itinerary total {total} over budget limit {limit}"
            )));
        }
    }

    let mut warnings: serde_json::Value =
        sqlx::query_scalar("SELECT warnings FROM itineraries WHERE id = $1")
            .bind(itinerary_id)
            .fetch_one(&mut *tx)
            .await?;
    if let Some(arr) = warnings.as_array_mut() {
        for w in op_warnings {
            arr.push(w);
        }
    }
    sqlx::query(
        "UPDATE itineraries SET budget = $1, warnings = $2, updated_at = now() WHERE id = $3",
    )
    .bind(&budget)
    .bind(&warnings)
    .bind(itinerary_id)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;

    // 只有受影响的天进入 changed_days，其余天保持不变（DESIGN §6）
    let mut changed_days = vec![day_index];
    if let Some(t) = to_day_index {
        changed_days.push(t);
    }
    let detail = get(state, itinerary_id).await?;
    let unchanged_days: Vec<i32> = detail
        .days
        .iter()
        .map(|(d, _)| d.day_index as i32)
        .filter(|d| !changed_days.contains(d))
        .collect();

    Ok(ReplanResult {
        itinerary_id,
        changed_days,
        unchanged_days,
        diff,
        warnings,
        detail,
    })
}

fn day_id_of(detail: &ItineraryDetail, day_index: i32) -> ApiResult<Uuid> {
    detail
        .days
        .iter()
        .find(|(d, _)| d.day_index as i32 == day_index)
        .map(|(d, _)| d.id)
        .ok_or_else(|| ApiError::NotFound("day not found".into()))
}

/// 删除景区节点：按 id 或 ref_id 精确定位（不再用名称字符串匹配），
/// 连带其进出 transit 一并删除，然后重排当天时间轴。
#[allow(clippy::too_many_arguments)]
async fn apply_remove(
    conn: &mut sqlx::PgConnection,
    day_id: Uuid,
    target: Uuid,
    diff: &mut serde_json::Value,
    warnings: &mut Vec<serde_json::Value>,
    delta: &mut BudgetDelta,
) -> ApiResult<()> {
    let mut rows = items_of_day(conn, day_id).await?;
    let hit = rows
        .iter()
        .position(|r| r.item_type == "attraction" && (r.id == target || r.ref_id == Some(target)))
        .ok_or_else(|| ApiError::NotFound("item not found in day".into()))?;
    let target_ref = rows[hit].ref_id;

    let removed: Vec<ItemRow> = rows
        .iter()
        .filter(|r| {
            r.id == target
                || (target_ref.is_some()
                    && r.ref_id == target_ref
                    && matches!(r.item_type.as_str(), "attraction" | "transit"))
        })
        .cloned()
        .collect();

    for r in &removed {
        match r.item_type.as_str() {
            "attraction" => delta.tickets -= r.cost as i64,
            "transit" => delta.transport -= r.cost as i64,
            _ => {}
        }
        sqlx::query("DELETE FROM itinerary_items WHERE id = $1")
            .bind(r.id)
            .execute(&mut *conn)
            .await?;
    }
    rows.retain(|r| !removed.iter().any(|x| x.id == r.id));
    reflow_and_persist(conn, day_id, &mut rows).await?;

    diff["removed"] =
        serde_json::json!(removed.iter().map(|r| r.id.to_string()).collect::<Vec<_>>());
    warnings.push(serde_json::json!({
        "code": "replan_removed",
        "message": format!("已移除节点 {} 个并重排当天时间轴", removed.len()),
        "ref": target.to_string(),
    }));
    Ok(())
}

/// 替换餐厅：原位改 title/ref_id/cost，并按人数折算费用。
#[allow(clippy::too_many_arguments)]
async fn apply_replace_restaurant(
    conn: &mut sqlx::PgConnection,
    day_id: Uuid,
    item_id: Uuid,
    restaurant_id: Uuid,
    people: i32,
    diff: &mut serde_json::Value,
    warnings: &mut Vec<serde_json::Value>,
    delta: &mut BudgetDelta,
) -> ApiResult<()> {
    let (name, price): (String, Option<i32>) =
        sqlx::query_as("SELECT name, price_per_person FROM restaurants WHERE id = $1")
            .bind(restaurant_id)
            .fetch_optional(&mut *conn)
            .await?
            .ok_or_else(|| ApiError::NotFound("restaurant not found".into()))?;

    let mut rows = items_of_day(conn, day_id).await?;
    let hit = rows
        .iter()
        .position(|r| r.id == item_id)
        .ok_or_else(|| ApiError::NotFound("item not found in day".into()))?;
    let new_cost = price.unwrap_or(0) * people.max(1);
    delta.food += (new_cost - rows[hit].cost) as i64;

    sqlx::query("UPDATE itinerary_items SET title = $1, ref_id = $2, cost = $3 WHERE id = $4")
        .bind(&name)
        .bind(restaurant_id)
        .bind(new_cost)
        .bind(item_id)
        .execute(&mut *conn)
        .await?;
    reflow_and_persist(conn, day_id, &mut rows).await?;

    diff["updated"] = serde_json::json!([item_id.to_string()]);
    warnings.push(serde_json::json!({
        "code": "replan_replaced_restaurant",
        "message": format!("已将餐厅替换为「{name}」"),
        "ref": item_id.to_string(),
    }));
    Ok(())
}

/// 跨天搬运：先给目标天 sort_order 腾空，避免撞 UNIQUE(day_id, sort_order)，
/// 再搬节点，并**分别**重排两天的时间轴（源天留空、目标天顺延）。
#[allow(clippy::too_many_arguments)]
async fn apply_move_item(
    conn: &mut sqlx::PgConnection,
    from_day: Uuid,
    to_day: Uuid,
    item_id: Uuid,
    diff: &mut serde_json::Value,
    warnings: &mut Vec<serde_json::Value>,
) -> ApiResult<()> {
    let mut from_rows = items_of_day(conn, from_day).await?;
    let hit = from_rows
        .iter()
        .position(|r| r.id == item_id)
        .ok_or_else(|| ApiError::NotFound("item not found in day".into()))?;
    let moved = from_rows.remove(hit);
    let mut to_rows = items_of_day(conn, to_day).await?;
    to_rows.push(moved);

    sqlx::query("UPDATE itinerary_items SET sort_order = -sort_order - 1 WHERE day_id = $1")
        .bind(to_day)
        .execute(&mut *conn)
        .await?;
    sqlx::query("UPDATE itinerary_items SET day_id = $1 WHERE id = $2")
        .bind(to_day)
        .bind(item_id)
        .execute(&mut *conn)
        .await?;

    reflow_and_persist(conn, from_day, &mut from_rows).await?;
    reflow_and_persist(conn, to_day, &mut to_rows).await?;

    diff["updated"] = serde_json::json!([item_id.to_string()]);
    warnings.push(serde_json::json!({
        "code": "replan_moved",
        "message": "已跨天搬运并重排两天时间轴",
        "ref": item_id.to_string(),
    }));
    Ok(())
}

/// 替换酒店：按 price_min × 房间数（每 2 人 1 间）折算，delta 计入 lodging 桶。
#[allow(clippy::too_many_arguments)]
async fn apply_replace_hotel(
    conn: &mut sqlx::PgConnection,
    day_id: Uuid,
    item_id: Uuid,
    hotel_id: Uuid,
    people: i32,
    diff: &mut serde_json::Value,
    warnings: &mut Vec<serde_json::Value>,
    delta: &mut BudgetDelta,
) -> ApiResult<()> {
    let (name, price_min, price_max): (String, Option<i32>, Option<i32>) =
        sqlx::query_as("SELECT name, price_min, price_max FROM hotels WHERE id = $1")
            .bind(hotel_id)
            .fetch_optional(&mut *conn)
            .await?
            .ok_or_else(|| ApiError::NotFound("hotel not found".into()))?;

    let mut rows = items_of_day(conn, day_id).await?;
    let hit = rows
        .iter()
        .position(|r| r.id == item_id)
        .ok_or_else(|| ApiError::NotFound("item not found in day".into()))?;

    let rooms = (people.max(1) + 1) / 2;
    let nightly = price_min.or_else(|| price_max.map(|m| m / 2)).unwrap_or(0);
    let new_cost = nightly * rooms;
    delta.lodging += (new_cost - rows[hit].cost) as i64;

    sqlx::query("UPDATE itinerary_items SET title = $1, ref_id = $2, cost = $3 WHERE id = $4")
        .bind(&name)
        .bind(hotel_id)
        .bind(new_cost)
        .bind(item_id)
        .execute(&mut *conn)
        .await?;
    reflow_and_persist(conn, day_id, &mut rows).await?;

    diff["updated"] = serde_json::json!([item_id.to_string()]);
    warnings.push(serde_json::json!({
        "code": "replan_replaced_hotel",
        "message": format!("已将酒店替换为「{name}」"),
        "ref": item_id.to_string(),
    }));
    Ok(())
}
