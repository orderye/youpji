//! 距离矩阵（DESIGN.md §6）：优先走高德驾车路径矩阵，Redis 缓存，
//! 无 Key / 调用失败时降级为「直线距离 × 绕行系数」，并在 warnings 中标注。
//!
//! 坐标系：全程 GCJ-02（DESIGN §4.2），与 attractions.geog 一致，可直接送高德。
use crate::{haversine_km, round1, travel_minutes_for};
use serde::{Deserialize, Serialize};
use std::time::Duration as StdDuration;

/// 直线距离 → 实际车程的经验绕行系数（山区路网保守取 1.3）。
pub const ROAD_FACTOR: f64 = 1.3;
/// 路网数据稳定，缓存期取 30 天。
const DIST_CACHE_TTL_SECS: u64 = 30 * 24 * 3600;
/// 一次矩阵请求的坐标上限（高德 distance 接口 origins/destinations 上限 100，留足余量）。
pub const MAX_MATRIX_POINTS: usize = 24;
const DIST_CACHE_PREFIX: &str = "youpji:dist:v1:";

/// 矩阵来源：`Road` 为真实路网，`Estimate` 为降级估算。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DistanceSource {
    Road,
    Estimate,
}

/// 对称矩阵：`km[i][j]` 表示 i → j 的驾车里程（km），`minutes[i][j]` 为车程（分钟）。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Matrix {
    pub km: Vec<Vec<f64>>,
    pub minutes: Vec<Vec<i32>>,
    pub source: DistanceSource,
}

impl Matrix {
    /// 全部用直线距离 × 绕行系数估算得到的降级矩阵。
    pub fn estimated(points: &[(f64, f64)]) -> Self {
        let n = points.len();
        let mut km = vec![vec![0.0; n]; n];
        let mut minutes = vec![vec![0; n]; n];
        for i in 0..n {
            for j in 0..n {
                if i == j {
                    continue;
                }
                let d = estimated_road_km(haversine_km(points[i], points[j]));
                km[i][j] = d;
                minutes[i][j] = travel_minutes_for(d);
            }
        }
        Self {
            km,
            minutes,
            source: DistanceSource::Estimate,
        }
    }
}

/// 直线距离 → 估算实际里程。
pub fn estimated_road_km(straight_km: f64) -> f64 {
    straight_km * ROAD_FACTOR
}

/// 距离服务：`http` 复用 AppState 的连接池，`redis` 可选，`amap_key` 为空即降级。
pub struct DistanceService<'a> {
    http: &'a reqwest::Client,
    redis: Option<&'a redis::aio::ConnectionManager>,
    amap_key: &'a str,
}

impl<'a> DistanceService<'a> {
    pub fn new(
        http: &'a reqwest::Client,
        redis: Option<&'a redis::aio::ConnectionManager>,
        amap_key: &'a str,
    ) -> Self {
        Self {
            http,
            redis,
            amap_key,
        }
    }

    pub fn enabled(&self) -> bool {
        !self.amap_key.trim().is_empty()
    }

    /// 构建距离矩阵。任一环节失败都**静默降级**为估算矩阵 —— 规划不因外部服务不可用而失败。
    pub async fn matrix(&self, points: &[(f64, f64)]) -> Matrix {
        let pts: Vec<(f64, f64)> = points.iter().take(MAX_MATRIX_POINTS).copied().collect();
        if pts.len() < 2 {
            return Matrix::estimated(&pts);
        }
        if !self.enabled() {
            return Matrix::estimated(&pts);
        }

        let cache_key = format!("{DIST_CACHE_PREFIX}{}", cache_key_of(&pts));
        if let Some(m) = self.cache_get(&cache_key).await {
            return m;
        }

        match self.fetch_amap(&pts).await {
            Some(m) => {
                self.cache_put(&cache_key, &m).await;
                m
            }
            None => {
                tracing::warn!("amap distance matrix unavailable, falling back to estimate");
                Matrix::estimated(&pts)
            }
        }
    }

