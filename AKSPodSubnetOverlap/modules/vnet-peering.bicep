param vnet1name string
param vnet2name string

resource vnet1 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: vnet1name
  resource peering 'virtualNetworkPeerings@2022-09-01' = {
    name: 'peering-to-${vnet2.name}'
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false
      useRemoteGateways: false
      remoteVirtualNetwork: {
        id: vnet2.id
      }
    }
  }
}

resource vnet2 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: vnet2name
  resource peering 'virtualNetworkPeerings@2022-09-01' = {
    name: 'peering-to-${vnet1.name}'
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false
      useRemoteGateways: false
      remoteVirtualNetwork: {
        id: vnet1.id
      }
    }
  }
}
