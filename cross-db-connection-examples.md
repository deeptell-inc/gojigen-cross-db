# DB間相互連携設定ガイド

## 概要
defoプロジェクトとGojigen-dockerプロジェクトのデータベース間で相互連携を実現するための設定が完了しています。

## 設定完了項目

### ネットワーク設定
- 両プロジェクトが `cross-project-network` で接続
- defo DB: `db-container:3306` (外部ポート: 3306)
- Gojigen DB: `gojigen-db-container:3306` (外部ポート: 3307)

### 環境変数
両プロジェクトのアプリケーションコンテナに相手のDB接続情報が設定済み

## 使用方法

### 1. セットアップの実行
```bash
chmod +x setup-cross-project-network.sh
./setup-cross-project-network.sh
```

### 2. Laravelでの実装例

#### defoプロジェクトからGojigen DBへの接続

**config/database.php に追加:**
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
        'unix_socket' => '',
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'strict' => true,
        'engine' => null,
    ],
],
```

**使用例:**
```php
// Gojigen DBからデータを取得
$gojigenData = DB::connection('gojigen')
    ->table('users')
    ->where('active', 1)
    ->get();

// Gojigen DBにデータを挿入
DB::connection('gojigen')
    ->table('sync_logs')
    ->insert([
        'source' => 'defo',
        'action' => 'data_sync',
        'created_at' => now(),
    ]);
```

#### Gojigen-dockerプロジェクトからdefo DBへの接続

**config/database.php に追加:**
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
        'unix_socket' => '',
        'charset' => 'utf8mb4',
        'collation' => 'utf8mb4_unicode_ci',
        'prefix' => '',
        'strict' => true,
        'engine' => null,
    ],
],
```

**使用例:**
```php
// defo DBからデータを取得
$defoData = DB::connection('defo')
    ->table('products')
    ->where('published', true)
    ->get();

// defo DBにデータを挿入
DB::connection('defo')
    ->table('integration_logs')
    ->insert([
        'source' => 'gojigen',
        'action' => 'product_sync',
        'created_at' => now(),
    ]);
```

### 3. データ同期の実装例

#### 相互同期のArtisanコマンド例

**defoプロジェクト用 (app/Console/Commands/SyncWithGojigen.php):**
```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SyncWithGojigen extends Command
{
    protected $signature = 'sync:gojigen';
    protected $description = 'Sync data with Gojigen database';

    public function handle()
    {
        $this->info('Starting sync with Gojigen DB...');
        
        try {
            // Gojigen から新しいユーザーを取得
            $newUsers = DB::connection('gojigen')
                ->table('users')
                ->where('synced_to_defo', false)
                ->get();

            foreach ($newUsers as $user) {
                // defo DB にユーザーを作成
                DB::connection('mysql')->table('users')->insert([
                    'name' => $user->name,
                    'email' => $user->email,
                    'source' => 'gojigen',
                    'source_id' => $user->id,
                    'created_at' => now(),
                ]);

                // Gojigen DB で同期済みフラグを更新
                DB::connection('gojigen')
                    ->table('users')
                    ->where('id', $user->id)
                    ->update(['synced_to_defo' => true]);
            }

            $this->info("Synced {$newUsers->count()} users from Gojigen");
        } catch (\Exception $e) {
            $this->error('Sync failed: ' . $e->getMessage());
        }
    }
}
```

### 4. 接続テスト

**接続テスト用のルート例:**
```php
// routes/web.php または routes/api.php
Route::get('/test-cross-db', function () {
    try {
        // 自身のDB接続テスト
        $localCount = DB::table('users')->count();
        
        // 相手のDB接続テスト（defoの場合）
        $remoteCount = DB::connection('gojigen')->table('users')->count();
        
        return response()->json([
            'status' => 'success',
            'local_users' => $localCount,
            'remote_users' => $remoteCount,
            'message' => 'Cross-database connection working!'
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'status' => 'error',
            'message' => $e->getMessage()
        ], 500);
    }
});
```

## トラブルシューティング

### 接続エラーの場合
1. ネットワークが作成されているか確認:
   ```bash
   docker network ls | grep cross-project
   ```

2. コンテナがネットワークに接続されているか確認:
   ```bash
   docker network inspect cross-project-network
   ```

3. コンテナ間の疎通確認:
   ```bash
   # defoコンテナからGojigenDBへ
   docker exec -it app-container ping gojigen-db-container
   
   # GojigenコンテナからdefoDB へ
   docker exec -it gojigen-app-container ping db-container
   ```

### 再起動が必要な場合
```bash
./setup-cross-project-network.sh
```

## セキュリティ考慮事項
- 本番環境では適切なユーザー権限とパスワードを設定
- ネットワークレベルでのアクセス制御を実装
- データ同期時はトランザクションを適切に管理 

