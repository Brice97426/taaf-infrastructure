#!/bin/bash

# ==========================================
# Script de Sauvegarde Infrastructure TAAF
# ==========================================

set -e

# Configuration
BACKUP_DIR="/backup/taaf"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="taaf-backup-$TIMESTAMP"
RETENTION_DAYS=30

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔄 Démarrage de la sauvegarde TAAF${NC}"
echo "Date: $(date)"
echo ""

# Créer le dossier de backup
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# 1. Arrêter les services (optionnel pour cohérence)
echo -e "${YELLOW}⏸️  Arrêt des services...${NC}"
cd ~/taaf-infrastructure
docker compose stop

# 2. Sauvegarder les volumes Docker
echo -e "${YELLOW}💾 Sauvegarde des volumes...${NC}"

# GitLab
echo "  → GitLab..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME/gitlab.tar.gz" -C ~/taaf-infrastructure/data gitlab/

# Nextcloud
echo "  → Nextcloud..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME/nextcloud.tar.gz" -C ~/taaf-infrastructure/data nextcloud/

# Mattermost
echo "  → Mattermost..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME/mattermost.tar.gz" -C ~/taaf-infrastructure/data mattermost/

# 3. Sauvegarder les bases de données
echo -e "${YELLOW}🗄️  Sauvegarde des bases de données...${NC}"

# Redémarrer temporairement les bases
docker compose start postgres nextcloud_db mattermost_db
sleep 10

# PostgreSQL (GitLab)
echo "  → PostgreSQL (GitLab)..."
docker compose exec -T postgres pg_dump -U taaf_user gitlab > "$BACKUP_DIR/$BACKUP_NAME/gitlab-db.sql"

# PostgreSQL (Nextcloud)
echo "  → PostgreSQL (Nextcloud)..."
docker compose exec -T nextcloud_db pg_dump -U nextcloud_user nextcloud > "$BACKUP_DIR/$BACKUP_NAME/nextcloud-db.sql"

# PostgreSQL (Mattermost)
echo "  → PostgreSQL (Mattermost)..."
docker compose exec -T mattermost_db pg_dump -U mattermost_user mattermost > "$BACKUP_DIR/$BACKUP_NAME/mattermost-db.sql"

# 4. Sauvegarder les configurations
echo -e "${YELLOW}⚙️  Sauvegarde des configurations...${NC}"
tar -czf "$BACKUP_DIR/$BACKUP_NAME/config.tar.gz" \
    ~/taaf-infrastructure/docker-compose.yml \
    ~/taaf-infrastructure/caddy/ \
    ~/taaf-infrastructure/scripts/

# 5. Créer une archive finale
echo -e "${YELLOW}📦 Création de l'archive finale...${NC}"
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME/"
rm -rf "$BACKUP_NAME/"

# 6. Redémarrer les services
echo -e "${YELLOW}▶️  Redémarrage des services...${NC}"
cd ~/taaf-infrastructure
docker compose up -d

# 7. Nettoyage des anciennes sauvegardes
echo -e "${YELLOW}🧹 Nettoyage des sauvegardes anciennes (>$RETENTION_DAYS jours)...${NC}"
find "$BACKUP_DIR" -name "taaf-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete

# 8. Vérification
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)
echo ""
echo -e "${GREEN}✅ Sauvegarde terminée avec succès !${NC}"
echo "📁 Fichier: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "📊 Taille: $BACKUP_SIZE"
echo ""

# Optionnel: Envoyer une notification Mattermost
if [ -n "$MATTERMOST_WEBHOOK_URL" ]; then
    curl -X POST "$MATTERMOST_WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{
            \"text\": \"✅ Sauvegarde TAAF terminée\",
            \"attachments\": [{
                \"color\": \"#00ff00\",
                \"fields\": [
                    {\"short\": true, \"title\": \"Taille\", \"value\": \"$BACKUP_SIZE\"},
                    {\"short\": true, \"title\": \"Date\", \"value\": \"$(date)\"}
                ]
            }]
        }" 2>/dev/null
fi
