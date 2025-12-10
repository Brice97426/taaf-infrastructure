#!/bin/bash
set -e

# Script d'initialisation des bases de données pour TAAF
# Ce script crée les bases de données nécessaires pour tous les services

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Créer la base de données pour Keycloak
    CREATE DATABASE keycloak;
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO $POSTGRES_USER;
    
    -- Afficher les bases créées
    \l
EOSQL

echo "✅ Bases de données initialisées avec succès !"
echo "📊 Bases disponibles : gitlab, keycloak"