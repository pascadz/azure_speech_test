// ── Azure App Service (Web App) – Alternative zu Container Apps ──
// Deploy: az deployment group create -g <rg> -f infra/webapp.bicep -p openAiEndpoint=... openAiApiKey=...
targetScope = 'resourceGroup'

@description('Name der Web App (muss global eindeutig sein)')
param webAppName string

@description('Location')
param location string = resourceGroup().location

@description('App Service Plan SKU')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v3', 'P2v3', 'P3v3'])
param sku string = 'B1'

// ── OpenAI Settings ──
@description('Azure OpenAI Endpoint URL')
param openAiEndpoint string

@description('Deployment-Name für GPT-4o Realtime')
param openAiRealtimeDeployment string = 'gpt-4o-realtime-preview'

@description('Voice choice')
param openAiRealtimeVoiceChoice string = 'alloy'

@secure()
@description('Azure OpenAI API Key')
param openAiApiKey string

// ── App Service Plan ──
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${webAppName}-plan'
  location: location
  kind: 'linux'
  sku: {
    name: sku
  }
  properties: {
    reserved: true // Linux
  }
}

// ── Web App ──
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'
      webSocketsEnabled: true
      alwaysOn: true
      appCommandLine: 'python -m gunicorn app:create_app --bind 0.0.0.0:8000 --worker-class aiohttp.GunicornWebWorker --timeout 600 --workers 1'
      appSettings: [
        { name: 'WEBSITES_PORT', value: '8000' }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'true' }
        { name: 'RUNNING_IN_PRODUCTION', value: 'true' }
        { name: 'AZURE_OPENAI_ENDPOINT', value: openAiEndpoint }
        { name: 'AZURE_OPENAI_REALTIME_DEPLOYMENT', value: openAiRealtimeDeployment }
        { name: 'AZURE_OPENAI_REALTIME_VOICE_CHOICE', value: openAiRealtimeVoiceChoice }
        { name: 'AZURE_OPENAI_API_KEY', value: openAiApiKey }
      ]
    }
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output webAppName string = webApp.name
