# Define the .env file path
$envFilePath = "app\backend\.env"

# Clear the contents of the .env file
Set-Content -Path $envFilePath -Value ""

# Append new values to the .env file
$azureOpenAiEndpoint = azd env get-value AZURE_OPENAI_ENDPOINT
$azureOpenAiRealtimeDeployment = azd env get-value AZURE_OPENAI_REALTIME_DEPLOYMENT
$azureOpenAiRealtimeVoiceChoice = azd env get-value AZURE_OPENAI_REALTIME_VOICE_CHOICE
$azureOpenAiApiKey = azd env get-value AZURE_OPENAI_API_KEY
$azureTenantId = azd env get-value AZURE_TENANT_ID

Add-Content -Path $envFilePath -Value "AZURE_OPENAI_ENDPOINT=$azureOpenAiEndpoint"
Add-Content -Path $envFilePath -Value "AZURE_OPENAI_REALTIME_DEPLOYMENT=$azureOpenAiRealtimeDeployment"
Add-Content -Path $envFilePath -Value "AZURE_OPENAI_REALTIME_VOICE_CHOICE=$azureOpenAiRealtimeVoiceChoice"
Add-Content -Path $envFilePath -Value "AZURE_OPENAI_API_KEY=$azureOpenAiApiKey"
Add-Content -Path $envFilePath -Value "AZURE_TENANT_ID=$azureTenantId"
