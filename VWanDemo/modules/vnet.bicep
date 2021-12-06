param name string
param location string
param addressSpace string
param defaultSubnet string = addressSpace
param zoneTag string = 'unknown'
param securityRules array = []

var subnetName = 'default'
var networkTag = '${zoneTag}/${name}'

resource network 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: defaultSubnet
          networkSecurityGroup:{
            id: nsg.id
          }
        }
      }
    ]
  }
  tags: {
    zone: zoneTag
    network: networkTag
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: name
  location: location
  properties: {
    securityRules: securityRules
  }
  tags: {
    zone: zoneTag
    network: networkTag
  }
}

output networkID string = network.id
output defaultSubnetId string = '${network.id}/subnets/${subnetName}'
output networkTag string = networkTag
