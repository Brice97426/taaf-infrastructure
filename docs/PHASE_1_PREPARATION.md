# 📦 Phase 1 : Préparation de l'Environnement

> **Objectif** : Installer et configurer tous les prérequis nécessaires au déploiement de l'infrastructure TAAF

---

## 📋 Table des Matières

- [1. Installation des Prérequis Système](#1-installation-des-prérequis-système)
- [2. Création de l'Architecture de Dossiers](#2-création-de-larchitecture-de-dossiers)
- [3. Configuration du DNS Local](#3-configuration-du-dns-local)
- [4. Vérifications et Tests](#4-vérifications-et-tests)
- [5. Checklist Phase 1](#5-checklist-phase-1)

---

## 1. Installation des Prérequis Système

### 1.1 Vérification de l'Environnement

```bash
# Vérifier la version de votre système
lsb_release -a

# Vérifier l'espace disque disponible (minimum 20 GB requis)
df -h

# Vérifier la RAM disponible (minimum 8 GB requis)
free -h
```

**Résultat attendu :**
- ✅ Système Linux (Ubuntu 20.04+, Debian 11+, ou équivalent)
- ✅ Au moins 20 GB d'espace libre
- ✅ Au moins 8 GB de RAM

---

### 1.2 Installation de Docker

#### Pour Ubuntu/Debian

```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation des dépendances
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Ajout de la clé GPG officielle de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Ajout du dépôt Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installation de Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Démarrage automatique de Docker
sudo systemctl enable docker
sudo systemctl start docker
```

#### Vérification de l'installation

```bash
# Vérifier la version de Docker
docker --version

# Tester Docker (doit afficher "Hello from Docker!")
sudo docker run hello-world
```

**Résultat attendu :**
```
Docker version 24.0.x, build xxxxx
```

---

### 1.3 Configuration de Docker (sans sudo)

```bash
# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# Appliquer les changements (ou redémarrer la session)
newgrp docker

# Tester sans sudo
docker run hello-world
```

**⚠️ Important :** Si vous obtenez une erreur de permission, déconnectez-vous et reconnectez-vous.

---

### 1.4 Installation de Docker Compose

#### Méthode 1 : Via le gestionnaire de paquets (recommandé)

```bash
# Installation de Docker Compose
sudo apt install -y docker-compose-plugin

# Vérification
docker compose version
```

#### Méthode 2 : Installation manuelle (si la méthode 1 ne fonctionne pas)

```bash
# Télécharger la dernière version
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Rendre exécutable
sudo chmod +x /usr/local/bin/docker-compose

# Vérification
docker-compose --version
```

**Résultat attendu :**
```
Docker Compose version v2.x.x
```

---

### 1.5 Outils de Développement Additionnels

```bash
# Installation d'outils utiles
sudo apt install -y \
    git \
    curl \
    wget \
    nano \
    vim \
    htop \
    net-tools \
    python3 \
    python3-pip

# Vérification Python (pour les scripts d'intégration)
python3 --version
pip3 --version
```

---

## 2. Création de l'Architecture de Dossiers

### 2.1 Structure Complète du Projet

```bash
# Créer le dossier racine du projet
mkdir -p ~/taaf-infrastructure
cd ~/taaf-infrastructure

# Créer l'arborescence complète
mkdir -p {caddy,scripts/{webhooks,monitoring,utils},data/{gitlab/{config,data,logs},nextcloud,mattermost/{config,data,logs,plugins},postgres,mysql,caddy},docs/assets/screenshots}

# Créer les fichiers de configuration principaux
touch docker-compose.yml
touch caddy/Caddyfile
touch .env
touch .gitignore
touch README.md
```

### 2.2 Visualisation de la Structure

```
taaf-infrastructure/
├── docker-compose.yml          # Orchestration des services
├── .env                        # Variables d'environnement
├── .gitignore                  # Fichiers à ignorer par Git
├── README.md                   # Documentation principale
│
├── caddy/                      # Configuration du reverse proxy
│   └── Caddyfile              # Règles de routage
│
├── scripts/                    # Scripts d'automatisation
│   ├── webhooks/              # Scripts webhooks GitLab
│   ├── monitoring/            # Scripts monitoring Nextcloud
│   └── utils/                 # Scripts utilitaires
│
├── data/                       # Données persistantes (non versionnées)
│   ├── gitlab/
│   │   ├── config/            # Configuration GitLab
│   │   ├── data/              # Dépôts Git et données
│   │   └── logs/              # Logs GitLab
│   ├── nextcloud/             # Données Nextcloud
│   ├── mattermost/
│   │   ├── config/            # Configuration Mattermost
│   │   ├── data/              # Données utilisateurs
│   │   ├── logs/              # Logs Mattermost
│   │   └── plugins/           # Plugins Mattermost
│   ├── postgres/              # Base PostgreSQL
│   ├── mysql/                 # Base MySQL
│   └── caddy/                 # Certificats et config Caddy
│
└── docs/                       # Documentation
    ├── assets/
    │   └── screenshots/       # Captures d'écran
    ├── PHASE_1_PREPARATION.md
    ├── PHASE_2_DEPLOIEMENT.md
    ├── PHASE_3_INTEGRATION.md
    └── ANNEXES.md
```

### 2.3 Création du fichier .gitignore

```bash
cat > .gitignore << 'EOF'
# ==========================================
# Données persistantes sensibles
# ==========================================
data/gitlab/
data/nextcloud/
data/mattermost/
data/postgres/
data/mysql/
data/caddy/

# Garder uniquement la structure
!data/.gitkeep
!data/*/.gitkeep

# ==========================================
# Fichiers de configuration sensibles
# ==========================================
.env
*.env
.env.*
secrets/
*.key
*.pem
*.crt

# ==========================================
# Logs et fichiers temporaires
# ==========================================
*.log
logs/
*.tmp
*.temp

# ==========================================
# OS et éditeurs
# ==========================================
.DS_Store
Thumbs.db
.vscode/
.idea/
*.swp
*.swo
*~

# ==========================================
# Backup
# ==========================================
*.bak
*.backup
backup/
EOF
```

### 2.4 Création des fichiers .gitkeep

```bash
# Créer des fichiers .gitkeep pour préserver la structure
find data -type d -exec touch {}/.gitkeep \;
find scripts -type d -exec touch {}/.gitkeep \;
```

### 2.5 Configuration des Permissions

```bash
# Définir les bonnes permissions pour les dossiers de données
chmod -R 755 data/
chmod -R 755 scripts/

# S'assurer que l'utilisateur actuel est propriétaire
sudo chown -R $USER:$USER ~/taaf-infrastructure
```

---

## 3. Configuration du DNS Local

### 3.1 Principe de Fonctionnement

Les services seront accessibles via des sous-domaines :
- `http://taaf.internal` → Page d'accueil
- `http://git.taaf.internal` → GitLab
- `http://cloud.taaf.internal` → Nextcloud
- `http://chat.taaf.internal` → Mattermost

Pour cela, nous devons modifier le fichier `/etc/hosts` pour résoudre ces domaines localement.

### 3.2 Modification du fichier /etc/hosts

```bash
# Sauvegarder le fichier hosts original
sudo cp /etc/hosts /etc/hosts.backup

# Ajouter les entrées DNS TAAF
sudo tee -a /etc/hosts > /dev/null << 'EOF'

# ==========================================
# Infrastructure TAAF - Projet DevOps
# ==========================================
127.0.0.1    taaf.internal
127.0.0.1    git.taaf.internal
127.0.0.1    cloud.taaf.internal
127.0.0.1    chat.taaf.internal
EOF

# Vérifier l'ajout
tail /etc/hosts
```

### 3.3 Test de Résolution DNS

```bash
# Tester la résolution des domaines
ping -c 2 taaf.internal
ping -c 2 git.taaf.internal
ping -c 2 cloud.taaf.internal
ping -c 2 chat.taaf.internal
```

**Résultat attendu :**
```
PING taaf.internal (127.0.0.1) 56(84) bytes of data.
64 bytes from localhost (127.0.0.1): icmp_seq=1 ttl=64 time=0.045 ms
```

---

## 4. Vérifications et Tests

### 4.1 Checklist Complète des Prérequis

```bash
# Script de vérification automatique
cat > ~/taaf-infrastructure/scripts/utils/check-prereqs.sh << 'EOF'
#!/bin/bash

echo "🔍 Vérification des prérequis TAAF..."
echo ""

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de vérification
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

# Docker
docker --version > /dev/null 2>&1
check "Docker installé"

# Docker Compose
docker compose version > /dev/null 2>&1 || docker-compose --version > /dev/null 2>&1
check "Docker Compose installé"

# Docker sans sudo
docker ps > /dev/null 2>&1
check "Docker accessible sans sudo"

# Espace disque
SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ $(echo "$SPACE > 20" | bc) -eq 1 ]; then
    echo -e "${GREEN}✅ Espace disque suffisant (${SPACE}GB disponibles)${NC}"
else
    echo -e "${YELLOW}⚠️  Espace disque limité (${SPACE}GB disponibles)${NC}"
fi

# RAM
RAM=$(free -g | awk 'NR==2 {print $2}')
if [ $RAM -ge 8 ]; then
    echo -e "${GREEN}✅ RAM suffisante (${RAM}GB)${NC}"
else
    echo -e "${YELLOW}⚠️  RAM limitée (${RAM}GB)${NC}"
fi

# Python
python3 --version > /dev/null 2>&1
check "Python 3 installé"

# Git
git --version > /dev/null 2>&1
check "Git installé"

# DNS local
ping -c 1 taaf.internal > /dev/null 2>&1
check "DNS local configuré (taaf.internal)"

echo ""
echo -e "${GREEN}✨ Tous les prérequis sont satisfaits !${NC}"
EOF

# Rendre le script exécutable
chmod +x ~/taaf-infrastructure/scripts/utils/check-prereqs.sh

# Exécuter la vérification
~/taaf-infrastructure/scripts/utils/check-prereqs.sh
```

### 4.2 Test de Création d'un Conteneur Simple

```bash
# Tester Docker avec un conteneur nginx simple
docker run -d --name test-nginx -p 8080:80 nginx:alpine

# Vérifier que le conteneur tourne
docker ps | grep test-nginx

# Tester l'accès
curl http://localhost:8080

# Nettoyer
docker stop test-nginx
docker rm test-nginx
```

**Résultat attendu :**
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

---

## 5. Checklist Phase 1

### ✅ Vérification Finale

Avant de passer à la Phase 2, assurez-vous que tous les points suivants sont validés :

- [ ] **Docker installé** (version 20.10+)
- [ ] **Docker Compose installé** (version 2.0+)
- [ ] **Docker accessible sans sudo** (`docker ps` fonctionne)
- [ ] **Arborescence de dossiers créée** (structure complète)
- [ ] **Fichier .gitignore configuré**
- [ ] **Permissions correctes** sur les dossiers
- [ ] **DNS local configuré** (/etc/hosts modifié)
- [ ] **Résolution DNS testée** (ping des domaines fonctionne)
- [ ] **Outils de développement installés** (git, python3, curl)
- [ ] **Script de vérification exécuté avec succès**

### 📊 Résumé de la Phase 1

```
🎯 Objectifs atteints :
   ✅ Environnement Docker opérationnel
   ✅ Structure de projet organisée
   ✅ DNS local configuré pour les services
   ✅ Outils de développement prêts

📁 Fichiers créés :
   • Structure complète de dossiers
   • docker-compose.yml (vide)
   • caddy/Caddyfile (vide)
   • .env (vide)
   • .gitignore (configuré)
   • scripts/utils/check-prereqs.sh

⏱️ Temps estimé : 30-45 minutes

🎓 Compétences acquises :
   • Installation et configuration de Docker
   • Gestion des permissions Linux
   • Configuration DNS locale
   • Organisation de projet DevOps
```

---

## 🔧 Dépannage Courant

### Problème : Docker nécessite sudo

**Solution :**
```bash
sudo usermod -aG docker $USER
newgrp docker
# Ou déconnectez-vous et reconnectez-vous
```

### Problème : Port 80 déjà utilisé

**Solution :**
```bash
# Identifier le processus utilisant le port 80
sudo lsof -i :80
sudo netstat -tulpn | grep :80

# Arrêter Apache ou nginx si installé
sudo systemctl stop apache2
sudo systemctl stop nginx
```

### Problème : Espace disque insuffisant

**Solution :**
```bash
# Nettoyer les conteneurs et images inutilisés
docker system prune -a --volumes
```

### Problème : DNS ne se résout pas

**Solution :**
```bash
# Vérifier le fichier hosts
cat /etc/hosts | grep taaf

# Vider le cache DNS
sudo systemd-resolve --flush-caches

# Tester avec nslookup
nslookup taaf.internal
```

---

## 📚 Ressources Complémentaires

- [Documentation Docker](https://docs.docker.com/)
- [Docker Compose File Reference](https://docs.docker.com/compose/compose-file/)
- [Best Practices Docker](https://docs.docker.com/develop/dev-best-practices/)

---

## ➡️ Prochaine Étape

Une fois tous les prérequis validés, vous êtes prêt pour :

**[📄 Phase 2 : Déploiement de l'Infrastructure](PHASE_2_DEPLOIEMENT.md)**

---

<div align="center">

**🌊 Infrastructure TAAF - Phase 1 Complétée ! 🎉**

[⬅️ Retour au README](../README.md) | [➡️ Phase 2](PHASE_2_DEPLOIEMENT.md)

</div>