# B-Route Management

スマートメーターの B ルートデータ（瞬間電力・積算電力）を取得し、Google Cloud (Pub/Sub, Cloud Run Functions, BigQuery) で管理するためのプロジェクトである。

## システム構成

- **instant2bq**: Cloud Scheduler を起点に Pub/Sub から瞬間電力データを Pull し、BigQuery へ保存する
- **total2bq**: Pub/Sub (Push) を起点に積算電力データを受信し、BigQuery へ保存する
- **Terraform**: `terraform/` ディレクトリにて、複数環境のインフラ定義を管理している

## 設計ドキュメント

詳細な仕様や設計については、以下のドキュメントを参照。

- [docs/instant2bq.md](docs/instant2bq.md): 瞬間電力計測の仕様
- [docs/total2bq.md](docs/total2bq.md): 積算電力計測の仕様
- [docs/service_account_design.md](docs/service_account_design.md): サービスアカウントと権限設計

## インフラ管理 (Terraform)

詳細は [terraform/README.md](terraform/README.md) を参照。
情報の秘匿のため、Partial Configuration を採用している。
Terraform では、BigQuery, Pub/Sub, Cloud Run, Cloud Scheduler, IAM, Cloud Monitoring など、システムに必要なほぼすべての Google Cloud リソースを管理している。

### セットアップ

1. **設定ファイルの作成**:
   各環境ディレクトリ (`terraform/environments/{dev,prd}`) 配下の `terraform.tfvars.example` を `terraform.tfvars` にコピーし、自身のプロジェクト情報を設定する。

2. **初期化 (Partial Configuration)**:
   Terraform の状態 (tfstate) を保存する Google Cloud Storage バケットはコード内に記述されていないため、`terraform init` 実行時に `-backend-config` オプションで指定する必要がある。

   ```shell
   terraform init -backend-config="bucket=YOUR_TFSTATE_BUCKET" -backend-config="prefix=b-route-management/dev"
   ```

### 環境ごとの構成

- **prd (Production)**: すべてのリソースが稼働状態である
- **dev (Development)**: コスト削減および開発の利便性のため、**Cloud Scheduler はデフォルトで停止 (Paused)** されている。テスト時のみ手動またはスクリプトで起動する。監視リソースも、結合テスト時以外は無効化することを推奨する

### ソースコードの編集

本システムではソースコードを直接管理・デプロイする方式をとっている。そのため、必要に応じて **Cloud Run の Source タブから、手でソースコードの編集を加える** ことで、迅速な修正やデバッグが可能である。

## License

This project is licensed under either CC0 or MIT at your option.

[![CC0](http://i.creativecommons.org/p/zero/1.0/88x31.png "CC0")](https://creativecommons.org/publicdomain/zero/1.0/deed)  
[MIT](https://opensource.org/licenses/MIT) (If you need, use `Copyright (c) 2026- takotakot`)
