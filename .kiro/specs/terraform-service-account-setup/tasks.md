# Implementation Plan

## タスク概要
このfeatureは、gcloud CLIを使用してTerraform実行用サービスアカウントをセットアップする手順実行タスクです。コード実装ではなく、GCP操作とローカル環境設定が中心となります。

## 前提条件
- GCPプロジェクトが作成済み
- gcloud CLIがインストール済み
- 実行ユーザーがプロジェクトのOwner or IAM Admin権限を持つ
- シェル環境（zsh or bash）が利用可能

## 実装タスク

### 1. サービスアカウント作成

- [x] 1.1 GCPプロジェクトIDの確認と設定
  - 現在のGCPプロジェクトを確認する
  - 環境変数 `PROJECT_ID` にプロジェクトIDを設定する
  - gcloud CLIのデフォルトプロジェクトを設定する
  - _Requirements: 1.1_

- [x] 1.2 サービスアカウントの作成
  - `gcloud iam service-accounts create` コマンドでサービスアカウントを作成する
  - 表示名を「Terraform Service Account」に設定する
  - 説明文を「Service account for Terraform infrastructure management」に設定する
  - サービスアカウントのメールアドレス（`terraform-sa@PROJECT_ID.iam.gserviceaccount.com`）を確認する
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

### 2. IAM権限の設定

- [x] 2.1 権限パターンの選択
  - 開発環境か本番環境かを判断する
  - 開発環境の場合はEditorロール、本番環境の場合は最小権限の原則を適用する
  - _Requirements: 2.1, 3.1_

- [x] 2.2 Editorロールの付与（開発環境向け）
  - `gcloud projects add-iam-policy-binding` で `roles/editor` を付与する
  - IAMポリシーバインディングが正常に適用されたことを確認する
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 2.3 最小権限の原則による個別ロール付与（本番環境向け）
  - 11個の個別ロール（BigQuery Admin, Pub/Sub Admin等）をループで付与する
  - 各ロールのバインディングが成功したことを確認する
  - 失敗したロールがあればエラーメッセージを確認する
  - _Requirements: 3.1, 3.2, 3.3_

### 3. JSONキーの生成と保存

- [x] 3.1 (P) `~/.gcp/` ディレクトリの作成
  - `mkdir -p ~/.gcp` でディレクトリを作成する
  - ディレクトリが存在することを確認する
  - _Requirements: 4.2, 4.3_

- [x] 3.2 JSONキーファイルの生成
  - `gcloud iam service-accounts keys create` コマンドでJSONキーを生成する
  - ファイル名を `terraform-sa-{PROJECT_ID}.json` に設定する
  - 保存先を `~/.gcp/` ディレクトリに指定する
  - JSONキーファイルが正常に作成されたことを確認する
  - _Requirements: 4.1, 4.2, 4.4, 4.5, 4.6_

- [x] 3.3 ファイルパーミッションの設定
  - `chmod 600` でJSONキーファイルのパーミッションを設定する
  - `ls -la` でパーミッションが `600` であることを確認する
  - _Requirements: 4.4_

### 4. プロジェクト別alias設定

- [x] 4.1 シェル設定ファイルの特定
  - 使用中のシェル（zsh or bash）を確認する
  - `~/.zshrc` または `~/.bashrc` のパスを特定する
  - _Requirements: 5.1_

- [x] 4.2 alias定義の追加
  - `GCP_KEYS_DIR` 環境変数を定義する
  - プロジェクト切り替え用alias（`tf-nyc` 等）を定義する
  - 現在のプロジェクト確認用alias（`tf-current`）を定義する
  - シェル設定ファイルに追記する
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 4.3 シェル設定の反映
  - `source ~/.zshrc` または `source ~/.bashrc` でシェル設定を再読み込みする
  - aliasが正しく定義されていることを確認する（`alias` コマンド）
  - _Requirements: 5.6, 5.7_

### 5. サービスアカウントの動作確認

