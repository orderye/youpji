use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::Type;

/// 来源分级：一级 official/government > 二级 map/platform > 三级 ugc > 四级 ai
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "source_type", rename_all = "snake_case")]
pub enum SourceType {
    Official,
    Government,
    Map,
    Platform,
    Ugc,
    Ai,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type)]
#[serde(rename_all = "snake_case")]
#[sqlx(type_name = "verification_status", rename_all = "snake_case")]
pub enum VerificationStatus {
    Verified,
    Pending,
    Stale,
    Disputed,
    Unverified,
}

/// 通用可信度元数据（DESIGN.md §4.1）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Provenance {
    pub source_type: SourceType,
    pub source_url: Option<String>,
    pub source_time: Option<DateTime<Utc>>,
    pub last_verified: Option<DateTime<Utc>>,
    pub verification_status: VerificationStatus,
    /// 0..=1
    pub confidence: f64,
}

/// 规划模式（不是价格系数，而是档位）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum PlanMode {
    Economy,
    #[default]
    Standard,
    Comfort,
}

/// 交通方式
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum TransportMode {
    Transit,
    Drive,
    Walk,
    Ride,
    #[default]
    SelfDrive,
}

/// 强度
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum Intensity {
    Low,
    #[default]
    Medium,
    High,
}

pub mod interest {
    pub const NATURE: &str = "nature";
    pub const FOOD: &str = "food";
    pub const PHOTO: &str = "photography";
    pub const HISTORY: &str = "history";
    pub const MUSEUM: &str = "museum";
    pub const FAMILY: &str = "family";
    pub const SHOPPING: &str = "shopping";
    pub const HIGH_INTENSITY: &str = "high_intensity";
}
