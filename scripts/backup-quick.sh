#!/bin/bash

# Sauvegarde rapide sans arrêt des services
BACKUP_DIR="/backup/taaf-quick"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "🔄 Sauvegarde rapide..."

# Sauvegarder uniquement les données modifiées récemment
rsync -av --update ~/taaf-infrastructure/data/ "$BACKUP_DIR/data-$TIMESTAMP/"

# Dump des bases de données
docker compose exec -T postgres pg_dump -U taaf_user gitlab > "$BACKUP_DIR/gitlab-db-$TIMESTAMP.sql"

echo "✅ Sauvegarde rapide terminée"