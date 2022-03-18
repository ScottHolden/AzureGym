param uniqueName string
param location string
param publisherEmail string = 'no-reply@microsoft.com'
param subnetId string

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: uniqueName
  location: location
  sku: {
    capacity: 1
    name: 'Developer'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: uniqueName
    publicIpAddressId: apimPIP.id
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }
  }
  resource appins 'loggers@2021-08-01' = {
    name: 'appins'
    properties: {
      loggerType: 'applicationInsights'
      credentials: {
        instrumentationKey: applicationInsights.properties.InstrumentationKey
      }
    }
  }
}

resource apimPIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${uniqueName}-apim'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: uniqueName
    }
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: uniqueName
  location: location
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: uniqueName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
  }
}

output apimName string = apim.name
