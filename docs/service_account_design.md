# サービスアカウント設計: B-Route 管理システム

本ドキュメントでは、B-Route 管理システムにおけるサービスアカウント（SA）の設計方針について記述する。本システムでは「最小権限の原則（Least Privilege）」に基づき、**「起動（トリガー）」**と**「実行（ランタイム）」**のアイデンティティを明確に分離している。

## 設計の基本方針

1.  **起動と実行の分離**: Cloud Run を起動する主体 (Scheduler/Eventarc) と、実際にデータ処理を行う主体（Cloud Run 自身）を別のアカウントにする
2.  **サービス間での権限最小化**: `instant2bq` と `total2bq` では必要なリソース権限が異なるため、それぞれ専用の SA を用意する

---

## アイデンティティ・マッピング

| 区分               | サービスアカウント名 | 役割                                             | 主な付与権限                                       |
| :----------------- | :------------------- | :----------------------------------------------- | :------------------------------------------------- |
| **起動 (Trigger)** | `broute-trigger-sa`  | Scheduler / Eventarc による Cloud Run の呼び出し | `roles/run.invoker`                                |
| **実行 (Runtime)** | `instant2bq-sa`      | `instant2bq` 内部でのデータ処理                  | `pubsub.subscriber`, `bq.jobUser`, `bq.dataEditor` |
| **実行 (Runtime)** | `total2bq-sa`        | `total2bq` 内部でのデータ処理                    | `bq.jobUser`, `bq.dataEditor`                      |

---

## 各アイデンティティの詳細

### 1. 起動用 SA (`broute-trigger-sa`)

システムを動かす「トリガー」としての役割

- **用途**: Cloud Scheduler のジョブ実行名義、および Eventarc トリガーの受信名義
- **セキュリティ**: この SA は Cloud Run を「叩く」ことしかできない。万が一この SA のトークンが漏洩しても、Pub/Sub のメッセージを盗み見たり、BigQuery のデータを操作したりすることは不可能である

### 2. instant2bq 実行用 SA (`instant2bq-sa`)

`instant2bq` サービスが動作する際の名義 (Runtime Identity)

- **特有の権限**: 本サービスはプログラム内で Pub/Sub からメッセージを **Pull** する実装であるため、`roles/pubsub.subscriber` が必要である
- **データ権限**: BigQuery への書き込み権限を持つ

### 3. total2bq 実行用 SA (`total2bq-sa`)

`total2bq` サービスが動作する際の名義 (Runtime Identity)

- **特有の権限**: 本サービスは Eventarc から Push（HTTPS）でデータを受けるため、Pub/Sub 自体へのアクセス権限は不要である
- **データ権限**: BigQuery への書き込み権限のみを持つ

---

## Terraform における実装

これらの SA と権限は `modules/iam` モジュールで一元管理され、各 Cloud Run モジュール（`instant2bq`, `total2bq`）の `service_account_email` 引数を通じて各環境（dev/prd）に適用される。
