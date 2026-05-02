# 提案 3：都市熱島避難地圖

> 2026 雙北程式設計節 城市儀表板大黑客松 提案規劃
> 主題分類：03 永續環境

---

## 1. 故事與目標使用者

**一句話故事**：
> 雙北夏天 38 度的高溫日越來越多，但你家那一里有地方可以乘涼嗎？這個儀表板把涼適點、公園綠地、行道樹、即時空品疊起來，找出最沒有避暑資源的「熱島脆弱里」。

**主要使用者**：
- 政府：民政局（涼適點推廣）、公園處（綠地配置）、環保局（熱島政策）
- 民眾：高齡者家屬、戶外工作者、家長帶小孩

**現有 dashboard 缺什麼**：
涼適點（cooling_point）、公園綠地（D050303_1）、行道樹（D050201）、即時空品（D050502）四份資料目前各自獨立。**沒有任何組件做「人均綠地 × 涼適點密度 × 空品」的綜合居住舒適度排名**——這正是本提案要補的位。

**為什麼這題政治正確**：氣候變遷是 2026 政策熱點，民眾有感（夏天越來越熱）、評審容易共鳴。

---

## 2. 四個組件設計

### 組件 1（地圖層）：熱島避難地圖
- **圖表類型**：Map（Choropleth + 多 layer）+ MapLegend
- **顯示內容**：
  - 行政區染色（Choropleth）：人均綠地面積（紅 = 缺乏，綠 = 充足）
  - 藍色點位：涼適點分布（cooling_point）
  - 綠色線條：行道樹密集路段（D050201）
  - 圓圈：空品測站即時 AQI（D050502，圈大小代表 AQI）
  - **點擊行政區 → popup 顯示「人均綠地、涼適點數、行道樹密度、平均 AQI」**
- **Taipei 資料源**：
  - cooling_point 涼適點（民政局，data.taipei）
  - D050303_1 公園綠地（工務局，data.taipei）
  - D050201 行道樹分布圖（工務局，data.taipei）
  - D050502 空氣品質每小時（環境部，全國資料）
- **NTPC 資料源**（要驗證）：
  - 新北市涼適點 / 涼夏專案點位（data.ntpc.gov.tw 民政局）
  - 新北市公園綠地（data.ntpc.gov.tw 城鄉局或景觀處）
  - 新北市行道樹（data.ntpc.gov.tw 養工處）
  - 環境部空品（同 D050502，全國資料）
- **互動**：圖層切換 ON/OFF、行政區點擊查詳細

### 組件 2：行政區熱島脆弱度排行
- **圖表類型**：BarChart（二維資料）
- **顯示內容**：12 區（雙北 29 區）的熱島脆弱度分數，越紅越脆弱
- **計算邏輯**：
  ```
  熱島脆弱度 = 該區人口 ÷ (公園綠地面積 m² + 涼適點數 × 100 + 行道樹數 × 5)
  ```
  分母代表「降溫資源總量」，分子是承受熱壓的人口。值越大表示資源越不足。
- **資料源**：聚合運算自組件 1 的四份來源 + 各區人口
- **欄位需求**：行政區、人口數、各資源量、脆弱度分數
- **互動**：點 bar 帶到組件 1 的對應行政區

### 組件 3：雙北空氣品質 7 天趨勢
- **圖表類型**：ColumnLineChart（時間序列）
- **顯示內容**：過去 7 天每天 AQI 平均 + 最高值，臺北 / 新北兩條線並列
- **資料源**：D050502 空氣品質歷史
- **欄位需求**：日期、城市、AQI 平均、AQI 最高、主要污染物
- **互動**：可切換污染物（PM2.5 / PM10 / O3）

### 組件 4：城市降溫資源 KPI
- **圖表類型**：TextUnitChart（4 格 KPI）
- **顯示內容**：
  - 涼適點總數
  - 公園綠地總面積（公頃）
  - 人均綠地面積（m²/人）
  - 行道樹總長度（公里）或總棵數
- **資料源**：聚合運算
- **欄位需求**：聚合各項資源量

---

## 3. 資料對應驗證（Day 1 開賽第一件事，1 小時）

