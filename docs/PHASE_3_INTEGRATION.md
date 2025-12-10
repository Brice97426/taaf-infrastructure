# 🔗 Phase 3 : Configuration et Intégrations

> **Objectif** : Mettre en place les intégrations automatiques entre GitLab, Nextcloud et Mattermost pour créer un écosystème collaboratif intelligent

---

## 📋 Table des Matières

- [1. Configuration de Mattermost pour les Intégrations](#1-configuration-de-mattermost-pour-les-intégrations)
- [2. Intégration GitLab → Mattermost (Webhooks)](#2-intégration-gitlab--mattermost-webhooks)
- [3. Intégration Nextcloud → Mattermost (Monitoring)](#3-intégration-nextcloud--mattermost-monitoring)
- [4. Tests et Validation](#4-tests-et-validation)
- [5. Automatisation et Scripts](#5-automatisation-et-scripts)
- [6. Checklist Phase 3](#6-checklist-phase-3)

---

## 1. Configuration de Mattermost pour les Intégrations

### 1.1 Activer les Webhooks Entrants

#### 1.1.1 Via l'Interface Web

1. Connectez-vous à Mattermost : http://chat.taaf.internal
2. Allez dans **Menu (☰) → System Console**
3. Naviguez vers **Integrations → Integration Management**
4. Activez les options suivantes :
   - ✅ Enable Incoming Webhooks
   - ✅ Enable Outgoing Webhooks
   - ✅ Enable Custom Slash Commands
   - ✅ Enable OAuth 2.0 Service Provider

5. Cliquez sur **Save**

**📸 SCREENSHOT REQUIS :**
- `screenshots/11-mattermost-integrations-enabled.png` - Page des intégrations activées

#### 1.1.2 Via la Ligne de Commande (Alternative)

```bash
# Activer les webhooks via CLI
docker compose exec mattermost mattermost config set ServiceSettings.EnableIncomingWebhooks true
docker compose exec mattermost mattermost config set ServiceSettings.EnableOutgoingWebhooks true
docker compose exec mattermost mattermost config set ServiceSettings.EnablePostUsernameOverride true
docker compose exec mattermost mattermost config set ServiceSettings.EnablePostIconOverride true

echo "✅ Webhooks activés dans Mattermost"
```

---

### 1.2 Créer les Webhooks pour Chaque Canal

#### 1.2.1 Webhook pour #dev-notifications

1. Allez dans le canal **#dev-notifications**
2. Cliquez sur le nom du canal → **Integrations → Incoming Webhooks**
3. Cliquez sur **Add Incoming Webhook**
4. Configurez :
   - **Title** : GitLab Notifications
   - **Description** : Notifications automatiques des merge requests et commits
   - **Channel** : #dev-notifications
5. Cliquez sur **Save**
6. **Copiez l'URL du webhook** (format : `http://chat.taaf.internal/hooks/xxxxxxxxxxxxx`)

**📸 SCREENSHOT REQUIS :**
- `screenshots/12-mattermost-webhook-gitlab.png` - Webhook GitLab créé avec URL visible

#### 1.2.2 Webhook pour #rh-alerts

Répétez les mêmes étapes pour le canal **#rh-alerts** :
- **Title** : Nextcloud File Monitor
- **Description** : Notifications de nouveaux fichiers RH
- **Channel** : #rh-alerts

**📸 SCREENSHOT REQUIS :**
- `screenshots/13-mattermost-webhook-nextcloud.png` - Webhook Nextcloud créé avec URL visible

#### 1.2.3 Sauvegarder les URLs de Webhooks

```bash
# Créer un fichier de configuration pour les webhooks
cat > ~/taaf-infrastructure/scripts/.webhooks.conf << 'EOF'
# ==========================================
# Configuration des Webhooks Mattermost
# ==========================================

# Webhook GitLab → Mattermost
GITLAB_WEBHOOK_URL="http://chat.taaf.internal/hooks/VOTRE_WEBHOOK_GITLAB_ID"

# Webhook Nextcloud → Mattermost
NEXTCLOUD_WEBHOOK_URL="http://chat.taaf.internal/hooks/VOTRE_WEBHOOK_NEXTCLOUD_ID"

# Note: Remplacez les IDs par vos webhooks réels
EOF

echo "⚠️  N'oubliez pas de remplacer les IDs de webhooks dans scripts/.webhooks.conf"
```

---

## 2. Intégration GitLab → Mattermost (Webhooks)

### 2.1 Architecture de l'Intégration

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   GitLab    │ Webhook │   Service    │  POST   │ Mattermost  │
│   Events    │────────>│   Python     │────────>│   Channel   │
│ (MR, Push)  │         │   Relay      │         │ #gitlab-... │
└─────────────┘         └──────────────┘         └─────────────┘
```

### 2.2 Installation des Dépendances Python

```bash
# Installer les packages Python nécessaires
sudo apt install -y python3-pip python3-venv

# Créer un environnement virtuel
cd ~/taaf-infrastructure/scripts/webhooks/
python3 -m venv venv

# Activer l'environnement
source venv/bin/activate

# Installer les dépendances
pip install flask requests

# Créer le fichier requirements.txt
cat > requirements.txt << 'EOF'
flask==3.0.0
requests==2.31.0
gunicorn==21.2.0
EOF

pip install -r requirements.txt
```

---

### 2.3 Script Python du Webhook GitLab

```bash
cat > ~/taaf-infrastructure/scripts/webhooks/gitlab_webhook.py << 'EOF'
#!/usr/bin/env python3
"""
Webhook pour transmettre les événements GitLab vers Mattermost
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
import requests
import os

# Configuration
MATTERMOST_WEBHOOK_URL = os.getenv('MATTERMOST_WEBHOOK_URL', 'http://mattermost:8065/hooks/8jomgg6xy3gkzn9btb1y6oanhc')
PORT = 8090

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        # Lire les données
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            # Parser les données GitLab
            gitlab_data = json.loads(post_data.decode('utf-8'))
            
            # Identifier le type d'événement
            event_type = gitlab_data.get('object_kind', 'unknown')
            
            print(f"[INFO] Événement reçu: {event_type}")
            
            if event_type == 'merge_request':
                self.handle_merge_request(gitlab_data)
            elif event_type == 'push':
                self.handle_push(gitlab_data)
            else:
                print(f"[INFO] Type d'événement non géré: {event_type}")
            
            # Réponse OK
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'OK')
            
        except Exception as e:
            print(f"[ERREUR] {e}")
            import traceback
            traceback.print_exc()
            self.send_response(500)
            self.end_headers()
    
    def handle_merge_request(self, data):
        """Traiter les événements de merge request"""
        mr = data['object_attributes']
        user = data['user']
        project = data['project']
        
        print(f"[MR] {user['name']} - {mr['action']} - {mr['title']}")
        
        # Définir la couleur selon l'action
        color_map = {
            'open': '#00ff00',
            'merge': '#0000ff',
            'close': '#ff0000',
            'update': '#ffaa00'
        }
        color = color_map.get(mr['action'], '#808080')
        
        # Construire le message pour Mattermost
        message = {
            "username": "GitLab Bot",
            "icon_url": "https://about.gitlab.com/images/press/logo/png/gitlab-icon-rgb.png",
            "attachments": [{
                "color": color,
                "title": f"Merge Request #{mr['iid']}: {mr['title']}",
                "title_link": mr['url'],
                "text": f"**{user['name']}** a {self.get_action_text(mr['action'])} une merge request",
                "fields": [
                    {
                        "short": True,
                        "title": "Projet",
                        "value": project['name']
                    },
                    {
                        "short": True,
                        "title": "Status",
                        "value": mr['state']
                    },
                    {
                        "short": True,
                        "title": "Source",
                        "value": mr['source_branch']
                    },
                    {
                        "short": True,
                        "title": "Target",
                        "value": mr['target_branch']
                    }
                ]
            }]
        }
        
        # Envoyer à Mattermost
        self.send_to_mattermost(message)
    
    def handle_push(self, data):
        """Traiter les événements de push"""
        user_name = data['user_name']
        project = data['project']['name']
        branch = data['ref'].replace('refs/heads/', '')
        commits_count = data['total_commits_count']
        
        print(f"[PUSH] {user_name} - {commits_count} commits sur {branch}")
        
        message = {
            "username": "GitLab Bot",
            "icon_url": "https://about.gitlab.com/images/press/logo/png/gitlab-icon-rgb.png",
            "text": f"📦 **{user_name}** a poussé {commits_count} commit(s) sur **{project}** (branche `{branch}`)"
        }
        
        self.send_to_mattermost(message)
    
    def get_action_text(self, action):
        """Traduire l'action en français"""
        actions = {
            'open': 'ouvert',
            'merge': 'fusionné',
            'close': 'fermé',
            'update': 'mis à jour',
            'reopen': 'réouvert'
        }
        return actions.get(action, action)
    
    def send_to_mattermost(self, payload):
        """Envoyer le message à Mattermost"""
        try:
            print(f"[SEND] Envoi vers Mattermost: {MATTERMOST_WEBHOOK_URL}")
            response = requests.post(
                MATTERMOST_WEBHOOK_URL,
                json=payload,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            print(f"[SEND] Réponse Mattermost: {response.status_code}")
            if response.status_code != 200:
                print(f"[ERREUR] Contenu de la réponse: {response.text}")
        except Exception as e:
            print(f"[ERREUR] Échec envoi Mattermost: {e}")
            import traceback
            traceback.print_exc()

    def log_message(self, format, *args):
        """Logger les requêtes HTTP"""
        print(f"[HTTP] {format % args}")

def run_server():
    server_address = ('', PORT)
    httpd = HTTPServer(server_address, WebhookHandler)
    print(f'[DÉMARRAGE] Serveur webhook GitLab sur le port {PORT}')
    print(f'[CONFIG] Webhook Mattermost: {MATTERMOST_WEBHOOK_URL}')
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()

EOF

chmod +x ~/taaf-infrastructure/scripts/webhooks/gitlab_webhook.py
```

---

### 2.4 Configurer GitLab pour Envoyer les Webhooks

#### 2.4.1 Créer un Projet de Test

1. Connectez-vous à GitLab : http://git.taaf.internal
2. Créez un nouveau projet : **"projet-test-taaf"**
3. Initialisez-le avec un README

**📸 SCREENSHOT REQUIS :**
- `screenshots/14-gitlab-projet-test.png` - Projet de test créé

#### 2.4.2 Configurer le Webhook dans GitLab

1. Dans votre projet → **Settings → Webhooks**
2. Configurez :
   - **URL** : `http://HOST_IP:8090/webhook/gitlab`
     - Remplacez HOST_IP par votre IP locale : `ip addr show | grep "inet " | grep -v 127.0.0.1`
   - **Secret Token** : (laisser vide pour le test)
   - **Trigger** : 
     - ✅ Push events
     - ✅ Merge request events
     - ✅ Issues events
   - ✅ Enable SSL verification (décocher pour le test local)

3. Cliquez sur **Add webhook**

**📸 SCREENSHOT REQUIS :**
- `screenshots/15-gitlab-webhook-config.png` - Configuration du webhook GitLab

#### 2.5.3 Tester le Webhook

```bash
# Dans GitLab, cliquez sur "Test" à côté du webhook
# Ou effectuez des actions réelles :

# 1. Créer une issue
# 2. Créer une merge request
# 3. Faire un commit/push

# Vérifier les logs
tail -f ~/taaf-infrastructure/scripts/webhooks/webhook_gitlab.log
```

**📸 SCREENSHOT REQUIS :**
- `screenshots/16-mattermost-gitlab-notification.png` - Notification GitLab dans Mattermost

---

## 3. Intégration Nextcloud → Mattermost (Monitoring)

### 3.1 Architecture du Monitoring

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Nextcloud  │  Watch  │   Script     │  POST   │ Mattermost  │
│  Dossier RH │────────>│   Python     │────────>│   Channel   │
│  (inotify)  │         │   Monitor    │         │ #nextcloud..│
└─────────────┘         └──────────────┘         └─────────────┘
```

### 3.2 Créer le Dossier RH dans Nextcloud

```bash
# Se connecter au conteneur Nextcloud
docker compose exec -u www-data nextcloud bash

# Créer la structure de dossiers RH
php occ files:scan admin
mkdir -p /var/www/html/data/admin/files/Documents_RH
mkdir -p /var/www/html/data/admin/files/Documents_RH/Contrats
mkdir -p /var/www/html/data/admin/files/Documents_RH/Fiches_Paie
mkdir -p /var/www/html/data/admin/files/Documents_RH/Conges

# Changer les permissions
chown -R www-data:www-data /var/www/html/data/admin/files/Documents_RH

# Scanner les nouveaux fichiers
php occ files:scan admin

exit
```

---

### 3.3 Script Python de Monitoring Nextcloud

```bash
cat > ~/taaf-infrastructure/scripts/monitoring/nextcloud-monitor.py << 'EOF'
#!/usr/bin/env python3
"""
Monitoring des nouveaux fichiers Nextcloud vers Mattermost
Version corrigée : détecte les fichiers après leur upload complet
"""
import os
import time
import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from datetime import datetime

# Configuration
WATCH_PATH = os.getenv('WATCH_PATH', '/nextcloud-data/admin/files/Documents-RH')
MATTERMOST_WEBHOOK_URL = os.getenv('MATTERMOST_WEBHOOK_URL')
CHECK_INTERVAL = 5  # secondes

class NextcloudFileHandler(FileSystemEventHandler):
    def __init__(self):
        self.last_notification = {}
    
    def on_created(self, event):
        """Détecte les nouveaux fichiers créés directement"""
        if event.is_directory:
            return
        
        file_path = event.src_path
        filename = os.path.basename(file_path)
        
        # Ignorer les fichiers temporaires
        if self.is_temp_file(filename):
            print(f"[SKIP] Fichier temporaire ignoré: {filename}")
            return
        
        # Traiter le fichier
        self.process_file(file_path)
    
    def on_moved(self, event):
        """
        Détecte les fichiers renommés (cas d'usage principal de Nextcloud)
        Nextcloud upload d'abord vers .part puis renomme vers le nom final
        """
        if event.is_directory:
            return
        
        # On s'intéresse uniquement au fichier de destination
        dest_path = event.dest_path
        dest_filename = os.path.basename(dest_path)
        
        # Ignorer si c'est toujours un fichier temporaire
        if self.is_temp_file(dest_filename):
            return
        
        # Le fichier source était un .part et est maintenant le fichier final
        src_filename = os.path.basename(event.src_path)
        if src_filename.endswith('.part') or src_filename.startswith('.'):
            print(f"[DÉTECTÉ] Fichier uploadé complètement: {dest_filename}")
            self.process_file(dest_path)
    
    def is_temp_file(self, filename):
        """Vérifier si un fichier est temporaire"""
        temp_patterns = [
            filename.startswith('.'),
            filename.endswith('.part'),
            filename.endswith('.tmp'),
            '.ocTransferId' in filename,
            filename.startswith('~'),
        ]
        return any(temp_patterns)
    
    def process_file(self, file_path):
        """Traiter un nouveau fichier détecté"""
        current_time = time.time()
        
        # Éviter les notifications en double (dans un délai de 3 secondes)
        if file_path in self.last_notification:
            if current_time - self.last_notification[file_path] < 3:
                print(f"[SKIP] Notification déjà envoyée récemment pour ce fichier")
                return
        
        self.last_notification[file_path] = current_time
        
        # Extraire les infos du fichier
        filename = os.path.basename(file_path)
        folder = os.path.basename(os.path.dirname(file_path))
        
        print(f"[NOUVEAU] {filename} dans {folder}")
        self.send_notification(filename, folder, file_path)
    
    def send_notification(self, filename, folder, file_path):
        """Envoyer une notification à Mattermost"""
        
        # Récupérer la taille du fichier
        try:
            file_size = os.path.getsize(file_path)
            size_mb = file_size / (1024 * 1024)
            size_str = f"{size_mb:.2f} MB" if size_mb >= 1 else f"{file_size / 1024:.2f} KB"
        except:
            size_str = "Taille inconnue"
        
        # Déterminer l'icône selon le type de fichier
        icon = self.get_file_icon(filename)
        
        # Déterminer la catégorie
        category = self.get_category(folder)
        
        message = {
            "username": "Nextcloud RH Bot",
            "icon_emoji": ":file_folder:",
            "attachments": [{
                "color": "#0082c9",
                "title": f"{icon} Nouveau document RH déposé",
                "text": f"Un nouveau document a été ajouté dans le dossier **{folder}**",
                "fields": [
                    {
                        "short": False,
                        "title": "📎 Fichier",
                        "value": f"`{filename}`"
                    },
                    {
                        "short": True,
                        "title": "📁 Catégorie",
                        "value": category
                    },
                    {
                        "short": True,
                        "title": "💾 Taille",
                        "value": size_str
                    },
                    {
                        "short": True,
                        "title": "📅 Date",
                        "value": datetime.now().strftime("%d/%m/%Y")
                    },
                    {
                        "short": True,
                        "title": "🕐 Heure",
                        "value": datetime.now().strftime("%H:%M:%S")
                    }
                ],
                "footer": "Nextcloud TAAF - Documents RH",
                "footer_icon": "https://nextcloud.com/wp-content/uploads/2022/03/favicon.png"
            }]
        }
        
        try:
            print(f"[SEND] Envoi notification vers Mattermost...")
            response = requests.post(
                MATTERMOST_WEBHOOK_URL,
                json=message,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            if response.status_code == 200:
                print(f"[✓] Notification envoyée avec succès pour: {filename}")
            else:
                print(f"[✗] Erreur HTTP {response.status_code}")
                print(f"[✗] Réponse: {response.text}")
        except Exception as e:
            print(f"[✗] Échec envoi Mattermost: {e}")
            import traceback
            traceback.print_exc()
    
    def get_file_icon(self, filename):
        """Retourner une icône selon le type de fichier"""
        ext = os.path.splitext(filename)[1].lower()
        icons = {
            '.pdf': '📄',
            '.doc': '📝',
            '.docx': '📝',
            '.xls': '📊',
            '.xlsx': '📊',
            '.csv': '📊',
            '.ppt': '📊',
            '.pptx': '📊',
            '.txt': '📃',
            '.jpg': '🖼️',
            '.jpeg': '🖼️',
            '.png': '🖼️',
            '.gif': '🖼️',
            '.zip': '🗜️',
            '.rar': '🗜️',
            '.7z': '🗜️',
        }
        return icons.get(ext, '📎')
    
    def get_category(self, folder):
        """Déterminer la catégorie selon le dossier"""
        # Normaliser le nom du dossier (gérer les différentes conventions)
        folder_normalized = folder.replace('-', ' ').replace('_', ' ').lower()
        
        categories = {
            'contrats': '📋 Contrats',
            'fiches paie': '💰 Fiches de Paie',
            'notes service': '📢 Notes de Service',
            'documents rh': '👥 RH Général',
            'conges': '🏖️ Congés',
            'formations': '🎓 Formations',
        }
        
        for key, value in categories.items():
            if key in folder_normalized:
                return value
        
        return f'📁 {folder}'

def main():
    print("=" * 60)
    print("[DÉMARRAGE] Monitoring Nextcloud → Mattermost")
    print("=" * 60)
    print(f"[CONFIG] Dossier surveillé: {WATCH_PATH}")
    
    if not MATTERMOST_WEBHOOK_URL:
        print(f"[✗ ERREUR] MATTERMOST_WEBHOOK_URL non configuré!")
        print("[INFO] Définissez la variable d'environnement MATTERMOST_WEBHOOK_URL")
        return
    
    print(f"[CONFIG] Webhook Mattermost: {MATTERMOST_WEBHOOK_URL[:50]}...")
    
    # Vérifier que le dossier existe
    if not os.path.exists(WATCH_PATH):
        print(f"[ATTENTE] Le dossier {WATCH_PATH} n'existe pas encore...")
        print("[INFO] Création automatique en attente...")
        
        # Attendre que le dossier soit créé (max 5 minutes)
        max_wait = 300  # 5 minutes
        waited = 0
        while not os.path.exists(WATCH_PATH) and waited < max_wait:
            time.sleep(5)
            waited += 5
            if waited % 30 == 0:
                print(f"[ATTENTE] Toujours en attente... ({waited}s)")
        
        if not os.path.exists(WATCH_PATH):
            print(f"[✗ ERREUR] Le dossier n'existe toujours pas après {max_wait}s")
            return
        
        print(f"[✓] Dossier détecté!")
    
    print("[OK] Initialisation du monitoring...")
    
    event_handler = NextcloudFileHandler()
    observer = Observer()
    observer.schedule(event_handler, WATCH_PATH, recursive=True)
    observer.start()
    
    print("=" * 60)
    print("[✓✓✓] MONITORING ACTIF - En attente de nouveaux fichiers...")
    print("=" * 60)
    print("[INFO] Événements détectés:")
    print("  - Création de fichiers")
    print("  - Renommage de fichiers (upload Nextcloud)")
    print("[INFO] Fichiers ignorés:")
    print("  - Fichiers .part (temporaires)")
    print("  - Fichiers cachés (commençant par .)")
    print("  - Fichiers avec ocTransferId")
    print("=" * 60)
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\n" + "=" * 60)
        print("[ARRÊT] Monitoring arrêté proprement")
        print("=" * 60)
    
    observer.join()

if __name__ == '__main__':
    main()
EOF

chmod +x ~/taaf-infrastructure/scripts/monitoring/nextcloud-monitor.py
```

---

### 3.4 Installation des Dépendances du Monitor

```bash
# Installer watchdog pour surveiller les fichiers
cd ~/taaf-infrastructure/scripts/monitoring/
python3 -m venv venv
source venv/bin/activate

pip install watchdog requests

# Créer requirements.txt
cat > requirements.txt << 'EOF'
watchdog==3.0.0
requests==2.31.0
EOF

pip install -r requirements.txt
```

## 4. Tests et Validation

### 4.1 Test de l'Intégration GitLab

#### 4.1.1 Test : Créer une Merge Request

```bash
# Dans GitLab, créer une nouvelle branche
cd /tmp
git clone http://git.taaf.internal/root/projet-test-taaf.git
cd projet-test-taaf

# Créer une nouvelle branche
git checkout -b feature/test-notification

# Faire des modifications
echo "Test de notification" >> README.md
git add README.md
git commit -m "Test: notification Mattermost"
git push origin feature/test-notification

# Créer la MR via l'interface GitLab
```

**Résultat attendu :** Une notification apparaît dans #dev-notifications

**📸 SCREENSHOT REQUIS :**
- `screenshots/17-gitlab-merge-request.png` - MR créée dans GitLab
- `screenshots/18-mattermost-mr-notification.png` - Notification MR dans Mattermost

---

#### 4.1.2 Test : Push de Code

```bash
# Faire un push simple
git checkout main
echo "Modification simple" >> test.txt
git add test.txt
git commit -m "feat: ajout fichier de test"
git push origin main
```

**Résultat attendu :** Notification de push dans #dev-notifications

**📸 SCREENSHOT REQUIS :**
- `screenshots/19-mattermost-push-notification.png` - Notification de push

---

### 4.2 Test de l'Intégration Nextcloud

#### 4.2.1 Test : Upload d'un Fichier RH

1. Connectez-vous à Nextcloud : http://cloud.taaf.internal
2. Naviguez vers **Documents_RH/Contrats**
3. Uploadez un fichier PDF de test (ou créez-en un)

**Résultat attendu :** Notification dans #rh-alerts

**📸 SCREENSHOT REQUIS :**
- `screenshots/20-nextcloud-upload.png` - Fichier uploadé dans Nextcloud
- `screenshots/21-mattermost-file-notification.png` - Notification fichier dans Mattermost

---

### 4.3 Tests Fonctionnels Complets

#### 4.3.1 Scénario 1 : Workflow de Développement

```
1. Développeur crée une issue dans GitLab
   → Notification dans #dev-notifications
   
2. Développeur crée une branche et fait des commits
   → Notification de push dans #dev-notifications
   
3. Développeur crée une Merge Request
   → Notification MR dans #dev-notifications
   
4. MR est mergée
   → Notification de merge dans #dev-notifications
```

#### 4.3.2 Scénario 2 : Processus RH

```
1. RH upload un nouveau contrat dans Nextcloud/Documents_RH/Contrats
   → Notification dans #rh-alerts
   
2. RH upload une fiche de paie dans Nextcloud/Documents_RH/Fiches_Paie
   → Notification dans #rh-alerts
   
3. Employé dépose une demande de congé
   → Notification dans #rh-alerts
```

---

## 5. Automatisation et Scripts

### 5.1 Script d'Arrêt Complet

```bash
cat > ~/taaf-infrastructure/scripts/stop-all-services.sh << 'EOF'
#!/bin/bash

echo "🛑 Arrêt de l'Infrastructure TAAF"
echo "==================================="

cd ~/taaf-infrastructure

# 1. Arrêter le webhook GitLab
if [ -f scripts/webhooks/webhook_gitlab.pid ]; then
    echo "🔗 Arrêt du GitLab Webhook..."
    kill $(cat scripts/webhooks/webhook_gitlab.pid) 2>/dev/null
    rm scripts/webhooks/webhook_gitlab.pid
fi

# 2. Arrêter le monitor Nextcloud
if [ -f scripts/monitoring/monitor.pid ]; then
    echo "🔍 Arrêt du Nextcloud Monitor..."
    kill $(cat scripts/monitoring/monitor.pid) 2>/dev/null
    rm scripts/monitoring/monitor.pid
fi

# 3. Arrêter Docker Compose
echo "📦 Arrêt des conteneurs Docker..."
docker compose down

echo ""
echo "✅ Infrastructure TAAF arrêtée !"
EOF

chmod +x ~/taaf-infrastructure/scripts/stop-all-services.sh
```

---

### 5.2 Script de Status

```bash
cat > ~/taaf-infrastructure/scripts/status.sh << 'EOF'
#!/bin/bash

echo "📊 État de l'Infrastructure TAAF"
echo "=================================="
echo ""

cd ~/taaf-infrastructure

# Docker Compose
echo "🐳 Conteneurs Docker :"
docker compose ps
echo ""

# Webhook GitLab
echo "🔗 GitLab Webhook :"
if [ -f scripts/webhooks/webhook_gitlab.pid ]; then
    PID=$(cat scripts/webhooks/webhook_gitlab.pid)
    if ps -p $PID > /dev/null; then
        echo "  ✅ Actif (PID: $PID)"
    else
        echo "  ❌ Inactif (PID obsolète)"
    fi
else
    echo "  ❌ Non démarré"
fi
echo ""

# Monitor Nextcloud
echo "🔍 Nextcloud Monitor :"
if [ -f scripts/monitoring/monitor.pid ]; then
    PID=$(cat scripts/monitoring/monitor.pid)
    if ps -p $PID > /dev/null; then
        echo "  ✅ Actif (PID: $PID)"
    else
        echo "  ❌ Inactif (PID obsolète)"
    fi
else
    echo "  ❌ Non démarré"
fi
echo ""

# Connectivité
echo "🌐 Tests de connectivité :"
for url in "http://taaf.internal" "http://git.taaf.internal" "http://cloud.taaf.internal" "http://chat.taaf.internal"; do
    if curl -s -o /dev/null -w "%{http_code}" $url | grep -q "200\|302"; then
        echo "  ✅ $url"
    else
        echo "  ❌ $url"
    fi
done
EOF

chmod +x ~/taaf-infrastructure/scripts/status.sh
```

---

### 5.3 Script de Tests Automatisés

```bash
cat > ~/taaf-infrastructure/scripts/test-integrations.sh << 'EOF'
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

EOF

chmod +x ~/taaf-infrastructure/scripts/test-integrations.sh
```

---

## 6. Checklist Phase 3

### ✅ Vérification Finale

- [ ] **Webhooks Mattermost créés** (#dev-notifications, #rh-alerts)
- [ ] **URLs de webhooks sauvegardées** (fichier .webhooks.conf)
- [ ] **Script Python GitLab créé** et testé
- [ ] **Service webhook GitLab démarré** (port 8090)
- [ ] **Webhook configuré dans GitLab** avec triggers activés
- [ ] **Test MR réussi** (notification reçue dans Mattermost)
- [ ] **Test Push réussi** (notification reçue)
- [ ] **Dossier RH créé dans Nextcloud**
- [ ] **Script Python Monitor créé** et testé
- [ ] **Service monitor démarré** (surveillance active)
- [ ] **Test upload Nextcloud réussi** (notification reçue)
- [ ] **Scripts d'automatisation créés** (start, stop, status, test)
- [ ] **12 screenshots capturés** (tous les tests documentés)

### 📊 Résumé de la Phase 3

```
🎯 Objectifs atteints :
   ✅ Intégrations GitLab → Mattermost fonctionnelles
   ✅ Intégrations Nextcloud → Mattermost fonctionnelles
   ✅ Notifications automatiques en temps réel
   ✅ Scripts d'automatisation et de maintenance
   ✅ Tests complets validés

🔗 Intégrations déployées :
   • Webhook GitLab pour Merge Requests
   • Webhook GitLab pour Push events
   • Webhook GitLab pour Issues
   • Monitor Nextcloud pour nouveaux fichiers RH

📝 Scripts créés :
   • gitlab_webhook.py (relay GitLab → Mattermost)
   • nextcloud_monitor.py (surveillance fichiers)
   • start-all-services.sh (démarrage complet)
   • stop-all-services.sh (arrêt propre)
   • status.sh (état de l'infrastructure)
   • test-integrations.sh (tests automatisés)

⏱️ Temps total : 60-90 minutes

🎓 Compétences acquises :
   • Développement de webhooks REST
   • Monitoring de systèmes de fichiers (watchdog)
   • Intégration de services hétérogènes
   • Scripting d'automatisation DevOps
   • Tests et validation d'intégrations
```

---
## 🔧 Dépannage Phase 3

### Webhook GitLab ne fonctionne pas

```bash
# Vérifier que le script tourne
ps aux | grep gitlab_webhook

# Vérifier les logs
tail -f ~/taaf-infrastructure/scripts/webhooks/webhook_gitlab.log

# Tester manuellement l'endpoint
curl http://localhost:8090/health

# Redémarrer le webhook
pkill -f gitlab_webhook.py
cd ~/taaf-infrastructure/scripts/webhooks
./start_gitlab_webhook.sh
```

### Monitor Nextcloud ne détecte pas les fichiers

```bash
# Vérifier que le script tourne
ps aux | grep nextcloud_monitor

# Vérifier les logs
tail -f ~/taaf-infrastructure/scripts/monitoring/monitor.log

# Vérifier le chemin du volume
docker volume inspect taaf-infrastructure_nextcloud_data

# Redémarrer le monitor
pkill -f nextcloud_monitor.py
cd ~/taaf-infrastructure/scripts/monitoring
./start_nextcloud_monitor.sh
```

### Notifications Mattermost non reçues

```bash
# Vérifier l'URL du webhook
cat ~/taaf-infrastructure/scripts/.webhooks.conf

# Tester manuellement le webhook Mattermost
curl -X POST http://chat.taaf.internal/hooks/VOTRE_WEBHOOK_ID \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test notification"}'

# Vérifier les logs Mattermost
docker compose logs mattermost | grep -i webhook
```

---

## 📚 Documentation Complémentaire

### APIs et Webhooks

- [GitLab Webhooks Documentation](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html)
- [Mattermost Incoming Webhooks](https://docs.mattermost.com/developer/webhooks-incoming.html)
- [Python Watchdog Documentation](https://python-watchdog.readthedocs.io/)

### Exemples de Payload

**GitLab Merge Request Webhook :**
```json
{
  "object_kind": "merge_request",
  "user": {
    "name": "Admin TAAF",
    "username": "admin"
  },
  "object_attributes": {
    "title": "Feature: Nouveau module",
    "state": "opened",
    "action": "open"
  }
}
```

**Mattermost Incoming Webhook :**
```json
{
  "text": "Message principal",
  "username": "Bot Name",
  "icon_url": "https://example.com/icon.png",
  "attachments": [{
    "color": "#36a64f",
    "title": "Titre",
    "text": "Description"
  }]
}
```

---

## ➡️ Prochaine Étape

Félicitations ! Vous avez terminé les 3 phases du TP TAAF. 🎉

Il reste à finaliser :

**[📄 ANNEXES.md](ANNEXES.md)**

Les annexes contiendront :
- Procédures de mise à jour
- Troubleshooting avancé
- Ressources complémentaires
- Glossaire technique

---

<div align="center">

**🌊 Infrastructure TAAF - Phase 3 Complétée ! 🎉**

Toutes les intégrations sont maintenant fonctionnelles !

[⬅️ Phase 2](PHASE_2_DEPLOIEMENT.md) | [🏠 README](../README.md) | [➡️ Annexes](ANNEXES.md)

</div>