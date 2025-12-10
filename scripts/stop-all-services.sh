#!/bin/bash

echo "🛑 Arrêt de l'Infrastructure TAAF"
echo "==================================="

cd ~/taaf-infrastructure

# 1. Arrêter le webhook GitLab
if [ -f scripts/webhooks/webhook_gitlab.pid ]; then
    echo "🔗 Arrêt du GitLab Webhook..."
    kill $(cat scripts/webhooks/webhook_gitlab.pid) 2>/dev/null
    rm scripts/webhooks/webhook_gitlab.pid
fi

# 2. Arrêter le monitor Nextcloud
if [ -f scripts/monitoring/monitor.pid ]; then
    echo "🔍 Arrêt du Nextcloud Monitor..."
    kill $(cat scripts/monitoring/monitor.pid) 2>/dev/null
    rm scripts/monitoring/monitor.pid
fi

# 3. Arrêter Docker Compose
echo "📦 Arrêt des conteneurs Docker..."
docker compose down

echo ""
echo "✅ Infrastructure TAAF arrêtée !"