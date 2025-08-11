# logs-collector-infra

ログ収集システムの Kubernetes インフラストラクチャ管理リポジトリです。k3d を使用したローカル開発環境と、Kustomize を使用したマニフェスト管理を提供します。

## 目次

- [アーキテクチャ](#アーキテクチャ)
- [前提条件](#前提条件)
- [クイックスタート](#クイックスタート)
- [ディレクトリ構造](#ディレクトリ構造)
- [使用方法](#使用方法)
- [開発ガイド](#開発ガイド)
- [トラブルシューティング](#トラブルシューティング)

## アーキテクチャ

このシステムは以下のコンポーネントで構成されています：

| コンポーネント    | 説明                                     | バージョン  | ポート                  |
| ----------------- | ---------------------------------------- | ----------- | ----------------------- |
| **API Server**    | gRPC/REST API サーバー                   | v0.0.5      | gRPC: 50051, REST: 8080 |
| **PostgreSQL**    | メタデータとログ情報の永続化             | 17          | 5432                    |
| **Elasticsearch** | ログデータの検索・分析エンジン           | 8.18.1      | 9200                    |
| **NATS**          | メッセージングシステム（JetStream 有効） | 2.10-alpine | 4222                    |

## 前提条件

以下のツールがインストールされている必要があります：

- [k3d](https://k3d.io/) - ローカル Kubernetes クラスター
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [Docker](https://www.docker.com/) - コンテナランタイム

## クイックスタート

### 1. クラスターの作成

```bash
make create
```

### 2. アプリケーションのデプロイ

```bash
make apply
```

### 3. 動作確認

```bash
make ctx
kubectl get pods -n logs-system
```

### 4. クリーンアップ

```bash
make teardown  # アプリケーション削除
make delete    # クラスター削除
```

## ディレクトリ構造

```
logs-collector-infra/
├── k3d/                           # k3d クラスター設定
│   └── cluster.yaml               # クラスター構成定義
├── k8s/                           # Kubernetes マニフェスト
│   ├── base/                      # ベースマニフェスト
│   │   ├── api/                   # API サーバー関連
│   │   │   ├── deployment.yaml    # デプロイメント（v0.0.5）
│   │   │   ├── kustomization.yaml # Kustomize 設定
│   │   │   └── service.yaml       # サービス（gRPC:50051, REST:8080）
│   │   ├── elasticsearch/         # Elasticsearch 関連
│   │   │   ├── deployment.yaml    # デプロイメント（8.18.1）
│   │   │   ├── kustomization.yaml # Kustomize 設定
│   │   │   └── service.yaml       # サービス（HTTP:9200）
│   │   ├── migrations/            # データベースマイグレーション
│   │   │   ├── job.yaml           # マイグレーション実行Job
│   │   │   ├── kustomization.yaml # Kustomize 設定
│   │   │   └── sql-configmap.yaml # SQL設定マップ
│   │   ├── nats/                  # NATS 関連
│   │   │   ├── deployment.yaml    # デプロイメント（2.10-alpine）
│   │   │   ├── kustomization.yaml # Kustomize 設定
│   │   │   └── service.yaml       # サービス（JetStream:4222）
│   │   ├── postgres/              # PostgreSQL 関連
│   │   │   ├── kustomization.yaml # Kustomize 設定
│   │   │   ├── service.yaml       # サービス（TCP:5432）
│   │   │   └── statefulset.yaml   # StatefulSet（postgres:17）
│   │   ├── kustomization.yaml     # ベース Kustomize 設定
│   │   └── namespace.yaml         # ネームスペース定義
│   └── overlays/                  # 環境別オーバーレイ
│       └── local/                 # ローカル環境用
│           └── kustomization.yaml # ローカル環境 Kustomize 設定
├── Makefile                       # 開発用コマンド
└── README.md                      # このファイル
```

## 使用方法

### Makefile コマンド

| コマンド        | 説明                   | 詳細                                                        |
| --------------- | ---------------------- | ----------------------------------------------------------- |
| `make create`   | k3d クラスターを作成   | `k3d cluster create logs-cluster --config k3d/cluster.yaml` |
| `make delete`   | k3d クラスターを削除   | `k3d cluster delete logs-cluster`                           |
| `make apply`    | マニフェストを適用     | `kubectl apply -k k8s/overlays/local`                       |
| `make teardown` | マニフェストを削除     | `kubectl delete -k k8s/overlays/local`                      |
| `make ctx`      | コンテキスト切替と確認 | `kubectl config use-context k3d-logs-cluster`               |
| `make diff`     | マニフェストの差分表示 | `kubectl diff -k k8s/overlays/local`                        |

### 手動コマンド

```bash
# クラスター作成
k3d cluster create logs-cluster --config k3d/cluster.yaml

# マニフェスト適用
kubectl apply -k k8s/overlays/local

# ログ確認
kubectl logs -f deployment/logs-collector-api -n logs-system

# サービス確認
kubectl get svc -n logs-system
```

## 🔧 設定

### k3d クラスター設定

`k3d/cluster.yaml`でクラスター構成を定義：

- マスターノード: 1 台
- ワーカーノード: 2 台
- ポートマッピング: 8080:80, 8443:443

### アプリケーション設定

各コンポーネントの設定は`k8s/base/`ディレクトリ内のマニフェストで管理：

- **API Server**: `ghcr.io/keitashimura/logs-collector-api:v0.0.5`
- **PostgreSQL**: `postgres:17`
- **Elasticsearch**: `elasticsearch:8.18.1`
- **NATS**: `nats:2.10-alpine`

## 動作確認

### ログ確認

```bash
# APIサーバーのログ
kubectl logs -f deployment/logs-collector-api -n logs-system

# PostgreSQLのログ
kubectl logs -f statefulset/db -n logs-system

# Elasticsearchのログ
kubectl logs -f deployment/elasticsearch -n logs-system

# NATSのログ
kubectl logs -f deployment/nats -n logs-system
```

### ポートフォワードによるアクセス

#### REST API

```bash
kubectl -n logs-system port-forward svc/logs-collector-api 8080:8080
# 別ターミナルで
curl -i http://localhost:8080/healthz
```

#### gRPC API

```bash
kubectl -n logs-system port-forward svc/logs-collector-api 50051:50051
# grpcurlなどで疎通確認
grpcurl -plaintext localhost:50051 list
```

#### Elasticsearch

```bash
kubectl -n logs-system port-forward svc/elasticsearch 19200:9200
# 別ターミナルで
curl -s localhost:19200/
```

正常に起動していれば、以下のようなクラスタ情報が返ってきます：

```json
{
  "name": "elasticsearch-7b4c7d4b4d-xxxx",
  "cluster_name": "docker-cluster",
  "cluster_uuid": "FJp_8T1cR7y5i3l9Q8w9kA",
  "version": {
    "number": "8.18.1",
    "build_flavor": "default",
    "build_type": "docker",
    "build_hash": "d2e1c8b5e0c6b7a2f4d7e7a1b6c7e1f3b7c6d8f1",
    "build_date": "2024-05-27T10:25:39.123456789Z",
    "build_snapshot": false,
    "lucene_version": "9.9.2",
    "minimum_wire_compatibility_version": "7.17.0",
    "minimum_index_compatibility_version": "7.0.0"
  },
  "tagline": "You Know, for Search"
}
```

## 🖥️ Apple Silicon (arm64) 対応

Apple Silicon (M1/M2) 環境では、arm64 アーキテクチャでビルドし、k3d クラスターへインポートする必要があります。

### ローカルでビルド（arm64）

```bash
docker build -t ghcr.io/keitashimura/logs-collector-api:v0.0.5 .
k3d image import ghcr.io/keitashimura/logs-collector-api:v0.0.5 -c logs-cluster
# pull させずに使えるようになる（imagePullPolicy: IfNotPresent 推奨）
```

AMD64 環境（GCP/AWS など）ではこの手順は不要です。

## セキュリティ

### 現在の設定

- Elasticsearch: セキュリティ無効化（ローカル開発用）
- PostgreSQL: テスト用認証情報
- NATS: 認証なし（ローカル開発用）

### 本番環境での注意点

本番環境では以下の設定を推奨します：

- 適切な認証・認可の設定
- シークレット管理の実装
- ネットワークポリシーの設定
- リソース制限の設定

## 開発ガイド

### 新しいコンポーネントの追加

1. `k8s/base/`に新しいディレクトリを作成
2. 必要なマニフェストファイルを追加
3. `k8s/base/kustomization.yaml`にリソースを追加
4. 必要に応じて`k8s/overlays/local/`で環境固有の設定を追加

### マニフェストの変更

```bash
# 差分確認
make diff

# 適用
make apply
```

### デプロイ後の確認

```bash
# Pod の一覧を確認
kubectl --context k3d-logs-cluster -n logs-system get pods

# API サーバーのログをリアルタイムで確認
kubectl --context k3d-logs-cluster -n logs-system logs -f deploy/logs-collector-api
```

## トラブルシューティング

### よくある問題

#### 1. クラスターが起動しない

```bash
# クラスターの状態確認
k3d cluster list
```

#### 2. Pod が起動しない

```bash
# Pod の詳細確認
kubectl describe pod <pod-name> -n logs-system

# イベント確認
kubectl get events -n logs-system --sort-by='.lastTimestamp'
```

#### 3. ポートフォワードができない

```bash
# サービス確認
kubectl get svc -n logs-system

# エンドポイント確認
kubectl get endpoints -n logs-system
```

### ログの確認方法

```bash
# 特定のPodのログ
kubectl logs <pod-name> -n logs-system

# リアルタイムログ
kubectl logs -f <pod-name> -n logs-system

# 前回のログ
kubectl logs <pod-name> -n logs-system --previous
```
