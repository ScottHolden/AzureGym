param vnetName string
param location string
param addressSpace string
param subnets array
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [addressSpace]
    }
    subnets: map(subnets, subnet => {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        delegations: contains(subnet, 'aksDelegation') && subnet.aksDelegation ? [{
          name: 'aks-delegation'
          properties: {
            serviceName: 'Microsoft.ContainerService/managedClusters'
          }
        }] : []
      }
    })
  }
  tags: tags
}

output subnetIdPrefix string = '${vnet.id}/subnets'
