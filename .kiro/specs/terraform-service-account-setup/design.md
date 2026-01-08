# Design Document

## Overview
このfeatureは、GCP上でTerraformを使用してインフラストラクチャを管理するために必要な、Terraform実行専用サービスアカウントのセットアップ手順を提供します。

**Purpose**: DevOps Engineerが複数のGCPプロジェクトでTerraformを実行するための認証基盤を構築します。

**Users**: DevOps Engineer、インフラ管理者がこの手順を実行し、Terraformの実行環境を準備します。

**Impact**: 現在のローカル開発環境に、GCPプロジェクト毎の認証情報とプロジェクト切り替え機構を追加します。

### Goals
- gcloud CLIを使用してTerraform実行用サービスアカウントを作成する
- 開発環境向け（Editorロール）と本番環境向け（最小権限）の2つの権限パターンを提供する
- 複数GCPプロジェクトを管理できるJSONキー保存戦略を確立する
- シェルaliasによる明示的なプロジェクト切り替え機構を実装する
- セキュリティベストプラクティスに従った認証情報管理を実現する
- Terraform初期化テストでセットアップの正確性を検証する

### Non-Goals
- Terraformによるインフラストラクチャリソースの作成・管理（別featureで対応）
- Cloud Function実行用サービスアカウントの作成（Terraformで管理）
- CI/CDパイプラインとの統合
- direnvやWorkload Identityを使用した自動認証切り替え

## Architecture

### 設計アプローチ

このfeatureは「手順実行タスク」であり、従来のソフトウェアアーキテクチャパターンは適用されません。代わりに、以下のステップベースのアプローチを採用します：

```
[DevOps Engineer]
       ↓
1. gcloud CLI実行
   ├─ サービスアカウント作成
   ├─ IAMロール付与
   └─ JSONキー生成
       ↓
2. ローカルファイルシステム
   └─ ~/.gcp/terraform-sa-{PROJECT_ID}.json
       ↓
3. シェル設定
   └─ ~/.zshrc (aliasを追加)
       ↓
4. Terraform検証
   └─ terraform init & plan
```

**ステップの依存関係**:
- ステップ1（GCP操作）が完了しないとステップ2（ファイル保存）は実行できない
- ステップ2が完了しないとステップ3（環境変数設定）は実行できない
- ステップ3が完了しないとステップ4（Terraform検証）は実行できない

**既存システムへの影響**:
- 既存のGCPリソースには影響なし
- ローカルファイルシステムに `~/.gcp/` ディレクトリを追加
- シェル設定ファイル（`~/.zshrc` または `~/.bashrc`）にalias定義を追加

## Requirements Traceability

| Requirement | Summary | 実現方法 | 検証方法 |
|-------------|---------|---------|---------|
| 1.1, 1.2, 1.3, 1.4 | サービスアカウント作成 | `gcloud iam service-accounts create` コマンド | gcloud CLIの標準出力確認 |
| 2.1, 2.2, 2.3 | IAM権限設定（Editor） | `gcloud projects add-iam-policy-binding` with `roles/editor` | IAMポリシー確認 |
| 3.1, 3.2, 3.3 | IAM権限設定（最小権限） | 11個の個別ロールを順次付与 | 各ロールのバインディング確認 |
| 4.1, 4.2, 4.3, 4.4, 4.5, 4.6 | JSONキー生成・保存 | `gcloud iam service-accounts keys create` + `chmod 600` | ファイル存在確認、パーミッション確認 |
| 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7 | プロジェクト別alias設定 | `~/.zshrc` にexport文とalias定義を追加 | `tf-current` で環境変数確認 |
| 6.1, 6.2, 6.3, 6.4 | サービスアカウント動作確認 | `gcloud auth activate-service-account` + `gcloud projects describe` | コマンド成功確認 |
| 7.1, 7.2, 7.3, 7.4, 7.5, 7.6 | セキュリティベストプラクティス | `.gitignore` 更新、パーミッション設定、ローテーション計画 | `.gitignore` 確認、ファイルパーミッション確認 |
| 8.1, 8.2, 8.3, 8.4, 8.5 | Terraform初期化テスト | テスト用 `main.tf` 作成、`terraform init` & `plan` 実行 | Terraformコマンド成功確認 |

