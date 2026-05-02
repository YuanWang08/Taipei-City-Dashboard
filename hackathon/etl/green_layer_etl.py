"""下載行道樹 + 公園資料，TWD97 轉 WGS84，輸出 GeoJSON"""
import json
import urllib.request
from pathlib import Path
from pyproj import Transformer

OUT_DIR = Path('/out')
OUT_DIR.mkdir(parents=True, exist_ok=True)

# TWD97 (EPSG:3826) → WGS84 (EPSG:4326)
transformer = Transformer.from_crs('EPSG:3826', 'EPSG:4326', always_xy=True)

def download(url, label):
    print(f'  fetching {label}...')
    req = urllib.request.Request(url, headers={'User-Agent': 'hackathon-2026/1.0'})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()

# ============================================================
# 行道樹：12 萬筆 JSON, TWD97 X/Y 座標
# ============================================================
print('=== 行道樹 ===')
raw = json.loads(download(
    'https://tppkl.blob.core.windows.net/blobfs/TaipeiTree.json',
    '行道樹 JSON 24MB'
))
print(f'  total records: {len(raw)}')
print(f'  sample keys: {list(raw[0].keys())[:10]}')

features = []
skip = 0
for r in raw:
    try:
        # TaipeiTree 欄位常見：X, Y (TWD97), TreeID, district, species, ...
        x = float(r.get('TWD97X') or r.get('X') or 0)
        y = float(r.get('TWD97Y') or r.get('Y') or 0)
        if not x or not y:
            skip += 1
            continue
        lng, lat = transformer.transform(x, y)
        if not (120 < lng < 122.5 and 23.5 < lat < 26):
            skip += 1
            continue
        # 只保留必要欄位減小檔案
        features.append({
            'type': 'Feature',
            'geometry': {'type': 'Point', 'coordinates': [round(lng, 6), round(lat, 6)]},
            'properties': {
                'd': r.get('Dist') or r.get('district') or '',
                's': r.get('TreeType') or '',
                'h': r.get('TreeHeight') or 0,
            }
        })
    except Exception:
        skip += 1

print(f'  geocoded: {len(features)}, skipped: {skip}')
out = {'type': 'FeatureCollection', 'features': features}
out_path = OUT_DIR / 'street_tree_tpe.geojson'
out_path.write_text(json.dumps(out, ensure_ascii=False))
print(f'  -> {out_path} ({out_path.stat().st_size // 1024} KB)')

# ============================================================
# 公園綠地：GeoJSON 1MB, MultiPolygon TWD97
# ============================================================
print('\n=== 公園綠地 ===')
park = json.loads(download(
    'https://data.taipei/api/frontstage/tpeod/dataset/resource.download?rid=f3ce4bb6-712a-41ae-902b-f8a6099eac85',
    '公園 GeoJSON 1MB'
))
print(f'  features: {len(park.get("features", []))}')

def transform_coords(coords):
    """遞迴把座標陣列從 TWD97 轉 WGS84"""
    if isinstance(coords[0], (int, float)):
        lng, lat = transformer.transform(coords[0], coords[1])
        return [round(lng, 6), round(lat, 6)]
    return [transform_coords(c) for c in coords]

new_features = []
for f in park.get('features', []):
    try:
        geom = f.get('geometry')
        if not geom or 'coordinates' not in geom:
            continue
        new_geom = {
            'type': geom['type'],
            'coordinates': transform_coords(geom['coordinates'])
        }
        # 只保留 name + 類型
        props = f.get('properties', {}) or {}
        new_features.append({
            'type': 'Feature',
            'geometry': new_geom,
            'properties': {
                'name': props.get('name') or props.get('NAME') or '公園',
                'area': props.get('area') or props.get('AREA') or 0,
            }
        })
    except Exception as e:
        print(f'  skip error: {e}')

out = {'type': 'FeatureCollection', 'features': new_features}
out_path = OUT_DIR / 'green_park_type_tpe.geojson'
out_path.write_text(json.dumps(out, ensure_ascii=False))
print(f'  -> {out_path} ({out_path.stat().st_size // 1024} KB)')

print('\n=== Done ===')
