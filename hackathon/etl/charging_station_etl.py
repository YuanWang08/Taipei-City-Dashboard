"""
雙北充電樁 ETL + Geocoding
用法：python charging_station_etl.py [--source car_ntpc|motor_ntpc|all]

流程：
1. 從 data.ntpc.gov.tw API 抓 JSON
2. 用 Nominatim (OpenStreetMap) 把地址 → 經緯度
3. 寫進 PostgreSQL（含 PostGIS POINT）

Geocode 失敗的會標 geocode_src='failed' 並用行政區中心點作 fallback，
保留資料但 demo 時記得篩 geocode_src='nominatim' 看高品質點位。
"""
import os
import re
import sys
import time
import json
import argparse
import urllib.request
import urllib.parse
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_values

# ---------------------- config ----------------------
DB = dict(
    host=os.getenv('DB_HOST', 'postgres-data'),
    port=int(os.getenv('DB_PORT', '5432')),
    user=os.getenv('DB_USER', 'postgres'),
    password=os.getenv('DB_PASSWORD', 'devpass'),
    dbname=os.getenv('DB_NAME', 'dashboard'),
)

SOURCES = {
    'car_ntpc': {
        'url': 'https://data.ntpc.gov.tw/api/datasets/1bb694e3-17c7-4ef0-ac75-52990c40edcd/json?size=1000',
        'format': 'json',
        'table': 'charging_station_car_new_tpe',
        'mapping': {
            'station_name': 'sta',
            'district':     'dis',
            'address':      'add',
            'category':     'das',
            'fee':          'fee',
            'socket_type':  'sty',
            'plug_count':   'number',
        },
    },
    'motor_ntpc': {
        'url': 'https://data.ntpc.gov.tw/api/datasets/e461bc62-34d2-42c5-a871-f2fc2fb88d01/json?size=1000',
        'format': 'json',
        'table': 'charging_station_motor_new_tpe',
        'mapping': {
            'station_name': 'charging station name',
            'district':     'administrative district',
            'address':      'location address',
            'category':     'station type',
            'status':       'operational status',
            'fee':          'fee applicable （yes/no）',
            'open_public':  'open to public（yes/no）',
            'plug_type':    'plug type',
            'plug_count':   'connector count',
        },
    },
    'restaurant_ntpc': {
        'url': 'https://data.ntpc.gov.tw/api/datasets/e90d14f8-5995-4ebb-af19-8f8fd7d396c8/json?size=2000',
        'format': 'json',
        'table': 'env_restaurant_new_tpe',
        'derive_district_from_address': True,
        'mapping': {
            'name':     'name',
            'address':  'address',
            'category': 'type',
            'phone':    'localcallservice',
        },
    },
    'restaurant_tpe': {
        'url': 'https://data.taipei/api/frontstage/tpeod/dataset/resource.download?rid=d706f428-b2c7-4591-9ebf-9f5cd7408f47',
        'format': 'csv',
        'table': 'env_restaurant_tpe',
        'derive_district_from_address': True,
        'mapping': {
            'name':     '餐廳名稱',
            'address':  '餐廳地址',
            'category': '餐廳類別',
            'phone':    '餐廳電話',
            'eco_tags': '額外環保作為',
        },
    },
    # ---- 台北充電樁 (汽車) ----
    'car_tpe_a': {
        'url': 'https://data.taipei/api/frontstage/tpeod/dataset/resource.download?rid=739cec36-ed1b-4b92-b1f3-ffadf05fe6c7',
        'format': 'csv',
        'encoding': 'big5',
        'table': 'charging_station_car_tpe',
        'truncate': True,
        'derive_district_from_address': True,
        'mapping': {
            'station_name': '名稱',
            'address':      '地址',
            'category':     '廠商',
        },
    },
    # ---- 台北充電樁 (機車) ----
    # 三個 CSV 灌進同一張表（後兩個 append）
    'motor_tpe_a': {
        'url': 'https://data.taipei/api/frontstage/tpeod/dataset/resource.download?rid=eff59f75-4a84-463d-adbe-59446dbf94c8',
        'format': 'csv',
        'encoding': 'utf-8-sig',
        'table': 'charging_station_motor_tpe',
        'truncate': True,
        'derive_district_from_address': True,
        'mapping': {
            'station_name': '單位',
            'district':     '行政區',
            'address':      '地址',
            'category':     '備註',
        },
    },
    'motor_tpe_b': {
        'url': 'https://data.taipei/api/frontstage/tpeod/dataset/resource.download?rid=c940eb09-c131-46e5-837c-5c96e7897253',
        'format': 'csv',
        'encoding': 'big5',
        'table': 'charging_station_motor_tpe',
        'truncate': False,
        'derive_district_from_address': True,
        'mapping': {
            'station_name': '名稱',
            'address':      '地址',
            'category':     '廠商',
        },
    },
    'motor_tpe_c': {
        'url': 'https://data.taipei/api/frontstage/tpeod/dataset/resource.download?rid=c0f07b6c-ff55-4fae-a390-ddfe9374d4d7',
        'format': 'csv',
        'encoding': 'big5',
        'table': 'charging_station_motor_tpe',
        'truncate': False,
        'derive_district_from_address': True,
        'mapping': {
            'station_name': '名稱',
            'address':      '地址',
            'category':     '廠商',
        },
    },
}

