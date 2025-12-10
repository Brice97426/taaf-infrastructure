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