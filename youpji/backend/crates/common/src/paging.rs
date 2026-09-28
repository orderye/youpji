use serde::{Deserialize, Serialize};

/// 统一分页（阶段 5.3）：`?limit=20&cursor=xxx`。
/// cursor 为不透明字符串；V0.1 实现为偏移量编码（`off:<n>`），后续可无缝换 keyset。
#[derive(Debug, Clone, Default, Deserialize, Serialize)]
pub struct Page {
    #[serde(default)]
    pub limit: Option<u64>,
    /// 兼容旧参数（?page=2&page_size=20）；新客户端一律用 limit + cursor。
    #[serde(default)]
    pub page: Option<u64>,
    #[serde(default)]
    pub page_size: Option<u64>,
    #[serde(default)]
    pub cursor: Option<String>,
}

fn default_limit() -> u64 {
    20
}

impl Page {
    pub fn limit(&self) -> i64 {
        self.limit
            .or(self.page_size)
            .unwrap_or_else(default_limit)
            .clamp(1, 100) as i64
    }

    pub fn offset(&self) -> i64 {
        if let Some(c) = self.cursor.as_deref() {
            if let Some(rest) = c.strip_prefix("off:") {
                if let Ok(v) = rest.parse::<u64>() {
                    return v as i64;
                }
            }
            // 非法 cursor → 从头开始（不报错，避免破坏列表可用性）
            return 0;
        }
        if let Some(p) = self.page {
            let size = self.page_size.unwrap_or_else(default_limit).clamp(1, 100);
            return ((p.max(1) - 1) * size) as i64;
        }
        0
    }

    /// 下一页 cursor；无更多数据返回 None。
    pub fn next_cursor(&self, returned: usize) -> Option<String> {
        if returned == 0 || returned < self.limit() as usize {
            return None;
        }
        Some(format!("off:{}", self.offset() + returned as i64))
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct PageMeta {
    pub limit: u64,
    pub offset: i64,
    pub returned: usize,
}

/// 统一分页响应（阶段 5.3）：{items, next_cursor}。
#[derive(Debug, Clone, Serialize)]
pub struct Paged<T> {
    pub items: Vec<T>,
    pub next_cursor: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub meta: Option<PageMeta>,
}

impl<T> Paged<T> {
    pub fn new(items: Vec<T>, page: &Page) -> Self {
        let returned = items.len();
        let next_cursor = page.next_cursor(returned);
        Self {
            items,
            next_cursor,
            meta: Some(PageMeta {
                limit: page.limit() as u64,
                offset: page.offset(),
                returned,
            }),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_limit_is_20() {
        let p = Page::default();
        assert_eq!(p.limit(), 20);
        assert_eq!(p.offset(), 0);
    }

    #[test]
    fn limit_is_clamped() {
        let p = Page {
            limit: Some(500),
            ..Default::default()
        };
        assert_eq!(p.limit(), 100);
        let p = Page {
            limit: Some(0),
            ..Default::default()
        };
        assert_eq!(p.limit(), 1);
    }

    #[test]
    fn cursor_decodes_to_offset() {
        let p = Page {
            cursor: Some("off:40".into()),
            ..Default::default()
        };
        assert_eq!(p.offset(), 40);
    }

    #[test]
    fn invalid_cursor_falls_back_to_zero() {
        let p = Page {
            cursor: Some("garbage".into()),
            ..Default::default()
        };
        assert_eq!(p.offset(), 0);
    }

    #[test]
    fn legacy_page_params_still_work() {
        let p = Page {
            page: Some(3),
            page_size: Some(10),
            ..Default::default()
        };
        assert_eq!(p.offset(), 20);
    }

    #[test]
    fn next_cursor_is_none_when_short_page() {
        let p = Page {
            limit: Some(20),
            ..Default::default()
        };
        assert_eq!(p.next_cursor(5), None);
        assert_eq!(p.next_cursor(20), Some("off:20".into()));
    }

    #[test]
    fn paged_serializes_items_and_next_cursor() {
        let p = Page {
            limit: Some(2),
            ..Default::default()
        };
        let out = Paged::new(vec![1, 2], &p);
        let v = serde_json::to_value(&out).unwrap();
        assert_eq!(v["next_cursor"], "off:2");
        assert_eq!(v["items"].as_array().unwrap().len(), 2);
    }
}
