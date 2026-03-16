# Projekt-Verlauf: Voice Chat mit RAG

Dieses Dokument beschreibt den gesamten Entwicklungsverlauf des Projekts – von der ursprünglichen VoiceRAG-Vorlage bis zum aktuellen Stand.

---

## Inhaltsverzeichnis

1. [Ausgangslage](#1-ausgangslage)
2. [Phase 1: Vereinfachung auf bestehende Ressourcen](#2-phase-1-vereinfachung-auf-bestehende-ressourcen)
3. [Phase 2: RAG entfernt – Pure Voice Chat](#3-phase-2-rag-entfernt--pure-voice-chat)
4. [Phase 3: Idempotentes Deployment (Bicep-Fixes)](#4-phase-3-idempotentes-deployment-bicep-fixes)
5. [Phase 4: API-Key-Authentifizierung](#5-phase-4-api-key-authentifizierung)
6. [Phase 5: Lokale Entwicklung ohne Azure](#6-phase-5-lokale-entwicklung-ohne-azure)
7. [Phase 6: App Service Deployment (Web App)](#7-phase-6-app-service-deployment-web-app)
8. [Phase 7: Remote Build – Oryx vs. Docker](#8-phase-7-remote-build--oryx-vs-docker)
9. [Phase 8: Multi-Stage Dockerfile für Container Apps](#9-phase-8-multi-stage-dockerfile-für-container-apps)
10. [Phase 9: Chat-Verlauf mit Transkription](#10-phase-9-chat-verlauf-mit-transkription)
11. [Phase 10: RAG wieder aktiviert](#11-phase-10-rag-wieder-aktiviert)
12. [Aktueller Stand](#12-aktueller-stand)

---

## 1. Ausgangslage

**Quelle:** [Azure-Samples/aisearch-openai-rag-audio](https://github.com/Azure-Samples/aisearch-openai-rag-audio)

Das Original-Repository ist eine Vorlage für „VoiceRAG" – eine Anwendung, die:

- Azure AI Search für RAG (Retrieval Augmented Generation) nutzt
- GPT-4o Realtime API für Sprach-Ein-/Ausgabe verwendet
- Über `azd up` eine komplette Infrastruktur provisioniert (OpenAI, AI Search, Container Apps, etc.)

**Problem:** Das Template ging davon aus, dass alle Ressourcen neu erstellt werden. Wir wollten es mit **bestehenden** Azure-Ressourcen nutzen.

---

## 2. Phase 1: Vereinfachung auf bestehende Ressourcen

### Ziel

Das Projekt so anpassen, dass es vorhandene Azure OpenAI- und Search-Instanzen nutzt, statt neue zu provisionieren.

### Änderungen

- `docs/existing_resources.todo.env.sh` erstellt – Platzhalter für bestehende Ressourcen
- Env-Skripte (`write_env.sh`, `write_env.ps1`) angepasst
- `azure.yaml` – `setup_intvect` aus den Hooks entfernt (kein neuer Search-Index nötig)

---

## 3. Phase 2: RAG entfernt – Pure Voice Chat

### Ziel

Alle RAG/Search-Funktionalität entfernen → reiner Voice Chat (Sprache → GPT-4o → Sprache).

### Geänderte Dateien

| Datei                                    | Änderung                                                   |
| ---------------------------------------- | ---------------------------------------------------------- |
| `app/backend/app.py`                     | `ragtools`-Import entfernt, System Message vereinfacht     |
| `app/backend/requirements.txt`           | `azure-search-documents` entfernt                          |
| `app/frontend/src/App.tsx`               | GroundingFiles-UI, Citations entfernt                      |
| `app/frontend/src/types.ts`              | RAG-spezifische Types entfernt                             |
| `app/frontend/src/hooks/useRealtime.tsx` | `ExtensionMiddleTierToolResponse`-Handler entfernt         |
| `infra/main.bicep`                       | AI Search-Ressourcen entfernt, nur OpenAI + Container Apps |
| `infra/main.parameters.json`             | Search-Parameter entfernt                                  |

### Ergebnis

Minimale Voice-Chat-App: Mikrofon → GPT-4o Realtime → Lautsprecher.

---

## 4. Phase 3: Idempotentes Deployment (Bicep-Fixes)

### Problem

Erneutes `azd up` schlug fehl – Bicep-Ressourcen waren nicht idempotent.

### Fixes

| Problem                                              | Lösung                                                           |
| ---------------------------------------------------- | ---------------------------------------------------------------- |
| `SERVICE_WEB_RESOURCE_EXISTS` falsch benannt         | → `SERVICE_BACKEND_RESOURCE_EXISTS`                              |
| `openAiResourceGroup`-Referenz ungültig bei neuem RG | → Fallback auf Haupt-RG                                          |
| Role-Assignments nicht deterministic                 | → `guid(subscription, rg, principalId, roleId)`                  |
| API-Versionen veraltet (`2023-05-02-preview`)        | → `2024-03-01` (Container Apps), `2023-11-01-preview` (Registry) |

---

## 5. Phase 4: API-Key-Authentifizierung

### Ziel

Alternativ zu Managed Identity auch API-Key-Authentifizierung unterstützen, um Role-Assignment-Probleme zu vermeiden.

### Änderungen

| Datei                                        | Änderung                                                       |
| -------------------------------------------- | -------------------------------------------------------------- |
| `infra/main.bicep`                           | `openAiApiKey` (secure param), `skipRoleAssignments` Parameter |
| `infra/main.parameters.json`                 | Mapping: `AZURE_OPENAI_API_KEY`, `AZURE_SKIP_ROLE_ASSIGNMENTS` |
| `infra/core/host/container-app.bicep`        | `skipRoleAssignments` durchgereicht                            |
| `infra/core/host/container-app-upsert.bicep` | `skipRoleAssignments` durchgereicht                            |

### Backend

`app.py` unterstützte bereits beide Varianten:

```python
llm_credential = AzureKeyCredential(llm_key) if llm_key else credential
```

---

## 6. Phase 5: Lokale Entwicklung ohne Azure

### Neue Dateien

| Datei                      | Zweck                                       |
| -------------------------- | ------------------------------------------- |
| `scripts/start_local.sh`   | Startet Backend + Frontend-Dev-Server lokal |
| `app/backend/.env.example` | Vorlage für lokale Konfiguration            |

### Ablauf von `start_local.sh`

1. Erstellt Python venv, installiert Deps
2. Prüft ob `.env` vorhanden ist
3. Startet Backend auf `localhost:8765`
4. Startet Vite Dev Server auf `localhost:5173` (Proxy → Backend)
5. Trap für Cleanup bei Ctrl+C

---

## 7. Phase 6: App Service Deployment (Web App)

### Ziel

Alternative zu Container Apps: Deployment auf Azure App Service (einfacher, günstiger).

### Neue Dateien

| Datei                      | Zweck                                         |
| -------------------------- | --------------------------------------------- |
| `scripts/deploy_webapp.sh` | Build lokal, ZIP-Push nach Azure              |
| `infra/webapp.bicep`       | Bicep-Template für App Service Plan + Web App |

### Ablauf von `deploy_webapp.sh`

1. Prüft Voraussetzungen (az, node, npm, python3)
2. Baut Frontend lokal (`npm install` + `vite build`)
3. Erstellt Deploy-Paket (Backend + gebautes Frontend + Python-Deps)
4. Erstellt Resource Group, App Service Plan (B1 Linux), Web App (Python 3.12)
5. Konfiguriert WebSockets, startup.sh, deaktiviert Oryx
6. Setzt Credentials aus `.env`
7. ZIP Deploy (kein Remote-Build)

### Wichtige App Service Settings

```
SCM_DO_BUILD_DURING_DEPLOYMENT=false
ENABLE_ORYX_BUILD=false
WEBSITES_PORT=8000
```

---

## 8. Phase 7: Remote Build – Oryx vs. Docker

### Problem

Wunsch: Alle Builds sollen in Azure laufen, nicht lokal.

### Oryx-Limitation

Azure App Service nutzt Oryx als Build-Engine. Oryx kann nur **eine Sprache** pro Deployment:

- Python-Runtime → `pip install` ✅, aber kein `npm` ❌
- Node.js-Runtime → `npm install` ✅, aber kein `pip` ❌
- Custom `build.sh` → `apt-get install nodejs` wird von der Kudu-Sandbox blockiert ❌

### Lösung: Docker-basiertes Deployment

Multi-Stage Dockerfile löst das Problem → siehe Phase 8.

---

## 9. Phase 8: Multi-Stage Dockerfile für Container Apps

### Ziel

Alles in Azure bauen via `az containerapp up --source .`

### Neues Dockerfile (`app/Dockerfile`)

```dockerfile
# Stage 1: Frontend (Node.js + Vite)
FROM node:20-slim AS frontend-build
WORKDIR /build/frontend
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npx vite build
# → Output: /build/backend/static/

# Stage 2: Produktion (Python)
FROM python:3.12-slim
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ .
COPY --from=frontend-build /build/backend/static ./static
EXPOSE 8000
CMD ["python", "-m", "gunicorn", "app:create_app", ...]
```

### Fix gegenüber Original

- `COPY --from=build-stage /backend/static` → Pfad war falsch
- Korrigiert zu: `COPY --from=frontend-build /build/backend/static ./static`
- Grund: Vite Output-Dir `../backend/static` relativ zu `frontend/` → im Container `/build/backend/static`

### Deployment

```bash
cd app/
az containerapp up --name <app> --resource-group <rg> --source .
```

→ ACR baut das Image in Azure, kein lokaler Docker/Node/Python nötig.

### `.dockerignore`

```
**/node_modules
**/static
**/__pycache__
**/*.pyc
**/.env
```

---

## 10. Phase 9: Chat-Verlauf mit Transkription

### Ziel

Die Spracheingabe des Users als Text anzeigen + KI-Antwort als Text streamen.

### Änderungen

**`App.tsx`:**

- `enableInputAudioTranscription: true` aktiviert Whisper-Transkription
- `chatHistory` State – Array von `{ role, text, final }` Einträgen
- `onReceivedInputAudioTranscriptionCompleted` → User-Sprache als Text (rechts, lila)
- `onReceivedResponseAudioTranscriptDelta` → KI-Antwort live gestreamt (links, grau)
- `onReceivedResponseDone` → markiert Antwort als fertig
- Mülleimer-Button zum Löschen
- Auto-Scroll zum neuesten Eintrag

**Übersetzungsdateien (i18n):**

- `history.clear` Key in allen 4 Sprachen ergänzt (en, es, fr, ja)

### UI-Layout

```
┌──────────────────────────────────────┐
│  Conversation                    🗑️  │
├──────────────────────────────────────┤
│         Wie wird das Wetter heute? ◼ │  ← User (transkribiert)
│ KI                                   │
│ Das Wetter wird heute sonnig...      │  ← KI (gestreamt)
│              Was ist die Hauptstadt   │
│                      von Frankreich? │
│ KI                                   │
│ Paris.▍                              │  ← Streaming-Cursor
└──────────────────────────────────────┘
              [ 🎤 Stop ]
```

---

## 11. Phase 10: RAG wieder aktiviert

### Ziel

Azure AI Search (Vektordatenbank) wieder anbinden – Antworten basieren auf Dokumenten.

### Änderungen

| Datei                          | Änderung                                                                           |
| ------------------------------ | ---------------------------------------------------------------------------------- |
| `app/backend/app.py`           | `from ragtools import attach_rag_tools`, RAG-Tools registriert, RAG-System-Message |
| `app/backend/requirements.txt` | `azure-search-documents==11.6.0b7` hinzugefügt                                     |
| `app/backend/.env.example`     | Search-Credentials (`AZURE_SEARCH_ENDPOINT`, `AZURE_SEARCH_INDEX`, etc.)           |
| `app/backend/ragtools.py`      | **Keine Änderung** – war bereits komplett vorhanden                                |

### RAG-Flow mit Realtime API

```
User spricht
    ↓
GPT-4o Realtime empfängt Audio
    ↓
GPT-4o entscheidet: "Ich brauche Infos"
    ↓
function_call → search(query="...")
    ↓
RTMiddleTier fängt ab → Azure AI Search (Hybrid: Text + Vektor)
    ↓ (~1-2 Sek.)
Suchergebnisse → function_call_output → zurück an GPT-4o
    ↓
GPT-4o antwortet MIT den RAG-Ergebnissen (Audio + Text)
    ↓
function_call → report_grounding(sources=["doc1", "doc2"])
    ↓
RTMiddleTier → Quellen an Client senden
```

### Zwei Tools in `ragtools.py`

1. **`search`** – Hybrid-Suche (Text + Vektor) gegen Azure AI Search
   - Ergebnis geht an GPT-4o (`ToolResultDirection.TO_SERVER`)
   - GPT-4o nutzt die Ergebnisse für seine Antwort

2. **`report_grounding`** – Zitiert verwendete Quellen
   - Ergebnis geht an den Client (`ToolResultDirection.TO_CLIENT`)
   - Könnte im Frontend als Quellenangabe angezeigt werden

### Konfigurierbare Suchfelder

```env
AZURE_SEARCH_IDENTIFIER_FIELD=chunk_id    # ID-Feld im Index
AZURE_SEARCH_CONTENT_FIELD=chunk           # Textinhalt
AZURE_SEARCH_EMBEDDING_FIELD=text_vector   # Vektor-Feld
AZURE_SEARCH_TITLE_FIELD=title             # Titel/Dateiname
AZURE_SEARCH_USE_VECTOR_QUERY=true         # Vektor-Suche an/aus
AZURE_SEARCH_SEMANTIC_CONFIGURATION=...    # Optional: Semantic Ranker
```

---

## 12. Aktueller Stand

### Architektur

```
┌─────────────────────────────────────────────────────────┐
│                      Browser (React)                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │ Mikrofon  │  │ AudioOut │  │ Chat-Verlauf (Text)  │  │
│  └─────┬─────┘  └─────▲────┘  └──────────▲───────────┘  │
│        │              │                   │              │
│        └──────┬───────┴───────────────────┘              │
│               │  WebSocket (/realtime)                   │
└───────────────┼──────────────────────────────────────────┘
                │
┌───────────────┼──────────────────────────────────────────┐
│  RTMiddleTier │ (Python Backend – aiohttp)               │
│               │                                          │
│    ┌──────────▼──────────┐     ┌──────────────────────┐  │
│    │  WebSocket Proxy    │────▶│  Azure OpenAI        │  │
│    │  (rtmt.py)          │◀────│  GPT-4o Realtime API │  │
│    └──────────┬──────────┘     └──────────────────────┘  │
│               │                                          │
│    ┌──────────▼──────────┐     ┌──────────────────────┐  │
│    │  Tool: search       │────▶│  Azure AI Search     │  │
│    │  (ragtools.py)      │◀────│  (Vektordatenbank)   │  │
│    └─────────────────────┘     └──────────────────────┘  │
│                                                          │
│    ┌─────────────────────┐                               │
│    │  Tool: grounding    │──▶ Quellen ans Frontend       │
│    └─────────────────────┘                               │
└──────────────────────────────────────────────────────────┘
```

### Dateistruktur

```
app/
├── Dockerfile              # Multi-Stage: Node + Python
├── .dockerignore
├── backend/
│   ├── app.py              # Hauptanwendung (aiohttp)
│   ├── rtmt.py             # RTMiddleTier (WebSocket Proxy + Tool-Handling)
│   ├── ragtools.py         # Azure AI Search Tools (search + grounding)
│   ├── requirements.txt    # Python-Deps
│   ├── .env.example        # Vorlage für Konfiguration
│   └── __init__.py
├── frontend/
│   ├── src/
│   │   ├── App.tsx         # Hauptkomponente (Chat-Verlauf + Mikrofon)
│   │   ├── types.ts        # TypeScript-Types
│   │   └── hooks/
│   │       ├── useRealtime.tsx   # WebSocket-Hook
│   │       ├── useAudioRecorder.tsx
│   │       └── useAudioPlayer.tsx
│   ├── vite.config.ts      # Build → ../backend/static/
│   └── package.json
scripts/
├── start_local.sh          # Lokaler Start (Backend + Vite Dev Server)
├── deploy_webapp.sh        # Deploy auf App Service (lokaler Build + ZIP)
infra/
├── main.bicep              # Container Apps Infrastruktur
├── main.parameters.json
├── webapp.bicep             # App Service Alternative
```

### Deployment-Optionen

| Methode                     | Befehl                                     | Build-Ort   |
| --------------------------- | ------------------------------------------ | ----------- |
| **Container Apps (Docker)** | `cd app/ && az containerapp up --source .` | Azure (ACR) |
| **App Service (ZIP)**       | `./scripts/deploy_webapp.sh <rg> <app>`    | Lokal       |
| **Lokal**                   | `./scripts/start_local.sh`                 | Lokal       |
| **Container Apps (azd)**    | `azd up`                                   | Azure (ACR) |

### Umgebungsvariablen

| Variable                              | Pflicht | Beschreibung                                     |
| ------------------------------------- | ------- | ------------------------------------------------ |
| `AZURE_OPENAI_ENDPOINT`               | ✅      | OpenAI Endpoint URL                              |
| `AZURE_OPENAI_REALTIME_DEPLOYMENT`    | ✅      | Deployment-Name (z.B. `gpt-4o-realtime-preview`) |
| `AZURE_OPENAI_API_KEY`                | ✅\*    | API Key (Alternative zu Managed Identity)        |
| `AZURE_OPENAI_REALTIME_VOICE_CHOICE`  | ❌      | Stimme (Default: `alloy`)                        |
| `AZURE_SEARCH_ENDPOINT`               | ✅      | AI Search Endpoint URL                           |
| `AZURE_SEARCH_INDEX`                  | ✅      | Search Index Name                                |
| `AZURE_SEARCH_API_KEY`                | ✅\*    | Search API Key                                   |
| `AZURE_SEARCH_SEMANTIC_CONFIGURATION` | ❌      | Semantic Ranker Config                           |
| `AZURE_SEARCH_IDENTIFIER_FIELD`       | ❌      | Default: `chunk_id`                              |
| `AZURE_SEARCH_CONTENT_FIELD`          | ❌      | Default: `chunk`                                 |
| `AZURE_SEARCH_EMBEDDING_FIELD`        | ❌      | Default: `text_vector`                           |
| `AZURE_SEARCH_TITLE_FIELD`            | ❌      | Default: `title`                                 |
| `AZURE_SEARCH_USE_VECTOR_QUERY`       | ❌      | Default: `true`                                  |
| `AZURE_TENANT_ID`                     | ❌      | Für Managed Identity                             |
| `RUNNING_IN_PRODUCTION`               | ❌      | Gesetzt in Azure, lädt keine `.env`              |

\* API-Keys oder Managed Identity – mindestens eins muss konfiguriert sein.

---

_Dokumentation erstellt am 16. März 2026_
