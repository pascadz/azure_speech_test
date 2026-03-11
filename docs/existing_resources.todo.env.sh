#!/usr/bin/env bash
# TODO: Replace all placeholder values below, then run each `azd env set ...` command.
# Ziel: `azd up` nutzt bestehende OpenAI/Search-Ressourcen und legt diese nicht neu an.

# ---------- OpenAI Realtime (bestehend) ----------
azd env set AZURE_OPENAI_REUSE_EXISTING true
azd env set AZURE_OPENAI_RESOURCE_GROUP "TODO_OPENAI_RESOURCE_GROUP"
azd env set AZURE_OPENAI_ENDPOINT "https://TODO_OPENAI_RESOURCE_NAME.openai.azure.com"
azd env set AZURE_OPENAI_REALTIME_DEPLOYMENT "TODO_GPT4O_REALTIME_DEPLOYMENT_NAME"
azd env set AZURE_OPENAI_REALTIME_VOICE_CHOICE "TODO_VOICE_CHOICE_echo_alloy_shimmer"
# Optional: nur setzen, wenn du Key-Auth statt Entra ID nutzen willst
azd env set AZURE_OPENAI_API_KEY "TODO_OPTIONAL_OPENAI_API_KEY"

# ---------- Azure AI Search (bestehend) ----------
azd env set AZURE_SEARCH_REUSE_EXISTING true
azd env set AZURE_SEARCH_SERVICE_RESOURCE_GROUP "TODO_SEARCH_RESOURCE_GROUP"
azd env set AZURE_SEARCH_ENDPOINT "https://TODO_SEARCH_SERVICE.search.windows.net"
azd env set AZURE_SEARCH_INDEX "TODO_SEARCH_INDEX_NAME"
azd env set AZURE_SEARCH_SEMANTIC_CONFIGURATION "TODO_SEMANTIC_CONFIG_OR_default"
azd env set AZURE_SEARCH_IDENTIFIER_FIELD "TODO_IDENTIFIER_FIELD_OR_id"
azd env set AZURE_SEARCH_CONTENT_FIELD "TODO_CONTENT_FIELD_OR_content"
azd env set AZURE_SEARCH_TITLE_FIELD "TODO_TITLE_FIELD_OR_sourcepage"
azd env set AZURE_SEARCH_EMBEDDING_FIELD "TODO_EMBEDDING_FIELD_OR_embedding"
azd env set AZURE_SEARCH_USE_VECTOR_QUERY true
# Optional: nur setzen, wenn du Key-Auth statt Entra ID nutzen willst
azd env set AZURE_SEARCH_API_KEY "TODO_OPTIONAL_SEARCH_API_KEY"

# ---------- Optional: Tenant für lokale Dev-Anmeldung ----------
azd env set AZURE_TENANT_ID "TODO_OPTIONAL_TENANT_ID"

# ---------- Optional: separates GPT-4o Chat Deployment ----------
# Hinweis: Das aktuelle Backend nutzt aktiv AZURE_OPENAI_REALTIME_DEPLOYMENT.
# Falls du parallel ein Chat-Deployment dokumentieren möchtest, kannst du es hier als Custom-Variable setzen:
azd env set AZURE_OPENAI_CHAT_DEPLOYMENT "TODO_OPTIONAL_GPT4O_CHAT_DEPLOYMENT"
