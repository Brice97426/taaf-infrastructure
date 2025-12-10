# Installation TAAF Infrastructure - Phase 1

## Prérequis installés

- [x] Docker version : `docker --version`
- [x] Docker Compose version : `docker-compose --version`

## Structure des dossiers
```
taaf-infrastructure/
├── caddy/                  # Configuration du reverse proxy
├── data/                   # Données persistantes des services
│   ├── gitlab/
│   ├── nextcloud/
│   ├── mattermost/
│   ├── postgres/
│   └── caddy/
└── scripts/                # Scripts utilitaires
```

## Configuration DNS

Les domaines suivants ont été ajoutés à `/etc/hosts` :
- taaf.internal
- git.taaf.internal
- cloud.taaf.internal
- chat.taaf.internal

## Vérification

Tester la résolution DNS :
```bash
ping -c 2 git.taaf.internal
```

## Prochaines étapes

Phase 2 : Déploiement de l'infrastructure
- Configuration du reverse proxy Caddy
- Déploiement de GitLab
- Déploiement de Nextcloud
- Déploiement de Mattermost
