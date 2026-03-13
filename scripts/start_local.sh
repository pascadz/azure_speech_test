#!/bin/bash
set -e

# ── Lokal starten OHNE Container Apps / Docker / Azure ──
# Voraussetzungen: Python 3.11+, Node.js 18+
# 1) Kopiere app/backend/.env.example → app/backend/.env und trage deine Werte ein
# 2) Führe dieses Skript aus: ./scripts/start_local.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "============================================"
echo "  Voice Chat – Lokaler Start (ohne Azure)"
echo "============================================"
echo ""

# ── 1. Python venv ──
if [ ! -d "$ROOT_DIR/.venv" ]; then
  echo "🐍 Erstelle Python Virtual Environment..."
  python3 -m venv "$ROOT_DIR/.venv"
fi

echo "📦 Installiere Python-Abhängigkeiten..."
"$ROOT_DIR/.venv/bin/python" -m pip --quiet --disable-pip-version-check install -r "$ROOT_DIR/app/backend/requirements.txt"

# ── 2. Frontend bauen (nur wenn nötig) ──
if [ ! -d "$ROOT_DIR/app/frontend/node_modules" ]; then
  echo "📦 Installiere Frontend npm-Pakete..."
  cd "$ROOT_DIR/app/frontend"
  npm install
fi

# ── 3. .env prüfen ──
if [ ! -f "$ROOT_DIR/app/backend/.env" ]; then
  echo ""
  echo "⚠️  Keine .env Datei gefunden!"
  echo "   Kopiere app/backend/.env.example → app/backend/.env"
  echo "   und trage deine Azure OpenAI Werte ein."
  echo ""
  exit 1
fi

# ── 4. Backend starten (Hintergrund) ──
echo ""
echo "🚀 Starte Backend auf http://localhost:8765 ..."
cd "$ROOT_DIR"
"$ROOT_DIR/.venv/bin/python" app/backend/app.py &
BACKEND_PID=$!

# Aufräumen bei Ctrl+C
cleanup() {
  echo ""
  echo "🛑 Beende Backend (PID $BACKEND_PID)..."
  kill $BACKEND_PID 2>/dev/null
  exit 0
}
trap cleanup INT TERM

# Kurz warten bis Backend bereit
sleep 2

# ── 5. Frontend Dev-Server starten ──
echo "🌐 Starte Frontend auf http://localhost:5173 ..."
echo ""
echo "  → Öffne http://localhost:5173 im Browser"
echo "  → Ctrl+C zum Beenden"
echo ""
cd "$ROOT_DIR/app/frontend"
npm run dev

# Falls Frontend beendet wird, auch Backend stoppen
cleanup
