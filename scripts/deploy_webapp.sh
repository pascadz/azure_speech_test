#!/bin/bash
set -e

# ── Deploy to Azure App Service (Web App) ──
# Lokaler Build: Frontend (npm) + Python-Deps werden HIER gebaut,
# dann als fertiges ZIP-Paket nach Azure hochgeladen.
#
# Voraussetzungen (lokal):
#   - Azure CLI (az)
#   - Node.js ≥ 18 + npm
#   - Python 3.12 + pip
#
# Usage:
#   ./scripts/deploy_webapp.sh <resource-group> <app-name> [location]
#
# Beispiel:
#   ./scripts/deploy_webapp.sh rg-voicechat voicechat-app westeurope

RESOURCE_GROUP="${1:?Fehler: Resource Group Name als 1. Argument angeben}"
APP_NAME="${2:?Fehler: Web App Name als 2. Argument angeben}"
LOCATION="${3:-westeurope}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "============================================"
echo "  Voice Chat → Azure App Service Deploy"
echo "  (Lokaler Build → ZIP Push)"
echo "============================================"
echo ""
echo "  Resource Group: $RESOURCE_GROUP"
echo "  App Name:       $APP_NAME"
echo "  Location:       $LOCATION"
echo ""

# ── 0. Voraussetzungen prüfen ──
echo "� Prüfe Voraussetzungen..."
missing=""
command -v az   &>/dev/null || missing="${missing}  - Azure CLI (az)\n"
command -v node &>/dev/null || missing="${missing}  - Node.js (node)\n"
command -v npm  &>/dev/null || missing="${missing}  - npm\n"
command -v python3 &>/dev/null || missing="${missing}  - Python 3 (python3)\n"

if [ -n "$missing" ]; then
  echo "❌ Fehlende Tools:"
  echo -e "$missing"
  exit 1
fi
echo "   az    $(az version --query '\"azure-cli\"' -o tsv 2>/dev/null || echo '?')"
echo "   node  $(node --version)"
echo "   npm   $(npm --version)"
echo "   python3 $(python3 --version 2>&1 | awk '{print $2}')"
echo ""

# ── 1. Frontend lokal bauen ──
echo "📦 Baue Frontend (npm install + vite build)..."
cd "$ROOT_DIR/app/frontend"
npm install --prefer-offline --no-audit --no-fund
npx vite build
# vite.config.ts: outDir = "../backend/static"  →  app/backend/static/
echo "✅ Frontend gebaut → app/backend/static/"
echo ""

# ── 2. Deploy-Paket zusammenstellen ──
echo "📦 Erstelle Deploy-Paket..."
#DEPLOY_DIR=$(mktemp -d)
DEPLOY_DIR="/Users/pascal/Development/deploydir"
#trap 'rm -rf "$DEPLOY_DIR"' EXIT

# Backend-Code
cp "$ROOT_DIR/app/backend/app.py"            "$DEPLOY_DIR/"
cp "$ROOT_DIR/app/backend/rtmt.py"           "$DEPLOY_DIR/"
cp "$ROOT_DIR/app/backend/__init__.py"       "$DEPLOY_DIR/"
cp "$ROOT_DIR/app/backend/requirements.txt"  "$DEPLOY_DIR/"

# Gebautes Frontend (statische Dateien)
cp -r "$ROOT_DIR/app/backend/static" "$DEPLOY_DIR/static"

# Python-Deps lokal in das Paket installieren
echo "📦 Installiere Python-Abhängigkeiten ins Paket..."
pip3 install \
  --target "$DEPLOY_DIR/.python_packages/lib/site-packages" \
  -r "$ROOT_DIR/app/backend/requirements.txt" \
  --quiet --disable-pip-version-check

# Startup-Skript
cat > "$DEPLOY_DIR/startup.sh" << 'EOF'
#!/bin/bash
# Falls Deps in .python_packages liegen, dem Python-Pfad hinzufügen
export PYTHONPATH="/home/site/wwwroot/.python_packages/lib/site-packages:$PYTHONPATH"

python -m gunicorn app:create_app \
  --bind 0.0.0.0:8000 \
  --worker-class aiohttp.GunicornWebWorker \
  --timeout 600 \
  --workers 1