## Technology Stack

| Layer | Choice / Version | Role in Feature | Notes |
|-------|------------------|-----------------|-------|
| CLI Tool | gcloud CLI (最新安定版) | GCPリソース操作（サービスアカウント、IAM） | 事前インストール必須 |
| Infrastructure | Terraform (1.x以降推奨) | 動作確認用（将来のインフラ管理） | セットアップ後の検証に使用 |
| Shell | zsh or bash | alias設定、環境変数管理 | ユーザー環境に依存 |
| Filesystem | `~/.gcp/` ディレクトリ | JSONキーファイル保存 | 複数プロジェクト一元管理 |
| GCP Services | IAM, Resource Manager API | サービスアカウント作成、ロール付与 | GCPプロジェクト内で有効化が必要 |

## Components and Interfaces

このfeatureは手順実行タスクのため、従来のソフトウェアコンポーネントではなく、**実行ステップ**として定義します。

| Step | 目的 | Requirements | 依存関係 | 検証 |
|------|------|-------------|---------|------|
| Step 1: SA作成 | サービスアカウント作成 | 1.1-1.4 | GCP Project, gcloud CLI | gcloud出力確認 |
| Step 2: 権限付与 | IAMロール設定 | 2.1-3.3 | Step 1完了 | IAMポリシー確認 |
| Step 3: キー生成 | JSONキーファイル作成 | 4.1-4.6 | Step 1完了 | ファイル存在確認 |
| Step 4: alias設定 | 環境変数とalias追加 | 5.1-5.7 | Step 3完了 | `tf-current`で確認 |
| Step 5: 動作確認 | SA認証テスト | 6.1-6.4 | Step 3, 4完了 | gcloud認証成功 |
| Step 6: セキュリティ設定 | `.gitignore`、パーミッション | 7.1-7.6 | Step 3完了 | Git status確認 |
| Step 7: Terraform検証 | Terraform動作確認 | 8.1-8.5 | Step 4完了 | terraform plan成功 |

### Step 1: サービスアカウント作成

| Field | Detail |
|-------|--------|
| Intent | GCP上にTerraform実行用サービスアカウントを作成する |
| Requirements | 1.1, 1.2, 1.3, 1.4 |

**実行コマンド**:
```bash
gcloud iam service-accounts create terraform-sa \
  --display-name="Terraform Service Account" \
  --description="Service account for Terraform infrastructure management"
```

**前提条件**:
- GCPプロジェクトが作成済み
- gcloud CLIがインストール済み
- 実行ユーザーがプロジェクトのOwner or IAM Admin権限を持つ

**事後条件**:
- サービスアカウント `terraform-sa@{PROJECT_ID}.iam.gserviceaccount.com` が作成される

**エラーハンドリング**:
- サービスアカウント名が既に存在: エラーメッセージ表示、処理中断
- 権限不足: IAM権限エラー、権限確認を促す

### Step 2: IAM権限付与

| Field | Detail |
|-------|--------|
| Intent | サービスアカウントにTerraform実行に必要な権限を付与する |
| Requirements | 2.1, 2.2, 2.3, 3.1, 3.2, 3.3 |

**実行コマンド（開発環境 - Editorロール）**:
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"
```

**実行コマンド（本番環境 - 最小権限）**:
```bash
ROLES=(
  "roles/bigquery.admin"
  "roles/pubsub.admin"
  "roles/cloudfunctions.admin"
  "roles/cloudscheduler.admin"
  "roles/storage.admin"
  "roles/secretmanager.admin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.roleAdmin"
  "roles/monitoring.admin"
  "roles/logging.admin"
  "roles/serviceusage.serviceUsageAdmin"
)

for role in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
done
```

**前提条件**:
- Step 1が完了している
- IAM APIが有効化されている

**事後条件**:
- サービスアカウントに指定したロールがバインドされる

**エラーハンドリング**:
- ロール付与失敗: エラーメッセージ表示、どのロールで失敗したかを示す
- IAM API無効: API有効化を促す

### Step 3: JSONキー生成と保存

| Field | Detail |
|-------|--------|
| Intent | サービスアカウント認証キーを生成し、適切な場所に保存する |
| Requirements | 4.1, 4.2, 4.3, 4.4, 4.5, 4.6 |

**実行コマンド**:
```bash
# ~/.gcp/ ディレクトリ作成
mkdir -p ~/.gcp

