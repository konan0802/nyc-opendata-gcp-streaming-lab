# NYC OpenData GCP ストリーミングETL システム設計

## 1. システム概要

NYC Open Dataからリアルタイムデータを取得し、Google Cloud Platform（GCP）上でストリーミング処理を行い、BigQueryに格納するETLパイプラインを構築します。

### 目的
- NYC Open DataのAPIから継続的にデータを取得
- リアルタイムでデータを変換・加工
- BigQueryに格納し、分析可能な状態にする
- スケーラブルで信頼性の高いデータパイプラインの構築

### 対象データ例
- 311サービスリクエスト（苦情、問い合わせ等）
- リアルタイム交通データ
- 駐車違反データ
- その他NYC Open Dataで提供されるストリーミング可能なデータセット

## 2. システムアーキテクチャ

```
┌─────────────────┐
│  NYC Open Data  │
│   API (SODA)    │
└────────┬────────┘
         │ HTTP/REST(Polling)
         ▼
┌─────────────────┐
│   Data Fetcher  │
│ (Cloud Function)│
└────────┬────────┘
         │ Publish
         ▼
┌─────────────────┐
│   Pub/Sub       │
│   (Message      │
│    Queue)       │
└────────┬────────┘
         │ BigQuery Subscription(Direct Write)
         ▼
┌─────────────────┐
│   BigQuery      │
│  (Data Warehouse)│
└─────────────────┘
```

## 3. コンポーネント詳細

### 3.1 Data Fetcher（データ取得層）

**実装: Cloud Functions（第2世代）**

- **トリガー**: Cloud Scheduler（定期実行）
- **処理内容**:
  - NYC Open Data APIにリクエスト送信（Socrata SODA API）
  - 増分データの取得（最終取得時刻以降のデータ）
  - BigQueryスキーマに合わせてJSONを整形
  - Pub/Subトピックにパブリッシュ
  - エラーハンドリングとリトライロジック
- **タイムアウト**: 最大9分（通常のAPI取得では十分）
- **メモリ**: 256MB〜512MB
- **実行頻度**: 5分毎（Cloud Scheduler経由）

**メリット**:
- シンプルな実装
- 完全なサーバーレス
- 従量課金で低コスト
- 自動スケーリング

### 3.2 Pub/Sub（メッセージキュー層）

**役割**:
- Data Fetcherからのデータ受信とバッファリング
- BigQueryへの直接配信（ETL処理層なし）
- 高可用性とスケーラビリティの確保

**設定**:
- **トピック**: `nyc-opendata-raw`
  - Cloud Functionがメッセージをパブリッシュ
- **BigQuery Subscription**: `nyc-opendata-to-bigquery`
  - タイプ: BigQuery Subscription（直接書き込み）
  - ターゲット: BigQueryテーブル
  - JSONメッセージがそのままBigQueryに挿入される
  - **コード実装不要** - Pub/Subの設定のみで完結
- **メッセージ保持期間**: 7日間（デフォルト）
- **Dead Letter Topic**: エラーハンドリング用

> **注**: 本プロジェクトでは**ETL処理層を設けません**。Cloud FunctionがBigQueryスキーマに合わせてデータを整形し、Pub/Sub経由でBigQueryに直接書き込みます。

**変換処理が必要になった場合の代替案**:
- Cloud Run: 軽量な変換処理（月額+$1-2）
- Dataflow: 複雑なストリーム処理（月額+$50-100）

### 3.3 BigQuery（データウェアハウス層）

**テーブル設計例**:
```sql
-- 例: 311サービスリクエストテーブル
CREATE TABLE `project.dataset.service_requests` (
  unique_key STRING NOT NULL,
  created_date TIMESTAMP NOT NULL,
  closed_date TIMESTAMP,
  agency STRING,
  complaint_type STRING,
  descriptor STRING,
  location_type STRING,
  incident_zip STRING,
  incident_address STRING,
  latitude FLOAT64,
  longitude FLOAT64,
  status STRING,
  borough STRING,
  ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  -- パーティショニングキー
  partition_date DATE NOT NULL
)
PARTITION BY partition_date
CLUSTER BY borough, agency, complaint_type;
```

**最適化戦略**:
- **パーティショニング**: 日付ベース（コスト削減、クエリ高速化）
- **クラスタリング**: 頻繁にフィルタする列（borough, agency等）
- **ストリーミングバッファ**: データは数秒以内にクエリ可能

## 4. データフロー

### 4.1 通常フロー

1. **データ取得（Cloud Function）**
   - Cloud Schedulerが5分毎にCloud Functionをトリガー
   - Cloud FunctionがNYC Open Data APIを呼び出し
   - `$where` パラメータで増分データのみ取得（例: `created_date > '2025-12-07T10:00:00'`）
   - 最終取得時刻はCloud StorageまたはFirestoreで管理

