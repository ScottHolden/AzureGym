@description('The location all resources will be deployed to')
param location string = resourceGroup().location

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'funcdns'

var uniqueNameFormat = '${prefix}-{0}-${uniqueString(resourceGroup().id, prefix)}'
var uniqueShortName = toLower('${prefix}${uniqueString(resourceGroup().id, prefix)}')

resource functionAppPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: format(uniqueNameFormat, 'asp')
  location: location
  sku: {
    tier: 'ElasticPremium'
    name: 'EP1'
    size: 'EP1'
    family: 'EP'
  }
  kind: 'elastic'
  properties: {
    maximumElasticWorkerCount: 20
    reserved: true
  }
}

resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: uniqueShortName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
  }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: uniqueShortName
  location: location
  kind: 'functionapp,linux'
  properties: {
    reserved: true
    serverFarmId: functionAppPlan.id
#disable-next-line BCP037
    dnsConfiguration: {
      dnsMaxCacheTimeout: 30
    }
    siteConfig: {
      
      vnetRouteAllEnabled: false
      linuxFxVersion: 'Node|18'
      appSettings: [
        /*{
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsight.properties.InstrumentationKey
        }*/
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};AccountKey=${functionStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};AccountKey=${functionStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: uniqueShortName
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~14'
        }
        {
          name: 'WEBSITE_ENABLE_DNS_CACHE'
          value: 'true'
        }
      ]
    }
  }
}