開賽第一個任務是去 [data.ntpc.gov.tw](https://data.ntpc.gov.tw) 確認以下資料**都存在 + 欄位夠用**：

| # | Taipei 資料 | NTPC 對應（待查） | 驗證關鍵 |
|---|---|---|---|
| 1 | cooling_point 涼適點 | 新北市涼夏 / 涼適點 / 避暑點 | 有經緯度欄位 |
| 2 | D050303_1 公園綠地 | 新北市公園綠地 | 多邊形 GIS + 面積欄位 |
| 3 | D050201 行道樹 | 新北市行道樹 | 點位或路段資料 |
| 4 | D050502 空品 | 同份（全國資料） | 雙北測站皆有 |

**最高風險**：「涼適點」是臺北市民政局獨有政策，新北可能用「親水點」、「鄰里活動中心開放冷氣」等不同名稱。
**若新北涼適點沒對應 → 改用「鄰里活動中心」或「便民服務據點」當作可冷氣空間替代**。

---

## 4. 技術架構

### DE 層（Airflow ETL）

要新增 **8 個 DAG**（4 個臺北 + 4 個新北）：

| DAG | 仿照範本 | 備註 |
|---|---|---|
| 4 個 Taipei DAG | `proj_city_dashboard/cooling_point/`, `D050303_1/`, `D050201/`, `D050502/` | 已存在，直接用 |
| 4 個 NTPC DAG | `proj_new_taipei_city_dashboard/long_term/` | 結構最相似（GIS + 月更）|

**好消息**：四份臺北資料的 ETL 都已存在，只要寫 4 個新北版本。**最低風險選項**——空品 D050502 是全國資料，幾乎不用改。

### DB schema

需要新增的表（4 對 8 張）：
- `cooling_point_tpe` / `cooling_point_new_tpe`（涼適點，POINT）
- `park_green_area_tpe` / `park_green_area_new_tpe`（公園綠地，POLYGON）
- `street_tree_tpe` / `street_tree_new_tpe`（行道樹，POINT 或 LINE）
- `air_quality_hourly_tpe` / `air_quality_hourly_new_tpe`（空品，每小時時序）

**關鍵欄位**：
- `data_time` / `_ctime` / `_mtime`
- `district` — 行政區（給組件 2 用）
- `geometry` — WKB
- 公園綠地表加：`area_m2`（面積）、`type`（社區公園 / 都會公園 / 河濱）
- 涼適點表加：`open_hours`、`facility`（飲水機 / 冷氣 / 噴霧）
- 空品表加：`aqi`、`pm25`、`pm10`、`o3`、`station_name`

### 預先計算（核心技術點）

**做法 A：BE 即時算（簡單）**
- 把 4 張表 + 行政區邊界 + 人口資料丟給 FE 算

**做法 B：DB 預先算（推薦）**
- 寫 SQL view 計算每個行政區的「人均綠地、涼適點密度、空品平均」
- 存到 `heat_vulnerability_tpe` / `heat_vulnerability_new_tpe`

```sql
-- 概念示意
CREATE TABLE heat_vulnerability_tpe AS
SELECT
  d.district,
  d.population,
  COUNT(DISTINCT cp.id) AS cooling_point_count,
  SUM(p.area_m2) AS green_area_total,
  SUM(p.area_m2) / NULLIF(d.population, 0) AS per_capita_green,
  AVG(aq.aqi) FILTER (WHERE aq.data_time > NOW() - INTERVAL '7 days') AS aqi_7d_avg,
  -- 脆弱度分數
  d.population::float / NULLIF(
    SUM(p.area_m2) + COUNT(DISTINCT cp.id) * 100 + COUNT(DISTINCT t.id) * 5,
    0
  ) AS vulnerability_score
FROM districts d
LEFT JOIN cooling_point_tpe cp ON ST_Contains(d.geometry, cp.geometry)
LEFT JOIN park_green_area_tpe p ON ST_Intersects(d.geometry, p.geometry)
LEFT JOIN street_tree_tpe t ON ST_Contains(d.geometry, t.geometry)
LEFT JOIN air_quality_hourly_tpe aq ON aq.district = d.district
GROUP BY d.district, d.population;
```

PostGIS 已內建在 [docker/docker-compose-db.yaml](docker/docker-compose-db.yaml)。

**人口資料來源**：可以從現有的 `population_age_distribution_tpe` 或 `city_age_distribution_taipei`（已是雙北範例組件，**只用資料不做組件**）取行政區人口。

### BE 層

`dashboardmanager` DB 新增：
- 4 個 `components` entries
- 4 個 `component_charts` entries
- 1 個 `component_maps` entry（給組件 1，含 4 個圖層）
- 1 個 `dashboards` entry：`urban_heat_island`

組件 API 已存在 `GET /api/v1/component/:id/chart`，不需動 BE 程式碼。

### FE 層

- 4 個既有 chart component 都能用
- **唯一新工作**：組件 1 的 Choropleth（行政區染色）+ 多點位圖層
- Choropleth 在 mapbox-gl 用 `fill-color` + `match` expression 即可
- 行政區邊界 GeoJSON 通常 repo 已有（`assets/data/` 或 backend 提供）

---

## 5. 時程拆解（32 小時）

### Day 1 (5/2)

| 時段 | 任務 | 產出 |
|---|---|---|
| 10:00-11:00 | 驗證新北 4 份資料 + 下載 sample | 確認沒地雷 |
| 11:00-12:00 | 設計 8 張 schema + 行政區邊界準備 | schema OK |
| 13:00-16:00 | 寫 4 個 NTPC DAG + 灌資料 | 8 張表有資料 |
| 16:00-18:00 | 寫 PostGIS view 計算 heat_vulnerability + 4 個 component config | API 回得出 |
| 18:00-22:00 | FE 組件 1 Choropleth + 多圖層 | 地圖跑得起來 |
| 22:00-02:00 | FE 組件 2、3、4 | 4 組件齊全 |

### Day 2 (5/3 凌晨到上午)

| 時段 | 任務 | 產出 |
|---|---|---|
| 02:00-04:00 | 雙北切換 + 互動 + popup | 互動完整 |
| 04:00-06:00 | 整合測試 + bug fix | demo 順 |
| 06:00-08:00 | README、簡報、demo 影片、來源清單 | 文件齊 |
| 08:00-09:30 | 排練 + 繳交 | 09:30 hard deadline |

---

## 6. 風險與備案

| 風險 | 機率 | 影響 | 備案 |
|---|---|---|---|
| 新北沒對應「涼適點」 | 中 | 中 | 改用鄰里活動中心 / 便民服務據點 |
| 行政區邊界 GeoJSON 找不到 | 低 | 中 | 從 OpenStreetMap 或 data.gov.tw 抓 |
| 空品測站雙北數量懸殊 | 低 | 低 | 用「離行政區質心最近的測站」代表 |
| 行道樹資料量過大 | 中 | 中 | 用密度（每平方公里棵數）取代逐點顯示 |

---

## 7. 創意加分點（時間還有再做）

- **AI tool calling**：「我家在文山區，最近的涼適點開到幾點？」LLM + 點位查詢
- **散步路線推薦**：「沿著行道樹密集路段走 30 分鐘」用 turf.js 找最佳路徑
- **歷史對比**：「過去 5 年高溫日數 vs 綠地增長率」，看政策成效
- **未來預測**：用簡易線性回歸看「按目前綠化速度，2030 年人均綠地」

---

## 8. 評分自我檢核

| 項目 | 權重 | 本提案怎麼拿分 |
|---|---|---|
| 作品應用 | 40% | 民政局 / 公園處 / 環保局三層用戶，氣候政策議題正當紅 |
| 作品技術 | 30% | Choropleth + 多圖層 + PostGIS 空間聚合，技術扎實 |
| 作品創意 | 30% | 「人均降溫資源」綜合指標，現有 dashboard 沒做 |

**主線任務檢核**：
- [x] 至少 4 個雙北組件
- [x] 至少 1 個含地圖圖層（組件 1，含 Choropleth）
- [x] 全部下拉切換臺北/雙北
- [x] 不抄現有範例組件
- [x] 資料來自開放平台

**這個提案的最大優勢**：**完賽風險最低**。資料穩定（多是靜態 GIS）、不靠即時 API、視覺呈現一目瞭然、demo 故事誰都聽得懂。如果這是你第一次黑客松，這題的時間成本最可控。

---

## 9. 參考資源

**官方文件**
- 競賽官網：https://codefest.taipei
- 儀表板技術文件：https://citydashboard.taipei/documentation

**開放資料**
- 臺北市資料大平臺：https://data.taipei
- 新北市資料開放平台：https://data.ntpc.gov.tw
- 環境部空品資料：https://airtw.moenv.gov.tw

**Repo 內參考**
- ETL 範本：[Taipei-City-Dashboard-DE/dags/proj_new_taipei_city_dashboard/long_term/](Taipei-City-Dashboard-DE/dags/proj_new_taipei_city_dashboard/long_term/)
- 既有 Taipei DAG：[Taipei-City-Dashboard-DE/dags/proj_city_dashboard/cooling_point/](Taipei-City-Dashboard-DE/dags/proj_city_dashboard/cooling_point/), [D050303_1/](Taipei-City-Dashboard-DE/dags/proj_city_dashboard/D050303_1/), [D050201/](Taipei-City-Dashboard-DE/dags/proj_city_dashboard/D050201/), [D050502/](Taipei-City-Dashboard-DE/dags/proj_city_dashboard/D050502/)
- 雙北組件 config 範本：[db-sample-data/dashboardmanager-demo.sql](db-sample-data/dashboardmanager-demo.sql)
- 地圖 Choropleth 範本：mapbox-gl 官方文件 `fill-color` + `match` expression
