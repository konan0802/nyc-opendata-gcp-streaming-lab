# プロジェクトバックログ

NYC OpenData GCP ストリーミングETLシステムの実装タスク、コスト見積もり、運用計画を記載します。

> **Note**: 大きなタスクは `/kiro/spec-init` でfeature specに落とし込んでから実装を開始します。

---

## 実装フェーズ概要

### Phase 1: 基本パイプライン構築（MVP）
- [ ] 環境セットアップ
- [ ] Terraformインフラ構築（**spec化推奨**: `infrastructure`）
- [ ] Data Fetcher実装（**spec化推奨**: `data-fetcher`）
- [ ] エンドツーエンドテスト

### Phase 2: 監視・運用機能追加
- [ ] モニタリング設定（**spec化推奨**: `monitoring`）
- [ ] ログ集約
- [ ] テスト強化
- [ ] ドキュメント整備

### Phase 3: 高度な機能（オプション）
- [ ] パフォーマンス最適化
- [ ] 追加機能（データ品質チェック等）
- [ ] CI/CD構築

---

## Phase 1: 基本パイプライン構築（MVP）

### 1.1 環境セットアップ

#### GCPプロジェクト初期設定
- [ ] GCPプロジェクト作成
- [ ] 必要なAPIの有効化
  - Cloud Functions API
  - Cloud Scheduler API
  - Pub/Sub API
  - BigQuery API
  - Secret Manager API
  - Cloud Storage API
- [ ] サービスアカウント作成
  - Cloud Function実行用
  - Terraform実行用

#### ローカル開発環境構築
- [ ] Python 3.11+ インストール
- [ ] gcloud CLI インストール・認証
- [ ] Terraform インストール
- [ ] NYC Open Data App Token取得

---

### 1.2 Terraformインフラ構築

> **Spec推奨**: `/kiro/spec-init "infrastructure"` で管理

#### Terraformセットアップ
- [ ] Terraformディレクトリ構成作成
  ```
  terraform/
  ├── modules/
  │   ├── bigquery/
  │   ├── pubsub/
  │   ├── cloud-function/
  │   └── monitoring/
  └── environments/
      ├── dev/
      └── prod/
  ```
- [ ] バックエンド設定（GCS）
- [ ] 変数定義ファイル作成
- [ ] `.kiro/steering/deployment.md` 作成（Terraform導入時）

#### BigQueryリソース（Terraform）
- [ ] データセット作成
- [ ] テーブルスキーマ定義
  - 311サービスリクエストテーブル
  - パーティショニング・クラスタリング設定
- [ ] エラーログテーブル作成

#### Pub/Subリソース（Terraform）
- [ ] トピック作成（`nyc-opendata-raw`）
- [ ] BigQuery Subscriptionの作成
- [ ] Dead Letter Topic設定
- [ ] IAMロール設定

#### Cloud Storageリソース（Terraform）
- [ ] 状態管理バケット作成
- [ ] バージョニング有効化

#### Secret Managerリソース（Terraform）
- [ ] NYC Open Data App Tokenシークレット作成

---

### 1.3 Data Fetcher実装

> **Spec推奨**: `/kiro/spec-init "data-fetcher"` で管理

#### Cloud Function実装（Python 3.11+）
- [ ] プロジェクト構造作成
  ```
  functions/data-fetcher/
  ├── main.py
  ├── requirements.txt
  ├── utils/
  │   ├── api_client.py
  │   ├── state_manager.py
  │   └── logger.py
  └── tests/
  ```
- [ ] NYC Open Data API統合（Socrata SODA API）
  - [ ] App Token認証
  - [ ] `$where` クエリによる増分取得
  - [ ] ページネーション処理
- [ ] 状態管理（Cloud Storage）
  - [ ] 最終取得時刻の保存・読み込み
  - [ ] 初回実行時のハンドリング
- [ ] BigQueryスキーマに合わせたJSON整形
  - [ ] フィールドマッピング
  - [ ] データ型変換
  - [ ] メタデータ追加（partition_date, ingestion_timestamp）
- [ ] Pub/Subパブリッシュ機能
  - [ ] メッセージ属性設定
  - [ ] バッチパブリッシュ
- [ ] エラーハンドリングとリトライロジック
  - [ ] エクスポネンシャルバックオフ
  - [ ] HTTPステータスコード別処理
- [ ] 構造化ロギング設定（Cloud Logging統合）

#### テスト
- [ ] ユニットテスト作成
  - [ ] API client
  - [ ] State manager
  - [ ] Data transformation
