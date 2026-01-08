# API Standards - NYC Open Data Integration

外部API（NYC Open Data Socrata API）統合のパターンと規約を定義します。

## Philosophy

- **増分取得優先**: 全データではなく、差分のみを効率的に取得
- **冪等性の保証**: 同じリクエストを複数回実行しても安全
- **レート制限への配慮**: APIプロバイダーの制限を尊重
- **エラー時の透明性**: 失敗時の詳細なログと適切なリトライ

## NYC Open Data Socrata API (SODA)

### Endpoint Pattern

```
https://data.cityofnewyork.us/resource/{dataset_id}.json
```

**例**:
- 311サービスリクエスト: `https://data.cityofnewyork.us/resource/erm2-nwe9.json`

### Authentication

**App Token方式（推奨）**:
```python
headers = {
    "X-App-Token": os.environ.get("NYC_OPENDATA_APP_TOKEN")
}
```

- トークンはSecret Managerで管理
- 環境変数経由でCloud Functionに注入
- **レート制限**: App Token使用で1,000 req/day → 無制限に緩和

### 増分データ取得パターン

**`$where` クエリパラメータ**で時刻ベースフィルタリング:

```python
# 最終取得時刻以降のデータのみ取得
params = {
    "$where": f"created_date > '{last_fetch_time}'",
    "$limit": 1000,
    "$order": "created_date ASC"
}
response = requests.get(endpoint, params=params, headers=headers)
```

**ポイント**:
- `created_date` フィールドで時系列ソート
- `$limit` でページングサイズ制御（デフォルト1,000、最大50,000）
- `$order` で古い順に取得（処理順序の保証）

### 状態管理

**最終取得時刻の保存**:
```python
# Cloud Storageに保存
bucket = storage_client.bucket("state-bucket")
blob = bucket.blob("last_fetch_time.txt")
blob.upload_from_string(datetime.now(timezone.utc).isoformat())
```

**初回実行時**:
- 状態ファイルが存在しない場合は、過去24時間分を取得
- または設計上の開始日時を使用

### Request/Response

**リクエスト例**:
```http
GET /resource/erm2-nwe9.json?$where=created_date>'2025-01-08T10:00:00'&$limit=1000
Host: data.cityofnewyork.us
X-App-Token: YOUR_APP_TOKEN
```

**レスポンス形式**:
```json
[
  {
    "unique_key": "12345678",
    "created_date": "2025-01-08T10:05:23.000",
    "agency": "NYPD",
    "complaint_type": "Noise - Street/Sidewalk",
    "latitude": "40.7128",
    "longitude": "-74.0060",
    ...
  },
  ...
]
```

**特徴**:
- JSON配列形式（オブジェクトのリスト）
- フィールド名はsnake_case
- タイムスタンプはISO 8601形式
- null値が含まれる可能性あり

## Data Transformation Pattern

### API → BigQuery スキーママッピング

**変換処理（Cloud Function内）**:
```python
def transform_record(api_record):
    """NYC Open Data API → BigQuery形式に変換"""
    return {
        "unique_key": api_record.get("unique_key"),
        "created_date": api_record.get("created_date"),
        "closed_date": api_record.get("closed_date"),
        "agency": api_record.get("agency"),
        "complaint_type": api_record.get("complaint_type"),
        "descriptor": api_record.get("descriptor"),
        "location_type": api_record.get("location_type"),
        "incident_zip": api_record.get("incident_zip"),
        "incident_address": api_record.get("incident_address"),
        "latitude": float(api_record.get("latitude")) if api_record.get("latitude") else None,
        "longitude": float(api_record.get("longitude")) if api_record.get("longitude") else None,
        "status": api_record.get("status"),
        "borough": api_record.get("borough"),
        # パーティション日付を追加
        "partition_date": datetime.fromisoformat(api_record.get("created_date")).date().isoformat(),
        # 取り込み時刻を追加
        "ingestion_timestamp": datetime.now(timezone.utc).isoformat()
    }
```

