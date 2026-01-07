# Product Overview

NYC Open Dataからリアルタイムでデータを取得し、GCP上でストリーミング処理を行い、BigQueryに格納するETLパイプラインの実験プロジェクト。

## Core Capabilities

- **リアルタイムデータ取得**: NYC Open Data Socrata API (SODA) から継続的にデータを取得
- **ストリーミングETL**: Pub/SubとBigQuery Subscriptionによる直接書き込み方式
- **スケーラブルなインフラ**: Cloud Functions + Pub/Sub + BigQueryの完全サーバーレス構成
- **低コスト運用**: ETL処理層を省略し、月額$2程度での運用を実現

## Target Use Cases

- NYC Open Dataのストリーミングデータ分析（311サービスリクエスト、交通データ、駐車違反データなど）
- GCPストリーミングアーキテクチャの学習・実験
- リアルタイムデータパイプラインのプロトタイピング
- BigQueryでの大規模データ分析基盤の構築

## Value Proposition

- **実験的アプローチ**: Production Readyではなく、学習・検証を目的とした設計
- **低コスト**: 完全サーバーレスで従量課金、最小限のリソース使用

---
_Focus on patterns and purpose, not exhaustive feature lists_

