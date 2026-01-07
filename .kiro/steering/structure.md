# Project Structure

## Organization Philosophy

**設計ドキュメント中心、実装未着手の実験プロジェクト**

- 現状: ドキュメント（設計・実装計画）とサンプルデータのみ
- 今後: Terraformによるインフラ定義と、Cloud Functions実装を予定

## Directory Patterns

### Terraform Infrastructure（予定）
**Location**: `/terraform/`  
**Purpose**: GCPリソースのIaC定義  
**Structure**:
```
terraform/
├── modules/           # 再利用可能なモジュール
│   ├── bigquery/
│   ├── pubsub/
│   ├── cloud-function/
│   └── monitoring/
└── environments/      # 環境別設定
    ├── dev/
    └── prod/
```

### Cloud Functions（予定）
**Location**: `/functions/` または `/src/`  
**Purpose**: データ取得・整形・パブリッシュロジック  
**Pattern**: Python 3.11+ モジュール構成

### Documentation
**Location**: ルートディレクトリ  
**Files**:
- `README.md`: プロジェクト概要
- `DESIGN.md`: システム設計詳細
- `IMPLEMENTATION.md`: 実装計画・コスト見積もり
- `AGENTS.md`: AI-DLC / Kiroワークフロー説明

### Data
**Location**: ルートディレクトリ  
**Example**: `311_Service_Requests_from_2020_to_Present_20260105.csv`  
**Purpose**: サンプルデータ、スキーマ検証用

## Naming Conventions

- **Terraformファイル**: `main.tf`, `variables.tf`, `outputs.tf`
- **Pythonファイル**: snake_case（例: `data_fetcher.py`）
- **GCPリソース名**: kebab-case（例: `nyc-opendata-raw`）

## Import Organization（Python予定）

```python
# 標準ライブラリ
import json
import os
from datetime import datetime

# サードパーティ
import requests
from google.cloud import pubsub_v1, storage

# プロジェクト内モジュール
from utils import logger
```

## Code Organization Principles

### Infrastructure as Code
- すべてのGCPリソースをTerraformで定義
- 環境変数や秘匿情報はSecret Managerで管理
- モジュール単位での再利用性を重視

### Serverless-First
- Cloud Functions: データ取得・パブリッシュ
- Pub/Sub: 非同期メッセージング
- BigQuery: データストレージ
- 状態管理はCloud Storageで最小限に

### Minimal ETL
- 変換処理はCloud Function内で完結
- Pub/Sub BigQuery Subscriptionで直接書き込み
- DataflowやCloud Runは不使用（シンプルさとコスト重視）

---
_Document patterns, not file trees. New files following patterns shouldn't require updates_

