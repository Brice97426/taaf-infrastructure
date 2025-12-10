#!/bin/bash

echo "🔍 Diagnostic Réseau TAAF"
echo "=========================="
echo ""

# 1. Vérifier le réseau Docker
echo "1. Réseau Docker:"
docker network ls | grep taaf
echo ""

# 2. Inspecter le réseau
echo "2. Conteneurs sur le réseau:"
docker network inspect taaf-infrastructure_taaf_network | jq -r '.[].Containers | to_entries[] | "\(.value.Name): \(.value.IPv4Address)"'
echo ""

# 3. Tester la connectivité entre services
echo "3. Tests de connectivité:"

services=("gitlab" "nextcloud" "mattermost" "caddy")
for src in "${services[@]}"; do
    for dst in "${services[@]}"; do
        if [ "$src" != "$dst" ]; then
            result=$(docker compose exec -T "$src" ping -c 1 -W 1 "$dst" 2>&1 | grep -q "1 received" && echo "✅" || echo "❌")
            echo "$result $src → $dst"
        fi
    done
done

echo ""
echo "4. Ports exposés:"
docker compose ps --format "table {{.Service}}\t{{.Ports}}"
