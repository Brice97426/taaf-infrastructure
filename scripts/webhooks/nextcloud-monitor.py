#!/usr/bin/env python3
"""
Monitoring des nouveaux fichiers Nextcloud vers Mattermost
"""
import os
import time
import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from datetime import datetime

# Configuration
WATCH_PATH = os.getenv('WATCH_PATH', '/var/www/html/data/admin/files/Documents-RH')
MATTERMOST_WEBHOOK_URL = os.getenv('MATTERMOST_WEBHOOK_URL')
CHECK_INTERVAL = 5  # secondes

class NextcloudFileHandler(FileSystemEventHandler):
    def __init__(self):
        self.last_notification = {}
    
    def on_created(self, event):
        if event.is_directory:
            return
        
        # Éviter les notifications en double
        file_path = event.src_path
        current_time = time.time()
        
        if file_path in self.last_notification:
            if current_time - self.last_notification[file_path] < 2:
                return
        
        self.last_notification[file_path] = current_time
        
        # Extraire les infos du fichier
        filename = os.path.basename(file_path)
        folder = os.path.basename(os.path.dirname(file_path))
        
        # Ignorer les fichiers temporaires
        if filename.startswith('.') or filename.endswith('.part'):
            print(f"[SKIP] Fichier temporaire ignoré: {filename}")
            return
        
        print(f"[DÉTECTÉ] Nouveau fichier: {filename} dans {folder}")
        self.send_notification(filename, folder)
    
    def send_notification(self, filename, folder):
        """Envoyer une notification à Mattermost"""
        
        # Déterminer l'icône selon le type de fichier
        icon = self.get_file_icon(filename)
        
        # Déterminer la catégorie
        category = self.get_category(folder)
        
        message = {
            "username": "Nextcloud RH",
            "icon_emoji": ":file_folder:",
            "attachments": [{
                "color": "#0082c9",
                "title": f"{icon} Nouveau document RH déposé",
                "text": f"Un nouveau document a été ajouté dans le dossier **{folder}**",
                "fields": [
                    {
                        "short": False,
                        "title": "Fichier",
                        "value": f"`{filename}`"
                    },
                    {
                        "short": True,
                        "title": "Catégorie",
                        "value": category
                    },
                    {
                        "short": True,
                        "title": "Date",
                        "value": datetime.now().strftime("%d/%m/%Y %H:%M")
                    }
                ],
                "footer": "Nextcloud TAAF",
                "footer_icon": "https://nextcloud.com/wp-content/uploads/2022/03/favicon.png"
            }]
        }
        
        try:
            print(f"[SEND] Envoi vers Mattermost: {MATTERMOST_WEBHOOK_URL}")
            response = requests.post(
                MATTERMOST_WEBHOOK_URL,
                json=message,
                headers={'Content-Type': 'application/json'},
                timeout=10
            )
            if response.status_code == 200:
                print(f"[OK] Notification envoyée pour {filename}")
            else:
                print(f"[ERREUR] Code HTTP: {response.status_code}")
                print(f"[ERREUR] Réponse: {response.text}")
        except Exception as e:
            print(f"[ERREUR] Échec envoi: {e}")
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
            '.jpg': '🖼️',
            '.jpeg': '🖼️',
            '.png': '🖼️',
            '.zip': '🗜️',
        }
        return icons.get(ext, '📎')
    
    def get_category(self, folder):
        """Déterminer la catégorie selon le dossier"""
        categories = {
            'Contrats': '📋 Contrat',
            'Fiches-Paie': '💰 Paie',
            'Notes-Service': '📢 Note de service',
            'Documents-RH': '👥 RH Général'
        }
        return categories.get(folder, '📁 Document')

def main():
    print(f"[DÉMARRAGE] Monitoring Nextcloud...")
    print(f"[CONFIG] Dossier surveillé: {WATCH_PATH}")
    if MATTERMOST_WEBHOOK_URL:
        print(f"[CONFIG] Webhook Mattermost: {MATTERMOST_WEBHOOK_URL[:60]}...")
    else:
        print(f"[ERREUR] MATTERMOST_WEBHOOK_URL non configuré!")
        return
    
    # Vérifier que le dossier existe
    if not os.path.exists(WATCH_PATH):
        print(f"[ATTENTE] Le dossier {WATCH_PATH} n'existe pas encore...")
        while not os.path.exists(WATCH_PATH):
            time.sleep(5)
        print(f"[OK] Dossier détecté!")
    
    event_handler = NextcloudFileHandler()
    observer = Observer()
    observer.schedule(event_handler, WATCH_PATH, recursive=True)
    observer.start()
    
    print("[OK] Monitoring actif!")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\n[ARRÊT] Monitoring arrêté")
    
    observer.join()

if __name__ == '__main__':
    main()