2. **データ整形とパブリッシュ（Cloud Function）**
   - 取得したレコードをBigQueryスキーマに合わせて整形
     - フィールド名の変換（必要に応じて）
     - データ型の変換（文字列、数値、タイムスタンプなど）
     - パーティション日付フィールドの追加
   - JSON形式でシリアライズ
   - Pub/Subトピックにパブリッシュ（個別メッセージとして送信）
   - メッセージ属性に取得時刻などのメタデータを追加

3. **直接書き込み（Pub/Sub BigQuery Subscription）**
   - Pub/SubがBigQuery Subscriptionを通じて自動的にメッセージを処理
   - JSONメッセージがBigQueryテーブルに直接挿入される
   - スキーマが一致していればエラーなく挿入完了
   - スキーマミスマッチの場合はDead Letter Topicに送信

4. **データ格納完了**
   - BigQueryに即座にデータが反映（数秒以内）
   - パーティショニングとクラスタリングが自動適用
   - 重複はBigQueryのDML（MERGE文）で後処理、またはunique_keyで管理

### 4.2 エラーハンドリング

1. **API取得エラー**
   - リトライロジック（エクスポネンシャルバックオフ）
   - Cloud Loggingに詳細ログ出力
   - アラート送信（Cloud Monitoring）

2. **Pub/Sub処理エラー**
   - Dead Letter Topicに送信
   - エラー内容をBigQuery別テーブルに記録
   - 手動リトライ用のメカニズム

3. **BigQuery挿入エラー**
   - スキーマミスマッチの場合はログ記録
   - Cloud Storageにバックアップ保存
   - アラート送信

## 5. 技術スタック

### GCPサービス
- **Cloud Scheduler**: 定期実行トリガー
- **Cloud Functions（第2世代）**: データ取得とパブリッシュ
- **Pub/Sub**: メッセージキュー、BigQuery Subscription
- **BigQuery**: データウェアハウス
- **Cloud Storage**: 状態管理（最終取得時刻）、バックアップ
- **Secret Manager**: APIトークン管理
- **Cloud Logging**: ログ管理
- **Cloud Monitoring**: モニタリング、アラート

### 開発言語・フレームワーク
- **Python 3.11+**: メイン開発言語
  - `requests`: API呼び出し
  - `google-cloud-pubsub`: Pub/Subクライアント
  - `google-cloud-storage`: 状態管理
- **Terraform**: インフラストラクチャのコード化（IaC）

### API
- **NYC Open Data Socrata API (SODA)**: データ取得元
  - エンドポイント例: `https://data.cityofnewyork.us/resource/erm2-nwe9.json`
  - 認証: App Token（レート制限緩和）

## 6. インフラストラクチャ管理

### Infrastructure as Code (IaC)

**本プロジェクトではすべてのGCPリソースをTerraformで管理します。**

**管理対象リソース**:
- BigQuery データセット・テーブル
- Pub/Sub トピック・サブスクリプション
- Cloud Functions
- Cloud Scheduler ジョブ
- Cloud Storage バケット
- Secret Manager シークレット
- IAM サービスアカウント・ロール
- Cloud Monitoring アラート

**メリット**:
- インフラの変更履歴管理（Git）
- 環境の再現性（dev/staging/prod）
- レビュープロセスの適用
- ドキュメントとしての役割

**ディレクトリ構成**:
```
terraform/
├── modules/
│   ├── bigquery/
│   ├── pubsub/
│   ├── cloud-function/
│   └── monitoring/
├── environments/
│   ├── dev/
│   └── prod/
└── variables.tf
```

## 7. セキュリティ考慮事項

### 認証・認可
- NYC Open Data APIトークンはSecret Managerで管理
- サービスアカウントは最小権限の原則に従う
- IAMロールの適切な設定（Terraformで管理）

### データ保護
- 転送中の暗号化（HTTPS、TLS）
- 保管時の暗号化（BigQueryデフォルトで有効）
- 個人情報（PII）が含まれる場合はマスキング処理

### ネットワーク
- VPCネットワーク構成（本番環境）
- Private Google Accessの有効化
- Cloud Armorによる保護（必要に応じて）

## 8. 参考資料

### NYC Open Data
- API ドキュメント: https://dev.socrata.com/
- データセット一覧: https://opendata.cityofnewyork.us/

### GCP ドキュメント
- Pub/Sub: https://cloud.google.com/pubsub/docs
- BigQuery Streaming: https://cloud.google.com/bigquery/streaming-data-into-bigquery
- Cloud Functions: https://cloud.google.com/functions/docs
- Terraform GCP Provider: https://registry.terraform.io/providers/hashicorp/google/latest/docs

---

**最終更新**: 2025-12-07  
**ステータス**: 草案
