# 提案 2：老舊社區災害脆弱度

> 2026 雙北程式設計節 城市儀表板大黑客松 提案規劃
> 主題分類：02 韌性防災

---

## TL;DR（一頁濃縮）

| | 內容 |
|---|---|
| **主題** | 02 韌性防災 |
| **故事** | 雙北高危老聚落離避難所多遠？多災害疊加找出政策優先順序 |
| **4 個組件** | 1 多災害疊圖（地圖）／ 2 行政區脆弱度排行 ／ 3 避難所 1km 涵蓋率 ／ 4 風險 KPI |
| **資料源** | R0021 老聚落 + R0019 土石流 + D050401 液化 + R0017 避難所（共 4 對 8 張表）|
| **技術核心** | PostGIS 空間運算（`ST_Intersects`、`ST_Distance`）+ turf.js + deck.gl 多圖層 |
| **新北資料風險** | 「老聚落」名稱不同（可能是「海砂屋」、「危老」），開賽 30 分鐘內驗證 |
| **原創性密度** | 4/4（全部組件都是跨源計算，無單純 Taipei 移植）|
| **預估工時** | 24 小時（含 6h ETL、4h SQL view、6h 地圖、4h 其他組件、4h demo/文件）|
| **失敗回退** | 老聚落資料缺 → 用屋齡 30 年建物；3 份以上缺 → 換提案 3 |

---

## 1. 故事與目標使用者

**一句話故事**：
> 雙北的老舊聚落，常常同時躺在土石流潛勢區、土壤液化區裡——但他們離最近的避難所多遠？這個儀表板把多重災害疊加成「社區脆弱度地圖」，找出最該優先強化的社區。

**主要使用者**：
- 政府：都更處（哪些老社區該優先都更）、消防局（防災演練選點）、民政局（弱勢社區關懷）
- 民眾：老社區里長、住戶（知道自家風險）

**現有 dashboard 缺什麼**：
老舊聚落（R0021）、土石流潛勢（R0018/R0019）、土壤液化（D050401）、避難所（R0017）四份資料目前各自是獨立圖層。**沒有任何組件做「多災害疊加 × 避難可及性」的綜合脆弱度分析**——這是本提案的核心價值。

**這也是評分簡報強調的方向**：「從『看數據』到『用數據做決策』」（簡報 PHASE03）。

**對標 user story**：
> 「中和有個里長想知道他里上的老社區，遇到極端降雨會不會被土石流影響？最近的避難所是哪間活動中心？容量夠不夠？」現有 dashboard 給不出答案，本提案直接給出。

**Demo 一句 hook**：
> 「我們把雙北 X,XXX 個老舊聚落、Y,YYY 個避難收容處所、土石流潛勢、土壤液化四份資料疊起來，找出 Z 個『三重風險 + 1km 內無避難所』的高危聚落——這是給市府都更與防災演練的優先名單。」

---

## 2. 四個組件設計

### 組件 1（地圖層）：多災害脆弱度疊圖
- **圖表類型**：Map（deck.gl 多 layer）+ MapLegend
- **顯示內容**：
  - 紅色多邊形：老舊聚落分布（R0021）
  - 黃色多邊形：土石流影響範圍（R0019）
  - 紫色多邊形：高液化潛勢區（D050401）
  - 綠色點位：可供避難收容處所（R0017）
  - **點擊老聚落 → 跳出 popup 顯示「最近 3 個避難所距離 + 該聚落涵蓋的災害類型」**
- **Taipei 資料源**：
  - R0021 老舊聚落分布圖（工務局，data.taipei）
  - R0019 土石流潛勢溪流影響範圍（農業部，全國資料切雙北）
  - D050401 土壤液化潛勢（工務局，全國資料切雙北）
  - R0017 可供避難收容處所（教育局，data.taipei）
- **NTPC 資料源**（要驗證）：
  - 新北市老舊建築 / 老舊聚落（data.ntpc.gov.tw 都市發展局）
  - 土石流（同 R0019，農業部全國資料）
  - 土壤液化（同 D050401，全國資料）
  - 新北市避難收容處所（data.ntpc.gov.tw 教育局或消防局）
- **互動**：圖層切換、點擊聚落看可及性、滑動條過濾「只看三重風險」

