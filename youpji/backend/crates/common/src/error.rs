use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde_json::json;

pub type ApiResult<T> = Result<T, ApiError>;

#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("{0}")]
    BadRequest(String),
    #[error("{0}")]
    Unauthorized(String),
    #[error("{0}")]
    Forbidden(String),
    #[error("{0}")]
    NotFound(String),
    #[error("{0}")]
    Conflict(String),
    #[error("{0}")]
    Unprocessable(String),
    #[error("{0}")]
    TooManyRequests(String),
    #[error("{0}")]
    BudgetExceeded(String),
    #[error("internal: {0}")]
    Internal(String),
    #[error(transparent)]
    Db(#[from] sqlx::Error),
}

impl ApiError {
    /// 统一错误码（阶段 5.2）：大写稳定码，供前端分支判断。
    pub fn code(&self) -> &'static str {
        match self {
            Self::BadRequest(_) => "VALIDATION_ERROR",
            Self::Unauthorized(_) => "UNAUTHORIZED",
            Self::Forbidden(_) => "FORBIDDEN",
            Self::NotFound(_) => "NOT_FOUND",
            Self::Conflict(_) => "CONFLICT",
            Self::Unprocessable(_) => "UNPROCESSABLE_ENTITY",
            Self::TooManyRequests(_) => "RATE_LIMITED",
            Self::BudgetExceeded(_) => "BUDGET_EXCEEDED",
            Self::Internal(_) | Self::Db(_) => "INTERNAL_ERROR",
        }
    }

    /// route::PlanError 映射（阶段 3.5/5.2）：预算硬约束失败 → 422 + BUDGET_EXCEEDED。
    /// 注意：PlanError 类型在 route crate；调用方用字符串码匹配，避免 common→route 循环依赖。
    pub fn from_plan_error_code(code: &str, message: String) -> Self {
        match code {
            "BUDGET_EXCEEDED" => Self::BudgetExceeded(message),
            _ => Self::Unprocessable(message),
        }
    }

    pub fn status(&self) -> StatusCode {
        match self {
            Self::BadRequest(_) => StatusCode::BAD_REQUEST,
            Self::Unauthorized(_) => StatusCode::UNAUTHORIZED,
            Self::Forbidden(_) => StatusCode::FORBIDDEN,
            Self::NotFound(_) => StatusCode::NOT_FOUND,
            Self::Conflict(_) => StatusCode::CONFLICT,
            Self::Unprocessable(_) => StatusCode::UNPROCESSABLE_ENTITY,
            Self::TooManyRequests(_) => StatusCode::TOO_MANY_REQUESTS,
            Self::BudgetExceeded(_) => StatusCode::UNPROCESSABLE_ENTITY,
            Self::Internal(_) | Self::Db(_) => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let public = matches!(self, Self::Internal(_) | Self::Db(_));
        let message = if public {
            "internal server error".to_string()
        } else {
            self.to_string()
        };
        if public {
            tracing::error!(error = %self, "api error");
        }
        // 统一错误格式（阶段 5.2）：{code, message, details}
        let body = json!({ "code": self.code(), "message": message, "details": {} });
        (self.status(), axum::Json(body)).into_response()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_codes_are_stable_uppercase() {
        assert_eq!(ApiError::BadRequest("x".into()).code(), "VALIDATION_ERROR");
        assert_eq!(ApiError::Unauthorized("x".into()).code(), "UNAUTHORIZED");
        assert_eq!(ApiError::Forbidden("x".into()).code(), "FORBIDDEN");
        assert_eq!(ApiError::NotFound("x".into()).code(), "NOT_FOUND");
        assert_eq!(ApiError::Conflict("x".into()).code(), "CONFLICT");
        assert_eq!(
            ApiError::Unprocessable("x".into()).code(),
            "UNPROCESSABLE_ENTITY"
        );
        assert_eq!(ApiError::TooManyRequests("x".into()).code(), "RATE_LIMITED");
        assert_eq!(
            ApiError::BudgetExceeded("x".into()).code(),
            "BUDGET_EXCEEDED"
        );
        assert_eq!(ApiError::Internal("x".into()).code(), "INTERNAL_ERROR");
    }

    #[test]
    fn budget_exceeded_maps_to_422() {
        assert_eq!(
            ApiError::BudgetExceeded("x".into()).status(),
            StatusCode::UNPROCESSABLE_ENTITY
        );
        assert!(matches!(
            ApiError::from_plan_error_code("BUDGET_EXCEEDED", "x".into()),
            ApiError::BudgetExceeded(_)
        ));
        assert!(matches!(
            ApiError::from_plan_error_code("NO_CANDIDATES", "x".into()),
            ApiError::Unprocessable(_)
        ));
    }
}
