# Project Structure

## Organization Philosophy

**実験・学習用プロジェクト、実装開始段階**

- 単一環境（検証用GCPプロジェクト）でのシンプルな構成
- Terraformセットアップ完了、インフラリソース作成前
- Cloud Functions実装は未着手

## Directory Patterns

### Terraform Infrastructure
**Location**: `/terraform/`  
**Purpose**: GCPリソースのIaC定義  
**Structure**:
```
terraform/
├── main.tf           # メインリソース定義
├── variables.tf      # 変数定義（今後追加）
├── terraform.tfvars  # 変数の値
├── outputs.tf        # 出力定義（今後追加）
└── .terraform/       # Terraformの内部ファイル（自動生成）
```

**設計判断**:
- **単一環境プロジェクト**: dev/prod分離は不要（検証用プロジェクト）
- **フラット構造**: シンプルさを優先、複雑化を避ける
- **将来的な拡張**: 必要に応じて `modules/` ディレクトリを追加可能

**サービスアカウント管理**:
- Terraform実行用: `~/.gcp/terraform-sa-{PROJECT_ID}.json`（手動作成）
- その他のサービスアカウント: Terraformで管理

### Cloud Functions（予定）
**Location**: `/functions/` または `/src/`  
**Purpose**: データ取得・整形・パブリッシュロジック  
**Pattern**: Python 3.11+ モジュール構成

### Documentation
**Location**: ルートディレクトリ  
**Files**:
- `README.md`: プロジェクト概要
- `BACKLOG.md`: 実装タスク・コスト見積もり・運用計画
- `AGENTS.md`: AI-DLC / Kiroワークフロー説明

### Specifications
**Location**: `.kiro/specs/`  
**Purpose**: Feature単位の詳細仕様  
**Pattern**: 各featureは独立したディレクトリで管理（requirements, design, tasks）

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

