-- 雙北用電比例 schema
DROP TABLE IF EXISTS power_usage_ratio_new_tpe CASCADE;
CREATE TABLE power_usage_ratio_new_tpe (
  ogc_fid     SERIAL PRIMARY KEY,
  year        INT,
  usage_type  VARCHAR(50),
  ratio       NUMERIC(5,2),
  data_time   TIMESTAMP DEFAULT NOW(),
  _ctime      TIMESTAMP DEFAULT NOW(),
  _mtime      TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_pur_new_tpe_year ON power_usage_ratio_new_tpe(year);

DROP TABLE IF EXISTS power_usage_ratio_tpe CASCADE;
CREATE TABLE power_usage_ratio_tpe (LIKE power_usage_ratio_new_tpe INCLUDING ALL);