# JSONキー生成
gcloud iam service-accounts keys create \
  ~/.gcp/terraform-sa-${PROJECT_ID}.json \
  --iam-account=terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com

# パーミッション設定
chmod 600 ~/.gcp/terraform-sa-${PROJECT_ID}.json
```

**前提条件**:
- Step 1が完了している
- `~/.gcp/` ディレクトリが存在する（なければ作成）

**事後条件**:
- `~/.gcp/terraform-sa-{PROJECT_ID}.json` ファイルが作成される
- ファイルパーミッションが `600` に設定される

**JSONキーファイル構造**:
```json
{
  "type": "service_account",
  "project_id": "nyc-opendata-streaming",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...",
  "client_email": "terraform-sa@nyc-opendata-streaming.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  ...
}
```

**エラーハンドリング**:
- ファイルが既に存在: 上書き確認プロンプト
- ディレクトリ作成失敗: パーミッションエラー、権限確認を促す

### Step 4: プロジェクト別alias設定

| Field | Detail |
|-------|--------|
| Intent | 複数GCPプロジェクト間でTerraform環境を切り替えられるaliasを設定する |
| Requirements | 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7 |

**シェル設定ファイル追加内容（`~/.zshrc` または `~/.bashrc`）**:
```bash
# GCP認証情報ディレクトリ
export GCP_KEYS_DIR="$HOME/.gcp"

# プロジェクト別alias
alias tf-nyc='export GOOGLE_APPLICATION_CREDENTIALS="$GCP_KEYS_DIR/terraform-sa-nyc-opendata-streaming.json" && export GOOGLE_PROJECT="nyc-opendata-streaming" && echo "Switched to project: nyc-opendata-streaming"'

# 現在のプロジェクト確認
alias tf-current='echo "Project: $GOOGLE_PROJECT" && echo "Credentials: $GOOGLE_APPLICATION_CREDENTIALS"'
```

**実行手順**:
1. `~/.zshrc` または `~/.bashrc` をエディタで開く
2. 上記内容をファイル末尾に追加
3. `source ~/.zshrc` または `source ~/.bashrc` で反映

**前提条件**:
- Step 3が完了している
- シェルがzshまたはbash

**事後条件**:
- `tf-nyc` aliasでプロジェクト切り替えが可能
- `tf-current` でプロジェクト確認が可能

**使用例**:
```bash
# プロジェクト切り替え
$ tf-nyc
Switched to project: nyc-opendata-streaming

# 現在のプロジェクト確認
$ tf-current
Project: nyc-opendata-streaming
Credentials: /Users/username/.gcp/terraform-sa-nyc-opendata-streaming.json
```

### Step 5: サービスアカウント動作確認

| Field | Detail |
|-------|--------|
| Intent | サービスアカウントが正しく設定され、GCPにアクセスできることを確認する |
| Requirements | 6.1, 6.2, 6.3, 6.4 |

**実行コマンド**:
```bash
# サービスアカウント認証を有効化
gcloud auth activate-service-account \
  --key-file=$GOOGLE_APPLICATION_CREDENTIALS

# プロジェクト情報取得テスト
gcloud projects describe $GOOGLE_PROJECT

