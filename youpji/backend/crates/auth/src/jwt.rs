//! 标准 JWT（阶段 5.1 HS256）：{sub: user_uuid, role, iat, exp}。
//!
//! 说明：为避免新增外部依赖，手写 HS256/base64url（纯 std 实现），
//! JWT_SECRET 为空时拒绝签发。
use common::error::{ApiError, ApiResult};
use common::state::AppState;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct JwtClaims {
    sub: String,
    role: String,
    iat: i64,
    exp: i64,
}

pub fn issue_token(state: &AppState, user: &super::UserRow) -> ApiResult<String> {
    let secret = state.config.jwt_secret.trim();
    if secret.is_empty() {
        return Err(ApiError::Internal("JWT_SECRET is not configured".into()));
    }
    if secret == "dev-secret-change-me" {
        tracing::warn!("JWT_SECRET is default; set a real secret for non-dev use");
    }
    let now = chrono::Utc::now().timestamp();
    let claims = JwtClaims {
        sub: user.id.to_string(),
        role: user.role.clone(),
        iat: now,
        exp: now + 7 * 24 * 3600,
    };
    let header = base64url(b"{\"alg\":\"HS256\",\"typ\":\"JWT\"}");
    let payload = base64url(
        serde_json::to_string(&claims)
            .unwrap_or_default()
            .as_bytes(),
    );
    let sig = base64url(&hmac_sha256(
        secret.as_bytes(),
        format!("{header}.{payload}").as_bytes(),
    ));
    Ok(format!("{header}.{payload}.{sig}"))
}

/// 校验 JWT 并返回 (user_id, role)。
pub fn parse_token_secret(secret: &str, token: &str) -> ApiResult<(Uuid, String)> {
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 {
        return Err(ApiError::Unauthorized("bad token".into()));
    }
    let expect = base64url(&hmac_sha256(
        secret.as_bytes(),
        format!("{}.{}", parts[0], parts[1]).as_bytes(),
    ));
    if !constant_time_eq(&expect, parts[2]) {
        return Err(ApiError::Unauthorized("bad token signature".into()));
    }
    let payload = base64url_decode(parts[1])
        .map_err(|_| ApiError::Unauthorized("bad token payload".into()))?;
    let claims: JwtClaims = serde_json::from_slice(&payload)
        .map_err(|_| ApiError::Unauthorized("bad token claims".into()))?;
    let now = chrono::Utc::now().timestamp();
    if claims.exp < now {
        return Err(ApiError::Unauthorized("token expired".into()));
    }
    let id =
        Uuid::parse_str(&claims.sub).map_err(|_| ApiError::Unauthorized("bad token id".into()))?;
    Ok((id, claims.role))
}

pub(crate) fn base64url(input: &[u8]) -> String {
    const ALPHA: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    let mut out = String::new();
    for chunk in input.chunks(3) {
        let mut n: u32 = 0;
        for (i, b) in chunk.iter().enumerate() {
            n |= (*b as u32) << (16 - 8 * i);
        }
        let pad = 3 - chunk.len();
        for i in 0..(4 - pad) {
            let idx = ((n >> (18 - 6 * i)) & 63) as usize;
            out.push(ALPHA[idx] as char);
        }
    }
    out
}

pub(crate) fn base64url_decode(input: &str) -> Result<Vec<u8>, ()> {
    fn val(c: u8) -> Result<u32, ()> {
        match c {
            b'A'..=b'Z' => Ok((c - b'A') as u32),
            b'a'..=b'z' => Ok((c - b'a' + 26) as u32),
            b'0'..=b'9' => Ok((c - b'0' + 52) as u32),
            b'-' => Ok(62),
            b'_' => Ok(63),
            _ => Err(()),
        }
    }
    let bytes = input.as_bytes();
    if bytes.len() % 4 == 1 {
        return Err(());
    }
    let mut out = Vec::new();
    for chunk in bytes.chunks(4) {
        let mut n: u32 = 0;
        let mut count = 0;
        for b in chunk {
            n = (n << 6) | val(*b)?;
            count += 1;
        }
        let pad = 4 - count;
        n <<= 6 * pad;
        out.push(((n >> 16) & 0xff) as u8);
        if count > 2 {
            out.push(((n >> 8) & 0xff) as u8);
        }
        if count > 3 {
            out.push((n & 0xff) as u8);
        }
    }
    Ok(out)
}

