-- 游迹 V0.1 初始 schema（DESIGN.md §4）
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 枚举
CREATE TYPE source_type AS ENUM (
  'official', 'government', 'map', 'platform', 'ugc', 'ai'
);
CREATE TYPE verification_status AS ENUM (
  'verified', 'pending', 'stale', 'disputed', 'unverified'
);
CREATE TYPE destination_level AS ENUM ('province', 'city', 'district');
CREATE TYPE itinerary_status AS ENUM (
  'draft', 'confirmed', 'active', 'completed', 'cancelled'
);
CREATE TYPE item_type AS ENUM (
  'attraction', 'meal', 'hotel', 'transit', 'free', 'activity'
);
CREATE TYPE content_topic AS ENUM (
  'route', 'ticket', 'best_time', 'photo', 'parking',
  'food', 'stay', 'pitfall', 'notice'
);

-- 通用宏式字段通过每表显式列出（避免过度抽象）

-- 用户
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(32),
  email VARCHAR(255),
  password_hash TEXT,
  display_name VARCHAR(64),
  role VARCHAR(16) NOT NULL DEFAULT 'user', -- user | admin
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (phone),
  UNIQUE (email)
);

CREATE TABLE user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  interests TEXT[] NOT NULL DEFAULT '{}',
  avoid TEXT[] NOT NULL DEFAULT '{}',
  intensity VARCHAR(16) NOT NULL DEFAULT 'medium',
  lodging_tier VARCHAR(16) NOT NULL DEFAULT 'standard',
  budget_hint INTEGER,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE travel_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scores JSONB NOT NULL DEFAULT '{}'::jsonb,
  pace VARCHAR(16) NOT NULL DEFAULT 'medium',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

CREATE TABLE favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  entity_type VARCHAR(32) NOT NULL,
  entity_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, entity_type, entity_id)
);

CREATE TABLE user_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  itinerary_id UUID,
  rating SMALLINT,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 目的地
CREATE TABLE destinations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID REFERENCES destinations(id),
  name VARCHAR(128) NOT NULL,
  level destination_level NOT NULL,
  full_path VARCHAR(512),
  longitude DOUBLE PRECISION,
  latitude DOUBLE PRECISION,
  source_type source_type NOT NULL DEFAULT 'government',
  source_url TEXT,
  source_time TIMESTAMPTZ,
  last_verified TIMESTAMPTZ,
  verification_status verification_status NOT NULL DEFAULT 'unverified',
  confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_destinations_parent ON destinations(parent_id);
CREATE INDEX idx_destinations_name_trgm ON destinations USING gin (name gin_trgm_ops);

-- 景区
CREATE TABLE attractions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  destination_id UUID REFERENCES destinations(id),
  name VARCHAR(128) NOT NULL,
  alias VARCHAR(255),
  province VARCHAR(64) NOT NULL DEFAULT '贵州',
  city VARCHAR(64),
  district VARCHAR(64),
  longitude DOUBLE PRECISION NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  coord_sys VARCHAR(16) NOT NULL DEFAULT 'gcj02',
  category VARCHAR(64),
  level VARCHAR(16),
  description TEXT,
  opening_time TIME,
  closing_time TIME,
  ticket_price INTEGER,
  discount_info TEXT,
  recommended_duration_min INTEGER,
  best_season TEXT[],
  difficulty SMALLINT,
  family_score SMALLINT NOT NULL DEFAULT 50,
  elderly_score SMALLINT NOT NULL DEFAULT 50,
  photography_score SMALLINT NOT NULL DEFAULT 50,
  couple_score SMALLINT NOT NULL DEFAULT 50,
  parking TEXT,
  transport TEXT,
  indoor BOOLEAN NOT NULL DEFAULT false,
  popularity INTEGER NOT NULL DEFAULT 50,
  source_type source_type NOT NULL DEFAULT 'official',
  source_url TEXT,
  source_time TIMESTAMPTZ,
  last_verified TIMESTAMPTZ,
  verification_status verification_status NOT NULL DEFAULT 'unverified',
  confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  geog geography(Point, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  ) STORED
);

CREATE INDEX idx_attractions_dest ON attractions(destination_id);
CREATE INDEX idx_attractions_city ON attractions(city);
CREATE INDEX idx_attractions_geog ON attractions USING gist (geog);
CREATE INDEX idx_attractions_name_trgm ON attractions USING gin (name gin_trgm_ops);
CREATE INDEX idx_attractions_category ON attractions(category);

