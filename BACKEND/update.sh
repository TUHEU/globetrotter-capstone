#!/usr/bin/env bash
# ============================================================
# update.sh — Met à jour le backend FahGlobe (GlobeTrotter Yaoundé)
# Phase 2 : microservices via Docker Compose (remplace l'ancien
# update.sh Phase 1, qui utilisait venv + systemd sur le port 4200
# directement — désormais c'est Docker qui écoute sur ce port).
#
# Usage :  ./update.sh
# À lancer DEPUIS le dossier du backend sur le VPS
#   (ex: ~/BACKEND-GLOBE-V2)
# ============================================================
set -euo pipefail

# ---------- Configuration (ajuste si besoin) ----------
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEALTH_URL="http://127.0.0.1:4200/health"
BACKUP_DIR="$APP_DIR/backups"
KEEP_BACKUPS=10   # combien de sauvegardes garder

# Dossiers de données réels (bind mounts, un par microservice) —
# ce sont les SEULS fichiers que git ne suit pas (gitignorés) et
# qui contiennent les vraies données de production.
DATA_DIRS=(
  "user-service/data"
  "itinerary-service/data"
  "recommendation-service/data"
  "chat-service/data"
  "chat-service/static"
)

# ---------- Couleurs pour la lisibilité ----------
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
fail()  { echo -e "${RED}[ERREUR]${NC} $1"; exit 1; }

cd "$APP_DIR"
echo "=== Mise à jour FahGlobe (Phase 2 — Docker) — $(date '+%Y-%m-%d %H:%M:%S') ==="

# ---------- 1. Sauvegarde des données AVANT toute mise à jour ----------
# Même si ces dossiers sont gitignorés (donc jamais écrasés par un
# git pull), on sauvegarde quand même par précaution avant de toucher
# aux conteneurs.
mkdir -p "$BACKUP_DIR"
STAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_PATH="$BACKUP_DIR/data_$STAMP.tar.gz"

EXISTING_DIRS=()
for d in "${DATA_DIRS[@]}"; do
  [ -d "$d" ] && EXISTING_DIRS+=("$d")
done

if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
  tar -czf "$BACKUP_PATH" "${EXISTING_DIRS[@]}"
  info "Données sauvegardées → $BACKUP_PATH"
  ls -1t "$BACKUP_DIR"/data_*.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm --
else
  warn "Aucun dossier data/ trouvé — sauvegarde ignorée (rien à sauvegarder ?)"
fi

# ---------- 2. Récupérer le nouveau code ----------
if [ -d "$APP_DIR/.git" ]; then
  info "Dépôt git détecté — récupération des changements..."
  git pull
else
  fail "Pas de dépôt git ici ($APP_DIR). Ce script suppose un déploiement via git clone."
fi

# ---------- 3. Reconstruire et redémarrer les conteneurs ----------
# "up --build -d" ne recrée QUE les conteneurs dont l'image a changé —
# les autres continuent de tourner sans interruption.
info "Reconstruction et redémarrage des conteneurs..."
docker compose up --build -d --remove-orphans

# ---------- 4. Vérification de santé ----------
info "Vérification du démarrage..."
sleep 3

HEALTH_OK=false
for i in 1 2 3 4 5; do
  if curl -sf "$HEALTH_URL" > /dev/null; then
    HEALTH_OK=true
    break
  fi
  sleep 2
done

if [ "$HEALTH_OK" = true ]; then
  info "API répond correctement sur $HEALTH_URL"
  echo ""
  docker compose ps
  echo ""
  echo "=== Mise à jour terminée avec succès ✅ ==="
else
  warn "L'API ne répond pas sur $HEALTH_URL après plusieurs essais."
  echo ""
  echo "État des conteneurs :"
  docker compose ps
  echo ""
  echo "Derniers logs (tous services) :"
  docker compose logs --tail=30
  fail "Vérifie les logs ci-dessus. Restauration des données possible depuis : $BACKUP_DIR"
fi
