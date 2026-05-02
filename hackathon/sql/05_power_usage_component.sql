-- ============================================================
-- 用電結構組件 (id 502)
-- ============================================================

DELETE FROM query_charts     WHERE index = 'power_usage_ratio';
DELETE FROM component_charts WHERE index = 'power_usage_ratio';
DELETE FROM components       WHERE id = 502;
UPDATE dashboards SET components = array_remove(components, 502) WHERE id = 601;

INSERT INTO components (id, index, name) VALUES
  (502, 'power_usage_ratio', '雙北用電結構（住宅 / 服務業 / 工業）');

INSERT INTO component_charts (index, color, types, unit) VALUES
  ('power_usage_ratio',
   '{#3498DB,#27AE60,#F39C12,#E74C3C,#95A5A6}',
   '{DonutChart,BarPercentChart}',
   '%');

INSERT INTO query_charts (
  index, source, short_desc, long_desc, use_case,
  query_type, query_chart, query_history, city,
  update_freq, update_freq_unit,
  links, contributors, map_config_ids,
  created_at, updated_at
) VALUES
  ('power_usage_ratio',
   '台電 d007019',
   '雙北最新年度用電結構（住宅 / 服務業 / 機關 / 工業 / 其他）',
   '台電依縣市發布的年度用電性質比例，可看出城市產業結構：商業大城（服務業高）vs 住商工平衡（住宅+工業偏高）。',
   '居民查自己城市用電結構 / 想搬家比較雙北 / 政策評估',
   'two_d',
   $$
SELECT usage_type AS x_axis, '台北市' AS y_axis, ratio AS data
FROM power_usage_ratio_tpe
WHERE year = (SELECT MAX(year) FROM power_usage_ratio_tpe)
ORDER BY data DESC;
   $$,
   NULL,
   'taipei',
   1, 'year',
   '{https://data.gov.tw/dataset/38959}',
   '{Yuan}',
   NULL,
   NOW(), NOW()),
  ('power_usage_ratio',
   '台電 d007019',
   '雙北最新年度用電結構（住宅 / 服務業 / 機關 / 工業 / 其他）',
   '台電依縣市發布的年度用電性質比例，可看出城市產業結構：商業大城（服務業高）vs 住商工平衡（住宅+工業偏高）。',
   '居民查自己城市用電結構 / 想搬家比較雙北 / 政策評估',
   'two_d',
   $$
SELECT usage_type AS x_axis, '新北市' AS y_axis, ratio AS data
FROM power_usage_ratio_new_tpe
WHERE year = (SELECT MAX(year) FROM power_usage_ratio_new_tpe)
ORDER BY data DESC;
   $$,
   NULL,
   'metrotaipei',
   1, 'year',
   '{https://data.gov.tw/dataset/38959}',
   '{Yuan}',
   NULL,
   NOW(), NOW());

-- 加進 dashboard
UPDATE dashboards
   SET components = ARRAY(SELECT DISTINCT unnest(components || ARRAY[502])),
       updated_at = NOW()
 WHERE id = 601;
