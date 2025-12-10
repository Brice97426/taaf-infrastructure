#!/bin/bash

echo "=== Vérification de l'environnement TAAF ==="
echo ""

# Vérifier Docker
echo "1. Docker :"
if command -v docker &> /dev/null; then
    echo "   ✓ Docker installé : $(docker --version)"
else
    echo "   ✗ Docker NON installé"
fi

# Vérifier Docker Compose
echo "2. Docker Compose :"
if command -v docker-compose &> /dev/null; then
    echo "   ✓ Docker Compose installé : $(docker-compose --version)"
else
    echo "   ✗ Docker Compose NON installé"
fi

# Vérifier la structure des dossiers
echo "3. Structure des dossiers :"
if [ -d "data/gitlab" ] && [ -d "data/nextcloud" ] && [ -d "data/mattermost" ]; then
    echo "   ✓ Structure de dossiers correcte"
else
    echo "   ✗ Structure de dossiers incomplète"
fi

# Vérifier la configuration DNS
echo "4. Configuration DNS :"
if grep -q "git.taaf.internal" /etc/hosts 2>/dev/null; then
    echo "   ✓ DNS configuré dans /etc/hosts"
else
    echo "   ✗ DNS NON configuré"
fi

# Vérifier les permissions Docker
echo "5. Permissions Docker :"
if docker ps &> /dev/null; then
    echo "   ✓ Permissions Docker OK"
else
    echo "   ⚠ Nécessite 'sudo' ou ajoutez l'utilisateur au groupe docker"
fi

echo ""
echo "=== Fin de la vérification ==="
