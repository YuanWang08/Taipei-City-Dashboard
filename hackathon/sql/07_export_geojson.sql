-- 把 6 張地理表匯出成 GeoJSON FeatureCollection
-- 用法：
--   docker exec postgres-data psql -U postgres -d dashboard \
--     -t -A -f /tmp/07_export_geojson.sql > FE/public/mapData/<table>.geojson

\pset format unaligned
\pset tuples_only on

-- 充電樁汽車（新北）
\o /tmp/ev_charging_car_new_tpe.geojson
SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', COALESCE(json_agg(
    json_build_object(
      'type', 'Feature',
      'geometry', ST_AsGeoJSON(geometry)::json,
      'properties', json_build_object(
        'station_name', station_name,
        'district',     district,
        'address',      address,
        'category',     category,
        'socket_type',  socket_type,
        'plug_count',   plug_count,
        'fee',          fee
      )
    )
  ), '[]'::json)
) FROM charging_station_car_new_tpe WHERE geometry IS NOT NULL;

-- 充電樁機車（新北）
\o /tmp/ev_charging_motor_new_tpe.geojson
SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', COALESCE(json_agg(
    json_build_object(
      'type', 'Feature',
      'geometry', ST_AsGeoJSON(geometry)::json,
      'properties', json_build_object(
        'station_name', station_name,
        'district',     district,
        'address',      address,
        'category',     category,
        'plug_type',    plug_type,
        'plug_count',   plug_count
      )
    )
  ), '[]'::json)
) FROM charging_station_motor_new_tpe WHERE geometry IS NOT NULL;

-- 充電樁汽車（台北 - 暫無資料）
\o /tmp/ev_charging_car_tpe.geojson
SELECT json_build_object('type', 'FeatureCollection', 'features', '[]'::json);

-- 充電樁機車（台北 - 暫無資料）
\o /tmp/ev_charging_motor_tpe.geojson
SELECT json_build_object('type', 'FeatureCollection', 'features', '[]'::json);

-- 環保餐廳（台北）
\o /tmp/env_restaurant_tpe.geojson
SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', COALESCE(json_agg(
    json_build_object(
      'type', 'Feature',
      'geometry', ST_AsGeoJSON(geometry)::json,
      'properties', json_build_object(
        'name',     name,
        'district', district,
        'address',  address,
        'category', category,
        'phone',    phone,
        'eco_tags', eco_tags
      )
    )
  ), '[]'::json)
) FROM env_restaurant_tpe WHERE geometry IS NOT NULL;

-- 環保餐廳（新北）
\o /tmp/env_restaurant_new_tpe.geojson
SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', COALESCE(json_agg(
    json_build_object(
      'type', 'Feature',
      'geometry', ST_AsGeoJSON(geometry)::json,
      'properties', json_build_object(
        'name',     name,
        'district', district,
        'address',  address,
        'category', category,
        'phone',    phone
      )
    )
  ), '[]'::json)
) FROM env_restaurant_new_tpe WHERE geometry IS NOT NULL;

\o
