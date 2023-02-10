@description('The location all resources will be deployed to')
param location string = resourceGroup().location

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'windup'

@description('The windup container image to use')
param containerImage string = 'eggboy/windup:6.1.2'

var uniqueName = '${toLower(prefix)}${uniqueString(prefix, resourceGroup().id)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: uniqueName
  location: location
  sku: {
    name: 'B2'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webapp 'Microsoft.Web/sites@2016-08-01' = {
  name: uniqueName
  location: location
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'true'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
      ]
      linuxFxVersion: 'DOCKER|${containerImage}'
    }
    serverFarmId: appServicePlan.id
  }
}

output windupUrl string = 'https://${webapp.properties.defaultHostName}/'