-- 受控标签词表
CREATE TABLE tag_vocab (
  key VARCHAR(32) PRIMARY KEY,
  label VARCHAR(64) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE attraction_tags (
  attraction_id UUID NOT NULL REFERENCES attractions(id) ON DELETE CASCADE,
  tag_key VARCHAR(32) NOT NULL REFERENCES tag_vocab(key),
  score SMALLINT NOT NULL CHECK (score BETWEEN 0 AND 100),
  PRIMARY KEY (attraction_id, tag_key)
);

CREATE TABLE attraction_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attraction_id UUID NOT NULL REFERENCES attractions(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  alt TEXT,
  sort SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE attraction_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attraction_id UUID NOT NULL REFERENCES attractions(id) ON DELETE CASCADE,
  weekday SMALLINT, -- 0-6, null=每天
  season VARCHAR(32),
  open_time TIME NOT NULL,
  close_time TIME NOT NULL,
  note TEXT,
  source_type source_type NOT NULL DEFAULT 'official',
  last_verified TIMESTAMPTZ,
  verification_status verification_status NOT NULL DEFAULT 'unverified'
);

CREATE TABLE attraction_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attraction_id UUID NOT NULL REFERENCES attractions(id) ON DELETE CASCADE,
  name VARCHAR(64) NOT NULL,
  price INTEGER NOT NULL,
  currency VARCHAR(8) NOT NULL DEFAULT 'CNY',
  eligibility TEXT,
  source_type source_type NOT NULL DEFAULT 'official',
  last_verified TIMESTAMPTZ,
  verification_status verification_status NOT NULL DEFAULT 'unverified',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE attraction_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attraction_id UUID NOT NULL REFERENCES attractions(id) ON DELETE CASCADE,
  name VARCHAR(128) NOT NULL,
  waypoints JSONB NOT NULL DEFAULT '[]'::jsonb,
  difficulty SMALLINT,
  duration_min INTEGER,
  note TEXT
);

-- 酒店
CREATE TABLE hotels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  destination_id UUID REFERENCES destinations(id),
  name VARCHAR(128) NOT NULL,
  brand VARCHAR(64),
  address TEXT,
  longitude DOUBLE PRECISION,
  latitude DOUBLE PRECISION,
  coord_sys VARCHAR(16) NOT NULL DEFAULT 'gcj02',
  price_min INTEGER,
  price_max INTEGER,
  rating DECIMAL(2,1),
  room_types TEXT[],
  facilities TEXT[],
  parking BOOLEAN NOT NULL DEFAULT false,
  breakfast BOOLEAN NOT NULL DEFAULT false,
  family_friendly BOOLEAN NOT NULL DEFAULT false,
  couple_friendly BOOLEAN NOT NULL DEFAULT false,
  booking_url TEXT,
  city VARCHAR(64),
  district VARCHAR(64),
  source_type source_type NOT NULL DEFAULT 'platform',
  source_url TEXT,
  last_verified TIMESTAMPTZ,
  verification_status verification_status NOT NULL DEFAULT 'unverified',
  confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  geog geography(Point, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  ) STORED
);

CREATE INDEX idx_hotels_geog ON hotels USING gist (geog);
CREATE INDEX idx_hotels_city ON hotels(city);

-- 餐厅
CREATE TABLE restaurants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  destination_id UUID REFERENCES destinations(id),
  name VARCHAR(128) NOT NULL,
  category VARCHAR(64),
  province VARCHAR(64) DEFAULT '贵州',
  city VARCHAR(64),
  district VARCHAR(64),
  longitude DOUBLE PRECISION,
  latitude DOUBLE PRECISION,
  coord_sys VARCHAR(16) NOT NULL DEFAULT 'gcj02',
  price_per_person INTEGER,
  rating DECIMAL(2,1),
  signature_dishes TEXT[],
  opening_hours TEXT,
  parking BOOLEAN NOT NULL DEFAULT false,
  family_friendly BOOLEAN NOT NULL DEFAULT false,
  local_specialty BOOLEAN NOT NULL DEFAULT false,
  source_type source_type NOT NULL DEFAULT 'platform',
  source_url TEXT,
  last_verified TIMESTAMPTZ,
  verification_status verification_status NOT NULL DEFAULT 'unverified',
  confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  geog geography(Point, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  ) STORED
);

CREATE INDEX idx_restaurants_geog ON restaurants USING gist (geog);
CREATE INDEX idx_restaurants_city ON restaurants(city);

CREATE TABLE restaurant_dishes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  name VARCHAR(128) NOT NULL,
  price INTEGER,
  note TEXT
);