### 組件 2：行政區綜合脆弱度排行
- **圖表類型**：BarPercentChart（百分比資料）
- **顯示內容**：12 區（雙北 29 區）的綜合脆弱度分數排序
- **計算邏輯**：
  ```
  脆弱度分數 = 0.4 × 老聚落覆蓋率
            + 0.3 × 高液化潛勢覆蓋率
            + 0.3 × 土石流影響覆蓋率
  ```
  覆蓋率定義為「該行政區內，老聚落 / 災害區的面積 ÷ 行政區總面積」
- **資料源**：聚合運算自組件 1 的四份來源
- **欄位需求**：行政區、各風險百分比、綜合分數
- **互動**：點 bar 帶到組件 1 的對應行政區地圖

### 組件 3：避難所可及性涵蓋率
- **圖表類型**：DonutChart（百分比資料）+ BarPercentChart 切換
- **顯示內容**：所有老舊聚落中，「步行 1km 內能到避難所」的比例分布
  - 完整覆蓋（綠）：1km 內 ≥ 2 個避難所
  - 部分覆蓋（黃）：1km 內 1 個
  - 無覆蓋（紅）：1km 內 0 個
- **計算邏輯**：用 turf.js `distance` 對每個老聚落 centroid 計算最近避難所
- **資料源**：R0021 + R0017（兩市都要算）
- **互動**：切換「步行 1km / 5km / 10km」三種距離

### 組件 4：災害風險統計 KPI
- **圖表類型**：TextUnitChart（4 格 KPI）
- **顯示內容**：
  - 老舊聚落總數
  - 三重風險聚落數（同時在老聚落 + 液化區 + 土石流區）
  - 避難所總容納人數
  - 1km 內無避難所的弱勢聚落數
- **資料源**：聚合運算
- **欄位需求**：聚落 ID、各風險旗標、最近避難所距離、避難所容量

---

## 3. 資料對應驗證（Day 1 開賽第一件事，1 小時）