# 元のユーザーアカウントに戻す
gcloud config set account your-email@example.com
```

**前提条件**:
- Step 3, 4が完了している
- 環境変数 `GOOGLE_APPLICATION_CREDENTIALS` と `GOOGLE_PROJECT` が設定されている

**事後条件**:
- サービスアカウント認証が成功
- プロジェクト情報が正常に取得できる

**エラーハンドリング**:
- 認証失敗: JSONキーファイルパスを確認、権限を確認
- 権限不足: IAMロールの付与を確認

### Step 6: セキュリティ設定

| Field | Detail |
|-------|--------|
| Intent | JSONキーファイルの漏洩を防止する設定を行う |
| Requirements | 7.1, 7.2, 7.3, 7.4, 7.5, 7.6 |

**実行手順**:

1. **`.gitignore` 更新**:
```bash
# プロジェクトルートの .gitignore に追加
echo "*.json" >> .gitignore
echo "!package.json" >> .gitignore  # package.jsonは除外
```

2. **パーミッション確認**:
```bash
ls -la ~/.gcp/terraform-sa-*.json
# 出力: -rw------- ... terraform-sa-nyc-opendata-streaming.json
```

3. **バックアップ除外設定**（Time Machine等）:
```bash
# macOSの場合
tmutil addexclusion ~/.gcp/
```

**前提条件**:
- Step 3が完了している

**事後条件**:
- `.gitignore` に `*.json` パターンが追加される
- ファイルパーミッションが `600` である
- バックアップ対象から除外される（オプション）

**キーローテーション手順（90日毎）**:
```bash
# 古いキーを削除
gcloud iam service-accounts keys list \
  --iam-account=terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com

gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com

# 新しいキーを生成（Step 3を再実行）
```

### Step 7: Terraform初期化テスト

| Field | Detail |
|-------|--------|
| Intent | Terraformがサービスアカウントで正常に動作することを確認する |
| Requirements | 8.1, 8.2, 8.3, 8.4, 8.5 |

**テスト用Terraform設定**:

```hcl
# terraform/main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

# テスト: プロジェクト情報を取得
data "google_project" "project" {
  project_id = var.project_id
}

output "project_name" {
  value = data.google_project.project.name
}
```

```hcl
# terraform/terraform.tfvars
project_id = "for-study-20251201"
```

**実行手順**:
```bash
# プロジェクト切り替え
tf-for-study-20251201

# Terraformディレクトリに移動
cd terraform

# 上記main.tfとterraform.tfvarsを作成

# Terraform初期化
terraform init

# プラン生成
terraform plan
```

**前提条件**:
- Step 4が完了している
- Terraformがインストールされている

**事後条件**:
- `terraform init` が成功し、プロバイダープラグインがダウンロードされる
- `terraform plan` が成功し、プロジェクト名が表示される

**エラーハンドリング**:
- 認証エラー: 環境変数 `GOOGLE_APPLICATION_CREDENTIALS` を確認
- 権限エラー: サービスアカウントのIAMロールを確認

## Testing Strategy

### Manual Verification Tests
このfeatureは手順実行タスクのため、各ステップの手動検証が中心となります。

1. **サービスアカウント作成確認**:
   - `gcloud iam service-accounts list` でサービスアカウントが存在することを確認
   - 表示名と説明文が正しいことを確認

2. **IAM権限確認**:
   - `gcloud projects get-iam-policy $PROJECT_ID` で付与されたロールを確認
   - Editorロールまたは11個の個別ロールが設定されていることを確認

3. **JSONキーファイル確認**:
   - `ls -la ~/.gcp/terraform-sa-*.json` でファイルが存在し、パーミッションが `600` であることを確認
   - JSONファイルの内容を確認（`cat` コマンドで読める）

4. **Alias動作確認**:
   - `tf-nyc` を実行し、環境変数が設定されることを確認
   - `tf-current` でプロジェクト情報が表示されることを確認

5. **サービスアカウント認証テスト**:
   - `gcloud auth activate-service-account` が成功することを確認
   - `gcloud projects describe` でプロジェクト情報が取得できることを確認

6. **`.gitignore` 確認**:
   - `git status` で `*.json` ファイルが表示されないことを確認

7. **Terraform動作テスト**:
   - `terraform init` が成功することを確認
   - `terraform plan` が成功し、プロジェクト名が表示されることを確認

### Error Scenario Tests

1. **サービスアカウント名重複**:
   - 同じ名前のサービスアカウントを再作成し、エラーメッセージが表示されることを確認

2. **権限不足**:
   - IAM権限のないユーザーでコマンドを実行し、権限エラーが表示されることを確認

3. **JSONキーファイルなし**:
   - `GOOGLE_APPLICATION_CREDENTIALS` に存在しないパスを設定し、Terraform実行時にエラーが表示されることを確認

4. **環境変数未設定**:
   - 環境変数を設定せずにTerraformを実行し、エラーメッセージが表示されることを確認

## Security Considerations

### 認証情報の保護

**JSONキーファイル管理**:
- ファイルパーミッション `600` で所有者のみがアクセス可能
- ホームディレクトリ配下 `~/.gcp/` で一元管理
- Gitリポジトリから除外（`.gitignore` に `*.json` 追加）
- バックアップ対象から除外（機密情報のため）

**キーローテーション**:
- 推奨期間: 90日毎
- 手順: 古いキーを削除 → 新しいキーを生成
- 漏洩時の対応: 即座にキーを無効化し、新しいキーを生成

### 権限管理

**開発環境 vs 本番環境**:
- 開発環境: Editorロール（簡潔性重視）
- 本番環境: 最小権限の原則（11個の個別ロール）

**最小権限の原則（本番環境）**:
- BigQuery Admin, Pub/Sub Admin等、必要なロールのみを付与
- プロジェクト全体の権限を制限

### 誤コミット防止

**`.gitignore` 設定**:
```
*.json
!package.json
```

**誤コミット時の対応手順**:
1. 即座にGCPコンソールでキーを無効化
2. 新しいキーを生成
3. Gitヒストリーからキーファイルを削除（`git filter-branch` 等）
4. リモートリポジトリの履歴も書き換え

## Supporting References

### gcloud CLIコマンド詳細

**サービスアカウント作成**:
```bash
gcloud iam service-accounts create SERVICE_ACCOUNT_ID \
  --display-name="DISPLAY_NAME" \
  --description="DESCRIPTION"
