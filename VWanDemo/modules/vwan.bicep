param name string
param location string
param addressSpace string
param zones array
param vnets array

// https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-bgp-overview#what-asns-autonomous-system-numbers-can-i-use
var vwanASN = 65515
var defaultLabel = 'default'
var noneLabel = 'none'

resource vwan 'Microsoft.Network/virtualWans@2021-03-01' = {
  name: name
  location: location
  properties: {
    allowVnetToVnetTraffic: true
    allowBranchToBranchTraffic: true
    type: 'Standard'
  }
}

resource vwanHub 'Microsoft.Network/virtualHubs@2021-03-01' = {
  name: '${name}-${location}'
  location: location
  properties: {
    addressPrefix: addressSpace
    virtualWan: {
      id: vwan.id
    }
  }
}

resource noneRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2021-03-01' = {
  name: 'noneRouteTable'
  parent: vwanHub
  properties:{
    labels: [
      noneLabel
    ]
  }
}

resource defaultRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2021-03-01' = {
  name: 'defaultRouteTable'
  parent: vwanHub
  properties:{
    labels: [
      defaultLabel
    ]
  }
}

resource zoneRouteTables 'Microsoft.Network/virtualHubs/hubRouteTables@2021-03-01' = [for zone in zones: {
  name: '${zone}RouteTable'
  parent: vwanHub
  properties:{
    labels: [
      toUpper(zone)
      defaultLabel
    ]
  }
}]

resource vnetConnections 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2021-03-01' = [for vnet in vnets: {
  name: last(split(vnet.id, '/'))
  parent: vwanHub
  properties:{
    allowRemoteVnetToUseHubVnetGateways: true
    allowHubToRemoteVnetTransit: true
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: vnet.id
    }
    routingConfiguration:{
      associatedRouteTable: {
        id: '${vwanHub.id}/hubRouteTables/${vnet.zone}RouteTable'
      }
      propagatedRouteTables: {
        labels: [
          toUpper(vnet.zone)
        ]
        ids:[
          {
            id: '${vwanHub.id}/hubRouteTables/${vnet.zone}RouteTable'
          }
          {
            id: '${vwanHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
      }
    }
  }
}]

resource gateway 'Microsoft.Network/vpnGateways@2021-03-01' = {
  name: name
  location: location
  properties:{
    vpnGatewayScaleUnit: 1
    virtualHub: {
      id: vwanHub.id
    }
    bgpSettings: {
      asn: vwanASN
    }
  }
}

output vwanASN int = vwanASN
output vwanPip string = gateway.properties.ipConfigurations[0].publicIpAddress
output vwanId string = vwan.id
output vwanHubId string = vwanHub.id
output gatewayName string = gateway.name
output defaultRouteTableId string = defaultRouteTable.id
output defaultRouteTableLabel string = defaultLabel