# 從地址抽出行政區，例如「臺北市松山區敦化北路…」→「松山區」
DISTRICT_RE = re.compile(r'.+?[市縣](.+?區)')

# 行政區中心點（fallback 給 geocode 失敗的）
NTPC_DISTRICT_CENTROID = {
    '板橋區': (25.0117, 121.4587), '三重區': (25.0612, 121.4866),
    '中和區': (24.9999, 121.4985), '永和區': (25.0073, 121.5141),
    '新莊區': (25.0359, 121.4524), '新店區': (24.9676, 121.5419),
    '土城區': (24.9722, 121.4434), '蘆洲區': (25.0848, 121.4730),
    '樹林區': (24.9909, 121.4209), '汐止區': (25.0691, 121.6420),
    '鶯歌區': (24.9544, 121.3543), '三峽區': (24.9342, 121.3691),
    '淡水區': (25.1697, 121.4406), '瑞芳區': (25.1095, 121.8108),
    '五股區': (25.0825, 121.4382), '泰山區': (25.0594, 121.4309),
    '林口區': (25.0772, 121.3917), '深坑區': (25.0023, 121.6157),
    '石碇區': (24.9914, 121.6586), '坪林區': (24.9374, 121.7113),
    '三芝區': (25.2587, 121.5012), '石門區': (25.2901, 121.5680),
    '八里區': (25.1466, 121.3984), '平溪區': (25.0258, 121.7397),
    '雙溪區': (25.0353, 121.8651), '貢寮區': (25.0226, 121.9081),
    '金山區': (25.2229, 121.6362), '萬里區': (25.1779, 121.6892),
    '烏來區': (24.8651, 121.5511),
}

# ---------------------- helpers ----------------------
import csv
import io

def fetch_records(url, fmt='json', encoding=None, retries=3):
    """從政府 API 抓 JSON 或 CSV，回傳 list of dict"""
    req = urllib.request.Request(url, headers={'User-Agent': 'hackathon-2026/1.0'})
    for i in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
            if fmt == 'csv':
                enc = encoding or 'utf-8-sig'
                text = raw.decode(enc, errors='replace')
                return list(csv.DictReader(io.StringIO(text)))
            return json.loads(raw.decode(encoding or 'utf-8'))
        except Exception as e:
            print(f"  fetch retry {i+1}: {e}")
            time.sleep(2)
    raise RuntimeError(f"fetch failed: {url}")


import re
# Taiwan address parser
ADDR_RE = re.compile(r'^(?P<city>.+?[市縣])(?P<district>.+?區)(?P<rest>.+)$')
HOUSE_RE = re.compile(r'(\d+巷)?(\d+弄)?(\d+(-\d+)?號)?(\d+樓.*)?$')

def parse_addr(addr):
    """把『新北市八里區博物館路200號』拆成 (路名, 區, 市)"""
    m = ADDR_RE.match(addr.strip())
    if not m:
        return None
    rest = m.group('rest')
    # 砍掉門牌 / 巷弄
    street = HOUSE_RE.sub('', rest).strip()
    # 砍掉路名後面的「之 N」之類
    street = re.sub(r'之\d+.*$', '', street).strip()
    return street, m.group('district'), m.group('city')

def _photon(query):
    q = urllib.parse.quote(query)
    url = f"https://photon.komoot.io/api/?q={q}&limit=1&lang=default"
    req = urllib.request.Request(url, headers={'User-Agent': 'hackathon-2026/1.0'})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode('utf-8'))

