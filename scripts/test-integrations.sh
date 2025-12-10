#!/bin/bash

echo "==================================="
echo "Tests d'intégration TAAF"
echo "==================================="
echo ""

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de test
test_service() {
    SERVICE=$1
    URL=$2
    
    echo -n "Test de $SERVICE... "
    
    if curl -f -s -o /dev/null "$URL"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ ÉCHEC${NC}"
        return 1
    fi
}

# Test des services
echo "1. Test d'accessibilité des services"
echo "-------------------------------------"
test_service "GitLab" "http://git.taaf.internal/-/health"
test_service "Nextcloud" "http://cloud.taaf.internal/status.php"
test_service "Mattermost" "http://chat.taaf.internal/api/v4/system/ping"
echo ""

# Test des webhooks
echo "2. Test des services webhook"
echo "-------------------------------------"
if docker-compose ps | grep -q "gitlab-webhook.*Up"; then
    echo -e "${GREEN}✓${NC} Webhook GitLab actif"
else
    echo -e "${RED}✗${NC} Webhook GitLab inactif"
fi

if docker-compose ps | grep -q "nextcloud-monitor.*Up"; then
    echo -e "${GREEN}✓${NC} Monitor Nextcloud actif"
else
    echo -e "${RED}✗${NC} Monitor Nextcloud inactif"
fi
echo ""

# Test de la communication inter-services
echo "3. Test de communication réseau"
echo "-------------------------------------"
if docker-compose exec -T gitlab ping -c 1 mattermost > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} GitLab → Mattermost"
else
    echo -e "${RED}✗${NC} GitLab → Mattermost"
fi

if docker-compose exec -T nextcloud ping -c 1 mattermost > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Nextcloud → Mattermost"
else
    echo -e "${RED}✗${NC} Nextcloud → Mattermost"
fi
echo ""

echo "==================================="
echo "Tests terminés"
echo "==================================="