EOF
chmod +x "$DEPLOY_DIR/startup.sh"

echo "✅ Deploy-Paket bereit"

# ── 3. Resource Group erstellen ──
echo ""
echo "☁️  Erstelle/prüfe Resource Group..."
echo "   az group create --name \"$RESOURCE_GROUP\" --location \"$LOCATION\" --output none"

# ── 4. App Service Plan + Web App ──
echo "☁️  Erstelle App Service Plan + Web App..."
PLAN_NAME="${APP_NAME}-plan"

# az appservice plan create \
#   --name "$PLAN_NAME" \
#   --resource-group "$RESOURCE_GROUP" \
#   --sku B1 \
#   --is-linux \
#   --output none 2>/dev/null || true

# az webapp create \
#   --name "$APP_NAME" \
#   --resource-group "$RESOURCE_GROUP" \
#   --plan "$PLAN_NAME" \
#   --runtime "PYTHON:3.12" \
#   --output none 2>/dev/null || true

# ── 5. Konfiguration ──
echo "⚙️  Konfiguriere Web App..."
echo "az webapp config set  --name "$APP_NAME"  --resource-group "$RESOURCE_GROUP"  --web-sockets-enabled true  --startup-file "startup.sh"  --output none"

# SCM_DO_BUILD_DURING_DEPLOYMENT=false → kein Oryx Build, ZIP wird 1:1 entpackt
echo "az webapp config appsettings set -name "$APP_NAME"  --resource-group "$RESOURCE_GROUP"   --settings WEBSITES_PORT=8000  SCM_DO_BUILD_DURING_DEPLOYMENT=false    ENABLE_ORYX_BUILD=false  RUNNING_IN_PRODUCTION=true --output none"


# ── 6. Credentials aus .env setzen ──
echo ""
echo "⚙️  Setze OpenAI Credentials..."
if [ -f "$ROOT_DIR/app/backend/.env" ]; then
#   while IFS='=' read -r key value; do
#     [[ "$key" =~ ^#.*$ ]] && continue
#     [[ -z "$key" ]] && continue
#     key=$(echo "$key" | xargs)
#     value=$(echo "$value" | xargs)
#     [ -n "$key" ] && [ -n "$value" ] && \
#     #   az webapp config appsettings set \
#     #     --name "$APP_NAME" \
#     #     --resource-group "$RESOURCE_GROUP" \
#     #     --settings "${key}=${value}" \
#     #     --output none
#   done < "$ROOT_DIR/app/backend/.env"
  echo "✅ Credentials gesetzt"
else
  echo "⚠️  Keine .env gefunden – setze Credentials manuell:"
  echo "   az webapp config appsettings set -n $APP_NAME -g $RESOURCE_GROUP \\"
  echo "     --settings AZURE_OPENAI_ENDPOINT=... AZURE_OPENAI_API_KEY=..."
fi

# ── 7. ZIP Deploy (kein Remote Build) ──
echo ""
echo "$ROOT_DIR/../../"
echo "🚀 Lade fertiges Paket hoch (ZIP Deploy)..."
cd "$DEPLOY_DIR"
zip -r -q deploy.zip . -x '*.pyc' '__pycache__/*'

ZIP_SIZE=$(du -sh deploy.zip | cut -f1)
echo "   ZIP-Größe: $ZIP_SIZE"

echo "az webapp deploy --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --src-path deploy.zip  --type zip --async true"


echo ""
echo "============================================"
echo "  ✅ Deployment abgeschlossen!"
echo ""
echo "  URL: https://${APP_NAME}.azurewebsites.net"
echo ""
echo "  ⏳ Die App braucht ca. 30-60 Sek. zum Starten."
echo ""
echo "  Logs anschauen:"
echo "    az webapp log tail -n $APP_NAME -g $RESOURCE_GROUP"
echo ""
echo "  Neu deployen (nur Upload, ohne Infra-Setup):"
echo "    az webapp deploy -n $APP_NAME -g $RESOURCE_GROUP \\"
echo "      --src-path deploy.zip --type zip"
echo "============================================"
