-- ============================================================
-- 環保餐廳組件 (id 503)
-- ============================================================
DELETE FROM query_charts     WHERE index = 'env_restaurant';
DELETE FROM component_charts WHERE index = 'env_restaurant';
DELETE FROM component_maps   WHERE index LIKE 'env_restaurant_%';
DELETE FROM components       WHERE id = 503;
UPDATE dashboards SET components = array_remove(components, 503) WHERE id = 601;

INSERT INTO components (id, index, name) VALUES
  (503, 'env_restaurant', '雙北環保餐廳');

INSERT INTO component_charts (index, color, types, unit) VALUES
  ('env_restaurant',
   '{#27AE60}',
   '{BarChart,MapLegend}',
   '家');

-- 地圖層
INSERT INTO component_maps (index, title, type, source, paint, property) VALUES
  ('env_restaurant_tpe',
   '環保餐廳',
   'circle',
   'geojson',
   '{"circle-color":"#27AE60","circle-radius":5,"circle-stroke-width":1,"circle-stroke-color":"#fff"}'::json,
   '[{"key":"name","name":"店名"},{"key":"district","name":"行政區"},{"key":"address","name":"地址"},{"key":"phone","name":"電話"},{"key":"eco_tags","name":"環保作為"}]'::json),
  ('env_restaurant_new_tpe',
   '環保餐廳',
   'circle',
   'geojson',
   '{"circle-color":"#27AE60","circle-radius":5,"circle-stroke-width":1,"circle-stroke-color":"#fff"}'::json,
   '[{"key":"name","name":"店名"},{"key":"district","name":"行政區"},{"key":"address","name":"地址"},{"key":"phone","name":"電話"}]'::json);

-- query_charts (各區家數)
INSERT INTO query_charts (
  index, source, short_desc, long_desc, use_case,
  query_type, query_chart, query_history, city,
  time_from, links, contributors, map_config_ids,
  created_at, updated_at
) VALUES
  ('env_restaurant',
   'data.taipei',
   '臺北市環保餐廳家數（按行政區）',
   '臺北市環保局認證的環保餐廳，落實環境管理、綠色採購、惜食、源頭減量等措施。',
   '電動車充電 30 分鐘旁邊吃個友善餐廳 / 約會選店',
   'two_d',
   $$
SELECT district AS x_axis, '環保餐廳' AS y_axis, COUNT(*)::int AS data
  FROM env_restaurant_tpe
  WHERE district IS NOT NULL AND district != ''
GROUP BY district
ORDER BY 3 DESC;
   $$,
   NULL,
   'taipei',
   'static',
   '{https://data.taipei/dataset/detail?id=...}',
   '{Yuan}',
   NULL,
   NOW(), NOW()),
  ('env_restaurant',
   'data.ntpc.gov.tw',
   '新北市環保餐廳家數（按行政區）',
   '新北市環保局認證的環保餐廳。',
   '電動車充電 30 分鐘旁邊吃個友善餐廳 / 約會選店',
   'two_d',
   $$
SELECT district AS x_axis, '環保餐廳' AS y_axis, COUNT(*)::int AS data
  FROM env_restaurant_new_tpe
  WHERE district IS NOT NULL AND district != ''
GROUP BY district
ORDER BY 3 DESC;
   $$,
   NULL,
   'metrotaipei',
   'static',
   '{https://data.ntpc.gov.tw/datasets/e90d14f8-5995-4ebb-af19-8f8fd7d396c8}',
   '{Yuan}',
   NULL,
   NOW(), NOW());

-- 加進 dashboard
UPDATE dashboards
   SET components = ARRAY(SELECT DISTINCT unnest(components || ARRAY[503])),
       updated_at = NOW()
 WHERE id = 601;