- [ ] モックレスポンス作成
- [ ] ローカルでのテスト実行

#### デプロイ（Terraform）
- [ ] Cloud Function リソース定義
- [ ] 環境変数設定
- [ ] IAMロール設定
- [ ] Cloud Scheduler作成
  - [ ] 実行間隔設定（5分毎）
  - [ ] タイムゾーン設定（America/New_York）

---

### 1.4 動作確認・テスト

- [ ] 手動トリガーテスト
  - [ ] gcloud コマンドでCloud Function実行
  - [ ] ログ確認
- [ ] エンドツーエンドテスト
  - [ ] NYC Open Data API → Cloud Function → Pub/Sub → BigQuery
  - [ ] データ整合性確認
- [ ] データフロー確認
  - [ ] BigQueryにデータが正しく挿入されているか
  - [ ] パーティション・クラスタリングが機能しているか
- [ ] エラーケーステスト
  - [ ] API障害時の挙動（リトライ確認）
  - [ ] スキーマミスマッチの処理（Dead Letter Topic確認）
  - [ ] タイムアウトのハンドリング
  - [ ] レート制限の処理

---

## Phase 2: 監視・運用機能追加

### 2.1 モニタリング設定

> **Spec推奨**: `/kiro/spec-init "monitoring"` で管理

#### Cloud Monitoring ダッシュボード作成（Terraform）
- [ ] データ取得レートメトリクス
- [ ] エラー率メトリクス
- [ ] 処理レイテンシメトリクス
- [ ] BigQuery挿入レコード数
- [ ] Pub/Subメッセージキューサイズ

#### アラート設定（Terraform）
- [ ] データ取得失敗3回連続
- [ ] 処理遅延10分以上
- [ ] エラー率5%以上
- [ ] BigQuery挿入失敗
- [ ] Dead Letter Topicメッセージ蓄積

#### 通知チャネル設定
- [ ] Email通知設定
- [ ] Slack通知設定（オプション）

---

### 2.2 ログ集約

- [ ] Cloud Logging ログシンク設定
- [ ] BigQueryへのログエクスポート
- [ ] ログベースメトリクス作成
  - [ ] エラーカウント
  - [ ] 処理時間分布

---

### 2.3 テスト強化

- [ ] ユニットテスト拡充（カバレッジ80%以上）
- [ ] インテグレーションテスト
  - [ ] Pub/Sub Emulator使用
  - [ ] BigQuery Emulator使用（可能であれば）
- [ ] 負荷テスト（大量データ）
  - [ ] 1,000レコード/回の処理確認
  - [ ] Cloud Functionタイムアウト確認

---

### 2.4 ドキュメント整備

- [ ] 運用手順書作成
  - [ ] デプロイ手順
  - [ ] 設定変更手順
- [ ] トラブルシューティングガイド作成
  - [ ] よくあるエラーと対処法
  - [ ] ログの見方
- [ ] アラート対応手順作成
  - [ ] アラート種別ごとの対応フロー

---

## Phase 3: 高度な機能（オプション）

### 3.1 最適化

#### パフォーマンスチューニング
- [ ] バッチサイズ最適化
  - [ ] Pub/Subパブリッシュのバッチサイズ調整
  - [ ] BigQuery挿入のバッファリング
- [ ] 並列処理の検討
  - [ ] 複数データセット同時取得
  - [ ] Cloud Runへの移行検討

#### コスト最適化
- [ ] BigQueryクエリ最適化
  - [ ] パーティショニング活用
  - [ ] クラスタリング最適化
- [ ] 不要なログの削減
  - [ ] ログレベル調整
  - [ ] サンプリング導入

#### アーキテクチャ改善
- [ ] Dataflow移行検討（必要に応じて）
  - [ ] 複雑な変換が必要になった場合
  - [ ] リアルタイム性が重要になった場合

---

### 3.2 追加機能

#### データ品質チェック
- [ ] スキーマバリデーション
  - [ ] 必須フィールドチェック
  - [ ] データ型検証
- [ ] 値の範囲チェック
  - [ ] 緯度経度の妥当性
  - [ ] 日付の整合性
- [ ] null値の検証
  - [ ] null許容フィールドの定義

#### データガバナンス
- [ ] データリネージ追跡
  - [ ] Data Catalog統合
- [ ] データカタログ整備
- [ ] データ保持ポリシー策定

#### 機能拡張
- [ ] 複数データソース対応
  - [ ] 複数のNYC Open Dataセット
  - [ ] 設定ファイルでデータソース管理
- [ ] リアルタイムダッシュボード（Looker Studio）
  - [ ] BigQuery接続
  - [ ] 可視化設計

