@description('The location for all resources to be deployed')
param location string = 'AustraliaEast'

@description('The prefix to be used for all resource names, should only be alphanumeric')
param prefix string = 'Demo'

@description('The URL of the workflow Zip, used to provide a single-click deploy demo. Leave empty to skip workflow deployment')
param workflowZipUrl string = 'https://raw.githubusercontent.com/ScottHolden/AzureGym/main/LogicAppNat/workflow.zip'

var uniqueName = '${toLower(prefix)}${uniqueString(prefix, resourceGroup().id)}'
var subnetName = 'LogicApp'
var subnetCIDR = '10.250.250.0/24'

// App Service Plan for the Logic App Standard to be hosted on
resource ServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: uniqueName
  location: location
  properties: {
    maximumElasticWorkerCount: 20
    zoneRedundant: false
  }
  sku: {
    tier: 'WorkflowStandard'
    name: 'WS1'
  }
}

// Storage for the Logic App
resource Storage 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: uniqueName
  location: location
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Outbound Public IP for the Nat Gateway
resource PublicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: uniqueName
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}

// Nat Gateway
resource NatGateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: uniqueName
  location: location
  properties: {
    publicIpAddresses: [
      {
        id: PublicIP.id
      }
    ]
  }
  sku: {
    name: 'Standard'
  }
}

// Virtual Network for the Logic App with Nat Gateway attached
resource VNet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: uniqueName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        subnetCIDR
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetCIDR
          natGateway: {
            id: NatGateway.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

// Logic App Standard with VNet integration
resource LogicApp 'Microsoft.Web/sites@2021-02-01' = {
  name: uniqueName
  location: location
  kind: 'functionapp,workflowapp'
  properties: {
    serverFarmId: ServicePlan.id
    virtualNetworkSubnetId: VNet.properties.subnets[0].id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      vnetRouteAllEnabled: true
      use32BitWorkerProcess: false
      cors: {}
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
      }
      {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
      }
      {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~12'
      }
      {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${Storage.name};AccountKey=${Storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
      }
      {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${Storage.name};AccountKey=${Storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
      }
      {
          name: 'WEBSITE_CONTENTSHARE'
          value: uniqueName
      }
      {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
      }
      {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
      }
      {
          name: 'APP_KIND'
          value: 'workflowApp'
      }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  resource MSDeploy 'extensions@2021-02-01' = if (!empty(trim(workflowZipUrl))) {
    name: 'MSDeploy'
    properties: {
      packageUri: workflowZipUrl
    }
  }
}

output LogicAppName string = LogicApp.name
output OutboundIP string = PublicIP.properties.ipAddress