```

**IAMロール付与**:
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SERVICE_ACCOUNT_EMAIL" \
  --role="ROLE_NAME"
```

**JSONキー生成**:
```bash
gcloud iam service-accounts keys create OUTPUT_FILE \
  --iam-account=SERVICE_ACCOUNT_EMAIL
```

**サービスアカウント認証**:
```bash
gcloud auth activate-service-account --key-file=KEY_FILE
```

### 必要なIAMロール（最小権限の原則）

| ロール | 用途 |
|--------|------|
| `roles/bigquery.admin` | BigQueryデータセット・テーブル管理 |
| `roles/pubsub.admin` | Pub/Subトピック・サブスクリプション管理 |
| `roles/cloudfunctions.admin` | Cloud Functions管理 |
| `roles/cloudscheduler.admin` | Cloud Schedulerジョブ管理 |
| `roles/storage.admin` | Cloud Storageバケット管理 |
| `roles/secretmanager.admin` | Secret Managerシークレット管理 |
| `roles/iam.serviceAccountAdmin` | サービスアカウント管理 |
| `roles/iam.roleAdmin` | IAMロール管理 |
| `roles/monitoring.admin` | Cloud Monitoringダッシュボード・アラート管理 |
| `roles/logging.admin` | Cloud Loggingシンク管理 |
| `roles/serviceusage.serviceUsageAdmin` | API有効化管理 |

### シェルalias設定例

**複数プロジェクト対応**:
```bash
# ~/.zshrc または ~/.bashrc
export GCP_KEYS_DIR="$HOME/.gcp"

# プロジェクト別alias
alias tf-nyc='export GOOGLE_APPLICATION_CREDENTIALS="$GCP_KEYS_DIR/terraform-sa-nyc-opendata-streaming.json" && export GOOGLE_PROJECT="nyc-opendata-streaming" && echo "Switched to project: nyc-opendata-streaming"'

alias tf-project-a='export GOOGLE_APPLICATION_CREDENTIALS="$GCP_KEYS_DIR/terraform-sa-project-a.json" && export GOOGLE_PROJECT="project-a" && echo "Switched to project: project-a"'

alias tf-project-b='export GOOGLE_APPLICATION_CREDENTIALS="$GCP_KEYS_DIR/terraform-sa-project-b.json" && export GOOGLE_PROJECT="project-b" && echo "Switched to project: project-b"'

# 現在のプロジェクト確認
alias tf-current='echo "Project: $GOOGLE_PROJECT" && echo "Credentials: $GOOGLE_APPLICATION_CREDENTIALS"'
```

