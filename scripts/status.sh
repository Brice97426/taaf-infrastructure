#!/bin/bash

echo "📊 État de l'Infrastructure TAAF"
echo "=================================="
echo ""

cd ~/taaf-infrastructure

# Docker Compose
echo "🐳 Conteneurs Docker :"
docker compose ps
echo ""

# Webhook GitLab
echo "🔗 GitLab Webhook :"
if [ -f scripts/webhooks/webhook_gitlab.pid ]; then
    PID=$(cat scripts/webhooks/webhook_gitlab.pid)
    if ps -p $PID > /dev/null; then
        echo "  ✅ Actif (PID: $PID)"
    else
        echo "  ❌ Inactif (PID obsolète)"
    fi
else
    echo "  ❌ Non démarré"
fi
echo ""

# Monitor Nextcloud
echo "🔍 Nextcloud Monitor :"
if [ -f scripts/monitoring/monitor.pid ]; then
    PID=$(cat scripts/monitoring/monitor.pid)
    if ps -p $PID > /dev/null; then
        echo "  ✅ Actif (PID: $PID)"
    else
        echo "  ❌ Inactif (PID obsolète)"
    fi
else
    echo "  ❌ Non démarré"
fi
echo ""

# Connectivité
echo "🌐 Tests de connectivité :"
for url in "http://taaf.internal" "http://git.taaf.internal" "http://cloud.taaf.internal" "http://chat.taaf.internal"; do
    if curl -s -o /dev/null -w "%{http_code}" $url | grep -q "200\|302"; then
        echo "  ✅ $url"
    else
        echo "  ❌ $url"
    fi
done