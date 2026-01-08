# Research & Design Decisions

## Summary
- **Feature**: `terraform-service-account-setup`
- **Discovery Scope**: Simple Addition（手順書的タスク、既存システムへの影響なし）
- **Key Findings**:
  - gcloud CLIによるサービスアカウント作成は標準的な手順であり、複雑な設計判断は不要
  - IAMロール付与は開発環境（Editor）と本番環境（最小権限の原則）の2パターンを提供
  - JSONキー管理は複数プロジェクト対応のため `~/.gcp/` ディレクトリ構造を採用

## Research Log

### gcloud CLI サービスアカウント管理
- **Context**: Terraform実行用サービスアカウントの作成手順を標準化する必要がある
- **Sources Consulted**: 
  - GCP公式ドキュメント - Service Accounts
  - Terraform GCP Provider公式ドキュメント
- **Findings**:
  - `gcloud iam service-accounts create` コマンドで簡単に作成可能
  - JSONキー生成は `gcloud iam service-accounts keys create` で実行
  - サービスアカウントの命名規則は `{purpose}-sa` が一般的
- **Implications**: 
  - 標準的な手順であり、特別な設計判断は不要
  - エラーハンドリングはgcloud CLIの標準出力で対応

### IAMロール設定戦略
- **Context**: 開発環境と本番環境で異なる権限レベルが必要
- **Sources Consulted**:
  - GCP IAM Best Practices
  - Terraform GCP Provider - Required Permissions
- **Findings**:
  - **Editor ロール**: 開発環境向け、シンプルで広範な権限
  - **最小権限の原則**: 本番環境向け、11個の個別ロールを付与
    - BigQuery Admin, Pub/Sub Admin, Cloud Functions Admin等
  - IAM API有効化が前提条件
- **Implications**:
  - 2つの権限パターンを要件として定義
  - 開発環境では簡潔性を優先、本番環境ではセキュリティを優先

### JSONキー管理とマルチプロジェクト対応
- **Context**: 複数のGCPプロジェクトを管理する際のキー管理戦略
- **Sources Consulted**:
  - GCP Service Account Key Management Best Practices
  - 既存のdotfile管理パターン（`.aws/`, `.kube/`等）
- **Findings**:
  - `~/.gcp/` ディレクトリでの一元管理が標準的
  - 命名規則: `terraform-sa-{PROJECT_ID}.json` でプロジェクトを区別
  - ファイルパーミッション `600` は必須
  - キーローテーション推奨期間: 90日
- **Implications**:
  - フラットな構造で命名規則による区別を採用
  - シェルaliasによるプロジェクト切り替えを実装

### セキュリティベストプラクティス
- **Context**: JSONキーファイルの漏洩防止策
- **Sources Consulted**:
  - GCP Security Best Practices
  - OWASP Secrets Management
- **Findings**:
  - `.gitignore`に `*.json` パターン追加は必須
  - ファイルパーミッション `600` で他ユーザーからのアクセスを制限
  - キーローテーション（90日毎）でリスク最小化
  - バックアップ対象から除外（機密情報のため）
- **Implications**:
  - セキュリティ要件として明示的に定義
  - 誤コミット時の対応手順も要件に含める

## Design Decisions

### Decision: JSONキー保存場所
- **Context**: 複数GCPプロジェクトを管理する際の認証情報の保存場所
- **Alternatives Considered**:
  1. ホームディレクトリ直下 - シンプルだが複数プロジェクト時に煩雑
  2. プロジェクトディレクトリ内 - Gitコミットリスクが高い
  3. `~/.gcp/` ディレクトリ - AWSやKubernetes等の標準パターンに準拠
- **Selected Approach**: `~/.gcp/` ディレクトリにフラット構造で配置
- **Rationale**: 
  - 他のクラウドツール（`.aws/`, `.kube/`）との一貫性
  - ホームディレクトリ配下で一元管理
  - Gitリポジトリ外で安全
- **Trade-offs**: 
  - ディレクトリ作成の追加ステップが必要
  - しかし長期的な管理性が向上
- **Follow-up**: 実装時に `.gitignore` に `~/.gcp/` を除外する必要はない（ホームディレクトリ外）

### Decision: プロジェクト切り替え方法
- **Context**: 複数GCPプロジェクト間でTerraform環境を切り替える方法
- **Alternatives Considered**:
  1. 手動で環境変数を毎回export - エラープロンで非効率
  2. direnv - 自動切り替えだが初回セットアップが複雑
  3. シェルalias - シンプルで明示的
- **Selected Approach**: シェルaliasによるプロジェクト切り替え
- **Rationale**: 
  - シンプルで理解しやすい
  - 明示的な切り替えで誤操作を防止
  - ユーザーが現在のプロジェクトを意識できる
- **Trade-offs**: 
  - ディレクトリベースの自動切り替えはなし
  - しかし明示性が高く、誤操作リスクが低い
- **Follow-up**: 将来的にdirenv移行も検討可能

### Decision: 権限設定の2パターン提供
- **Context**: 環境によって異なるセキュリティ要件への対応
- **Alternatives Considered**:
  1. Editor ロールのみ - シンプルだが本番環境では過剰権限
  2. 最小権限のみ - セキュアだが開発環境では設定が煩雑
  3. 両方を提供 - 環境に応じた選択が可能
- **Selected Approach**: 開発環境向けEditorロールと、本番環境向け最小権限の2パターン
- **Rationale**: 
  - 開発環境では簡潔性を優先（Editor ロール）
  - 本番環境ではセキュリティを優先（11個の個別ロール）
  - 環境に応じた柔軟性を提供
- **Trade-offs**: 
  - ドキュメント量が増加
  - しかしセキュリティと利便性のバランスが取れる
- **Follow-up**: 実装時にどちらを選択するかをユーザーが判断

## Risks & Mitigations
- **Risk 1**: JSONキーファイルの誤コミット
  - **Mitigation**: `.gitignore` に `*.json` パターンを追加、定期的なリポジトリスキャン
- **Risk 2**: 過剰な権限付与（Editorロール）
  - **Mitigation**: 本番環境では最小権限の原則を適用、開発環境のみEditorロール使用
- **Risk 3**: サービスアカウントキーの長期使用
  - **Mitigation**: 90日毎のキーローテーション手順を明示
- **Risk 4**: 複数プロジェクト管理時の環境変数混乱
  - **Mitigation**: aliasによる明示的なプロジェクト切り替え、`tf-current` で現在のプロジェクト確認

## References
- [GCP Service Accounts](https://cloud.google.com/iam/docs/service-accounts) — サービスアカウントの概念と管理
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference/iam/service-accounts) — gcloud iam service-accounts コマンド詳細
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs) — Terraform実行に必要な権限
- [GCP IAM Best Practices](https://cloud.google.com/iam/docs/best-practices-for-securing-service-accounts) — サービスアカウントのセキュリティベストプラクティス