-- 交通
CREATE TABLE transportation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  origin VARCHAR(128) NOT NULL,
  destination VARCHAR(128) NOT NULL,
  mode VARCHAR(32) NOT NULL,
  duration_min INTEGER,
  distance_km DOUBLE PRECISION,
  price INTEGER,
  note TEXT,
  source_type source_type NOT NULL DEFAULT 'map',
  last_verified TIMESTAMPTZ,
  verification_status verification_status NOT NULL DEFAULT 'unverified'
);

-- 攻略
CREATE TABLE travel_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_type source_type NOT NULL,
  name VARCHAR(128) NOT NULL,
  url TEXT,
  trust_tier SMALLINT NOT NULL DEFAULT 3, -- 1..4
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE travel_contents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id UUID REFERENCES travel_sources(id),
  attraction_id UUID REFERENCES attractions(id) ON DELETE SET NULL,
  title VARCHAR(255) NOT NULL,
  summary TEXT NOT NULL,
  topic content_topic,
  language VARCHAR(16) NOT NULL DEFAULT 'zh-CN',
  source_url TEXT,
  source_time TIMESTAMPTZ,
  last_verified TIMESTAMPTZ,
  verification_status verification_status NOT NULL DEFAULT 'unverified',
  confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contents_attraction ON travel_contents(attraction_id);
CREATE INDEX idx_contents_topic ON travel_contents(topic);

CREATE TABLE travel_content_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id UUID NOT NULL REFERENCES travel_contents(id) ON DELETE CASCADE,
  chunk_index INTEGER NOT NULL,
  text TEXT NOT NULL,
  embedding vector(384),
  UNIQUE (content_id, chunk_index)
);

CREATE INDEX idx_chunks_embedding ON travel_content_chunks
  USING hnsw (embedding vector_cosine_ops);

-- 天气（按城市日粒度）
CREATE TABLE weather (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  city VARCHAR(64) NOT NULL,
  date DATE NOT NULL,
  temp_min SMALLINT,
  temp_max SMALLINT,
  precip_prob SMALLINT,
  description TEXT,
  raw JSONB,
  source_type source_type NOT NULL DEFAULT 'map',
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (city, date)
);

-- 行程
CREATE TABLE itineraries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  title VARCHAR(255) NOT NULL,
  origin VARCHAR(128),
  destination VARCHAR(128),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  people SMALLINT NOT NULL DEFAULT 2,
  budget_limit INTEGER,
  transport VARCHAR(32) NOT NULL DEFAULT 'self_drive',
  interests TEXT[] NOT NULL DEFAULT '{}',
  avoid TEXT[] NOT NULL DEFAULT '{}',
  intensity VARCHAR(16) NOT NULL DEFAULT 'medium',
  mode VARCHAR(16) NOT NULL DEFAULT 'standard',
  lodging_tier VARCHAR(16) NOT NULL DEFAULT 'standard',
  status itinerary_status NOT NULL DEFAULT 'draft',
  summary JSONB NOT NULL DEFAULT '{}'::jsonb,
  budget JSONB NOT NULL DEFAULT '{}'::jsonb,
  warnings JSONB NOT NULL DEFAULT '[]'::jsonb,
  natural_input TEXT,
  algo_version VARCHAR(32),
  schema_version VARCHAR(16) NOT NULL DEFAULT 'v1',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_itineraries_user ON itineraries(user_id);

CREATE TABLE itinerary_days (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  itinerary_id UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
  day_index SMALLINT NOT NULL,
  date DATE NOT NULL,
  title VARCHAR(255),
  note TEXT,
  UNIQUE (itinerary_id, day_index)
);

CREATE TABLE itinerary_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  day_id UUID NOT NULL REFERENCES itinerary_days(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL,
  item_type item_type NOT NULL,
  start_time TIME,
  end_time TIME,
  title VARCHAR(255) NOT NULL,
  location VARCHAR(255),
  longitude DOUBLE PRECISION,
  latitude DOUBLE PRECISION,
  ref_id UUID,
  distance_km DOUBLE PRECISION,
  duration_min INTEGER,
  cost INTEGER NOT NULL DEFAULT 0,
  reason TEXT,
  notice TEXT,
  meta JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (day_id, sort_order)
);

CREATE TABLE route_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  itinerary_id UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
  algo_version VARCHAR(32) NOT NULL,
  candidates JSONB NOT NULL DEFAULT '[]'::jsonb,
  score_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  matrix_cache_key TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 数据审核
CREATE TABLE data_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(32) NOT NULL,
  entity_id UUID NOT NULL,
  field VARCHAR(64),
  proposed JSONB NOT NULL,
  current JSONB,
  source_type source_type NOT NULL,
  source_url TEXT,
  status verification_status NOT NULL DEFAULT 'pending',
  reviewer_id UUID REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_reviews_status ON data_reviews(status);
