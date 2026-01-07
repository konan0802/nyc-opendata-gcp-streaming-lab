# Technology Stack

## Architecture

**完全サーバーレスストリーミングETLアーキテクチャ**

```
NYC Open Data API → Cloud Functions → Pub/Sub → BigQuery
                         ↓
                  Cloud Storage (状態管理)
```

- データ取得: Cloud Scheduler + Cloud Functions（定期実行）
- メッセージキュー: Pub/Sub + BigQuery Subscription（直接書き込み）
- データウェアハウス: BigQuery（パーティショニング・クラスタリング）
- インフラ管理: Terraform（IaC）

## Core Technologies

- **Language**: Python 3.11+
- **Cloud Platform**: Google Cloud Platform (GCP)
- **IaC**: Terraform
- **API**: NYC Open Data Socrata API (SODA)

## Key Libraries

### Python Dependencies（予定）
- `google-cloud-pubsub`: Pub/Subクライアント
- `google-cloud-storage`: 状態管理（最終取得時刻）
- `requests`: NYC Open Data API呼び出し

### GCP Services
- **Cloud Functions（第2世代）**: データ取得とパブリッシュ
- **Cloud Scheduler**: 定期実行トリガー（5分毎）
- **Pub/Sub**: メッセージキュー、BigQuery Subscription
- **BigQuery**: データウェアハウス
- **Cloud Storage**: 状態管理、バックアップ
- **Secret Manager**: APIトークン管理
- **Cloud Logging / Monitoring**: ログ・モニタリング

## Development Standards

### Code Quality
- 構造化ロギング（Cloud Logging統合）
- エラーハンドリングとリトライロジック
- 最小権限の原則（IAM設計）

### Infrastructure as Code
- **すべてのGCPリソースをTerraformで管理**
- モジュール構成（bigquery, pubsub, cloud-function, monitoring）
- 環境分離（dev/prod）

## Development Environment

### Required Tools
- Python 3.11+
- gcloud CLI
- Terraform

### Common Commands（予定）
```bash
# Terraform: terraform plan / terraform apply
# Cloud Functions Deploy: gcloud functions deploy
# Test: pytest
```

## Key Technical Decisions

### ETL処理層の省略
- Cloud FunctionでBigQueryスキーマに合わせてデータを整形
- Pub/Sub BigQuery Subscriptionで直接書き込み
- 追加のETL処理レイヤー（DataflowやCloud Run）は不使用
- **メリット**: 実装のシンプル化、コスト削減（月額$2程度）

### 増分データ取得
- Socrata SODA APIの `$where` パラメータで増分取得
- 最終取得時刻をCloud Storageで管理
- 重複データはBigQueryのunique_keyで管理

### BigQuery最適化
- 日付ベースのパーティショニング（コスト削減、クエリ高速化）
- borough, agency, complaint_typeでクラスタリング
- ストリーミングバッファによる即時クエリ可能

---
_Document standards and patterns, not every dependency_

