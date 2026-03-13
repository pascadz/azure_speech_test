# ══════════════════════════════════════════════════════════════
#  Multi-Stage Dockerfile: Frontend (Node) + Backend (Python)
#  
#  Nutzung mit Azure Container Apps:
#    cd app/
#    az containerapp up --name <app> --resource-group <rg> --source .
#
#  Der gesamte Build läuft in Azure (ACR) – lokal wird nichts gebaut.
# ══════════════════════════════════════════════════════════════

# ── Stage 1: Frontend bauen (Node.js + Vite) ──
FROM node:20-slim AS frontend-build

WORKDIR /build/frontend
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --no-audit --no-fund

# Restliche Frontend-Dateien kopieren & bauen
COPY frontend/ ./
# vite.config.ts: outDir = "../backend/static"  →  /build/backend/static/
RUN npx vite build

# ── Stage 2: Produktion (Python) ──
FROM python:3.12-slim

WORKDIR /app

# Python-Deps zuerst (Layer-Caching)
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Backend-Code kopieren
COPY backend/ .

# Gebautes Frontend aus Stage 1 kopieren
COPY --from=frontend-build /build/backend/static ./static

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["python", "-m", "gunicorn", "app:create_app", \
    "--bind", "0.0.0.0:8000", \
    "--worker-class", "aiohttp.GunicornWebWorker", \
    "--timeout", "600", \
    "--workers", "1"]