fn constant_time_eq(a: &str, b: &str) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut diff = 0u8;
    for (x, y) in a.bytes().zip(b.bytes()) {
        diff |= x ^ y;
    }
    diff == 0
}

/// SHA-256（FIPS 180-4，纯 std 实现，仅用于开发期 JWT 签名）。
pub(crate) fn sha256(data: &[u8]) -> [u8; 32] {
    const K: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
        0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
        0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
        0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
        0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
        0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
        0xc67178f2,
    ];
    let mut h: [u32; 8] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
        0x5be0cd19,
    ];
    let mut msg = data.to_vec();
    let bit_len = (data.len() as u64).wrapping_mul(8);
    msg.push(0x80);
    while msg.len() % 64 != 56 {
        msg.push(0);
    }
    msg.extend_from_slice(&bit_len.to_be_bytes());
    for block in msg.chunks(64) {
        let mut w = [0u32; 64];
        for i in 0..16 {
            w[i] = u32::from_be_bytes([
                block[4 * i],
                block[4 * i + 1],
                block[4 * i + 2],
                block[4 * i + 3],
            ]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16]
                .wrapping_add(s0)
                .wrapping_add(w[i - 7])
                .wrapping_add(s1);
        }
        let (mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut hh) =
            (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]);
        for i in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let t1 = hh
                .wrapping_add(s1)
                .wrapping_add(ch)
                .wrapping_add(K[i])
                .wrapping_add(w[i]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let t2 = s0.wrapping_add(maj);
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = b;
            b = a;
            a = t1.wrapping_add(t2);
        }
        h[0] = h[0].wrapping_add(a);
        h[1] = h[1].wrapping_add(b);
        h[2] = h[2].wrapping_add(c);
        h[3] = h[3].wrapping_add(d);
        h[4] = h[4].wrapping_add(e);
        h[5] = h[5].wrapping_add(f);
        h[6] = h[6].wrapping_add(g);
        h[7] = h[7].wrapping_add(hh);
    }
    let mut out = [0u8; 32];
    for (i, v) in h.iter().enumerate() {
        out[4 * i..4 * i + 4].copy_from_slice(&v.to_be_bytes());
    }
    out
}

pub(crate) fn hmac_sha256(key: &[u8], data: &[u8]) -> [u8; 32] {
    let mut k = [0u8; 64];
    if key.len() > 64 {
        let h = sha256(key);
        k[..32].copy_from_slice(&h);
    } else {
        k[..key.len()].copy_from_slice(key);
    }
    let mut ipad = [0x36u8; 64];
    let mut opad = [0x5cu8; 64];
    for i in 0..64 {
        ipad[i] ^= k[i];
        opad[i] ^= k[i];
    }
    let mut inner = ipad.to_vec();
    inner.extend_from_slice(data);
    let inner_hash = sha256(&inner);
    let mut outer = opad.to_vec();
    outer.extend_from_slice(&inner_hash);
    sha256(&outer)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sha256_matches_known_vector() {
        let h = sha256(b"abc");
        let hex: String = h.iter().map(|b| format!("{b:02x}")).collect();
        assert_eq!(
            hex,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn base64url_roundtrip() {
        for s in ["hello", "ab", "a", "user-uuid-1234", "{\"alg\":\"HS256\"}"] {
            let enc = base64url(s.as_bytes());
            assert!(!enc.contains('+') && !enc.contains('/') && !enc.contains('='));
            assert_eq!(base64url_decode(&enc).unwrap(), s.as_bytes());
        }
    }

    #[test]
    fn tampered_signature_fails() {
        let secret = "test-secret";
        let claims = JwtClaims {
            sub: "11111111-1111-1111-1111-111111111111".into(),
            role: "user".into(),
            iat: 1_700_000_000,
            exp: 9_999_999_999,
        };
        let header = base64url(b"{\"alg\":\"HS256\",\"typ\":\"JWT\"}");
        let payload = base64url(serde_json::to_string(&claims).unwrap().as_bytes());
        let sig = base64url(&hmac_sha256(
            secret.as_bytes(),
            format!("{header}.{payload}").as_bytes(),
        ));
        let good = format!("{header}.{payload}.{sig}");
        let (id, role) = parse_token_secret(secret, &good).unwrap();
        assert_eq!(role, "user");
        assert_eq!(id.to_string(), "11111111-1111-1111-1111-111111111111");
        let bad = format!("{header}.{payload}.AAAA");
        assert!(parse_token_secret(secret, &bad).is_err());
        assert!(parse_token_secret("wrong", &good).is_err());
    }
}
