-- ============================================================
-- 行道樹 + 綠地組件 (id 504, 505)
-- ============================================================
DELETE FROM query_charts     WHERE index IN ('street_tree_dist','green_park_type');
DELETE FROM component_charts WHERE index IN ('street_tree_dist','green_park_type');
DELETE FROM components       WHERE id IN (504, 505);
UPDATE dashboards SET components = array_remove(components, 504) WHERE id = 601;
UPDATE dashboards SET components = array_remove(components, 505) WHERE id = 601;

-- 1. 行道樹組件
INSERT INTO components (id, index, name) VALUES
  (504, 'street_tree_dist', '台北行道樹分布（各區）');

INSERT INTO component_charts (index, color, types, unit) VALUES
  ('street_tree_dist', '{#27AE60}', '{BarChart}', '棵');

INSERT INTO query_charts (
  index, source, short_desc, long_desc, use_case,
  query_type, query_chart, city, time_from,
  links, contributors, created_at, updated_at
) VALUES
  ('street_tree_dist',
   'data.taipei',
   '台北市各區行道樹數量',
   '台北市各行政區行道樹分布。資料來自台北市工務局 TaipeiTree 開放資料聚合。行道樹多代表林蔭密度高、夏季散步較涼爽。',
   '夏天找有遮蔭的散步路線 / 評估各區城市綠化程度',
   'two_d',
   'SELECT district AS x_axis, ''行道樹'' AS y_axis, tree_count AS data FROM street_tree_tpe ORDER BY data DESC;',
   'taipei', 'static',
   '{https://data.taipei/dataset/detail?id=7a49d00c-a5ff-4a6b-be9e-aaa6dc1ff7e8}',
   '{doit}',
   NOW(), NOW()),
  ('street_tree_dist',
   'data.taipei',
   '台北市各區行道樹數量',
   '台北市各行政區行道樹分布（新北資料目前未公開於 data.ntpc）',
   '夏天找有遮蔭的散步路線 / 評估各區城市綠化程度',
   'two_d',
   'SELECT district AS x_axis, ''行道樹'' AS y_axis, tree_count AS data FROM street_tree_tpe ORDER BY data DESC;',
   'metrotaipei', 'static',
   '{https://data.taipei/dataset/detail?id=7a49d00c-a5ff-4a6b-be9e-aaa6dc1ff7e8}',
   '{doit}',
   NOW(), NOW());

-- 2. 綠地組成組件
INSERT INTO components (id, index, name) VALUES
  (505, 'green_park_type', '台北綠地組成（公頃）');

INSERT INTO component_charts (index, color, types, unit) VALUES
  ('green_park_type', '{#27AE60,#3498DB,#F39C12,#E67E22}', '{DonutChart}', '公頃');

INSERT INTO query_charts (
  index, source, short_desc, long_desc, use_case,
  query_type, query_chart, city, time_from,
  links, contributors, created_at, updated_at
) VALUES
  ('green_park_type',
   'data.taipei',
   '台北市綠地組成（按類型分）',
   '台北市水綠地圖集統計。公園 1243 公頃 + 河濱 486 + 生態化 174 + 校園 11 = 總計 1914 公頃。',
   '評估城市綠化結構 / 規劃散步去處（河濱適合長走、生態園適合親子）',
   'two_d',
   'SELECT park_type AS x_axis, ''綠地'' AS y_axis, area_ha AS data FROM green_park_type_tpe ORDER BY data DESC;',
   'taipei', 'static',
   '{https://data.taipei/dataset/detail?id=5b277432-f534-4d09-a24c-d3f6b514e042}',
   '{doit}',
   NOW(), NOW()),
  ('green_park_type',
   'data.taipei',
   '台北市綠地組成（按類型分）',
   '台北市水綠地圖集統計（新北資料尚未整合）',
   '評估城市綠化結構 / 規劃散步去處',
   'two_d',
   'SELECT park_type AS x_axis, ''綠地'' AS y_axis, area_ha AS data FROM green_park_type_tpe ORDER BY data DESC;',
   'metrotaipei', 'static',
   '{https://data.taipei/dataset/detail?id=5b277432-f534-4d09-a24c-d3f6b514e042}',
   '{doit}',
   NOW(), NOW());

-- 加進 dashboard
UPDATE dashboards
   SET components = ARRAY(SELECT DISTINCT unnest(components || ARRAY[504, 505])),
       updated_at = NOW()
 WHERE id = 601;
