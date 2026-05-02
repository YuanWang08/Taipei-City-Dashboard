-- ============================================================
-- 行道樹 + 綠地 schema (台北聚合資料；新北目前同份待補)
-- ============================================================
DROP TABLE IF EXISTS street_tree_tpe CASCADE;
CREATE TABLE street_tree_tpe (
  ogc_fid    SERIAL PRIMARY KEY,
  district   VARCHAR(50),
  tree_count INT,
  data_time  TIMESTAMP DEFAULT NOW()
);

DROP TABLE IF EXISTS green_park_type_tpe CASCADE;
CREATE TABLE green_park_type_tpe (
  ogc_fid     SERIAL PRIMARY KEY,
  park_type   VARCHAR(50),
  area_ha     NUMERIC(10,2),
  data_time   TIMESTAMP DEFAULT NOW()
);

-- 行道樹資料 (data.taipei TaipeiTree 聚合)
INSERT INTO street_tree_tpe (district, tree_count) VALUES
  ('大安區', 14386), ('北投區', 11723), ('士林區', 10427),
  ('中山區', 9237),  ('松山區', 7973),  ('信義區', 7651),
  ('內湖區', 7548),  ('中正區', 6535),  ('南港區', 6415),
  ('文山區', 4488),  ('大同區', 3329),  ('萬華區', 3277);

-- 綠地組成 (台北市水綠地圖集)
INSERT INTO green_park_type_tpe (park_type, area_ha) VALUES
  ('公園',         1242.99),
  ('河濱公園',     485.69),
  ('公園生態化',   174.36),
  ('校園綠化',     10.84);

SELECT '行道樹' AS x, COUNT(*) AS n, SUM(tree_count) AS total_trees FROM street_tree_tpe
UNION ALL
SELECT '綠地組成', COUNT(*), SUM(area_ha)::int FROM green_park_type_tpe;
