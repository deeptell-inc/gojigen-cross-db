#!/bin/bash

echo "=== プロジェクト起動スクリプト ==="
echo ""
echo "起動モードを選択してください:"
echo "1. 通常起動（各プロジェクト単独で動作）"
echo "2. DB間連携起動（プロジェクト間でDB相互接続）"
echo ""
read -p "選択してください (1 or 2): " choice

case $choice in
    1)
        echo "=== 通常起動モード ==="
        
        # 既存のコンテナを停止
        echo "1. 既存のコンテナを停止..."
        cd defo && docker compose down
        cd ../Gojigen-docker && docker compose down
        cd ..
        
        # defoプロジェクトの起動
        echo "2. defoプロジェクトの起動..."
        cd defo && docker compose up -d
        cd ..
        
        # Gojigen-dockerプロジェクトの起動
        echo "3. Gojigen-dockerプロジェクトの起動..."
        cd Gojigen-docker && docker compose up -d
        cd ..
        
        echo "=== 通常起動完了 ==="
        echo ""
        echo "接続情報:"
        echo "- defo DB: localhost:3306"
        echo "- Gojigen DB: localhost:3307"
        echo "- defo App: http://localhost:8080"
        echo "- Gojigen App: http://localhost:8081"
        echo "- defo phpMyAdmin: http://localhost:4040"
        echo "- Gojigen phpMyAdmin: http://localhost:4041"
        ;;
        
    2)
        echo "=== DB間連携起動モード ==="
        
        # 共通ネットワークの作成
        echo "1. 共通ネットワークの作成..."
        docker network create cross-project-network 2>/dev/null || echo "ネットワークは既に存在します"
        
        # 既存のコンテナを停止
        echo "2. 既存のコンテナを停止..."
        cd defo && docker compose -f compose.yaml -f compose.cross-db.yaml down
        cd ../Gojigen-docker && docker compose -f compose.yaml -f compose.cross-db.yaml down
        cd ..
        
        # defoプロジェクトの起動（DB間連携付き）
        echo "3. defoプロジェクトの起動（DB間連携付き）..."
        cd defo && docker compose -f compose.yaml -f compose.cross-db.yaml up -d
        cd ..
        
        # Gojigen-dockerプロジェクトの起動（DB間連携付き）
        echo "4. Gojigen-dockerプロジェクトの起動（DB間連携付き）..."
        cd Gojigen-docker && docker compose -f compose.yaml -f compose.cross-db.yaml up -d
        cd ..
        
        echo "=== DB間連携起動完了 ==="
        echo ""
        echo "接続情報:"
        echo "- defo DB: localhost:3306"
        echo "- Gojigen DB: localhost:3307"
        echo "- defo App: http://localhost:8080"
        echo "- Gojigen App: http://localhost:8081"
        echo "- defo phpMyAdmin: http://localhost:4040"
        echo "- Gojigen phpMyAdmin: http://localhost:4041"
        echo ""
        echo "DB間連携:"
        echo "- defoアプリからGojigen DBへ: gojigen-db-container:3306"
        echo "- GojigenアプリからdefoDBへ: db-container:3306"
        echo ""
        echo "ネットワーク状態を確認:"
        echo "docker network inspect cross-project-network"
        ;;
        
    *)
        echo "無効な選択です。1 または 2 を選択してください。"
        exit 1
        ;;
esac 