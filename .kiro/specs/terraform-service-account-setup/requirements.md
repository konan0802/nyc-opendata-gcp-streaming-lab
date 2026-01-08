# Requirements Document

## Project Description (Input)
Terraform実行用サービスアカウント作成

## Introduction
GCP上でTerraformを使用してインフラストラクチャを管理するためには、適切な権限を持つサービスアカウントが必要です。このspecificationでは、Terraform実行専用のサービスアカウントをgcloud CLIを使用して作成し、必要なIAMロールを付与し、認証キーを安全に管理する手順を定義します。

このサービスアカウントは、BigQuery、Pub/Sub、Cloud Functions、Secret Manager等のGCPリソースをTerraformで作成・管理するために使用されます。

## Requirements

### Requirement 1: サービスアカウントの作成
**Objective:** As a DevOps Engineer, I want Terraform実行用のサービスアカウントをGCP上に作成する, so that Terraformがインフラリソースを管理できる

#### Acceptance Criteria
1. When gcloud CLIでサービスアカウント作成コマンドを実行する, the GCP Project shall 一意のサービスアカウント（`terraform-sa@PROJECT_ID.iam.gserviceaccount.com`）を作成する
2. The サービスアカウント shall 表示名として「Terraform Service Account」を持つ
3. The サービスアカウント shall 説明文として「Service account for Terraform infrastructure management」を持つ
4. If サービスアカウント名が既に存在する, then gcloud CLI shall エラーメッセージを表示して処理を中断する

### Requirement 2: IAM権限の設定（Editor ロール方式）
**Objective:** As a DevOps Engineer, I want サービスアカウントに適切な権限を付与する（開発環境向け）, so that Terraformがすべての必要なリソースを作成・管理できる

#### Acceptance Criteria
1. When Editorロールを付与する, the GCP Project shall サービスアカウントに`roles/editor`ロールをバインドする
2. The IAM Policy Binding shall プロジェクト全体に適用される
3. If ロールの付与に失敗した, then gcloud CLI shall エラーメッセージを表示し、失敗理由を示す

### Requirement 3: IAM権限の設定（最小権限の原則方式）
**Objective:** As a Security-conscious DevOps Engineer, I want サービスアカウントに必要最小限の権限のみを付与する（本番環境向け）, so that セキュリティリスクを最小化できる

#### Acceptance Criteria
1. When 個別ロールを付与する, the GCP Project shall 以下のロールをサービスアカウントにバインドする:
   - `roles/bigquery.admin`
   - `roles/pubsub.admin`
   - `roles/cloudfunctions.admin`
   - `roles/cloudscheduler.admin`
   - `roles/storage.admin`
   - `roles/secretmanager.admin`
   - `roles/iam.serviceAccountAdmin`
   - `roles/iam.roleAdmin`
   - `roles/monitoring.admin`
   - `roles/logging.admin`
   - `roles/serviceusage.serviceUsageAdmin`
2. The IAM Policy Binding shall 各ロールごとに個別に適用される
3. If いずれかのロールの付与に失敗した, then gcloud CLI shall エラーメッセージを表示し、どのロールで失敗したかを示す

### Requirement 4: JSONキーの生成と保存
**Objective:** As a DevOps Engineer, I want サービスアカウントの認証キーを生成して適切な場所に保存する, so that Terraformがサービスアカウントとして認証でき、複数プロジェクトを管理できる

#### Acceptance Criteria
1. When JSONキー作成コマンドを実行する, the gcloud CLI shall サービスアカウント用のJSONキーファイルを生成する
2. The JSONキーファイル shall `~/.gcp/` ディレクトリに `terraform-sa-{PROJECT_ID}.json` の命名規則で保存される
3. When `~/.gcp/` ディレクトリが存在しない, the DevOps Engineer shall `mkdir -p ~/.gcp` でディレクトリを作成する
4. When JSONキーファイルが作成される, the gcloud CLI shall ファイルパーミッションを`600`（所有者のみ読み書き可）に設定する
5. The JSONキーファイル shall 以下の情報を含む:
   - `type`: "service_account"
   - `project_id`: プロジェクトID
   - `private_key`: 秘密鍵
   - `client_email`: サービスアカウントのメールアドレス
