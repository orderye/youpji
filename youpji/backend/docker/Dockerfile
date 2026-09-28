# 多阶段构建 youpji 后端：api / worker / scheduler
FROM rust:1.85-bookworm AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# 先只拷清单，利用依赖层缓存；再拷源码触发重建
COPY Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY apps ./apps
COPY migrations ./migrations

# 一次性编译三个二进制（scheduler 此前从未被编译，导致 COPY 必然失败）
RUN cargo build --release -p api -p worker -p scheduler \
    && strip target/release/api target/release/worker target/release/scheduler

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --shell /usr/sbin/nologin youpji

COPY --from=builder /app/target/release/api       /usr/local/bin/youpji-api
COPY --from=builder /app/target/release/worker    /usr/local/bin/youpji-worker
COPY --from=builder /app/target/release/scheduler /usr/local/bin/youpji-scheduler
# 迁移在编译期经 sqlx::migrate! 内嵌；此处仅供运维手工排查
COPY --from=builder /app/migrations /opt/youpji/migrations

ENV DATABASE_URL=postgres://youpji:youpji_dev@postgres:5432/youpji \
    BIND=0.0.0.0:8081 \
    RUST_LOG=info,tower_http=warn
EXPOSE 8081
USER youpji
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8081/health || exit 1

ENTRYPOINT []
CMD ["youpji-api"]
