# プロジェクト起動ガイド

## 概要
defoプロジェクトとGojigen-dockerプロジェクトは、以下の2つのモードで起動できます：

1. **通常起動**: 各プロジェクトが独立して動作
2. **DB間連携起動**: プロジェクト間でデータベースの相互接続が可能

## 🚀 クイックスタート

### 自動セットアップ（推奨）
```bash
# WSL環境で実行
wsl ./setup-cross-project-network.sh
```

起動モードを選択するプロンプトが表示されます：
- `1`: 通常起動（環境変数不要）
- `2`: DB間連携起動

### 手動起動

#### 通常起動
```bash
# defoプロジェクト
cd defo
docker compose up -d

# Gojigen-dockerプロジェクト  
cd ../Gojigen-docker
docker compose up -d
```

#### DB間連携起動
```bash
# 共通ネットワーク作成
docker network create cross-project-network

# defoプロジェクト（DB間連携付き）
cd defo
docker compose -f compose.yaml -f compose.cross-db.yaml up -d

# Gojigen-dockerプロジェクト（DB間連携付き）
cd ../Gojigen-docker
docker compose -f compose.yaml -f compose.cross-db.yaml up -d
```

## 📋 接続情報

### 通常起動時
| サービス | URL/接続先 | 説明 |
|---------|-----------|------|
| defo App | http://localhost:8080 | defoアプリケーション |
| defo DB | localhost:3306 | defoデータベース |
| defo phpMyAdmin | http://localhost:4040 | defoデータベース管理 |
| Gojigen App | http://localhost:8081 | Gojigenアプリケーション |
| Gojigen DB | localhost:3307 | Gojigenデータベース |
| Gojigen phpMyAdmin | http://localhost:4041 | Gojigenデータベース管理 |

### DB間連携起動時
上記に加えて、アプリケーション間で以下の接続が可能：
- defoアプリ → Gojigen DB: `gojigen-db-container:3306`
- Gojigenアプリ → defo DB: `db-container:3306`

## 📁 ファイル構成

### 主要設定ファイル
```
├── defo/
│   ├── compose.yaml                # 通常起動用設定
│   └── compose.cross-db.yaml      # DB間連携用オーバーライド
├── Gojigen-docker/
│   ├── compose.yaml                # 通常起動用設定
│   └── compose.cross-db.yaml      # DB間連携用オーバーライド
├── setup-cross-project-network.sh # 自動セットアップスクリプト
├── PROJECT_SETUP_GUIDE.md         # このファイル
└── cross-db-connection-examples.md # DB間連携実装例
```

### 設定ファイルの役割

#### `compose.yaml` (各プロジェクト)
- 基本的なサービス構成
- 環境変数に依存しない設定
- 単独で動作可能

#### `compose.cross-db.yaml` (各プロジェクト) 
- DB間連携用の環境変数設定
- `compose.yaml` にオーバーライドして使用
- オプション設定ファイル

## 💻 Laravel実装例

### DB接続設定の追加

#### defoプロジェクト（config/database.php）
```php
'connections' => [
    // 既存の設定...
    'gojigen' => [
        'driver' => 'mysql',
        'host' => env('GOJIGEN_DB_HOST', 'gojigen-db-container'),
        'port' => env('GOJIGEN_DB_PORT', '3306'),
        'database' => env('GOJIGEN_DB_DATABASE', 'database'),
        'username' => env('GOJIGEN_DB_USERNAME', 'user'),
        'password' => env('GOJIGEN_DB_PASSWORD', 'password'),
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
    ],
],
```

#### Gojigen-dockerプロジェクト（config/database.php）
```php
'connections' => [
    // 既存の設定...
    'defo' => [
        'driver' => 'mysql',
        'host' => env('DEFO_DB_HOST', 'db-container'),
        'port' => env('DEFO_DB_PORT', '3306'),
        'database' => env('DEFO_DB_DATABASE', 'database'),
        'username' => env('DEFO_DB_USERNAME', 'user'),
        'password' => env('DEFO_DB_PASSWORD', 'test'),
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
    ],
],
```

### 使用例
```php
// Gojigen DBからデータを取得（defoアプリ内）
$gojigenUsers = DB::connection('gojigen')->table('users')->get();

// defo DBからデータを取得（Gojigenアプリ内）
$defoProducts = DB::connection('defo')->table('products')->get();
```

## 🔧 トラブルシューティング

### ポート競合エラー
```bash
# 使用中ポートの確認
netstat -an | findstr :3306
netstat -an | findstr :3307

# コンテナの停止
docker compose down
```

### ネットワーク接続エラー
```bash
# ネットワーク確認
docker network ls | grep cross-project

# ネットワーク詳細
docker network inspect cross-project-network

# コンテナ間疎通確認
docker exec -it app-container ping gojigen-db-container
```

### 設定リセット
```bash
# 全コンテナ停止
cd defo && docker compose down
cd ../Gojigen-docker && docker compose down

# ネットワーク削除（必要に応じて）
docker network rm cross-project-network

# 再セットアップ
./setup-cross-project-network.sh
```

## 📝 追加情報

- 詳細な実装例: `cross-db-connection-examples.md`
- DB間連携が不要な場合は通常起動を使用
- 本番環境では適切なセキュリティ設定を実装
- 環境変数は `.env` ファイルでの管理も可能 