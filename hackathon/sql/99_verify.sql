-- 跑在 dashboard DB，檢查 ETL 結果
\echo '=== 各表筆數 ==='
SELECT 'car_new_tpe' AS tbl, COUNT(*) FROM charging_station_car_new_tpe
UNION ALL SELECT 'motor_new_tpe', COUNT(*) FROM charging_station_motor_new_tpe
UNION ALL SELECT 'car_tpe', COUNT(*) FROM charging_station_car_tpe
UNION ALL SELECT 'motor_tpe', COUNT(*) FROM charging_station_motor_tpe;

\echo ''
\echo '=== Geocode 來源分布（汽車 NTPC）==='
SELECT geocode_src, COUNT(*) FROM charging_station_car_new_tpe GROUP BY geocode_src;

\echo ''
\echo '=== 各區站數（汽車 NTPC）==='
SELECT district, COUNT(*) cnt
FROM charging_station_car_new_tpe
GROUP BY district ORDER BY cnt DESC LIMIT 10;

\echo ''
\echo '=== 5 筆 sample（驗座標）==='
SELECT station_name,
       district,
       address,
       ROUND(ST_Y(geometry)::numeric, 5) AS lat,
       ROUND(ST_X(geometry)::numeric, 5) AS lng,
       geocode_src
FROM charging_station_car_new_tpe
WHERE geocode_src = 'nominatim'
LIMIT 5;