**変換の原則**:
- フィールド名はそのまま維持（BigQueryスキーマと一致）
- データ型変換（文字列→数値、タイムスタンプ）
- null値の適切な処理（`.get()` でデフォルトNone）
- メタデータ追加（partition_date、ingestion_timestamp）

## Error Handling & Retry

### HTTP Status Codes

**成功**:
- `200 OK`: データ取得成功（空配列も含む）

**クライアントエラー（4xx）**:
- `400 Bad Request`: クエリパラメータが不正 → **リトライしない**
- `401 Unauthorized`: App Tokenが無効 → **リトライしない、アラート**
- `403 Forbidden`: アクセス権限なし → **リトライしない、アラート**
- `429 Too Many Requests`: レート制限 → **エクスポネンシャルバックオフでリトライ**

**サーバーエラー（5xx）**:
- `500 Internal Server Error`: → **リトライ（最大3回）**
- `503 Service Unavailable`: → **リトライ（最大3回）**

### Retry Strategy

```python
import time
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

# リトライ設定
retry_strategy = Retry(
    total=3,
    status_forcelist=[429, 500, 502, 503, 504],
    backoff_factor=2,  # 2秒、4秒、8秒
    allowed_methods=["GET"]
)
adapter = HTTPAdapter(max_retries=retry_strategy)
session = requests.Session()
session.mount("https://", adapter)
```

**ポイント**:
- GETメソッドのみリトライ（冪等性）
- エクスポネンシャルバックオフ（2秒→4秒→8秒）
- 最大3回リトライ後に失敗とする

### Logging Pattern

```python
import logging
from google.cloud import logging as cloud_logging

# 構造化ロギング
logger = logging.getLogger(__name__)

# API呼び出し前
logger.info(
    "Fetching data from NYC Open Data",
    extra={
        "dataset_id": dataset_id,
        "last_fetch_time": last_fetch_time,
        "params": params
    }
)

# エラー時
logger.error(
    "API request failed",
    extra={
        "status_code": response.status_code,
        "error_message": response.text,
        "retry_count": retry_count
    },
    exc_info=True
)
```

## Rate Limiting & Throttling

### Socrata API Limits

- **App Tokenなし**: 1,000 requests/day
- **App Token使用**: 無制限（実質的に）
- **推奨**: App Tokenを必ず使用

### Throttling Strategy

```python
# Cloud Schedulerで実行頻度を制御
# 設定: 5分毎（1日288回）
# → App Token使用で十分余裕あり
```

**ポイント**:
- Cloud Schedulerで実行頻度を調整
- 必要に応じて実行間隔を変更可能（1分〜60分）
- App Token使用で基本的にレート制限は心配不要

## Timeout Configuration

```python
# リクエストタイムアウト設定
TIMEOUT = (3.05, 27)  # (connection timeout, read timeout)

response = requests.get(
    endpoint,
    params=params,
    headers=headers,
    timeout=TIMEOUT
)
```

**Cloud Function制約**:
- 第2世代: 最大60分のタイムアウト
- 通常のAPI取得: 30秒以内で完了
- 大量データ: ページング処理で分割

## Testing Pattern

### Local Development

```python
# モックレスポンス
def mock_nyc_api_response():
    return [
        {
            "unique_key": "test123",
            "created_date": "2025-01-08T10:00:00.000",
            "agency": "TEST",
            ...
        }
    ]

# ユニットテスト
def test_transform_record():
    api_record = mock_nyc_api_response()[0]
    bq_record = transform_record(api_record)
    assert bq_record["unique_key"] == "test123"
    assert "partition_date" in bq_record
```

### Integration Testing

- NYC Open Data APIのテストエンドポイント使用
- 少量データ（`$limit=10`）で動作確認
- タイムアウト、リトライロジックの検証

---

**参考資料**:
- Socrata API Docs: https://dev.socrata.com/
- NYC Open Data: https://opendata.cityofnewyork.us/

_Document patterns and decisions, not implementation details._

