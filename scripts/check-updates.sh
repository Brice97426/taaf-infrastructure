#!/bin/bash

echo "🔍 Vérification des mises à jour disponibles..."
echo ""

cd ~/taaf-infrastructure

# Pour chaque service, vérifier la version
services=("gitlab/gitlab-ce" "nextcloud" "mattermost/mattermost-team-edition" "caddy" "postgres")

for service in "${services[@]}"; do
    echo "📦 $service"
    
    # Version locale
    local_version=$(docker images --format "{{.Tag}}" "$service" | head -1)
    echo "  Local: $local_version"
    
    # Version disponible sur Docker Hub (simplifié)
    echo "  Vérifiez sur: https://hub.docker.com/r/$service/tags"
    echo ""
done

echo "Pour mettre à jour, exécutez: ./scripts/update.sh"