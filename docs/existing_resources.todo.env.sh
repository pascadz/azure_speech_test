#!/usr/bin/env bash
# ============================================================
# TODO: Replace all placeholder values below with your actual values,
#       then run each `azd env set ...` command.
#
# This configures the project for DIRECT VOICE CHAT (no RAG/Search).
# Only Azure OpenAI GPT-4o Realtime is needed.
# ============================================================

# ---------- OpenAI Realtime (existing) ----------
azd env set AZURE_OPENAI_REUSE_EXISTING true
azd env set AZURE_OPENAI_RESOURCE_GROUP "TODO_OPENAI_RESOURCE_GROUP"
azd env set AZURE_OPENAI_ENDPOINT "https://TODO_OPENAI_RESOURCE_NAME.openai.azure.com"
azd env set AZURE_OPENAI_REALTIME_DEPLOYMENT "TODO_GPT4O_REALTIME_DEPLOYMENT_NAME"
azd env set AZURE_OPENAI_REALTIME_VOICE_CHOICE "alloy"
# Optional: nur setzen, wenn du Key-Auth statt Entra ID nutzen willst
# azd env set AZURE_OPENAI_API_KEY "TODO_OPTIONAL_OPENAI_API_KEY"

# ---------- Optional: Tenant für lokale Dev-Anmeldung ----------
# azd env set AZURE_TENANT_ID "TODO_OPTIONAL_TENANT_ID"