    async fn fetch_amap(&self, points: &[(f64, f64)]) -> Option<Matrix> {
        let join = |v: &[(f64, f64)]| -> String {
            v.iter()
                .map(|(lng, lat)| format!("{lng:.6},{lat:.6}"))
                .collect::<Vec<_>>()
                .join(";")
        };
        let url = format!(
            "https://restapi.amap.com/v3/distance?type=1&key={}&origins={}&destinations={}",
            self.amap_key,
            join(points),
            join(points)
        );

        let resp = self
            .http
            .get(&url)
            .timeout(StdDuration::from_secs(5))
            .send()
            .await
            .ok()?;
        let body: AmapDistanceResponse = resp.json().await.ok()?;
        if body.status != "1" {
            tracing::warn!(info = %body.info, code = %body.infocode, "amap distance rejected");
            return None;
        }
        let n = points.len();
        let mut km = vec![vec![0.0; n]; n];
        let mut minutes = vec![vec![0; n]; n];
        for (i, row) in body.results.iter().enumerate().take(n) {
            for (j, cell) in row.iter().enumerate().take(n) {
                if i == j {
                    continue;
                }
                match (cell.distance, cell.duration) {
                    (Some(d), Some(t)) => {
                        km[i][j] = round1(d / 1000.0);
                        minutes[i][j] = (t / 60.0).max(1.0) as i32;
                    }
                    // 高德对不可达点返回 null：退回估算，不能让矩阵出现 0 里程
                    _ => {
                        let d = estimated_road_km(haversine_km(points[i], points[j]));
                        km[i][j] = d;
                        minutes[i][j] = travel_minutes_for(d);
                    }
                }
            }
        }
        Some(Matrix {
            km,
            minutes,
            source: DistanceSource::Road,
        })
    }

    async fn cache_get(&self, key: &str) -> Option<Matrix> {
        let cm = self.redis?;
        let mut conn = cm.clone();
        let raw: Option<String> = redis::cmd("GET")
            .arg(key)
            .query_async(&mut conn)
            .await
            .ok()
            .flatten();
        serde_json::from_str(&raw?).ok()
    }

    async fn cache_put(&self, key: &str, m: &Matrix) {
        let Some(cm) = self.redis else { return };
        let Ok(payload) = serde_json::to_string(m) else {
            return;
        };
        let mut conn = cm.clone();
        let res: redis::RedisResult<()> = redis::cmd("SET")
            .arg(key)
            .arg(payload)
            .arg("EX")
            .arg(DIST_CACHE_TTL_SECS)
            .query_async(&mut conn)
            .await;
        if let Err(e) = res {
            tracing::warn!(%e, "distance cache write failed");
        }
    }
}

#[derive(Debug, Deserialize)]
struct AmapDistanceResponse {
    status: String,
    #[serde(default)]
    info: String,
    #[serde(default)]
    infocode: String,
    #[serde(default)]
    results: Vec<Vec<AmapDistanceCell>>,
}

#[derive(Debug, Deserialize, Default)]
struct AmapDistanceCell {
    /// 米
    distance: Option<f64>,
    /// 秒
    duration: Option<f64>,
}

/// 缓存键：坐标保留 4 位小数（约 11m），既能命中缓存又不失精度。
fn cache_key_of(points: &[(f64, f64)]) -> String {
    points
        .iter()
        .map(|(lng, lat)| format!("{lng:.4}_{lat:.4}"))
        .collect::<Vec<_>>()
        .join("|")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn estimated_matrix_is_symmetric_and_positive() {
        let pts = vec![(106.630, 26.647), (105.932, 26.245), (106.100, 26.400)];
        let m = Matrix::estimated(&pts);
        assert_eq!(m.source, DistanceSource::Estimate);
        for i in 0..pts.len() {
            assert_eq!(m.km[i][i], 0.0);
            for j in 0..pts.len() {
                assert_eq!(m.km[i][j], m.km[j][i], "矩阵应对称");
                if i != j {
                    assert!(m.km[i][j] > 0.0 && m.minutes[i][j] > 0);
                }
            }
        }
    }

    #[test]
    fn estimated_road_applies_factor() {
        assert!((estimated_road_km(100.0) - 130.0).abs() < 1e-9);
    }

    #[test]
    fn cache_key_is_stable_and_order_sensitive() {
        let a = [(106.6301, 26.6471), (105.9320, 26.2450)];
        let b = [(105.9320, 26.2450), (106.6301, 26.6471)];
        assert_eq!(cache_key_of(&a), cache_key_of(&a));
        assert_ne!(cache_key_of(&a), cache_key_of(&b));
    }

    #[test]
    fn estimated_matrix_is_square() {
        let pts: Vec<(f64, f64)> = (0..100).map(|i| (106.0 + i as f64 * 0.01, 26.0)).collect();
        let m = Matrix::estimated(&pts);
        assert_eq!(m.km.len(), pts.len());
        assert_eq!(m.km[0].len(), pts.len());
    }

    /// 矩阵请求必须限制点数，避免撞外部接口上限（编译期校验）。
    #[test]
    fn matrix_point_cap_is_within_provider_limit() {
        const { assert!(MAX_MATRIX_POINTS <= 100, "高德 distance 接口单侧上限 100") };
        const { assert!(MAX_MATRIX_POINTS >= 8, "至少要覆盖一个 3 天行程的落点") };
    }
}
