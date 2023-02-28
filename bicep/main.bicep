@description('Suffix for the resource')
param suffix string

@description('The name of the storage account for the function and document')
param storageName string

var location = resourceGroup().location

// Create the Azure storage needed for the function and document
resource storageAccountDocument 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'    
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource containerDocuments 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: '${storageAccountDocument.name}/default/documents'
  properties: {
    publicAccess: 'None'
  }
}

// End Azure storage

// Application insights

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'log-${suffix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: 'appinsights-${suffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// End Application insights

// Create the Azure function

resource serverFarm 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: 'asp-${suffix}'
  kind: 'linux'
  location: location
  sku: {
    tier: 'Dynamic'
    name: 'Y1'
  }
}

resource function 'Microsoft.Web/sites@2020-06-01' = {
  name: 'function-${suffix}'
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: serverFarm.id    
    siteConfig: {      
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountDocument.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccountDocument.id, storageAccountDocument.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountDocument.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccountDocument.id, storageAccountDocument.apiVersion).keys[0].value}'
        }      
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'processorapp092'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
      ]
      linuxFxVersion: 'PYTHON|3.8'
    }
  }
}

// End Azure function
