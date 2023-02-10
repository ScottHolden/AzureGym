param uniqueName string
param location string
param containerImage string
param acrUserManagedIdentityID string

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: uniqueName
  location: location
  sku: {
    name: 'B3'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webapp 'Microsoft.Web/sites@2022-03-01' = {
  name: uniqueName
  location: location
  properties: {
    siteConfig: {
      acrUseManagedIdentityCreds: !empty(acrUserManagedIdentityID)
      acrUserManagedIdentityID: acrUserManagedIdentityID
      alwaysOn: true
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
  identity: empty(acrUserManagedIdentityID) ? {} : {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${acrUserManagedIdentityID}': {}
    }
  }
}

output url string = 'https://${webapp.properties.defaultHostName}/'
