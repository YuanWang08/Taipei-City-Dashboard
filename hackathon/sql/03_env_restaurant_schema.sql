-- ============================================================
-- 雙北環保餐廳 schema
-- ============================================================

DROP TABLE IF EXISTS env_restaurant_new_tpe CASCADE;
CREATE TABLE env_restaurant_new_tpe (
  ogc_fid       SERIAL PRIMARY KEY,
  name          VARCHAR(255),
  district      VARCHAR(50),
  address       TEXT,
  category      VARCHAR(100),       -- 餐廳類別 (環保餐廳 / 蔬食 etc.)
  phone         VARCHAR(50),
  eco_tags      TEXT,               -- 額外環保作為 (Taipei 才有，逗號分隔)
  geometry      GEOMETRY(POINT, 4326),
  geocode_src   VARCHAR(50),
  data_time     TIMESTAMP DEFAULT NOW(),
  _ctime        TIMESTAMP DEFAULT NOW(),
  _mtime        TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_er_new_tpe_geom ON env_restaurant_new_tpe USING GIST(geometry);
CREATE INDEX idx_er_new_tpe_dist ON env_restaurant_new_tpe(district);

DROP TABLE IF EXISTS env_restaurant_tpe CASCADE;
CREATE TABLE env_restaurant_tpe (LIKE env_restaurant_new_tpe INCLUDING ALL);
