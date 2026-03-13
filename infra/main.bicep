targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param backendServiceName string = ''
param resourceGroupName string = ''
param logAnalyticsName string = ''

// --- OpenAI (existing) ---
param reuseExistingOpenAi bool = true
param openAiServiceName string = ''
param openAiResourceGroupName string = ''
param openAiEndpoint string = ''
param openAiRealtimeDeployment string = ''
param openAiRealtimeVoiceChoice string = ''

@secure()
@description('Optional: Azure OpenAI API Key. When set, API key auth is used instead of Managed Identity (no role assignments needed for OpenAI).')
param openAiApiKey string = ''

@description('Location for the OpenAI resource group (only used when reuseExistingOpenAi=false)')
@allowed([
  'eastus2'
  'swedencentral'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param openAiServiceLocation string = 'eastus2'

param realtimeDeploymentCapacity int = 1
param realtimeDeploymentVersion string = '2024-12-17'

param tenantId string = tenant().tenantId

@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

@description('Whether the deployment is running on GitHub Actions')
param runningOnGh string = ''

@description('Whether the deployment is running on Azure DevOps Pipeline')
param runningOnAdo string = ''

@description('Used by azd for containerapps deployment')
param webAppExists bool = false

@description('Skip role assignments if you lack Owner/User Access Administrator rights. You must then assign roles manually.')
param skipRoleAssignments bool = false

@allowed(['Consumption', 'D4', 'D8', 'D16', 'D32', 'E4', 'E8', 'E16', 'E32', 'NC24-A100', 'NC48-A100', 'NC96-A100'])
param azureContainerAppsWorkloadProfile string

param acaIdentityName string = '${environmentName}-aca-identity'
param containerRegistryName string = '${replace(environmentName, '-', '')}acr'

// Figure out if we're running as a user or service principal
var principalType = empty(runningOnGh) && empty(runningOnAdo) ? 'User' : 'ServicePrincipal'

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Reference the resource group that holds (or will hold) the OpenAI resource.
// Uses a separate RG when specified, otherwise falls back to the main resource group.
resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: !empty(openAiResourceGroupName) ? openAiResourceGroupName : resourceGroup.name
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  name: 'loganalytics'
  scope: resourceGroup
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    useResourcePermissions: true
  }
}

// Azure container apps resources

// User-assigned identity for pulling images from ACR
module acaIdentity 'core/security/aca-identity.bicep' = {
  name: 'aca-identity'
  scope: resourceGroup
  params: {
    identityName: acaIdentityName
    location: location
  }
}

module containerApps 'core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'app'
    tags: tags
    location: location
    workloadProfile: azureContainerAppsWorkloadProfile
    containerAppsEnvironmentName: '${environmentName}-aca-env'
    containerRegistryName: '${containerRegistryName}${resourceToken}'
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
  }
}

// Container Apps for the web application (Python app with JS frontend)
module acaBackend 'core/host/container-app-upsert.bicep' = {
  name: 'aca-web'
  scope: resourceGroup
  dependsOn: [
    containerApps
    acaIdentity
  ]
  params: {
    name: !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesContainerApps}backend-${resourceToken}'
    location: location
    identityName: acaIdentityName
    exists: webAppExists
    workloadProfile: azureContainerAppsWorkloadProfile
    containerRegistryName: containerApps.outputs.registryName
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    identityType: 'UserAssigned'
    tags: union(tags, { 'azd-service-name': 'backend' })
    targetPort: 8000
    containerCpuCoreCount: '1.0'
    containerMemory: '2Gi'
    env: {
      AZURE_OPENAI_ENDPOINT: reuseExistingOpenAi ? openAiEndpoint : openAi.outputs.endpoint
      AZURE_OPENAI_REALTIME_DEPLOYMENT: reuseExistingOpenAi ? openAiRealtimeDeployment : openAiDeployments[0].name
      AZURE_OPENAI_REALTIME_VOICE_CHOICE: openAiRealtimeVoiceChoice
      AZURE_OPENAI_API_KEY: openAiApiKey
      // CORS support, for frontends on other hosts
      RUNNING_IN_PRODUCTION: 'true'
      // For using managed identity to access Azure resources
      AZURE_CLIENT_ID: acaIdentity.outputs.clientId
    }
    skipRoleAssignments: skipRoleAssignments
  }
}

var openAiDeployments = [
  {
    name: 'gpt-4o-realtime-preview'
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-realtime-preview'
      version: realtimeDeploymentVersion
    }
    sku: {
      name: 'GlobalStandard'
      capacity: realtimeDeploymentCapacity
    }
  }
]

module openAi 'br/public:avm/res/cognitive-services/account:0.8.0' = if (!reuseExistingOpenAi) {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiServiceLocation
    tags: tags
    kind: 'OpenAI'
    customSubDomainName: !empty(openAiServiceName)
      ? openAiServiceName
      : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    sku: 'S0'
    deployments: openAiDeployments
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {}
    roleAssignments: skipRoleAssignments ? [] : [
      {
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
        principalId: principalId
        principalType: principalType
      }
    ]
  }
}

// Role for the backend managed identity to access OpenAI (Cognitive Services OpenAI User).
// Skipped when an API key is provided or when skipRoleAssignments=true.
module openAiRoleBackend 'core/security/role.bicep' = if (!skipRoleAssignments && empty(openAiApiKey)) {
  scope: openAiResourceGroup
  name: 'openai-role-backend'
  params: {
    principalId: acaBackend.outputs.identityPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenantId
output AZURE_RESOURCE_GROUP string = resourceGroup.name

output AZURE_OPENAI_ENDPOINT string = reuseExistingOpenAi ? openAiEndpoint : openAi.outputs.endpoint
output AZURE_OPENAI_REALTIME_DEPLOYMENT string = reuseExistingOpenAi
  ? openAiRealtimeDeployment
  : openAiDeployments[0].name
output AZURE_OPENAI_REALTIME_VOICE_CHOICE string = openAiRealtimeVoiceChoice

output BACKEND_URI string = acaBackend.outputs.uri
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
