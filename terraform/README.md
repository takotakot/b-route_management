# Terraform Infrastructure Management

このディレクトリでは、Google Cloud インフラを管理するための Terraform 構成を保持している。

## ディレクトリ構成

- `modules/`: 各コンポーネント (BigQuery, Pub/Sub, Functions, Scheduler, IAM) の共通定義
- `environments/`: 各環境 (dev, prd) ごとの設定

## 機密情報の管理 (Security)

OSS 公開のため、以下の情報はコードに含めていない

1.  **Backend Config (GCS Bucket)**: `environments/*/main.tf` 内の `backend "gcs" {}` は空
2.  **Environment Variables**: `project_id` などの変数はコマンドライン引数や `terraform.tfvars` で渡す

## デプロイ手順

### 0. 事前準備：Backend 用バケットの作成

Terraform の状態 (tfstate) を共有管理するために、GCS バケットが必要である。以下のコマンドで作成できる。

```shell
# バケット名の例: b-route-management-test-tfstate
# リージョンは us-central1 などを指定
gcloud storage buckets create gs://YOUR_TFSTATE_BUCKET --project=YOUR_PROJECT_ID --location=us-central1 --uniform-bucket-level-access --soft-delete-duration=0

# 誤削除や上書きからの復旧のため、バージョニング有効化を強く推奨する
gcloud storage buckets update gs://YOUR_TFSTATE_BUCKET --versioning

# ストレージコスト削減のため、古いバージョンを自動削除するライフサイクルポリシーを適用する
# サンプル: misc/tfstate-lifecycle.json (最新5世代を残して削除)
gcloud storage buckets update gs://YOUR_TFSTATE_BUCKET --lifecycle-file=misc/tfstate-lifecycle.json
```

### 1. 初期化

本プロジェクトでは、tfstate 格納用バケット名をコードに含めない **Partial Configuration** を採用している。
そのため、`terraform init` 実行時には必ず `-backend-config` オプションでバケット名とプレフィックスを指定する必要がある。

```shell
cd terraform/environments/dev

# 1. 設定ファイルの作成
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
# project_id を自身の環境に合わせて編集する（通知先メール等は任意）

# 2. 初期化 (Backend 構成を指定)
terraform init -backend-config="bucket=YOUR_TFSTATE_BUCKET" -backend-config="prefix=b-route-management/dev"
```

### 2. 計画の確認

```shell
terraform plan
```

### 3. 適用

```shell
terraform apply
```

### 4. アプリケーションコード更新（ビルド/デプロイ）

本プロジェクトでは、Terraform の実行時間を短縮し、インフラ変更とアプリ更新のライフサイクルを分離するため、Cloud Run サービスのビルド/プッシュ処理を制御する `skip_build` 変数を導入している。

- **通常時 (`skip_build = true` / デフォルト)**:
  - コンテナのビルド処理と、ソースコードのハッシュ計算をスキップ
  - すでにデプロイされているリビジョンがあれば、そのまま維持される
  - インフラ設定（IAM, Topic, Scheduler など）のみを変更する場合に使用

- **アプリデプロイ時 (`skip_build = false`)**:
  - `gcloud builds submit` によるコンテナビルドを実行し、Artifact Registry にイメージをプッシュ
  - ソースコードに変更がある場合、新しいリビジョンとして Cloud Run を更新
  - **初回構築時** や、アプリケーションコードを更新したい場合に指定する
  - `latest` タグを指定しているが、Cloud Run 側ではリビジョン単位で管理されるため、ちゃんと更新されるかは「未検証」である

`terraform.tfvars` の値を一時的に上書きしたい場合（例: アプリデプロイ時のみ `skip_build=false` にする）は、環境変数 `TF_VAR_変数名` を利用すると便利である。

```shell
# アプリケーションのビルドとデプロイを行う場合
TF_VAR_skip_build=false terraform apply
```
