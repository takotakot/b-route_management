# B-Route 結合テスト

本ディレクトリには、B-Route システムの結合テスト用スクリプトが含まれている。

Pub/Sub -> Cloud Run -> BigQuery のパイプラインが正常に動作することを確認するためのものであり、データの正確性やエッジケースの検証は目的としていない。

---

## 前提条件

動作には以下が必要である。これらは、次のように、`dev` 環境で `terraform apply` した後を想定している。

`apply` 前には `terraform/environments/dev/terraform.tfvars` が正しく設定されている必要がある。

```shell
# 監視設定と Scheduler を有効化してデプロイ
TF_VAR_enable_monitoring=true TF_VAR_activate_scheduler=true terraform apply
```

- `gcloud` CLI がインストールされている
- `bq` コマンドが使用可能
- 対象の GCP プロジェクトに以下のリソースがデプロイ済み:
  - Pub/Sub トピック (`instant_electric_power`, `total_electric_power`)
  - Cloud Run サービス (`instant2bq`, `total2bq`)
  - Cloud Scheduler ジョブ (`instant2bq-trigger`)
  - BigQuery データセット・テーブル

## 使い方

エントリーポイントは `run_test.sh` である。

```shell
PROJECT_ID=<your-project-id> ./run_test.sh
```

### 環境変数

| 変数名                  |   必須   | デフォルト値      | 説明                                          |
| :---------------------- | :------: | :---------------- | :-------------------------------------------- |
| `PROJECT_ID`            | REQUIRED | -                 | Google Cloud プロジェクト ID                  |
| `REGION`                |    -     | `asia-northeast1` | リージョン                                    |
| `INSTANT_MESSAGE_COUNT` |    -     | `10`              | 送信する instant メッセージ数                 |
| `MESSAGE_INTERVAL`      |    -     | `2`               | メッセージ間の待機秒数                        |
| `TRIGGER_METHOD`        |    -     | `scheduler`       | instant2bq の起動方法 (`scheduler` or `curl`) |

### 実行例

```shell
# 基本的な実行（10件、2秒間隔、Scheduler 経由）
PROJECT_ID=b-route-management-test ./run_test.sh

# 5件のメッセージを1秒間隔で送信し、curl で直接 Cloud Run を呼び出す
PROJECT_ID=b-route-management-test REGION=asia-northeast1 INSTANT_MESSAGE_COUNT=5 MESSAGE_INTERVAL=1 TRIGGER_METHOD=curl ./run_test.sh
```

## 監視を含めたテストの推奨運用手順

本システムの監視 (Alert Policy) は、データが一定時間届かない場合に通知を送る仕組みになっている。テスト時にこの挙動を確認し、完了後にリソースを削除する推奨フローは以下の通り。

1. **環境構築・機能有効化**: `terraform.tfvars` で基本設定（Project ID 等）を行った上で、`TF_VAR_enable_monitoring=true TF_VAR_activate_scheduler=true terraform apply` を実行し、監視リソースの作成と Scheduler の有効化を行う。
2. **テスト実行**: `PROJECT_ID=<your-project-id> ./run_test.sh` を実行。最初に Enter を押すとテスト（現状確認）が開始される。
3. **通知確認**: テスト終了後、しばらく待機して「データ欠損」のアラート通知が正常に届くことを確認する（監視の健全性確認）。
4. **後片付け（無効化）**: `TF_VAR_enable_monitoring=false TF_VAR_activate_scheduler=false terraform apply` を実行し、監視リソースを物理的に削除し、Scheduler を停止する。

## テストフロー（スクリプト内部の動作）

`run_test.sh` は以下の順序で処理を実行する。

1. **事前確認**: BigQuery の当日データ件数を表示
2. **メッセージ送信**: instant / total トピックへ publish
3. **待機**: Eventarc による total2bq 処理を待つ (30秒)
4. **instant2bq 起動**: Scheduler または curl で手動トリガー
5. **待機**: 処理完了を待つ (60秒)
6. **事後確認**: BigQuery のデータ件数を再表示

## テスト後の後片付けについて

上記フローのステップ4により、環境変数 `TF_VAR_enable_monitoring=false TF_VAR_activate_scheduler=false` を指定（あるいは、何も指定しない）して `apply` することで、`dev` プロジェクトをクリーンな状態に戻すことができる（`terraform.tfvars` の設定値よりも環境変数が優先されるため）。

監視は有償化される可能性があるため、テスト後に監視リソースを削除することを推奨する。また、Scheduler も無駄な実行を避けるため、通常は `activate_scheduler=false` としておく。

## ファイル構成

| ファイル                | 説明                                          |
| :---------------------- | :-------------------------------------------- |
| `run_test.sh`           | **エントリーポイント** - テスト全体を実行する |
| `config.sh`             | 環境変数の設定・検証を行う                    |
| `publish_instant.sh`    | instant トピックへ複数メッセージを送信する    |
| `publish_total.sh`      | total トピックへメッセージを送信する          |
| `trigger_instant2bq.sh` | instant2bq を手動起動する                     |
| `verify_data.sh`        | BigQuery のデータ件数を確認する               |
