#!/bin/bash

# ==========================================
# Script de Mise à Jour Infrastructure TAAF
# ==========================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔄 Mise à jour de l'infrastructure TAAF${NC}"
echo ""

cd ~/taaf-infrastructure

# 1. Créer une sauvegarde avant mise à jour
echo -e "${YELLOW}💾 Création d'une sauvegarde de sécurité...${NC}"
./scripts/backup.sh

# 2. Télécharger les nouvelles images
echo -e "${YELLOW}📥 Téléchargement des nouvelles images...${NC}"
docker compose pull

# 3. Recréer les conteneurs avec les nouvelles images
echo -e "${YELLOW}🔄 Mise à jour des conteneurs...${NC}"
docker compose up -d --force-recreate

# 4. Vérifier que tout fonctionne
echo -e "${YELLOW}✅ Vérification des services...${NC}"
sleep 30
docker compose ps

# 5. Nettoyer les anciennes images
echo -e "${YELLOW}🧹 Nettoyage des anciennes images...${NC}"
docker image prune -f

echo ""
echo -e "${GREEN}✅ Mise à jour terminée !${NC}"
echo ""
echo "Vérifiez les logs si nécessaire:"
echo "  docker compose logs -f"