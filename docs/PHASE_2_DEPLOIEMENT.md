# 🚀 Phase 2 : Déploiement de l'Infrastructure

> **Objectif** : Déployer et configurer tous les services de l'infrastructure TAAF avec Docker Compose

---

## 📋 Table des Matières

- [1. Configuration du Reverse Proxy Caddy](#1-configuration-du-reverse-proxy-caddy)
- [2. Création du fichier docker-compose.yml](#2-création-du-fichier-docker-composeyml)
- [3. Configuration des Variables d'Environnement](#3-configuration-des-variables-denvironnement)
- [4. Déploiement de l'Infrastructure](#4-déploiement-de-linfrastructure)
- [5. Vérification des Services](#5-vérification-des-services)
- [6. Configuration Initiale des Services](#6-configuration-initiale-des-services)
- [7. Checklist Phase 2](#7-checklist-phase-2)

---

## 1. Configuration du Reverse Proxy Caddy

### 1.1 Pourquoi Caddy ?

Caddy est un reverse proxy moderne qui offre :
- ✅ **SSL automatique** avec Let's Encrypt
- ✅ **Configuration simple** en comparaison avec Nginx
- ✅ **Rechargement à chaud** sans interruption
- ✅ **HTTP/2 et HTTP/3** par défaut

### 1.2 Création du Caddyfile

```bash
# Créer le fichier de configuration Caddy
cat > ~/taaf-infrastructure/caddy/Caddyfile << 'EOF'
# ==========================================
# Configuration globale
# ==========================================
{
    auto_https off
    log {
        output file /data/logs/caddy-global.log
    }
}

# ==========================================
# GITLAB
# ==========================================
http://git.taaf.internal {
    reverse_proxy gitlab:80

    log {
        output file /data/logs/gitlab-access.log
    }
}

# ==========================================
# NEXTCLOUD
# ==========================================
http://cloud.taaf.internal {
    reverse_proxy nextcloud:80 {
        transport http {
            read_timeout 300s
            write_timeout 300s
        }
    }

    log {
        output file /data/logs/nextcloud-access.log
    }
}

# ==========================================
# MATTERMOST
# ==========================================
http://chat.taaf.internal {
    reverse_proxy mattermost:8065 {
        transport http {
            read_timeout 300s
            write_timeout 300s
        }
    }

    log {
        output file /data/logs/mattermost-access.log
    }
}

# ==========================================
# KEYCLOAK
# ==========================================
http://keycloak.taaf.internal:8080 {
    reverse_proxy taaf_keycloak:8080 {
        transport http {
            read_timeout 300s
            write_timeout 300s
        }
    }

    log {
        output file /data/logs/keycloak-access.log
    }
}

# ==========================================
# PORTAIL CENTRAL (sur taaf.internal)
# ==========================================
http://taaf.internal {
    root * /srv/portal
    file_server {
        index portal.html
    }

    header {
        Content-Type "text/html; charset=utf-8"
    }
}
EOF

echo "✅ Caddyfile créé avec succès"
```

---

## 2. Création du fichier docker-compose.yml

### 2.1 Architecture des Services

```
┌─────────────────────────────────────────────┐
│           Caddy (Reverse Proxy)             │
│              Port 80 / 443                  │
└────────────┬────────────────────────────────┘
             │
    ┌────────┼────────┬────────────┐
    │        │        │            │
┌───▼───┐ ┌──▼──┐ ┌──▼───┐   ┌────▼────┐
│GitLab │ │Next │ │Matter│   │ Bases   │
│  CE   │ │cloud│ │most  │   │ Données │
└───┬───┘ └──┬──┘ └──┬───┘   └────┬────┘
    │        │       │             │
    └────────┴───────┴─────────────┘
           PostgreSQL / MySQL
```

### 2.2 Fichier docker-compose.yml Complet

```bash
cat > ~/taaf-infrastructure/docker-compose.yml << 'EOF'
services:
  # ==========================================
  # POSTGRESQL 16
  # ==========================================
  postgres:
    image: postgres:16-alpine
    container_name: taaf_postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: taaf_user
      POSTGRES_PASSWORD: taaf_secure_password_2024
      POSTGRES_DB: gitlab
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - ./scripts/init-databases.sh:/docker-entrypoint-initdb.d/init-databases.sh
    networks:
      - taaf_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U taaf_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ==========================================
  # GITLAB
  # ==========================================
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: taaf_gitlab
    restart: unless-stopped
    hostname: git.taaf.internal
    depends_on:
      - postgres
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://git.taaf.internal'
        gitlab_rails['initial_root_password'] = 'TAAFAdmin2024!'

        postgresql['enable'] = false
        gitlab_rails['db_adapter'] = 'postgresql'
        gitlab_rails['db_encoding'] = 'utf8'
        gitlab_rails['db_host'] = 'postgres'
        gitlab_rails['db_port'] = 5432
        gitlab_rails['db_database'] = 'gitlab'
        gitlab_rails['db_username'] = 'taaf_user'
        gitlab_rails['db_password'] = 'taaf_secure_password_2024'

        prometheus_monitoring['enable'] = false

        nginx['listen_port'] = 80
        nginx['listen_https'] = false
    ports:
      - "2222:22"
    volumes:
      - ./data/gitlab/config:/etc/gitlab
      - ./data/gitlab/data:/var/opt/gitlab
      - ./data/gitlab/logs:/var/log/gitlab
    networks:
      - taaf_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/-/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 300s

  # ==========================================
  # NEXTCLOUD
  # ==========================================
  nextcloud_db:
    image: postgres:15-alpine
    container_name: taaf_nextcloud_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: nextcloud_user
      POSTGRES_PASSWORD: nextcloud_secure_2024
      POSTGRES_DB: nextcloud
    volumes:
      - ./data/nextcloud/db:/var/lib/postgresql/data
    networks:
      - taaf_network

  nextcloud:
    image: nextcloud:latest
    container_name: taaf_nextcloud
    restart: unless-stopped
    depends_on:
      - nextcloud_db
    environment:
      POSTGRES_HOST: nextcloud_db
      POSTGRES_DB: nextcloud
      POSTGRES_USER: nextcloud_user
      POSTGRES_PASSWORD: nextcloud_secure_2024
      NEXTCLOUD_ADMIN_USER: admin
      NEXTCLOUD_ADMIN_PASSWORD: TAAFCloud2024!
      NEXTCLOUD_TRUSTED_DOMAINS: cloud.taaf.internal
      OVERWRITEPROTOCOL: http
      OVERWRITEHOST: cloud.taaf.internal
    volumes:
      - ./data/nextcloud/html:/var/www/html
      - ./data/nextcloud/data:/var/www/html/data
      #- ./data/nextcloud/config:/var/www/html/config
    networks:
      - taaf_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/status.php"]
      interval: 30s
      timeout: 10s
      retries: 3


  # ==========================================
  # MATTERMOST
  # ==========================================
  mattermost_db:
    image: postgres:15-alpine
    container_name: taaf_mattermost_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: mattermost
      POSTGRES_USER: mattermost_user
      POSTGRES_PASSWORD: mattermost_secure_2024
    volumes:
      - ./data/mattermost/db:/var/lib/postgresql/data
    networks:
      - taaf_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mattermost_user -d mattermost"]
      interval: 10s
      timeout: 5s
      retries: 5

  mattermost:
    image: mattermost/mattermost-team-edition:latest
    container_name: taaf_mattermost
    restart: unless-stopped
    depends_on:
      mattermost_db:
        condition: service_healthy
    environment:
      MM_SQLSETTINGS_DRIVERNAME: postgres
      MM_SQLSETTINGS_DATASOURCE: postgres://mattermost_user:mattermost_secure_2024@mattermost_db:5432/mattermost?sslmode=disable&connect_timeout=10
      MM_SERVICESETTINGS_SITEURL: http://chat.taaf.internal
      MM_SERVICESETTINGS_ENABLELOCALMODE: "true"
      TZ: Indian/Reunion

      # === Admin Mattermost par défaut ===
      MM_ADMIN_USERNAME: admin
      MM_ADMIN_EMAIL: admin@taaf.internal
      MM_ADMIN_PASSWORD: TAAFAdmin2025!

      # === SMTP MailHog pour tests ===
      MM_EMAILSETTINGS_ENABLESMTP: "true"
      MM_EMAILSETTINGS_SMTPUSERNAME: ""
      MM_EMAILSETTINGS_SMTPPASSWORD: ""
      MM_EMAILSETTINGS_SMTPSERVER: mailhog
      MM_EMAILSETTINGS_SMTPPORT: "1025"
      MM_EMAILSETTINGS_SENDERADDRESS: "noreply@taaf.internal"
      MM_EMAILSETTINGS_SENDPASSWORDRESETEMAIL: "true"
      MM_EMAILSETTINGS_NOTIFYPROPERTIESCHANGED: "true"

    volumes:
      - ./data/mattermost/config:/mattermost/config
      - ./data/mattermost/data:/mattermost/data
      - ./data/mattermost/logs:/mattermost/logs
      - ./data/mattermost/plugins:/mattermost/plugins
      - ./data/mattermost/client-plugins:/mattermost/client/plugins
    networks:
      - taaf_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8065/api/v4/system/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # ==========================================
  # MAILHOG (SMTP pour Mattermost)
  # ==========================================
  mailhog:
    image: mailhog/mailhog
    container_name: taaf_mailhog
    restart: unless-stopped
    ports:
      - "8025:8025"   # interface web
      - "1025:1025"   # SMTP
    networks:
      - taaf_network

  # ==========================================
  # KEYCLOAK
  # ==========================================
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: taaf_keycloak
    restart: unless-stopped
    command: start-dev
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: TAAFKeycloak2024!
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://taaf_postgres:5432/keycloak
      KC_DB_USERNAME: taaf_user
      KC_DB_PASSWORD: taaf_secure_password_2024
      KC_HOSTNAME: 192.168.50.139
      KC_HOSTNAME_PORT: 8080
      KC_HOSTNAME_STRICT: "false"
      KC_HTTP_ENABLED: "true"
      KC_PROXY: edge
    ports:
      - "8080:8080"
      - "8443:8443"
    volumes:
      - ./data/keycloak:/opt/keycloak/data
    networks:
      - taaf_network
    depends_on:
      - postgres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s

  # ==========================================
  # CADDY
  # ==========================================
  caddy:
    image: caddy:2-alpine
    container_name: taaf_caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./data/caddy/data:/data
      - ./data/caddy/config:/config
      - ./caddy/portal:/srv/portal
    networks:
      - taaf_network
    depends_on:
      - gitlab
      - nextcloud
      - mattermost
    healthcheck:
      test: ["CMD", "caddy", "version"]
      interval: 30s
      timeout: 10s
      retries: 3
  # Webhook GitLab vers Mattermost
  gitlab-webhook:
    build:
      context: ./scripts/webhooks
      dockerfile: Dockerfile
    container_name: taaf_gitlab_webhook
    environment:
      - MATTERMOST_WEBHOOK_URL=http://mattermost:8065/hooks/8jomgg6xy3gkzn9btb1y6oanhc
    networks:
      - taaf_network
    restart: unless-stopped

  # Monitoring Nextcloud vers Mattermost
  nextcloud-monitor:
    build:
      context: ./scripts/webhooks
      dockerfile: Dockerfile.monitor
    container_name: taaf_nextcloud_monitor
    environment:
      - WATCH_PATH=/nextcloud-data/admin/files/Documents-RH
      - MATTERMOST_WEBHOOK_URL=http://mattermost:8065/hooks/zgq58agzebnyxp78xsgyfb9p8a
    volumes:
      - ./data/nextcloud/data:/nextcloud-data:ro
    networks:
      - taaf_network
    restart: unless-stopped
    depends_on:
      - nextcloud
      - mattermost
# ==========================================
# RÉSEAU
# ==========================================
networks:
  taaf_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

echo "✅ docker-compose.yml créé avec succès"
```

---

## 3. Configuration des Variables d'Environnement

### 3.1 Création du fichier .env

```bash
cat > ~/taaf-infrastructure/.env << 'EOF'
# ==========================================
# Configuration Infrastructure TAAF
# ==========================================

# ==========================================
# GITLAB
# ==========================================
GITLAB_DB_NAME=gitlabhq_production
GITLAB_DB_USER=gitlab
GITLAB_DB_PASSWORD=GitLab2024SecurePassword!

# ==========================================
# NEXTCLOUD
# ==========================================
MYSQL_ROOT_PASSWORD=RootMySQL2024Secure!
NEXTCLOUD_DB_NAME=nextcloud
NEXTCLOUD_DB_USER=nextcloud
NEXTCLOUD_DB_PASSWORD=Nextcloud2024SecurePassword!
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=AdminNextcloud2024!

# ==========================================
# MATTERMOST
# ==========================================
MATTERMOST_DB_NAME=mattermost
MATTERMOST_DB_USER=mattermost
MATTERMOST_DB_PASSWORD=Mattermost2024SecurePassword!

# ==========================================
# NOTES
# ==========================================
# ⚠️  Ne JAMAIS commiter ce fichier sur Git
# ⚠️  Utiliser des mots de passe forts en production
# ⚠️  Changer tous les mots de passe par défaut
EOF

echo "✅ Fichier .env créé avec succès"
echo "⚠️  IMPORTANT: Ne commitez JAMAIS ce fichier sur Git!"
```

### 3.2 Sécuriser le fichier .env

```bash
# Restreindre les permissions (lecture seule par le propriétaire)
chmod 600 ~/taaf-infrastructure/.env

# Vérifier qu'il est dans .gitignore
grep -q "^.env$" ~/taaf-infrastructure/.gitignore || echo ".env" >> ~/taaf-infrastructure/.gitignore
```

---

## 4. Déploiement de l'Infrastructure

### 4.1 Validation de la Configuration

```bash
cd ~/taaf-infrastructure

# Valider la syntaxe du docker-compose.yml
docker compose config

# Vérifier les services définis
docker compose config --services
```

**Résultat attendu :**
```
mailhog
mattermost_db
mattermost
nextcloud_db
nextcloud
nextcloud-monitor
postgres
gitlab
caddy
keycloak
gitlab-webhook
```

### 4.2 Téléchargement des Images Docker

```bash
# Télécharger toutes les images (cela peut prendre 5-10 minutes)
docker compose pull

# Vérifier les images téléchargées
docker images | grep -E "caddy|gitlab|nextcloud|mattermost|postgres|mysql"
```

### 4.3 Démarrage de l'Infrastructure

```bash
# Démarrer tous les services en arrière-plan
docker compose up -d

# Suivre les logs en temps réel (Ctrl+C pour quitter)
docker compose logs -f
```

**⏱️ Temps de démarrage estimés :**
- Caddy : ~10 secondes
- PostgreSQL/MySQL : ~20-30 secondes
- Nextcloud : ~1-2 minutes
- Mattermost : ~1-2 minutes
- **GitLab : ~5-8 minutes** ⚠️ (le plus long)

### 4.4 Surveiller le Démarrage de GitLab

```bash
# Suivre spécifiquement les logs de GitLab
docker compose logs -f gitlab

# Dans un autre terminal, vérifier l'état de santé
watch -n 5 'docker compose ps'
```

**GitLab est prêt quand vous voyez :**
```
gitlab is up and running
```

---

## 5. Vérification des Services

### 5.1 État des Conteneurs

```bash
# Vérifier que tous les services sont "Up"
docker compose ps

# Format attendu :
# NAME                    STATUS              PORTS
# taaf_caddy              Up (healthy)        0.0.0.0:80->80/tcp
# taaf_gitlab             Up (healthy)        0.0.0.0:2222->22/tcp
# taaf_nextcloud          Up (healthy)        
# taaf_mattermost         Up (healthy)        
```

### 5.2 Vérification des Health Checks

```bash
# Vérifier l'état de santé de tous les services
docker compose ps --format json | jq -r '.[] | "\(.Service): \(.Health)"'
```

### 5.3 Test de Connectivité HTTP

```bash
# Tester l'accès aux services via curl
echo "Testing Caddy..."
curl -I http://taaf.internal

echo "Testing GitLab..."
curl -I http://git.taaf.internal

echo "Testing Nextcloud..."
curl -I http://cloud.taaf.internal

echo "Testing Mattermost..."
curl -I http://chat.taaf.internal
```

**Résultat attendu : HTTP 200 ou 302 pour chaque service**

### 5.4 Test depuis le Navigateur

Ouvrez votre navigateur et accédez à :
- http://taaf.internal
- http://git.taaf.internal
- http://cloud.taaf.internal
- http://chat.taaf.internal

**📸 SCREENSHOTS REQUIS :**
1. `screenshots/01-taaf-home.png` - Page d'accueil TAAF
2. `screenshots/02-gitlab-login.png` - Page de connexion GitLab
3. `screenshots/03-nextcloud-login.png` - Page de connexion Nextcloud
4. `screenshots/04-mattermost-login.png` - Page de connexion Mattermost

---

## 6. Configuration Initiale des Services

### 6.1 GitLab - Première Connexion

#### 6.1.1 Récupérer le Mot de Passe Root

```bash
# Attendre que GitLab soit complètement démarré (5-8 minutes)
sleep 60

# Récupérer le mot de passe root initial
docker compose exec gitlab grep 'Password:' /etc/gitlab/initial_root_password

# Ou
docker compose exec gitlab cat /etc/gitlab/initial_root_password
```

**⚠️ Important :** Ce fichier est supprimé 24h après le premier démarrage !

#### 6.1.2 Se Connecter à GitLab

1. Ouvrez http://git.taaf.internal
2. Connectez-vous avec :
   - Username: `root`
   - Password: (celui récupéré ci-dessus)

3. **Changez immédiatement le mot de passe** :
   - Cliquez sur votre avatar → Settings → Password
   - Nouveau mot de passe : `GitLabAdmin2024!`

**📸 SCREENSHOT REQUIS :**
- `screenshots/05-gitlab-dashboard.png` - Dashboard GitLab après connexion

#### 6.1.3 Configuration de GitLab

```bash
# Script de configuration automatique GitLab
cat > ~/taaf-infrastructure/scripts/utils/configure-gitlab.sh << 'EOF'
#!/bin/bash

echo "🔧 Configuration de GitLab..."

# Attendre que GitLab soit prêt
until docker compose exec -T gitlab gitlab-rails runner "puts 'GitLab is ready'" 2>/dev/null; do
  echo "Attente de GitLab..."
  sleep 10
done

# Désactiver l'enregistrement public (sécurité)
docker compose exec -T gitlab gitlab-rails runner "
  ApplicationSetting.current.update(signup_enabled: false)
  puts 'Signup disabled'
"

# Créer un utilisateur TAAF
docker compose exec -T gitlab gitlab-rails runner "
  u = User.create!(
    email: 'admin@taaf.internal',
    name: 'Admin TAAF',
    username: 'admin-taaf',
    password: 'TaafAdmin2024!',
    password_confirmation: 'TaafAdmin2024!',
    admin: true
  )
  u.confirm
  puts 'Admin TAAF user created'
"

echo "✅ Configuration GitLab terminée"
EOF

chmod +x ~/taaf-infrastructure/scripts/utils/configure-gitlab.sh
~/taaf-infrastructure/scripts/utils/configure-gitlab.sh
```

---

### 6.2 Nextcloud - Première Connexion

1. Ouvrez http://cloud.taaf.internal
2. La configuration automatique s'est effectuée avec :
   - Username: `admin` (ou celui défini dans .env)
   - Password: `AdminNextcloud2024!` (ou celui défini dans .env)

**📸 SCREENSHOT REQUIS :**
- `screenshots/06-nextcloud-dashboard.png` - Dashboard Nextcloud après connexion

#### 6.2.1 Configuration Post-Installation

```bash
# Créer un dossier RH pour les tests de monitoring
docker compose exec -u www-data nextcloud php occ files:scan --all

# Configurer les domaines de confiance
docker compose exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value=cloud.taaf.internal

# Installer des applications utiles
docker compose exec -u www-data nextcloud php occ app:install files_sharing
docker compose exec -u www-data nextcloud php occ app:install files_versions

echo "✅ Configuration Nextcloud terminée"
```

---

### 6.3 Mattermost - Première Connexion

#### 6.3.1 Créer le Compte Administrateur

1. Ouvrez http://chat.taaf.internal
2. Créez le premier compte (admin) :
   - Email: `admin@taaf.internal`
   - Username: `admin-taaf`
   - Password: `MattermostAdmin2024!`

**📸 SCREENSHOT REQUIS :**
- `screenshots/07-mattermost-welcome.png` - Écran de bienvenue Mattermost

#### 6.3.2 Créer l'Équipe TAAF

1. Créez une équipe : **"TAAF Infrastructure"**
2. Créez les canaux suivants :
   - `#general` (par défaut)
   - `#dev-notifications` (pour les webhooks GitLab)
   - `#rh-alerts` (pour le monitoring Nextcloud pour le dépot de document RH)

**📸 SCREENSHOT REQUIS :**
- `screenshots/08-mattermost-team.png` - Équipe TAAF créée avec les canaux

---

## 7. Checklist Phase 2

### 7.1 Vérification Finale

- [ ] **Caddyfile configuré** (routage des services)
- [ ] **docker-compose.yml créé** (7 services définis)
- [ ] **Variables d'environnement configurées** (.env sécurisé)
- [ ] **Toutes les images téléchargées**
- [ ] **Tous les conteneurs démarrés** (7/7)
- [ ] **Health checks OK** pour tous les services
- [ ] **Accès HTTP fonctionnel** pour tous les domaines
- [ ] **GitLab accessible** et mot de passe root récupéré
- [ ] **Nextcloud accessible** et configuré
- [ ] **Mattermost accessible** et équipe créée
- [ ] **Canaux Mattermost créés** (#gitlab-notifications, #nextcloud-notifications)
- [ ] **8 screenshots capturés** et sauvegardés
### 7.2 Docker Vérification
- `screenshots/09-docker-compose-ps.png` - Le tableau avec tous les services "Up (healthy)"
- `screenshots/10-docker-stats.png` - L'utilisation CPU/RAM de tous les conteneurs


### 📊 Résumé de la Phase 2

```
🎯 Objectifs atteints :
   ✅ Reverse proxy Caddy opérationnel
   ✅ 3 bases de données déployées (2x PostgreSQL, 1x MySQL)
   ✅ GitLab CE installé et configuré
   ✅ Nextcloud installé et configuré
   ✅ Mattermost installé et équipe créée
   ✅ Tous les services accessibles via DNS local

📦 Services déployés :
   • Caddy (reverse proxy)
   • GitLab CE (git + CI/CD)
   • PostgreSQL x2 (GitLab, Mattermost)
   • MySQL (Nextcloud)
   • Nextcloud (cloud storage)
   • Mattermost (team chat)

🔌 Ports exposés :
   • 80 (HTTP - Caddy)
   • 443 (HTTPS - Caddy, désactivé en local)
   • 2222 (SSH - GitLab)

💾 Volumes créés : 11 volumes Docker pour persistance

⏱️ Temps total : 45-60 minutes (incluant le démarrage de GitLab)

🎓 Compétences acquises :
   • Configuration de reverse proxy
   • Orchestration multi-services Docker Compose
   • Gestion de bases de données conteneurisées
   • Configuration de services d'entreprise
   • Gestion des dépendances entre services
```

---

## 🔧 Commandes Utiles pour la Maintenance

### Gestion des Services

```bash
# Voir l'état de tous les services
docker compose ps

# Redémarrer un service spécifique
docker compose restart gitlab

# Voir les logs d'un service
docker compose logs -f nextcloud

# Arrêter tous les services
docker compose stop

# Démarrer tous les services
docker compose start

# Redémarrer complètement l'infrastructure
docker compose restart
```

### Monitoring et Debug

```bash
# Voir les ressources utilisées
docker stats

# Accéder au shell d'un conteneur
docker compose exec gitlab bash
docker compose exec nextcloud bash
docker compose exec mattermost sh

# Voir les logs en direct de tous les services
docker compose logs -f --tail=100
```

### Sauvegarde des Données

```bash
# Créer un backup des volumes
docker compose down
sudo tar -czf taaf-backup-$(date +%Y%m%d).tar.gz data/

# Restaurer un backup
sudo tar -xzf taaf-backup-YYYYMMDD.tar.gz
docker compose up -d
```

---

## 🔥 Dépannage Courant

### GitLab ne démarre pas

```bash
# Vérifier les logs
docker compose logs gitlab

# Problème de mémoire ? Augmenter shm_size
# Dans docker-compose.yml : shm_size: '512m'

# Redémarrer GitLab
docker compose restart gitlab
```

### Nextcloud : "Domaines non fiables"

```bash
# Ajouter le domaine de confiance
docker compose exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value=cloud.taaf.internal
```

### Mattermost : Erreur de connexion à la base

```bash
# Vérifier que PostgreSQL est prêt
docker compose ps postgres_mattermost

# Redémarrer Mattermost
docker compose restart mattermost
```

### Services inaccessibles via le navigateur

```bash
# Vérifier que les domaines DNS sont configurés
cat /etc/hosts | grep taaf

# Tester la résolution
ping git.taaf.internal

# Vider le cache DNS du navigateur (Chrome)
# chrome://net-internals/#dns -> Clear host cache
```

## ➡️ Prochaine Étape

Une fois tous les services déployés et accessibles, vous êtes prêt pour :

**[📄 Phase 3 : Configuration et Intégrations](PHASE_3_INTEGRATION.md)**

Dans la Phase 3, nous allons :
- Configurer les webhooks GitLab → Mattermost
- Mettre en place le monitoring Nextcloud → Mattermost
- Tester les notifications automatiques
- Valider tous les cas d'usage TAAF

---

<div align="center">

**🌊 Infrastructure TAAF - Phase 2 Complétée ! 🎉**

Tous les services sont maintenant opérationnels !

[⬅️ Phase 1](PHASE_1_PREPARATION.md) | [🏠 README](../README.md) | [➡️ Phase 3](PHASE_3_INTEGRATION.md)

</div>