def geocode(address, cache):
    """用 Photon (OSM-based, 寬鬆 rate limit)。
    Taiwan 地址需要用『路名, 區, 市』comma-separated 才查得到。"""
    if address in cache:
        return cache[address]

    parsed = parse_addr(address)
    if not parsed:
        return (None, None, 'failed')
    street, district, city = parsed

    # 候選 query (從具體到抽象)
    candidates = [
        f"{street}, {district}, {city}",
        f"{street}, {city}",
        f"{district}, {city}",
    ]

    for cand in candidates:
        try:
            data = _photon(cand)
            time.sleep(0.4)  # Photon 寬鬆，不用 1s
            feats = data.get('features', [])
            if feats:
                # Photon 的 country filter
                if feats[0].get('properties', {}).get('countrycode') != 'TW':
                    continue
                lng, lat = feats[0]['geometry']['coordinates']
                cache[address] = (float(lat), float(lng), 'photon')
                return cache[address]
        except Exception as e:
            print(f"  geocode error on '{cand}': {e}")
            time.sleep(1.0)

    return (None, None, 'failed')


def to_int(x):
    try:
        return int(str(x).strip())
    except Exception:
        return None


# ---------------------- main pipeline ----------------------
def extract_district(addr):
    m = DISTRICT_RE.match(addr)
    return m.group(1) if m else ''

def run(source_key, conn, cache):
    cfg = SOURCES[source_key]
    derive_district = cfg.get('derive_district_from_address', False)
    truncate = cfg.get('truncate', True)
    print(f"\n=== Loading {source_key} from {cfg['url']} ===")
    rows = fetch_records(cfg['url'], fmt=cfg.get('format', 'json'), encoding=cfg.get('encoding'))
    print(f"  fetched {len(rows)} records (truncate={truncate})")

    # 1. geocode all addresses
    print(f"  geocoding {len(rows)} addresses (this takes ~{len(rows)} sec)...")
    geocoded = []
    failed_count = 0
    for i, row in enumerate(rows, 1):
        addr = (row.get(cfg['mapping']['address']) or '').strip()
        if not addr:
            continue
        # district: 從欄位取 or 從地址抽
        if derive_district:
            district = extract_district(addr)
        else:
            district = (row.get(cfg['mapping'].get('district', '')) or '').strip()

        lat, lng, src = geocode(addr, cache)

        # fallback to district centroid
        if src == 'failed' and district in NTPC_DISTRICT_CENTROID:
            lat, lng = NTPC_DISTRICT_CENTROID[district]
            src = 'district_centroid'
            failed_count += 1

        if lat is None:
            failed_count += 1
            continue

        # build row dict
        record = {col: row.get(src_col) for col, src_col in cfg['mapping'].items()}
        if derive_district:
            record['district'] = district
        record['_lat'] = lat
        record['_lng'] = lng
        record['_geocode_src'] = src
        geocoded.append(record)

        if i % 25 == 0 or i == len(rows):
            print(f"    {i}/{len(rows)} done (failed/fallback so far: {failed_count})")

    # 2. insert
    print(f"  inserting {len(geocoded)} rows into {cfg['table']}...")
    with conn.cursor() as cur:
        if truncate:
            cur.execute(f"TRUNCATE {cfg['table']} RESTART IDENTITY")

        all_cols = list(cfg['mapping'].keys())
        if derive_district and 'district' not in all_cols:
            all_cols.append('district')
        col_sql = ', '.join(all_cols + ['geometry', 'geocode_src'])
        placeholders = ', '.join(['%s'] * len(all_cols)) + ', ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s'

        for r in geocoded:
            values = [r.get(c) for c in all_cols]
            # plug_count to int
            if 'plug_count' in all_cols:
                idx = all_cols.index('plug_count')
                values[idx] = to_int(values[idx])
            values += [r['_lng'], r['_lat'], r['_geocode_src']]
            cur.execute(f"INSERT INTO {cfg['table']} ({col_sql}) VALUES ({placeholders})", values)
        conn.commit()

    # 3. summary
    with conn.cursor() as cur:
        cur.execute(f"SELECT geocode_src, COUNT(*) FROM {cfg['table']} GROUP BY geocode_src")
        for src, cnt in cur.fetchall():
            print(f"    {src}: {cnt}")

    return len(geocoded), failed_count


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', default='all', choices=list(SOURCES.keys()) + ['all'])
    args = ap.parse_args()

    cache_path = Path('/data/geocode_cache.json')
    cache = {}
    if cache_path.exists():
        cache = {k: tuple(v) for k, v in json.loads(cache_path.read_text()).items()}
        print(f"loaded geocode cache: {len(cache)} entries")

    conn = psycopg2.connect(**DB)

    sources = list(SOURCES.keys()) if args.source == 'all' else [args.source]
    total_inserted = 0
    total_failed = 0
    try:
        for src in sources:
            ins, fail = run(src, conn, cache)
            total_inserted += ins
            total_failed += fail
    finally:
        # save cache
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(cache, ensure_ascii=False, indent=2))
        conn.close()

    print(f"\n=== Done. inserted={total_inserted}, failed/fallback={total_failed} ===")


if __name__ == '__main__':
    main()
