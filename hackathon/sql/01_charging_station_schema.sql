-- ============================================================
-- 雙北充電樁 schema
-- 4 張表：汽車/機車 × 雙北
-- ============================================================

-- New Taipei (新北) ----------------------------------
DROP TABLE IF EXISTS charging_station_car_new_tpe CASCADE;
CREATE TABLE charging_station_car_new_tpe (
  ogc_fid       SERIAL PRIMARY KEY,
  station_name  VARCHAR(255),
  district      VARCHAR(50),
  address       TEXT,
  category      VARCHAR(100),       -- 公務機關-其他 / 公有停車場 ...
  fee           VARCHAR(10),        -- Y / N
  socket_type   VARCHAR(50),        -- 80A / 16A ...
  plug_count    INT,
  geometry      GEOMETRY(POINT, 4326),
  geocode_src   VARCHAR(50),        -- nominatim / failed
  data_time     TIMESTAMP DEFAULT NOW(),
  _ctime        TIMESTAMP DEFAULT NOW(),
  _mtime        TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_csc_new_tpe_geom ON charging_station_car_new_tpe USING GIST(geometry);
CREATE INDEX idx_csc_new_tpe_dist ON charging_station_car_new_tpe(district);

DROP TABLE IF EXISTS charging_station_motor_new_tpe CASCADE;
CREATE TABLE charging_station_motor_new_tpe (
  ogc_fid       SERIAL PRIMARY KEY,
  station_name  VARCHAR(255),
  district      VARCHAR(50),
  address       TEXT,
  category      VARCHAR(100),       -- 社區大樓 / 公有停車場 ...
  status        VARCHAR(50),        -- 良好 / 維修中
  fee           VARCHAR(10),
  open_public   VARCHAR(10),        -- Y / N
  plug_type     VARCHAR(50),        -- 充電箱 / 充電柱
  plug_count    INT,
  geometry      GEOMETRY(POINT, 4326),
  geocode_src   VARCHAR(50),
  data_time     TIMESTAMP DEFAULT NOW(),
  _ctime        TIMESTAMP DEFAULT NOW(),
  _mtime        TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_csm_new_tpe_geom ON charging_station_motor_new_tpe USING GIST(geometry);
CREATE INDEX idx_csm_new_tpe_dist ON charging_station_motor_new_tpe(district);

-- Taipei (臺北) ----------------------------------
-- 同 schema 結構，餵 Taipei 資料
DROP TABLE IF EXISTS charging_station_car_tpe CASCADE;
CREATE TABLE charging_station_car_tpe (LIKE charging_station_car_new_tpe INCLUDING ALL);

DROP TABLE IF EXISTS charging_station_motor_tpe CASCADE;
CREATE TABLE charging_station_motor_tpe (LIKE charging_station_motor_new_tpe INCLUDING ALL);

-- ============================================================
-- 完成檢核
-- SELECT table_name FROM information_schema.tables
-- WHERE table_name LIKE 'charging_station%';
-- ============================================================
