//! 事实统一校验（阶段 1.3）：禁止未验证事实进入确定性字段。
//!
//! 规则：
//! - `verification_status == verified` 且 `source_url` 非空且 `confidence >= 0.7` 时，
//!   事实才可作为确定性行程事实（门票/开放时间/交通/酒店价等）使用；
//! - 否则只能：放入 `warnings`、标注估算、或拒绝进入正式行程事实字段。
use crate::error::{ApiError, ApiResult};

/// 事实可用性下限。
pub const MIN_FACT_CONFIDENCE: f64 = 0.7;

/// 检查一条事实是否可作为确定性事实使用。
pub fn is_fact_usable(
    verification_status: &str,
    source_url: Option<&str>,
    confidence: f64,
) -> bool {
    if verification_status != "verified" {
        return false;
    }
    let has_url = source_url.map(|u| !u.trim().is_empty()).unwrap_or(false);
    if !has_url {
        return false;
    }
    confidence.is_finite() && confidence >= MIN_FACT_CONFIDENCE
}

/// 失败时返回 422（事实类字段写入前必须过校验/对源）。
pub fn assert_fact_usable(
    field: &str,
    verification_status: &str,
    source_url: Option<&str>,
    confidence: f64,
) -> ApiResult<()> {
    if is_fact_usable(verification_status, source_url, confidence) {
        Ok(())
    } else {
        Err(ApiError::Unprocessable(format!(
            "unverified fact must not enter deterministic field '{field}': status={verification_status} confidence={confidence}",
        )))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verified_fact_with_url_and_high_confidence_is_usable() {
        assert!(is_fact_usable(
            "verified",
            Some("https://www.hgsly.cn"),
            0.92
        ));
    }

    #[test]
    fn non_verified_status_is_not_usable() {
        for status in ["pending", "stale", "disputed", "unverified"] {
            assert!(
                !is_fact_usable(status, Some("https://example.com"), 0.9),
                "status={status}"
            );
        }
    }

    #[test]
    fn verified_without_url_is_not_usable() {
        assert!(!is_fact_usable("verified", None, 0.9));
        assert!(!is_fact_usable("verified", Some("  "), 0.9));
    }

    #[test]
    fn verified_with_low_confidence_is_not_usable() {
        assert!(!is_fact_usable(
            "verified",
            Some("https://example.com"),
            0.5
        ));
        assert!(!is_fact_usable(
            "verified",
            Some("https://example.com"),
            0.69
        ));
    }

    #[test]
    fn assert_fact_usable_rejects_pending_facts() {
        let err = assert_fact_usable("ticket_price", "pending", None, 0.6).unwrap_err();
        assert!(matches!(err, ApiError::Unprocessable(_)));
    }
}
