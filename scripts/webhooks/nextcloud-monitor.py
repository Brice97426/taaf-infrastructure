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