#!/bin/bash

# ==========================================
# Script de Restauration Infrastructure TAAF
# ==========================================

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 "
    echo ""
    echo "Exemple: $0 /backup/taaf/taaf-backup-20241210_143000.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"
RESTORE_DIR="/tmp/taaf-restore-$$"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}⚠️  ATTENTION: Cette opération va écraser les données actuelles !${NC}"
echo ""
read -p "Êtes-vous sûr de vouloir continuer ? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restauration annulée"
    exit 0
fi

echo -e "${GREEN}🔄 Démarrage de la restauration...${NC}"
echo ""

# 1. Arrêter les services
echo -e "${YELLOW}⏸️  Arrêt des services...${NC}"
cd ~/taaf-infrastructure
docker compose down

# 2. Extraire la sauvegarde
echo -e "${YELLOW}📦 Extraction de la sauvegarde...${NC}"
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

BACKUP_NAME=$(basename "$BACKUP_FILE" .tar.gz)
EXTRACT_DIR="$RESTORE_DIR/$BACKUP_NAME"

# 3. Restaurer les données
echo -e "${YELLOW}💾 Restauration des données...${NC}"

# Sauvegarder l'ancien data (au cas où)
if [ -d ~/taaf-infrastructure/data ]; then
    mv ~/taaf-infrastructure/data ~/taaf-infrastructure/data.backup-$(date +%s)
fi

# Restaurer GitLab
echo "  → GitLab..."
tar -xzf "$EXTRACT_DIR/gitlab.tar.gz" -C ~/taaf-infrastructure/data/

# Restaurer Nextcloud
echo "  → Nextcloud..."
tar -xzf "$EXTRACT_DIR/nextcloud.tar.gz" -C ~/taaf-infrastructure/data/

# Restaurer Mattermost
echo "  → Mattermost..."
tar -xzf "$EXTRACT_DIR/mattermost.tar.gz" -C ~/taaf-infrastructure/data/

# 4. Démarrer les bases de données
echo -e "${YELLOW}🗄️  Restauration des bases de données...${NC}"
docker compose up -d postgres nextcloud_db mattermost_db
sleep 15

# Restaurer les dumps SQL
echo "  → PostgreSQL (GitLab)..."
docker compose exec -T postgres psql -U taaf_user -d gitlab < "$EXTRACT_DIR/gitlab-db.sql"

echo "  → PostgreSQL (Nextcloud)..."
docker compose exec -T nextcloud_db psql -U nextcloud_user -d nextcloud < "$EXTRACT_DIR/nextcloud-db.sql"

echo "  → PostgreSQL (Mattermost)..."
docker compose exec -T mattermost_db psql -U mattermost_user -d mattermost < "$EXTRACT_DIR/mattermost-db.sql"

# 5. Restaurer les configurations (optionnel)
echo -e "${YELLOW}⚙️  Restauration des configurations...${NC}"
if [ -f "$EXTRACT_DIR/config.tar.gz" ]; then
    tar -xzf "$EXTRACT_DIR/config.tar.gz" -C ~/
fi

# 6. Redémarrer tous les services
echo -e "${YELLOW}▶️  Redémarrage de tous les services...${NC}"
docker compose up -d

# 7. Nettoyage
echo -e "${YELLOW}🧹 Nettoyage...${NC}"
rm -rf "$RESTORE_DIR"

echo ""
echo -e "${GREEN}✅ Restauration terminée avec succès !${NC}"
echo ""
echo "Vérifiez que tous les services fonctionnent correctement:"
echo "  docker compose ps"