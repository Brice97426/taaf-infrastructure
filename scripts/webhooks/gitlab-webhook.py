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
