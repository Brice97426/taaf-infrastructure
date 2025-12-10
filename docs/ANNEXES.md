# 📚 Annexes - Infrastructure TAAF

> **Ressources complémentaires, guides de maintenance et documentation technique avancée**

---

## 📋 Table des Matières

- [1. Guide de Sauvegarde et Restauration](#1-guide-de-sauvegarde-et-restauration)
- [2. Procédures de Mise à Jour](#2-procédures-de-mise-à-jour)
- [3. Troubleshooting Approfondi](#3-troubleshooting-approfondi)
- [4. Optimisations de Performance](#4-optimisations-de-performance)
- [5. Checklist de Sécurité](#5-checklist-de-sécurité)
- [6. Glossaire Technique](#6-glossaire-technique)
- [7. Ressources Complémentaires](#7-ressources-complémentaires)

---

## 1. Guide de Sauvegarde et Restauration

### 1.1 Stratégie de Sauvegarde

#### Types de Données à Sauvegarder

```
Infrastructure TAAF
├── Données critiques (PRIORITÉ 1)
│   ├── Dépôts Git (GitLab)
│   ├── Fichiers utilisateurs (Nextcloud)
│   ├── Messages et historique (Mattermost)
│   └── Bases de données
│
├── Configurations (PRIORITÉ 2)
│   ├── docker-compose.yml
│   ├── Caddyfile
│   ├── Scripts d'intégration
│   └── Fichiers .env (chiffrés)
│
└── Logs (PRIORITÉ 3)
    ├── Logs applicatifs
    └── Logs d'accès
```

---

### 1.2 Script de Sauvegarde Automatique

#### 1.2.1 Sauvegarde Complète

```bash
cat > ~/taaf-infrastructure/scripts/backup.sh << 'EOF'
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

EOF

chmod +x ~/taaf-infrastructure/scripts/backup.sh
```

#### 1.2.2 Sauvegarde Incrémentielle (Rapide)

```bash
cat > ~/taaf-infrastructure/scripts/backup-quick.sh << 'EOF'
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
EOF

chmod +x ~/taaf-infrastructure/scripts/backup-quick.sh
```

---

### 1.3 Restauration depuis une Sauvegarde

```bash
cat > ~/taaf-infrastructure/scripts/restore.sh << 'EOF'
#!/bin/bash

# ==========================================
# Script de Restauration Infrastructure TAAF
# ==========================================

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <fichier-backup.tar.gz>"
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

EOF

chmod +x ~/taaf-infrastructure/scripts/restore.sh
```

---

### 1.4 Automatisation des Sauvegardes avec Cron

```bash
# Éditer le crontab
crontab -e

# Ajouter ces lignes:

# Sauvegarde complète tous les dimanches à 2h du matin
0 2 * * 0 /home/user/taaf-infrastructure/scripts/backup.sh >> /var/log/taaf-backup.log 2>&1

# Sauvegarde rapide tous les jours à 23h
0 23 * * * /home/user/taaf-infrastructure/scripts/backup-quick.sh >> /var/log/taaf-backup-quick.log 2>&1
```

---

## 2. Procédures de Mise à Jour

### 2.1 Mise à Jour des Images Docker

#### 2.1.1 Vérifier les Nouvelles Versions

```bash
cat > ~/taaf-infrastructure/scripts/check-updates.sh << 'EOF'
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
EOF

chmod +x ~/taaf-infrastructure/scripts/check-updates.sh
```

#### 2.1.2 Script de Mise à Jour

```bash
cat > ~/taaf-infrastructure/scripts/update.sh << 'EOF'
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

EOF

chmod +x ~/taaf-infrastructure/scripts/update.sh
```

---

### 2.2 Mise à Jour d'un Service Spécifique

```bash
# Exemple: Mise à jour de GitLab uniquement

# 1. Sauvegarder les données GitLab
docker compose exec -T postgres pg_dump -U taaf_user gitlab > /backup/gitlab-before-update.sql

# 2. Arrêter GitLab
docker compose stop gitlab

# 3. Télécharger la nouvelle image
docker compose pull gitlab

# 4. Redémarrer avec la nouvelle version
docker compose up -d gitlab

# 5. Vérifier les logs
docker compose logs -f gitlab
```

---

## 3. Troubleshooting Approfondi

### 3.1 Problèmes Courants et Solutions

#### 3.1.1 GitLab ne Démarre Pas

**Symptômes:**
```bash
docker compose ps
# gitlab    Exit 137
```

**Diagnostic:**
```bash
# Vérifier les logs
docker compose logs gitlab | tail -100

# Vérifier la mémoire disponible
free -h

# Vérifier l'espace disque
df -h
```

**Solutions:**

1. **Mémoire insuffisante:**
```bash
# Augmenter la mémoire partagée dans docker-compose.yml
services:
  gitlab:
    shm_size: '512m'  # Augmenter à 1g si nécessaire
```

2. **Port déjà utilisé:**
```bash
# Vérifier quel processus utilise le port
sudo lsof -i :80
sudo netstat -tulpn | grep :80

# Arrêter le service conflictuel
sudo systemctl stop apache2
```

3. **Base de données non accessible:**
```bash
# Vérifier que PostgreSQL est bien démarré
docker compose ps postgres

# Tester la connexion
docker compose exec postgres psql -U taaf_user -d gitlab -c "SELECT 1;"
```

---

#### 3.1.2 Nextcloud - Erreur "Trusted Domains"

**Symptômes:**
```
Access through untrusted domain
```

**Solution:**
```bash
# Ajouter le domaine de confiance
docker compose exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value=cloud.taaf.internal

# Vérifier la configuration
docker compose exec -u www-data nextcloud php occ config:system:get trusted_domains
```

---

#### 3.1.3 Mattermost - Erreur de Connexion à la Base

**Symptômes:**
```
Failed to ping DB retrying in 10 seconds
```

**Diagnostic:**
```bash
# Vérifier que la base est accessible
docker compose exec mattermost_db psql -U mattermost_user -d mattermost -c "SELECT 1;"

# Vérifier les variables d'environnement
docker compose exec mattermost env | grep MM_SQL
```

**Solution:**
```bash
# Recréer la base si nécessaire
docker compose exec mattermost_db psql -U mattermost_user -c "DROP DATABASE IF EXISTS mattermost;"
docker compose exec mattermost_db psql -U mattermost_user -c "CREATE DATABASE mattermost;"

# Redémarrer Mattermost
docker compose restart mattermost
```

---

#### 3.1.4 Webhooks ne Fonctionnent Pas

**Diagnostic:**
```bash
# Vérifier que le conteneur webhook tourne
docker compose ps gitlab-webhook

# Vérifier les logs
docker compose logs gitlab-webhook

# Tester manuellement le webhook
curl -X POST http://localhost:8090/webhook \
  -H 'Content-Type: application/json' \
  -d '{"test": "data"}'
```

**Solutions:**

1. **Webhook Mattermost invalide:**
```bash
# Vérifier l'URL dans docker-compose.yml
docker compose exec gitlab-webhook env | grep MATTERMOST_WEBHOOK_URL

# Tester le webhook Mattermost
curl -X POST "http://mattermost:8065/hooks/VOTRE_ID" \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test"}'
```

2. **Problème réseau:**
```bash
# Vérifier que les conteneurs sont sur le même réseau
docker network inspect taaf-infrastructure_taaf_network

# Tester la connectivité
docker compose exec gitlab-webhook ping -c 3 mattermost
```

---

### 3.2 Diagnostic Réseau Avancé

```bash
cat > ~/taaf-infrastructure/scripts/network-diagnostic.sh << 'EOF'
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

EOF

chmod +x ~/taaf-infrastructure/scripts/network-diagnostic.sh
```

---

## 4. Optimisations de Performance

### 4.1 Optimisation Docker

#### 4.1.1 Limiter les Ressources

```yaml
# Dans docker-compose.yml, ajouter pour chaque service:

services:
  gitlab:
    # ... configuration existante ...
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

#### 4.1.2 Optimisation des Volumes

```bash
# Utiliser des volumes nommés plutôt que des bind mounts pour de meilleures performances

volumes:
  gitlab_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/fast-ssd/gitlab  # SSD dédié
```

---

### 4.2 Optimisation GitLab

```ruby
# Dans docker-compose.yml, section GITLAB_OMNIBUS_CONFIG:

# Réduire le nombre de workers
puma['worker_processes'] = 2  # Au lieu de 4
sidekiq['concurrency'] = 10   # Au lieu de 25

# Désactiver les fonctionnalités non utilisées
prometheus_monitoring['enable'] = false
grafana['enable'] = false
gitlab_kas['enable'] = false

# Optimiser PostgreSQL
postgresql['shared_buffers'] = "256MB"
postgresql['work_mem'] = "16MB"
```

---

### 4.3 Optimisation Nextcloud

```bash
# Activer le caching Redis (optionnel)
docker compose exec -u www-data nextcloud php occ config:system:set memcache.local --value='\OC\Memcache\APCu'

# Configurer les jobs en arrière-plan
docker compose exec -u www-data nextcloud php occ background:cron

# Optimiser la base de données
docker compose exec -u www-data nextcloud php occ db:add-missing-indices
docker compose exec -u www-data nextcloud php occ db:convert-filecache-bigint
```

---

### 4.4 Monitoring des Performances

```bash
cat > ~/taaf-infrastructure/scripts/monitor-performance.sh << 'EOF'
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

EOF

chmod +x ~/taaf-infrastructure/scripts/monitor-performance.sh
```

---

## 5. Checklist de Sécurité

### 5.1 Sécurité de Base

- [ ] **Mots de passe forts** pour tous les comptes administrateurs
- [ ] **Fichier .env** non commité sur Git
- [ ] **Ports** : Seuls 80/443 exposés publiquement
- [ ] **SSH GitLab** sur port non-standard (2222)
- [ ] **Mises à jour** régulières des images Docker
- [ ] **Sauvegardes** automatiques configurées
- [ ] **Logs** conservés et analysés régulièrement

### 5.2 Durcissement de la Configuration

#### 5.2.1 Utiliser des Secrets Docker

```yaml
# docker-compose.yml
secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
  gitlab_root_password:
    file: ./secrets/gitlab_root_password.txt

services:
  postgres:
    secrets:
      - postgres_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
```

```bash
# Créer les fichiers de secrets
mkdir -p ~/taaf-infrastructure/secrets
echo "VotreMotDePasseSecure123!" > ~/taaf-infrastructure/secrets/postgres_password.txt
chmod 600 ~/taaf-infrastructure/secrets/*

# Ajouter au .gitignore
echo "secrets/" >> .gitignore
```

---

#### 5.2.2 Fail2ban pour Protection contre les Attaques

```bash
# Installer fail2ban
sudo apt install fail2ban

# Configurer pour GitLab
sudo tee /etc/fail2ban/jail.d/gitlab.conf << 'EOF'
[gitlab]
enabled = true
port = http,https
filter = gitlab
logpath = /home/user/taaf-infrastructure/data/gitlab/logs/gitlab-rails/production.log
maxretry = 5
bantime = 600
EOF

# Redémarrer fail2ban
sudo systemctl restart fail2ban
```

---

#### 5.2.3 Audit de Sécurité

```bash
cat > ~/taaf-infrastructure/scripts/security-audit.sh << 'EOF'
#!/bin/bash

echo "🔒 Audit de Sécurité TAAF"
echo "========================="
echo ""

# Vérifier les mots de passe par défaut
echo "1. Vérification des mots de passe par défaut:"
if grep -q "admin_password" ~/taaf-infrastructure/.env 2>/dev/null; then
    echo "⚠️  ATTENTION: Fichier .env contient des mots de passe"
fi

# Vérifier les ports exposés
echo ""
echo "2. Ports exposés:"
docker compose ps --format "table {{.Service}}\t{{.Ports}}" | grep "0.0.0.0"

# Vérifier les permissions
echo ""
echo "3. Permissions des fichiers sensibles:"
ls -la ~/taaf-infrastructure/.env 2>/dev/null

# Vérifier les images non signées
echo ""
echo "4. Images Docker:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Vérifier les CVE connues (nécessite trivy)
if command -v trivy &> /dev/null; then
    echo ""
    echo "5. Scan de vulnérabilités (Trivy):"
    trivy image gitlab/gitlab-ce:latest --severity HIGH,CRITICAL
fi

EOF

chmod +x ~/taaf-infrastructure/scripts/security-audit.sh
```

---

### 5.3 Configuration SSL/TLS (Production)

Pour un déploiement en production avec domaine réel :

```caddyfile
# caddy/Caddyfile (production)

# Activer HTTPS automatique
{
    email admin@votredomaine.com
}

git.votredomaine.com {
    reverse_proxy gitlab:80
    tls internal  # Ou automatique avec Let's Encrypt
}

cloud.votredomaine.com {
    reverse_proxy nextcloud:80
}

chat.votredomaine.com {
    reverse_proxy mattermost:8065
}
```

---

## 6. Glossaire Technique

### Termes Docker

| Terme | Définition |
|-------|------------|
| **Image** | Template en lecture seule contenant l'application et ses dépendances |
| **Conteneur** | Instance d'une image en cours d'exécution |
| **Volume** | Stockage persistant pour les données des conteneurs |
| **Network** | Réseau virtuel permettant la communication entre conteneurs |
| **Compose** | Outil pour définir et gérer des applications multi-conteneurs |
| **Health Check** | Test automatique vérifiant qu'un service fonctionne correctement |
| **Bind Mount** | Montage d'un dossier de l'hôte dans un conteneur |

### Termes Infrastructure

| Terme | Définition |
|-------|------------|
| **Reverse Proxy** | Serveur intermédiaire qui distribue les requêtes vers les services backend |
| **Webhook** | URL appelée automatiquement lors d'événements (push, MR, etc.) |
| **CI/CD** | Continuous Integration / Continuous Deployment (intégration et déploiement continus) |
| **DNS** | Domain Name System, système de résolution de noms de domaine |
| **SSL/TLS** | Protocoles de chiffrement pour sécuriser les communications |

### Commandes Essentielles

```bash
# Docker
docker ps                    # Lister les conteneurs actifs
docker logs <container>      # Voir les logs d'un conteneur
docker exec -it <container> bash  # Accéder au shell d'un conteneur
docker stats                 # Voir l'utilisation des ressources

# Docker Compose
docker compose up -d         # Démarrer tous les services
docker compose down          # Arrêter et supprimer les conteneurs
docker compose ps            # État des services
docker compose logs -f       # Suivre les logs en temps réel
docker compose restart       # Redémarrer les services
```

---

## 7. Ressources Complémentaires

### 7.1 Documentation Officielle

#### Docker et Conteneurisation
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Docker Security](https://docs.docker.com/engine/security/)

#### Services TAAF
- [GitLab Docker Installation](https://docs.gitlab.com/install/docker/installation/)
- [GitLab Administration](https://docs.gitlab.com/ee/administration/)
- [Nextcloud Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [Mattermost Deployment Guide](https://docs.mattermost.com/guides/deployment.html)
- [Caddy Documentation](https://caddyserver.com/docs/)

#### Intégrations
- [GitLab Webhooks](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html)
- [Mattermost Incoming Webhooks](https://docs.mattermost.com/developer/webhooks-incoming.html)
- [Python Watchdog](https://python-watchdog.readthedocs.io/)

---

### 7.2 Tutoriels et Guides

#### DevOps et Infrastructure
- [The Twelve-Factor App](https://12factor.net/) - Méthodologie de développement d'applications cloud
- [DevOps Roadmap](https://roadmap.sh/devops) - Parcours d'apprentissage DevOps
- [Docker Mastery](https://www.bretfisher.com/docker/) - Formation Docker complète

#### Sécurité
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) - Standards de sécurité Docker

---

### 7.3 Outils Recommandés

#### Monitoring et Observabilité
```yaml
# Ajouter Prometheus + Grafana (optionnel)
prometheus:
  image: prom/prometheus:latest
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
  ports:
    - "9090:9090"

grafana:
  image: grafana/grafana:latest
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
```

#### Scanning de Vulnérabilités
```bash
# Installer Trivy pour scanner les images
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update && sudo apt install trivy

# Scanner une image
trivy image gitlab/gitlab-ce:latest
```

#### Backup et Disaster Recovery
- [Restic](https://restic.net/) - Backup moderne et sécurisé
- [Duplicati](https://www.duplicati.com/) - Backup avec interface web
- [Velero](https://velero.io/) - Backup pour Kubernetes (si migration future)

---

### 7.4 Communautés et Support

#### Forums et Discussions
- [GitLab Forum](https://forum.gitlab.com/)
- [Nextcloud Community](https://help.nextcloud.com/)
- [Mattermost Community](https://mattermost.com/community/)
- [Docker Community Forums](https://forums.docker.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/docker)

#### Blogs et Ressources
- [GitLab Blog](https://about.gitlab.com/blog/)
- [Docker Blog](https://www.docker.com/blog/)
- [Awesome Docker](https://github.com/veggiemonk/awesome-docker) - Liste de ressources Docker

---

### 7.5 Commandes de Référence Rapide

```bash
# ==========================================
# COMMANDES ESSENTIELLES TAAF
# ==========================================

# Démarrage complet
cd ~/taaf-infrastructure
docker compose up -d

# Arrêt complet
docker compose down

# Redémarrage d'un service
docker compose restart gitlab

# Logs en temps réel
docker compose logs -f
docker compose logs -f gitlab  # Service spécifique

# État des services
docker compose ps

# Ressources utilisées
docker stats

# Sauvegarde
./scripts/backup.sh

# Restauration
./scripts/restore.sh /backup/taaf/taaf-backup-YYYYMMDD_HHMMSS.tar.gz

# Mise à jour
./scripts/update.sh

# Tests
./scripts/test-integrations.sh

# Audit de sécurité
./scripts/security-audit.sh

# Diagnostic réseau
./scripts/network-diagnostic.sh

# Monitoring performances
./scripts/monitor-performance.sh

# ==========================================
# ACCÈS AUX SERVICES
# ==========================================
# GitLab:     http://git.taaf.internal
# Nextcloud:  http://cloud.taaf.internal
# Mattermost: http://chat.taaf.internal
# Keycloak:   http://localhost:8080
# MailHog:    http://localhost:8025

# ==========================================
# COMMANDES DOCKER UTILES
# ==========================================

# Shell dans un conteneur
docker compose exec gitlab bash
docker compose exec -u www-data nextcloud bash

# Copier des fichiers
docker cp fichier.txt taaf_gitlab:/tmp/

# Vérifier les logs d'un conteneur
docker logs taaf_gitlab --tail 100 -f

# Nettoyer les ressources inutilisées
docker system prune -a --volumes

# Inspecter un conteneur
docker inspect taaf_gitlab

# Voir les variables d'environnement
docker compose exec gitlab env

# ==========================================
# MAINTENANCE BASE DE DONNÉES
# ==========================================

# Backup PostgreSQL
docker compose exec -T postgres pg_dump -U taaf_user gitlab > backup.sql

# Restaurer PostgreSQL
docker compose exec -T postgres psql -U taaf_user gitlab < backup.sql

# Se connecter à PostgreSQL
docker compose exec postgres psql -U taaf_user -d gitlab

# Lister les bases
docker compose exec postgres psql -U taaf_user -c "\l"

# ==========================================
# DÉPANNAGE RAPIDE
# ==========================================

# Service ne démarre pas
docker compose logs <service>
docker compose restart <service>
docker compose up -d --force-recreate <service>

# Problème de réseau
docker network inspect taaf-infrastructure_taaf_network
docker compose exec <service> ping <autre_service>

# Problème de volume
docker volume ls
docker volume inspect <volume_name>

# Nettoyer et redémarrer complètement
docker compose down
docker system prune -a --volumes  # ATTENTION: Supprime les données
docker compose up -d
```

---

### 7.6 Checklist de Mise en Production

Pour déployer en production sur un serveur réel :

- [ ] Acheter et configurer un nom de domaine
- [ ] Configurer les DNS A/AAAA vers le serveur
- [ ] Obtenir des certificats SSL (Let's Encrypt via Caddy)
- [ ] Configurer un pare-feu (UFW, iptables)
- [ ] Mettre en place des sauvegardes automatiques off-site
- [ ] Configurer un monitoring (Prometheus + Grafana)
- [ ] Mettre en place des alertes (email, SMS)
- [ ] Documenter les procédures d'urgence
- [ ] Former les administrateurs
- [ ] Tester le plan de reprise d'activité
- [ ] Configurer les mises à jour automatiques de sécurité
- [ ] Mettre en place une politique de mots de passe forte
- [ ] Activer l'authentification à deux facteurs (2FA)
- [ ] Configurer les logs centralisés
- [ ] Faire un audit de sécurité initial

---

### 7.7 Évolutions Futures Possibles

#### Authentification Centralisée
- **Keycloak** déjà intégré pour SSO (Single Sign-On)
- Configuration LDAP/AD pour l'authentification d'entreprise
- Intégration OAuth2 avec GitLab, Nextcloud et Mattermost

#### Haute Disponibilité
- Réplication des bases de données (PostgreSQL Streaming Replication)
- Load balancing avec plusieurs instances
- Stockage distribué (Ceph, GlusterFS)

#### Monitoring Avancé
- Prometheus + Grafana pour métriques détaillées
- ELK Stack (Elasticsearch, Logstash, Kibana) pour logs centralisés
- Alerting avec AlertManager

#### CI/CD Avancé
- GitLab Runners pour exécuter les pipelines
- Registry Docker privé intégré
- Déploiement automatique avec ArgoCD

---

## 📊 Métriques et KPIs

### Indicateurs de Performance

| Métrique | Objectif | Comment Mesurer |
|----------|----------|-----------------|
| **Uptime** | > 99.5% | Monitoring Prometheus |
| **Temps de réponse** | < 2s | curl avec time_total |
| **Temps de restauration** | < 30 min | Tests réguliers |
| **Fréquence des sauvegardes** | Quotidienne | Cron logs |
| **Taille des sauvegardes** | < 50GB | du -sh backup/ |

### Monitoring Continu

```bash
# Script de monitoring simple
while true; do
    echo "=== $(date) ==="
    docker compose ps --format "table {{.Service}}\t{{.Status}}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    sleep 300  # Toutes les 5 minutes
done > /var/log/taaf-monitor.log 2>&1 &
```

---

## 🎓 Conclusion

Cette annexe fournit tous les outils et connaissances nécessaires pour :

- ✅ **Maintenir** l'infrastructure TAAF au quotidien
- ✅ **Résoudre** les problèmes rapidement
- ✅ **Optimiser** les performances
- ✅ **Sécuriser** la plateforme
- ✅ **Évoluer** vers des architectures plus avancées

### Points Clés à Retenir

1. **Sauvegardes régulières** = Pas de stress en cas de problème
2. **Monitoring proactif** = Détecter les problèmes avant qu'ils n'impactent les utilisateurs
3. **Documentation à jour** = Facilite la maintenance et le transfert de connaissances
4. **Sécurité en priorité** = Protège les données et la réputation
5. **Apprentissage continu** = Les technologies évoluent, restez à jour

---

## 📞 Support et Contact

Pour toute question sur ce projet :

- 📧 Email : b.bernardin@rt-iut.re
- 💼 LinkedIn : [Brice BERNARDIN](https://www.linkedin.com/in/brice-bernardin-43a21b2a4/)
- 🔗 GitHub : [@Brice97426](https://github.com/Brice97426)

---

<div align="center">

**🌊 Infrastructure TAAF - Documentation Complète**

Bon courage pour votre soutenance ! 🎓

[⬅️ Phase 3](PHASE_3_INTEGRATION.md) | [🏠 README](../README.md)

---

**Créé avec ❤️ à La Réunion 🇷🇪**

*Ce projet démontre une maîtrise complète des compétences DevOps modernes*

</div>