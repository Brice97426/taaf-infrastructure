#!/bin/bash

echo "📊 Monitoring des Performances TAAF"
echo "===================================="
echo ""

# Utilisation CPU/RAM par conteneur
echo "1. Ressources par conteneur:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo "2. Espace disque des volumes:"
docker system df -v | grep taaf-infrastructure

echo ""
echo "3. Temps de réponse des services:"
for url in "http://git.taaf.internal" "http://cloud.taaf.internal" "http://chat.taaf.internal"; do
    response_time=$(curl -o /dev/null -s -w '%{time_total}' "$url")
    echo "$url: ${response_time}s"
done