開賽第一個任務是去 [data.ntpc.gov.tw](https://data.ntpc.gov.tw) 確認以下資料**都存在 + 欄位夠用**：

| # | Taipei 資料 | NTPC 對應（待查） | 驗證關鍵 |
|---|---|---|---|
| 1 | R0021 老舊聚落分布 | 新北市老舊建築 / 老舊社區 | 有多邊形 GIS 或地址點位 |
| 2 | R0019 土石流影響範圍 | 同份（農業部全國資料） | 確認新北行政區欄位可篩 |
| 3 | D050401 土壤液化潛勢 | 同份（經濟部地調所全國資料） | WMS 圖磚或 GeoJSON |
| 4 | R0017 可供避難收容處所 | 新北市避難收容處所 | 有經緯度 + 容納人數 |

**最高風險**：「老舊聚落」在新北可能用不同名稱（例如「老舊社區」、「列管老屋」、「都更專案」）。要花 30 分鐘搜 data.ntpc 確認。
**若新北老聚落資料不全 → 退而求其次用「屋齡 30 年以上建物」資料代替（建管處應有）**。

**建議搜尋關鍵字（按優先序）**：
| 主題 | 搜尋詞（在 data.ntpc.gov.tw 試這些）|
|---|---|
| 老聚落 | `老舊` `老屋` `屋齡` `都更` `海砂屋` `危老` |
| 土石流 | `土石流` `坡地` `災害潛勢` |
| 土壤液化 | `土壤液化` `地質` `液化潛勢` |
| 避難所 | `避難` `收容` `防災據點` `防空避難` `緊急避難` |

**搜尋全國資料的回退來源**：
- 農業部土石流防災資訊網：https://246.ardswc.gov.tw/Info/DebrisFlowDetail
- 經濟部地質調查所土壤液化：https://www.geologycloud.tw/map/Liquefaction/zh-tw

---

## 4. 技術架構

### DE 層（Airflow ETL）

要新增 **8 個 DAG**（4 個臺北 + 4 個新北）：

| DAG | 仿照範本 | 備註 |
|---|---|---|
| 4 個 Taipei DAG | `proj_city_dashboard/R0017/`, `R0019/`, `R0021/`, `D050401/` 已存在 | 直接用 |
| 4 個 NTPC DAG | `proj_new_taipei_city_dashboard/long_term/` | 結構最相似（GIS + 月更）|

**好消息**：四份臺北資料的 ETL 全部都已存在，你只要寫 4 個新北版本。

**特殊處理**：土石流（R0019）和土壤液化（D050401）是農業部 / 地調所**全國資料**，可能不需要寫新北版本，只需要在查詢時 filter 行政區即可——但這要看資料形式（是否本來就分縣市）。

### DB schema

需要新增 4 對 8 張表：
- `old_settlement_tpe` / `old_settlement_new_tpe`（老舊聚落，多邊形 GIS）
- `debris_flow_area_tpe` / `debris_flow_area_new_tpe`（土石流影響範圍）
- `soil_liquefaction_tpe` / `soil_liquefaction_new_tpe`（土壤液化潛勢）
- `evacuation_shelter_tpe` / `evacuation_shelter_new_tpe`（避難收容處所，點位 + 容量）

**關鍵欄位**：
- `data_time` / `_ctime` / `_mtime`
- `district` — 行政區
- `geometry` — WKB（PostGIS POLYGON 或 POINT）
- 老聚落表加：`building_count`、`age_avg`
- 避難所表加：`capacity`（容納人數）、`address`、`type`（學校 / 活動中心 / 體育館）

### 預先計算（核心技術點）

**做法 A：BE 即時算（簡單）**
- 把 4 張表全部餵給 FE，turf.js 在前端做距離運算
- 缺點：點位多會卡

**做法 B：DB 預先算（推薦）**
- 寫一個 SQL view 或補一個 ETL，預先算出每個老聚落的「最近避難所距離 + 災害旗標」
- 結果存到 `vulnerability_score_tpe` / `vulnerability_score_new_tpe`
- 組件 2、3、4 直接讀這張表

```sql
-- 概念示意
CREATE TABLE vulnerability_score_tpe AS
SELECT
  os.id,
  os.district,
  os.geometry,
  -- 災害旗標
  EXISTS(SELECT 1 FROM debris_flow_area_tpe d
         WHERE ST_Intersects(d.geometry, os.geometry)) AS in_debris,
  EXISTS(SELECT 1 FROM soil_liquefaction_tpe s
         WHERE ST_Intersects(s.geometry, os.geometry)
         AND s.level = 'high') AS in_liquefaction,
  -- 最近避難所
  (SELECT ST_Distance(os.geometry, e.geometry)
   FROM evacuation_shelter_tpe e
   ORDER BY os.geometry <-> e.geometry LIMIT 1) AS nearest_shelter_m
FROM old_settlement_tpe os;
```

PostGIS 已內建在 [docker/docker-compose-db.yaml](docker/docker-compose-db.yaml) 用的 `postgis/postgis:16-3.4-alpine` image，可直接用 `ST_*` 函式。

### 完整可貼上的 PostGIS 計算腳本（核心）

```sql
-- ========================================
-- vulnerability_score_tpe 預先計算表
-- 跑一次後組件 2、3、4 直接讀這張
-- ========================================
DROP TABLE IF EXISTS vulnerability_score_tpe CASCADE;

CREATE TABLE vulnerability_score_tpe AS
WITH settlement_risks AS (
  SELECT
    os.ogc_fid AS settlement_id,
    os.district,
    os.geometry,
    os.building_count,
    -- 災害旗標
    EXISTS(
      SELECT 1 FROM debris_flow_area_tpe d
      WHERE ST_Intersects(d.geometry, os.geometry)
    ) AS in_debris_flow,
    EXISTS(
      SELECT 1 FROM soil_liquefaction_tpe s
      WHERE ST_Intersects(s.geometry, os.geometry)
        AND s.level IN ('high', '高')
    ) AS in_high_liquefaction,
    -- 最近避難所
    (
      SELECT ST_Distance(
        os.geometry::geography,
        e.geometry::geography
      )
      FROM evacuation_shelter_tpe e
      ORDER BY os.geometry <-> e.geometry
      LIMIT 1
    ) AS nearest_shelter_m,
    -- 1km 內避難所數量
    (
      SELECT COUNT(*) FROM evacuation_shelter_tpe e
      WHERE ST_DWithin(
        os.geometry::geography,
        e.geometry::geography,
        1000
      )
    ) AS shelters_within_1km
  FROM old_settlement_tpe os
)
SELECT
  *,
  -- 三重風險旗標
  (in_debris_flow AND in_high_liquefaction) AS triple_risk,
  -- 綜合脆弱度分數 (0-100)
  ROUND(
    (CASE WHEN in_debris_flow THEN 30 ELSE 0 END) +
    (CASE WHEN in_high_liquefaction THEN 30 ELSE 0 END) +
    (CASE WHEN shelters_within_1km = 0 THEN 40
          WHEN shelters_within_1km = 1 THEN 20
          ELSE 0 END)
  )::int AS vulnerability_score
FROM settlement_risks;

CREATE INDEX idx_vuln_district_tpe ON vulnerability_score_tpe (district);
CREATE INDEX idx_vuln_geom_tpe ON vulnerability_score_tpe USING GIST (geometry);

-- 同樣再跑一次 _new_tpe 版本
```

**為什麼這份 SQL 是核心**：跑一次（10-30 秒），組件 2、3、4 全部變成 `SELECT * FROM vulnerability_score_tpe` 等級的單表查詢，BE 不用改邏輯，FE 也不用算。

### BE 層

`dashboardmanager` DB 新增：
- 4 個 `components` entries
- 4 個 `component_charts` entries（types: `[Map]`、`[BarPercentChart]`、`[DonutChart, BarPercentChart]`、`[TextUnitChart]`）
- 1 個 `component_maps` entry（給組件 1，含 4 個圖層 source）
- 1 個 `dashboards` entry：`disaster_resilience_oldtown`

組件 API 已存在 `GET /api/v1/component/:id/chart`，不需動 BE 程式。

### 可貼上的 component config SQL（範本）

```sql
-- 1. 註冊 4 個 components
INSERT INTO public.components (id, index, name) VALUES
  (501, 'old_settlement_risk_map', '多災害脆弱度疊圖'),
  (502, 'district_vulnerability_rank', '行政區綜合脆弱度排行'),
  (503, 'shelter_accessibility', '避難所 1km 涵蓋率'),
  (504, 'disaster_kpi', '災害風險統計');

-- 2. chart 設定
INSERT INTO public.component_charts (index, color, types, unit) VALUES
  ('old_settlement_risk_map', '{#E74C3C,#F39C12,#9B59B6,#27AE60}', '{MapLegend}', ''),
  ('district_vulnerability_rank', '{#E74C3C,#F39C12,#27AE60}', '{BarPercentChart}', '%'),
  ('shelter_accessibility', '{#27AE60,#F39C12,#E74C3C}', '{DonutChart,BarPercentChart}', '%'),
  ('disaster_kpi', '{#E74C3C}', '{TextUnitChart}', '');

-- 3. 地圖層（給組件 1）
INSERT INTO public.component_maps (index, title, type, source, paint, property) VALUES
  ('old_settlement_tpe',     '老舊聚落',       'fill',   'geojson', '{"fill-color":"#E74C3C","fill-opacity":0.4}', '[{"key":"district","name":"行政區"},{"key":"building_count","name":"建物數"}]'),
  ('debris_flow_area_tpe',   '土石流影響範圍', 'fill',   'geojson', '{"fill-color":"#F39C12","fill-opacity":0.3}', '[]'),
  ('soil_liquefaction_tpe',  '土壤液化潛勢',   'fill',   'geojson', '{"fill-color":"#9B59B6","fill-opacity":0.3}', '[{"key":"level","name":"潛勢等級"}]'),
  ('evacuation_shelter_tpe', '避難收容處所',   'symbol', 'geojson', '{}',                                          '[{"key":"name","name":"場所名稱"},{"key":"capacity","name":"容納人數"}]');

-- 4. 建立 dashboard，掛上 4 個組件
INSERT INTO public.dashboards (id, index, name, components, icon) VALUES
  (601, 'disaster_resilience_oldtown', '老舊社區災害脆弱度', '{501,502,503,504}', 'shield');
```

對應「下拉切換城市」邏輯：FE 在組件卡上用 select 切換 `_tpe` / `_new_tpe`，BE chart endpoint 已支援 `?city=...` query param（見 [Taipei-City-Dashboard-BE/app/controllers/componentData.go](Taipei-City-Dashboard-BE/app/controllers/componentData.go)）。

### FE 層

- 4 個既有 chart component 都能用，**唯一要寫的是組件 1 的多圖層地圖**
- 地圖層配置仿照 [src/components/map/](Taipei-City-Dashboard-FE/src/components/map/) 既有的 deck.gl 整合
- 地圖層數比一般組件多（4 層 + popup）→ 多花 2-3 小時

---

## 4.5. 各組件 Definition of Done

每個組件都有「MVP（必做）」和「Nice-to-have（時間夠再做）」兩層：

### 組件 1：多災害脆弱度疊圖
- **MVP（4 小時）**：4 個圖層能載入 + 切換 ON/OFF + 雙北切換
- **Nice-to-have**：點擊老聚落跳 popup（顯示三重風險旗標 + 1km 內避難所數）
- **完成驗收**：開兩個 tab 分別看臺北 / 新北，4 個圖層都正確、互不蓋住

### 組件 2：行政區綜合脆弱度排行
- **MVP（1 小時）**：BarPercentChart 顯示 12 / 29 區 vulnerability_score 平均
- **Nice-to-have**：點擊 bar 帶到組件 1 對應區（cross-component linking）
- **完成驗收**：bar 排序由高到低，hover 顯示三項細部分數

### 組件 3：避難所 1km 涵蓋率
- **MVP（1 小時）**：DonutChart 顯示完整覆蓋 / 部分覆蓋 / 無覆蓋三色比例
- **Nice-to-have**：切換距離（1km / 5km），切換城市
- **完成驗收**：百分比加總 = 100%，與組件 4 KPI 數字一致

### 組件 4：災害風險統計 KPI
- **MVP（30 分鐘）**：4 格 TextUnitChart 顯示總數
- **Nice-to-have**：紅黃綠色標示警戒等級
- **完成驗收**：4 個數字皆 > 0，與 SQL 直接查詢結果一致

> **如果 Day 1 結束時還沒到 MVP，立刻砍掉組件 4，先保 1+2+3。**

---

## 5. 時程拆解（32 小時）

### Day 1 開賽前 30 分鐘 Kickoff Checklist（10:00-10:30）

到場後 30 分鐘內必做的事：

```
[ ] 09:30-09:50 報到 + 開幕後立刻上 data.ntpc.gov.tw 搜以下 4 個關鍵字：
    1. "避難收容" → 確認新北避難所資料、欄位含經緯度+容量
    2. "老舊" 或 "屋齡" 或 "海砂屋" → 找老建築替代資料
    3. "土石流" → 確認新北版本（或用全國資料切）
    4. "土壤液化" → 確認新北版本（或用全國資料切）

[ ] 10:00-10:10 把 4 個 NTPC dataset URL 抄到 NOTES.md，標註：
    - dataset name
    - 更新頻率
    - 欄位是否齊全（地理欄位 + 行政區）
    - 資料量（筆數）

[ ] 10:10-10:20 緊急決策點：
    - 若 4 份新北資料齊全 → 確定做提案 2，繼續往下
    - 若 1-2 份缺 → 用替代資料 + 調整故事
    - 若 3+ 份缺 → 立刻換做提案 3（熱島）

[ ] 10:20-10:30 啟動本地環境：
    - 進 repo 根目錄 git pull origin develop
    - cd docker && docker compose -f docker-compose-db.yaml up -d postgres-data postgres-manager redis
    - 確認 postgres-data + postgres-manager 都 Up
    - psql 可連 (psql -h localhost -p 5432 -U postgres -d dashboard)
```

> ⚠️ 不要在 09:00-09:50 浪費時間做技術準備——那段時間用來社交、找位置、確認電源。**技術上場是 10:00 開賽鈴響後**。

---

### Day 1 (5/2)

| 時段 | 任務 | 產出 |
|---|---|---|
| 10:00-11:00 | 驗證新北資料 + 下載 sample | 確認沒地雷 |
| 11:00-13:00 | 設計 schema + PostGIS view + 寫第一個 NTPC DAG | 1 個 ETL 跑通 |
| 14:00-17:00 | 完成另 3 個 NTPC DAG + 灌資料 + 跑 vulnerability_score view | 8 張表 + 1 張 score view |
| 17:00-20:00 | 寫 4 個 component config + dashboard config | API 回得出 chart data |
| 20:00-23:00 | FE 組件 1 多圖層地圖（最難） | 地圖能顯示 4 層 |
| 23:00-02:00 | FE 組件 2、3、4 | 4 個組件就位 |

### Day 2 (5/3 凌晨到上午)

| 時段 | 任務 | 產出 |
|---|---|---|
| 02:00-04:00 | 雙北切換 + 點擊互動 + popup | 互動完整 |
| 04:00-06:00 | 整合測試 + bug fix | demo 順 |
| 06:00-08:00 | README、簡報、demo 影片、來源清單 | 文件齊 |
| 08:00-09:30 | 排練 + 繳交 | 09:30 hard deadline |

---

## 6. 風險與備案

| 風險 | 機率 | 影響 | 備案 |
|---|---|---|---|
| 新北沒對應老聚落資料 | **高** | 致命 | 用「屋齡 30 年以上建物」替代；或退到提案 3 |
| PostGIS 空間運算太慢 | 中 | 中 | 預先把 score view materialize 成 table，或搬到 DAG 計算 |
| 多圖層地圖卡頓 | 中 | 中 | zoom out 改顯示行政區聚合 |
| 4 種資料的座標系統不統一 | 中 | 高 | 確認都轉成 WGS84（EPSG:4326）|

---

## 7. 創意加分點（時間還有再做）

### 加分 A：AI 對話查詢（評審最愛看，做出來就是亮點）

- 一句話：「我住中和區永和路，附近老社區災害風險高嗎？」LLM 回答 + 帶出地圖 highlight

**實作架構**（4 步驟）：
1. FE 在 dashboard 角落加聊天框（用既有 [chatStore](Taipei-City-Dashboard-FE/src/store/chatStore.js)）
2. 送到 BE `/api/v1/ai/chat/twai`
3. BE 帶上 system prompt，定義 tool: `query_settlement_risk(district, address)`
4. LLM 回 tool_call → BE 查 `vulnerability_score_tpe` → 回自然語言

**system prompt 範本**：
```
你是雙北防災助理。當使用者問特定地區的災害風險時，呼叫
query_settlement_risk(district)，整合回傳的脆弱度分數、
三重風險聚落數、最近避難所距離，給出 3-4 句回答。
不要編造資料，沒查到就說「該區查無記錄」。
```

**tool definition 範本**：
```json
{
  "type": "function",
  "function": {
    "name": "query_settlement_risk",
    "description": "查詢特定行政區的老舊聚落災害脆弱度",
    "parameters": {
      "type": "object",
      "properties": {
        "district": {"type": "string", "description": "行政區，如 中和區"}
      },
      "required": ["district"]
    }
  }
}
```

**注意**：30 RPM 限制，比賽當天每隊一支 key。賽前用試用 key 跑 demo 流程。

### 加分 B：避難路線

點擊老聚落 → 用 turf.js `nearestPoint` 找最近避難所 → 在地圖畫直線（簡單版）或用 Mapbox Directions API（漂亮版，但需要額外 token）。**先做直線版**，視覺效果就夠。

### 加分 C：歷史災情疊加

如果 data.taipei 有「歷史淹水紀錄」、「地震受損建物」等資料，可以加第 5 層歷史災情，做「曾發生災情 × 高脆弱度」的紅色警報區。**只做有時間時加**，不要本末倒置。

---

## 7.5. Demo 簡報腳本（5 分鐘）

評審會看 demo + 問問題。腳本如下：

### 開場（30 秒）—— 抓注意力
> 「雙北有超過 X,XXX 個老舊聚落。你知道有 Z 個——同時躺在土石流潛勢區、土壤液化區，**而且 1 公里內找不到避難所**嗎？我們的儀表板讓市府在 30 秒內找出他們。」

### 主秀（3 分鐘）—— 4 個組件展示

1. **打開地圖（組件 1）**（45 秒）：「先看疊圖，紅色是老聚落，黃色是土石流，紫色是高液化區。點這個聚落看，1km 內 0 個避難所——這就是高危。」
2. **切到雙北（組件 1+2）**（45 秒）：下拉切到新北。「新北的脆弱度排行第一是 OO 區，比臺北 OO 區還高 X%。」
3. **看可及性（組件 3）**（30 秒）：「全雙北老聚落中，X% 是『1km 內無避難所』——這是消防局演練應該優先選點的地方。」
4. **看 KPI（組件 4）**（30 秒）：「總共 Z 個三重風險聚落，估計影響 N 萬人——這就是政策應該優先處理的『誰』。」
5. **AI 對話（如做了）**（30 秒）：「我也可以直接問：『中和區永和路一段附近安全嗎？』AI 會幫我查。」（demo live）

### 收尾（30 秒）—— 政策意義
> 「現有 dashboard 是把資料『呈現』出來，我們補上的是『洞察』——把 4 個機關的資料疊出 1 份施政優先名單。這是 2026 願景講的『從看數據到用數據做決策』。」

### 預期被問的問題 + 回答

| Q | A |
|---|---|
| 為什麼脆弱度公式是 0.4/0.3/0.3？ | 「初版按災害嚴重度權衡，可調。重要的是公開、可解釋——市府可以調整自己的權重。」 |
| 資料來源是？ | 「全部 data.taipei + data.ntpc 開放資料 + 農業部土石流 + 經濟部地調所液化資料。每張 chart 角落都附 source 連結。」|
| 為什麼選 1km 距離？ | 「步行 15 分鐘範圍。內政部消防署避難所選點原則。可以調。」|
| 即時性？ | 「老聚落、災害潛勢屬靜態圖資（年度更新），避難所是月更。即時資料不適用此提案。」|

---

## 7.7. 5/3 09:30 文件繳交 Checklist（hard deadline）

簡報明寫 09:30 繳交文件、否則無法初選。**比賽結束前一晚（5/3 凌晨）就寫好**。

### 繳交內容（自己準備）

- [ ] **README.md**（在你的 fork repo 根目錄）
  - 隊名 / 主題 / 一句話描述
  - 4 個組件清單（含截圖）
  - 4 份資料來源 URL（雙北 = 8 個）
  - 安裝執行步驟（`docker compose up`）
  - 評審若想跑能跑得起來

- [ ] **DATA_SOURCES.md**（複審會看這個）
  - 每份資料：dataset 名稱、URL、欄位說明、更新頻率、授權條款
  - 例：
    ```
    | 名稱 | URL | 欄位 | 頻率 | 授權 |
    |---|---|---|---|---|
    | 臺北市老舊聚落分布圖 | https://data.taipei/dataset/detail?id=... | name, address, geometry, building_count | 年更 | OGDL 1.0 |
    ```

- [ ] **Demo 簡報 PDF**（5-8 頁）
  - 1. 封面（題目 + 隊名）
  - 2. 痛點 / 故事
  - 3. 4 個組件預覽（screenshot）
  - 4. 技術架構圖（DE → DB → BE → FE）
  - 5. 關鍵指標計算公式
  - 6. 創意亮點（如 AI 對話）
  - 7. 政策意義 / 評審該關注的洞察
  - 8. 致謝 + 來源

- [ ] **Demo 影片**（如果評分流程要求；以官方 FAQ 為準）
  - 90 秒，螢幕錄影 + 旁白
  - OBS 或 macOS 的 QuickTime 都行

- [ ] **Pull Request 草稿**（得獎才會 merge，但先準備好）
  - 從你 fork 的 develop branch 開 PR 到官方 main
  - 描述：4 個新組件 + 4 個 NTPC ETL + 1 個 vulnerability_score view

### 自我審查（繳交前 30 分鐘做）

- [ ] 4 個組件全部能跑、能切雙北
- [ ] 1 個地圖層運作正常（非空白、非破圖）
- [ ] 沒用 Apexcharts 以外的圖表套件（檢查 `package.json`）
- [ ] 沒用 llama3.3-ffm-70b-16k-chat 以外的 LLM（檢查 BE config）
- [ ] git history 看得出開發過程（不是一個 commit 定江山）
- [ ] README 提到的截圖、URL 都對得上

---

## 8. 評分自我檢核

| 項目 | 權重 | 本提案怎麼拿分 |
|---|---|---|
| 作品應用 | 40% | 都更政策、防災演練、弱勢關懷三層 audience，story 很強 |
| 作品技術 | 30% | PostGIS 空間運算 + turf.js + 多圖層疊圖，技術深度足 |
| 作品創意 | 30% | 多災害綜合脆弱度指標 + 避難可及性，現有 dashboard 完全沒有 |

**主線任務檢核**：
- [x] 至少 4 個雙北組件
- [x] 至少 1 個含地圖圖層（組件 1，且是最複雜的多圖層）
- [x] 全部下拉切換臺北/雙北
- [x] 不抄現有範例組件（4 個全是新組合）
- [x] 資料來自開放平台

**這個提案的最大優勢**：技術炫技（PostGIS / turf.js / 多圖層）+ 故事打動力（生命安全 + 弱勢）+ 視覺衝擊（多圖層疊加）三項都是滿分潛力。

---

## 8.5. 環境啟動踩雷紀錄（5/2 凌晨實測）

實際在 WSL2 / 7.6GB RAM 環境跑過一次，這些坑要避開：

### 雷 1：`.env` 的 GIN_MODE 行尾註解會被當成值
原本是：
```
GIN_MODE=debug # gin mode can be release(default)/debug/test
```
BE 會 panic：`gin mode unknown: debug # gin mode can be...`

**修法**：把註解換到上一行
```
# gin mode can be release(default)/debug/test
GIN_MODE=debug
```

### 雷 2：DB / 預設帳號密碼欄位空白
init 容器和 postgres 都需要密碼。template 是空的：
```
DB_DASHBOARD_PASSWORD=
DB_MANAGER_PASSWORD=
DASHBOARD_DEFAULT_PASSWORD=
PGADMIN_DEFAULT_PASSWORD=
```
**修法**：填 dev 用的值（任何非空值都行），不填 postgres 不會啟動。

### 雷 3：BE 啟動強制要求 `/opt/lm_model/onnx-e5/model.onnx`
BE 啟動時 [app/models/qdrant.go:128](Taipei-City-Dashboard-BE/app/models/qdrant.go) 會呼叫 `NewDynamicSession`，找不到 model.onnx 就 `log.Fatalf` 退出。

這個 model 是給 `/api/v1/vector/component` 語意搜尋用的，**比賽 4 個組件用不到**。

**修法 3 選 1**：
- A. **改 code**（最快，1 分鐘）：在 [Taipei-City-Dashboard-BE/app/models/qdrant.go](Taipei-City-Dashboard-BE/app/models/qdrant.go) 把 `log.Fatalf` 改成 `log.Printf`，BE 就會繼續跑（只是向量搜尋不能用，比賽用不到）
- B. **跑完整 Dockerfile build**（10-15 分鐘）：`docker compose -f docker-compose.yaml build dashboard-be` 會跑 Python + transformers + 從 HuggingFace 下載 model
- C. **手動產生 model**：`cd Taipei-City-Dashboard-BE && python export_model.py` 會輸出到 `lm_model/onnx-e5/`，然後 mount 進容器

賽前建議用 **A 方案**（最穩、最快），等 demo 階段有時間再切回 B。

### 雷 4：不需要起 qdrant + pgadmin（省記憶體）
我這次跑的是：postgres-data + postgres-manager + redis + dashboard-fe + nginx + dashboard-be。**6 個容器吃 2.8GB RAM**，i7-1255U / 16GB 完全應付得來（host 給 WSL 8GB 還剩 5GB）。如果開 qdrant 會多吃 ~500MB。

### 啟動指令範本（已驗證可跑）

```bash
# 1. 建 docker network
docker network create --driver=bridge --subnet=192.168.128.0/24 \
  --gateway=192.168.128.1 br_dashboard

# 2. 起 DB（不要 qdrant、不要 pgadmin，省 RAM）
cd docker
docker compose -f docker-compose-db.yaml --env-file .env up -d \
  postgres-data postgres-manager redis

# 3. 灌種子資料（first time 約 3-5 分鐘）
docker compose -f docker-compose-init.yaml --env-file .env up

# 4. 起 FE + nginx
docker compose -f docker-compose.yaml --env-file .env up -d \
  nginx dashboard-fe

# 5. 起 BE（先用方案 A 改完 qdrant.go 再跑）
docker compose -f docker-compose.yaml --env-file .env up -d dashboard-be
```

**驗證**：
- http://localhost:8080 → 看到 Vue dashboard 首頁
- http://localhost:8088/api/v1/dashboard/ → 回 JSON

---

## 9. 參考資源

**官方文件**
- 競賽官網：https://codefest.taipei
- 儀表板技術文件：https://citydashboard.taipei/documentation

**開放資料**
- 臺北市資料大平臺：https://data.taipei
- 新北市資料開放平台：https://data.ntpc.gov.tw
- 農業部土石流潛勢溪流：https://246.ardswc.gov.tw
- 經濟部地質調查所（土壤液化）：https://www.geologycloud.tw

**Repo 內參考**
- ETL 範本：[Taipei-City-Dashboard-DE/dags/proj_new_taipei_city_dashboard/long_term/](Taipei-City-Dashboard-DE/dags/proj_new_taipei_city_dashboard/long_term/)
- 雙北組件 config 範本：[db-sample-data/dashboardmanager-demo.sql](db-sample-data/dashboardmanager-demo.sql)
- 既有 Taipei DAG：[Taipei-City-Dashboard-DE/dags/proj_city_dashboard/R0017/](Taipei-City-Dashboard-DE/dags/proj_city_dashboard/R0017/), [R0019/](Taipei-City-Dashboard-DE/dags/proj_city_dashboard/R0019/), [R0021/](Taipei-City-Dashboard-DE/dags/proj_city_dashboard/R0021/), [D050401/](Taipei-City-Dashboard-DE/dags/proj_city_dashboard/D050401/)
- 地圖組件參考：[Taipei-City-Dashboard-FE/src/components/map/](Taipei-City-Dashboard-FE/src/components/map/)
- 空間運算函式庫：`@turf/turf` 已在 [Taipei-City-Dashboard-FE/package.json](Taipei-City-Dashboard-FE/package.json)