6. If JSONキーファイルが既に存在する, then gcloud CLI shall 既存ファイルを上書きするか確認する

### Requirement 5: プロジェクト別alias設定
**Objective:** As a DevOps Engineer, I want プロジェクト別のalias設定を行う, so that 複数のGCPプロジェクト間でTerraform環境を簡単に切り替えられる

#### Acceptance Criteria
1. The シェル設定ファイル（`~/.zshrc` または `~/.bashrc`）shall 各GCPプロジェクト用のaliasを定義する
2. The alias shall 環境変数 `GOOGLE_APPLICATION_CREDENTIALS` を `~/.gcp/terraform-sa-{PROJECT_ID}.json` に設定する
3. The alias shall 環境変数 `GOOGLE_PROJECT` を対象のプロジェクトIDに設定する
4. The シェル設定 shall プロジェクト切り替え用aliasを含む（例: `tf-nyc`, `tf-project-a`）
5. The シェル設定 shall 現在のプロジェクト確認用aliasを含む（`tf-current`）
6. When aliasを実行する, the シェル shall 環境変数を即座に切り替える
7. When `source ~/.zshrc`を実行する, the 現在のシェルセッション shall alias設定を即座に反映する

### Requirement 6: サービスアカウントの動作確認
**Objective:** As a DevOps Engineer, I want サービスアカウントが正しく設定され機能することを確認する, so that Terraformが問題なく実行できることを保証できる

#### Acceptance Criteria
1. When `gcloud auth activate-service-account`でサービスアカウントを有効化する, the gcloud CLI shall 認証に成功し、サービスアカウントをアクティブなアカウントとして設定する
2. When `gcloud projects describe`でプロジェクト情報を取得する, the gcloud CLI shall プロジェクトの詳細情報を正常に返す
3. If サービスアカウントの権限が不足している, then gcloud CLI shall 権限エラーメッセージを表示する
4. When 動作確認が完了する, the DevOps Engineer shall 元のユーザーアカウントに戻す（`gcloud config set account`）

### Requirement 7: セキュリティのベストプラクティス
**Objective:** As a Security-conscious DevOps Engineer, I want JSONキーファイルを安全に管理する, so that 認証情報の漏洩を防止できる

#### Acceptance Criteria
1. The プロジェクトの`.gitignore` shall `*.json`パターンを含み、JSONキーファイルがGitリポジトリにコミットされない
2. The JSONキーファイル shall `~/.gcp/`ディレクトリに配置され、ホームディレクトリ配下で一元管理される
3. The JSONキーファイル shall ファイルパーミッション`600`を維持する
4. When 90日が経過する, the DevOps Engineer shall サービスアカウントキーをローテーション（古いキーの削除と新しいキーの生成）する
5. If JSONキーファイルが誤ってコミットされた, then DevOps Engineer shall 即座にキーを無効化し、新しいキーを生成する
6. The `~/.gcp/` ディレクトリ shall バックアップ対象から除外される（機密情報のため）

### Requirement 8: Terraform初期化テスト
**Objective:** As a DevOps Engineer, I want サービスアカウント設定後にTerraformで動作確認する, so that インフラ管理を開始できることを確認できる

#### Acceptance Criteria
1. When テスト用の`main.tf`ファイルを作成する, the Terraform Configuration shall GCPプロバイダーとプロジェクト情報取得データソースを含む
2. When `terraform init`を実行する, the Terraform shall プロバイダープラグインをダウンロードし、初期化に成功する
3. When `terraform plan`を実行する, the Terraform shall サービスアカウントで認証し、プロジェクト情報を取得し、プランを正常に生成する
4. If Terraform実行中に認証エラーが発生する, then Terraform shall エラーメッセージを表示し、環境変数の設定を確認するよう促す
5. The Terraformテスト shall プロジェクト名をoutputとして表示し、サービスアカウントが正しく機能していることを確認できる

## Out of Scope
- Terraformによるインフラストラクチャリソース（BigQuery、Pub/Sub等）の実装
- Cloud Function実行用サービスアカウントの作成（Terraformで管理）
- CI/CDパイプラインとの統合
- マルチプロジェクト環境での管理
- Workload Identityの設定