- [x] 5.1 サービスアカウント認証テスト
  - プロジェクト切り替えaliasを実行する（例: `tf-nyc`）
  - `gcloud auth activate-service-account` でサービスアカウント認証を有効化する
  - 認証が成功したことを確認する
  - _Requirements: 6.1_

- [x] 5.2 GCPアクセステスト
  - `gcloud projects describe` でプロジェクト情報を取得する
  - プロジェクト名、プロジェクトID等が正常に表示されることを確認する
  - 権限エラーが発生しないことを確認する
  - _Requirements: 6.2, 6.3_

- [x] 5.3 元のユーザーアカウントへの復帰
  - `gcloud config set account` で元のユーザーアカウントに戻す
  - デフォルトアカウントが復元されたことを確認する
  - _Requirements: 6.4_

### 6. セキュリティ設定

- [x] 6.1 (P) `.gitignore` の更新
  - プロジェクトルートの `.gitignore` ファイルに `*.json` パターンを追加する
  - `!package.json` で `package.json` を除外対象から外す
  - `git status` でJSONキーファイルが表示されないことを確認する
  - _Requirements: 7.1_

- [x] 6.2 (P) ファイルパーミッションの最終確認
  - `ls -la ~/.gcp/terraform-sa-*.json` でパーミッションを確認する
  - パーミッションが `600` であることを再確認する
  - _Requirements: 7.2, 7.3_

- [x] 6.3 (P) バックアップ除外設定（オプション）
  - macOSの場合は `tmutil addexclusion ~/.gcp/` でTime Machine除外設定を行う
  - 他のバックアップツール使用時も同様に除外設定を行う
  - _Requirements: 7.6_

### 7. Terraform初期化テスト

- [x] 7.1 (P) Terraformディレクトリの作成
  - `terraform/` ディレクトリを作成する
  - _Requirements: 8.1_

- [x] 7.2 (P) Terraform設定ファイルの作成
  - `main.tf` にGCPプロバイダー設定を記述する
  - プロジェクト情報取得用のデータソースを定義する
  - プロジェクト名を表示するoutputを定義する
  - `terraform.tfvars` にプロジェクトIDを設定する
  - _Requirements: 8.1_

- [x] 7.3 (P) Terraform初期化の実行
  - プロジェクト切り替えaliasを実行する
  - `terraform init` を実行する
  - プロバイダープラグインが正常にダウンロードされることを確認する
  - _Requirements: 8.2_

- [x] 7.4 (P) Terraformプラン生成の実行
  - `terraform plan` を実行する
  - サービスアカウントで認証が成功することを確認する
  - プロジェクト情報が取得できることを確認する
  - プロジェクト名がoutputとして表示されることを確認する
  - 認証エラーや権限エラーが発生しないことを確認する
  - _Requirements: 8.3, 8.4, 8.5_

## 完了基準
- すべてのタスクが完了し、チェックボックスがチェックされている
- サービスアカウントが作成され、適切な権限が付与されている
- JSONキーファイルが `~/.gcp/` ディレクトリに保存されている
- プロジェクト切り替えaliasが動作している
- サービスアカウント認証が成功し、GCPにアクセスできる
- `.gitignore` にJSONファイルパターンが追加されている
- Terraformが正常に初期化され、プランが生成できる

## 要件カバレッジ
- Requirement 1（サービスアカウント作成）: Task 1.1, 1.2
- Requirement 2（IAM権限設定 - Editor）: Task 2.1, 2.2
- Requirement 3（IAM権限設定 - 最小権限）: Task 2.1, 2.3
- Requirement 4（JSONキー生成・保存）: Task 3.1, 3.2, 3.3
- Requirement 5（プロジェクト別alias設定）: Task 4.1, 4.2, 4.3
- Requirement 6（サービスアカウント動作確認）: Task 5.1, 5.2, 5.3
- Requirement 7（セキュリティベストプラクティス）: Task 6.1, 6.2, 6.3
- Requirement 8（Terraform初期化テスト）: Task 7.1, 7.2, 7.3, 7.4

