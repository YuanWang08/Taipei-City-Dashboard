# 提案 1：事故黑點 × 道路施工

> 2026 雙北程式設計節 城市儀表板大黑客松 提案規劃
> 主題分類：01 智慧通勤

---

## 1. 故事與目標使用者

**一句話故事**：
> 雙北每天車禍頻傳，但工務局的施工排程跟事故熱區對得上嗎？這個儀表板讓交通局長一眼看出「事故多但還沒進場改善」的路段。

**主要使用者**：
- 政府：交通局、工務局、警察局（跨機關決策輔助）
- 民眾：通勤族（看到自家路段事故風險）

**現有 dashboard 缺什麼**：
事故斑點圖（R0042）、道路施工（R0040）、VD 壅塞（R0038）、A1A2 統計（D030201）四份資料目前各自獨立呈現。**沒有任何組件把它們疊起來找施政盲點**——這正是我們要補的位。

---

## 2. 四個組件設計

### 組件 1（地圖層）：事故黑點 × 施工點疊圖
- **圖表類型**：Map（deck.gl IconLayer + ScatterplotLayer）+ MapLegend
- **顯示內容**：地圖上同時呈現事故斑點（紅色點）與今日施工位置（黃色三角），hover 路段顯示「30 天事故數 / 是否在施工」
- **Taipei 資料源**：
  - R0042 道路交通事故斑點圖（警察局，data.taipei）
  - R0040 今日施工資訊（工務局，data.taipei）
- **NTPC 資料源**（要驗證）：
  - 新北市道路交通事故點位（data.ntpc.gov.tw 警察局）
  - 新北市道路工程資訊（data.ntpc.gov.tw 工務局）
- **欄位需求**：經緯度、事故類別、發生時間、施工類別、施工起訖
- **互動**：圖層切換 ON/OFF、點擊路段跳出小卡

### 組件 2：事故熱區行政區排行
- **圖表類型**：BarChart（二維資料）
- **顯示內容**：12 個臺北市行政區（或雙北 29 區）的 A1+A2 事故總件數排序
- **Taipei 資料源**：D030201 A1及A2交通事故資料（交通局，data.taipei）
- **NTPC 資料源**：新北市交通事故統計（data.ntpc.gov.tw 交通局）
- **欄位需求**：行政區、事故類別（A1/A2/A3）、件數、年月
- **互動**：點 bar 帶到組件 1 對應行政區地圖

### 組件 3：VD 24 小時壅塞趨勢
- **圖表類型**：ColumnLineChart（時間序列）
- **顯示內容**：00:00–23:00 各時段平均壅塞指數，顯示尖峰時段
- **Taipei 資料源**：R0038_1 全市 VD 道路壅塞程度統計（交通局）
- **NTPC 資料源**：新北市 VD 即時資料（TDX 全國皆有）
- **欄位需求**：時段、壅塞指數、路段類別
- **互動**：可切換「今日 / 過去 7 天平均」

### 組件 4：今日施工 KPI 儀表
- **圖表類型**：TextUnitChart（4 格 KPI）
- **顯示內容**：
  - 今日施工件數
  - 影響車道總數
  - 平均工期天數
  - 施工類別 TOP 1（如：管線維修）
- **Taipei 資料源**：R0040 今日施工資訊
- **NTPC 資料源**：新北市道路工程資訊
- **欄位需求**：施工類別、車道影響數、起訖時間

---

## 3. 資料對應驗證（Day 1 開賽第一件事，1 小時）