---

### 3.3 技術的改善

#### CI/CD パイプライン構築
- [ ] GitHub Actions / Cloud Build選定
- [ ] 自動テスト実行
- [ ] Terraformの自動適用（staging環境）
- [ ] Cloud Functionの自動デプロイ
- [ ] 環境分離（dev/staging/prod）

#### マルチリージョン対応
- [ ] レイテンシ削減のための配置検討
- [ ] ディザスタリカバリ計画

#### 開発効率向上
- [ ] ローカル開発環境の改善
  - [ ] Pub/Sub Emulator統合
  - [ ] BigQuery Emulator統合
  - [ ] Docker Compose環境
- [ ] テスト自動化
- [ ] ドキュメント自動生成
  - [ ] APIドキュメント
  - [ ] Terraformドキュメント

---

## コスト見積もり

### 想定条件
- データ取得頻度: 5分毎（月間8,640回）
- 1回あたりのデータ量: 100レコード
- 月間総レコード数: 約86万レコード
- レコードサイズ: 平均2KB

### サービス別コスト（月間）

| サービス | 使用量 | 概算コスト (USD) |
|---------|--------|-----------------|
| Cloud Scheduler | 1ジョブ | $0.10 |
| Cloud Functions | 8,640呼び出し、各30秒 | $0.50 |
| Pub/Sub | 1.7GB転送、ストレージ | $0.60 |
| BigQuery Storage | 2GB（圧縮後） | $0.04 |
| BigQuery Streaming | 86万レコード（BigQuery Sub経由） | $0.50 |
| Cloud Storage | 状態管理ファイル | $0.01 |
| Cloud Logging | 5GB | $0.25 |
| Secret Manager | APIトークン1個 | $0.01 |
| **合計** | | **約$2/月** |

**コスト削減ポイント**:
- ETL処理層なしで非常に低コスト
- BigQuery Subscriptionで追加の処理コスト不要
- Dataflowは不使用（使用する場合+$50-100/月）

### コストアラート設定
- [ ] 月額$5を超えた場合にアラート
- [ ] 日次コストレポート

---

## 運用計画

### モニタリング指標（KPI）

| 指標 | 目標値 | アラート閾値 |
|------|--------|-------------|
| データ鮮度 | 5分以内 | 10分以上 |
| エラー率 | < 1% | > 5% |
| 処理レイテンシ | < 30秒 | > 60秒 |
| 可用性 | > 99.5% | < 99% |
| 月間コスト | $2前後 | > $5 |

### 定期メンテナンス

#### 日次
- [ ] エラーログ確認
- [ ] データ取得状況確認
- [ ] コストダッシュボード確認

#### 週次
- [ ] パフォーマンスレビュー
- [ ] コストレビュー
- [ ] Dead Letter Topicのメッセージ確認

#### 月次
- [ ] BigQueryテーブルサイズ確認
- [ ] 古いデータのアーカイブ検討
- [ ] セキュリティパッチ適用
- [ ] 依存関係更新

### バックアップ・リカバリ

#### 状態管理
- Cloud Storageに最終取得時刻を保存
- バージョニング有効化

#### データバックアップ
- BigQueryスナップショット（週次）
- 保持期間: 30日

#### リカバリ手順
1. Dead Letter Topicからメッセージ再発行
2. 手動でCloud Functionをトリガー
3. BigQueryで重複データをMERGE処理

### スケーリング戦略

**現在の設計での限界**:
- Cloud Functions: 最大60分のタイムアウト（第2世代）
- Pub/Sub: 1メッセージあたり10MB
- BigQuery Streaming: 100,000 rows/秒（十分）

**スケーリングが必要になる場合**:
- データ量が10倍以上増加 → Cloud Runへ移行
- 複雑な変換が必要 → Dataflowへ移行
- リアルタイム性が重要 → Pub/Subのパーティション数増加

---

## Kiro Spec作成タイミング

大きなタスクは以下のタイミングでspecに落とし込むことを推奨：

1. **infrastructure** - Terraformセットアップ開始時
   - `/kiro/spec-init "infrastructure"`
   - Terraform構成、モジュール設計、リソース定義

2. **data-fetcher** - Cloud Function実装開始時
   - `/kiro/spec-init "data-fetcher"`
   - API統合、データ変換、Pub/Subパブリッシュ

3. **monitoring** - モニタリング設定開始時
   - `/kiro/spec-init "monitoring"`
   - ダッシュボード、アラート、ログ集約

---

**最終更新**: 2026-01-08

