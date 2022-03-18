param uniqueName string
param location string

var addressSpace = '10.250.0.0/16'

var apimSubnetName = 'apim'
var apimSubnetPrefix = '10.250.1.0/24'

var backendSubnetName = 'backend'
var backendSubnetPrefix = '10.250.2.0/24'

var appgwSubnetName = 'appgw'
var appgwSubnetPrefix = '10.250.3.0/24'
// v2 Requires a static ip
var appgwPrivateIp = '10.250.3.250'

resource vnet 'Microsoft.Network/virtualNetworks@2019-09-01' = {
  name: uniqueName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [
      {
        name: apimSubnetName
        properties: {
          addressPrefix: apimSubnetPrefix
          networkSecurityGroup: {
            id: apimNSG.id
          }
        }
      }
      {
        name: backendSubnetName
        properties: {
          addressPrefix: backendSubnetPrefix
          networkSecurityGroup: {
            id: defaultNSG.id
          }
          natGateway: {
            id: natGateway.id
          }
        }
      }
      {
        name: appgwSubnetName
        properties: {
          addressPrefix: appgwSubnetPrefix
        }
      }
    ]
  }
}

resource defaultNSG 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: uniqueName
  location: location
  properties: {
    securityRules: []
  }
}

resource apimNSG 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: '${uniqueName}-apim'
  location: location
  properties: {
    securityRules: [
      {
        name: 'apim'
        properties: {
          priority: 320
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '80'
            '443'
            '3443'
            '6390'
          ]
        }
      }
    ]
  }
}

resource natPIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${uniqueName}-nat'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: uniqueName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: natPIP.id
      }
    ]
  }
}

output apimSubnetId string = '${vnet.id}/subnets/${apimSubnetName}'
output backendSubnetId string = '${vnet.id}/subnets/${backendSubnetName}'
output appgwSubnetId string = '${vnet.id}/subnets/${appgwSubnetName}'
output appgwPrivateIp string = appgwPrivateIp
output defaultNSGId string = defaultNSG.id