開賽第一個任務是去 [data.ntpc.gov.tw](https://data.ntpc.gov.tw) 確認以下 4 份資料**都存在 + 欄位夠用**：

| # | Taipei 資料 | NTPC 對應（待查） | 驗證關鍵 |
|---|---|---|---|
| 1 | R0042 道路交通事故斑點圖 | 新北市交通事故點位 | 有經緯度欄位 |
| 2 | R0040 今日施工資訊 | 新北市道路工程資訊 | 有施工點位或路段 |
| 3 | R0038 VD 壅塞統計 | TDX 全國 VD 即時 | API 可用、雙北都有測站 |
| 4 | D030201 A1A2 事故 | 新北市交通事故統計 | 有行政區欄位、A1/A2 分類 |

**若任何一份新北沒有對應 → 立刻換成提案 2 或 3**，不要硬幹。

---

## 4. 技術架構

### DE 層（Airflow ETL）

要新增 **8 個 DAG**（4 個臺北 + 4 個新北）。仿照現有範本：

| 你要做的 DAG | 仿照範本 | 為什麼 |
|---|---|---|
| 事故斑點 ETL | `proj_city_dashboard/R0042/` 已存在 → 直接用 | 不用重做 |
| 施工資訊 ETL | `proj_city_dashboard/R0040/` 已存在 → 直接用 | 不用重做 |
| VD 壅塞 ETL | `proj_city_dashboard/R0038_1/` 已存在 → 直接用 | 不用重做 |
| A1A2 事故 ETL | `proj_city_dashboard/D030201/` 已存在 → 直接用 | 不用重做 |
| 4 個 NTPC 對應 ETL | `proj_new_taipei_city_dashboard/long_term/` | 結構最相似 |

**好消息**：四份臺北資料的 ETL 都已存在，你只要寫 4 個新北版本。

### DB schema

雙北命名慣例：`<dataset>_tpe` + `<dataset>_new_tpe`（或 `_nwtpe`，看現有怎麼命）。

需要新增的表（4 對 8 張）：
- `traffic_accident_location_tpe` / `traffic_accident_location_new_tpe`
- `road_work_today_tpe` / `road_work_today_new_tpe`
- `traffic_vd_congestion_tpe` / `traffic_vd_congestion_new_tpe`
- `traffic_accident_a12_tpe` / `traffic_accident_a12_new_tpe`

關鍵欄位（每張表都要有）：
- `data_time` / `_ctime` / `_mtime` — 時間戳
- `district` — 行政區（給組件 2、4 用）
- `geometry` — WKB 地理欄位（地圖層用，turf 或 PostGIS）
- 各表自己的業務欄位

### BE 層

要在 `dashboardmanager` DB 新增：
- 4 個 entries in `components`（id 自增，name 中文）
- 4 個 entries in `component_charts`（types 陣列、color 陣列、unit）
- 1 個 entry in `component_maps`（給組件 1 用）
- 1 個 entry in `dashboards`（新 dashboard，components 陣列含 4 個 component id）

仿照 `dependency_aging` 那一組 config（在 [db-sample-data/dashboardmanager-demo.sql](db-sample-data/dashboardmanager-demo.sql)）。

組件 API 已存在：`GET /api/v1/component/:id/chart`，不用改 BE 程式碼，只改 DB config。

### FE 層

`Taipei-City-Dashboard-FE/src/dashboardComponent/` 下：
- 不需要新增 chart component（既有 `BarChart`、`ColumnLineChart`、`TextUnitChart` 都能用）
- 地圖組件用既有 [src/components/map/](Taipei-City-Dashboard-FE/src/components/map/) 的 deck.gl 整合
- **唯一要新增**：dashboard 路由 + 城市切換下拉選單在組件卡片上方

---

## 5. 時程拆解（32 小時）

### Day 1 (5/2)

| 時段 | 任務 | 產出 |
|---|---|---|
| 10:00-11:00 | 驗證新北 4 份資料 + 下載 sample CSV | 確認沒地雷 / 換題 |
| 11:00-12:00 | 設計 8 張 table schema + 寫第一個 NTPC DAG | 1 個 ETL 跑通 |
| 13:00-16:00 | 把另 3 個 NTPC DAG 寫完 + 跑 ETL 灌資料 | 8 張表都有資料 |
| 16:00-19:00 | 寫 4 個 component config (manager DB) + 1 個 dashboard | API 能回 chart data |
| 19:00-23:00 | FE 接組件 1（地圖）+ 組件 2（BarChart） | 地圖跑得起來 |
| 23:00-02:00 | FE 接組件 3（ColumnLine）+ 組件 4（KPI） | 4 個組件都顯示 |

### Day 2 (5/3 凌晨到上午)

| 時段 | 任務 | 產出 |
|---|---|---|
| 02:00-04:00 | 雙北切換下拉做完 + 跨組件互動 | 切換能跑 |
| 04:00-06:00 | 整合測試 + bug fix | demo 順暢 |
| 06:00-08:00 | 寫 README、demo 簡報、來源清單 | 文件齊全 |
| 08:00-09:30 | 排練 + 繳交文件 | 09:30 hard deadline |

---

## 6. 風險與備案

| 風險 | 機率 | 影響 | 備案 |
|---|---|---|---|
| 新北沒有對應資料 | 中 | 致命 | 開賽第一小時驗證，沒有就換題 |
| 即時 VD/施工 API 在會場斷網 | 中 | 高 | 預先抓 24 小時歷史快照當 fallback |
| 事故斑點點位太多，地圖卡頓 | 中 | 中 | 做行政區聚合，zoom out 不顯示個別點 |
| ETL 跑太久 | 低 | 中 | 限制資料抓近 30 天，不要全歷史 |

---

## 7. 創意加分點（時間還有再做）

- **AI tool calling**：用台智雲 LLM 加「我家在 OO 路，最近一年事故狀況？」對話查詢
- **熱區預測**：用過去 12 個月事故數據做簡易趨勢預測（不要訓練模型，pandas rolling mean 就夠）
- **施政效能指標**：「事故熱區 × 是否進入施工排程」百分比，這是很有政策意義的 metric

---

## 8. 評分自我檢核

| 項目 | 權重 | 本提案怎麼拿分 |
|---|---|---|
| 作品應用 | 40% | 跨機關施政盲點分析，給局長級決策用，story 強 |
| 作品技術 | 30% | 4 個 ETL × 雙北 = 8 個 pipeline 整合，地圖疊圖技術 |
| 作品創意 | 30% | 「事故熱區但無施工」的施政效能指標，現有 dashboard 沒有 |

**主線任務檢核**：
- [x] 至少 4 個雙北組件
- [x] 至少 1 個含地圖圖層（組件 1）
- [x] 全部下拉切換臺北/雙北
- [x] 不抄現有範例組件（4 個都是新組合）
- [x] 資料來自開放平台 data.taipei + data.ntpc

---

## 9. 參考資源

**官方文件**
- 競賽官網：https://codefest.taipei
- 儀表板技術文件：https://citydashboard.taipei/documentation

**開放資料**
- 臺北市資料大平臺：https://data.taipei
- 新北市資料開放平台：https://data.ntpc.gov.tw
- TDX 運輸資料流通服務：https://tdx.transportdata.tw

**Repo 內參考**
- ETL 範本：[Taipei-City-Dashboard-DE/dags/proj_new_taipei_city_dashboard/long_term/](Taipei-City-Dashboard-DE/dags/proj_new_taipei_city_dashboard/long_term/)
- 雙北組件 config 範本：[db-sample-data/dashboardmanager-demo.sql](db-sample-data/dashboardmanager-demo.sql) 中 `dependency_aging`、`aging_workforce_trend`
- Map 設定範本：同上 `bike_network_tpe`、`bike_network_metrotaipei`
