param name string
param location string
param gatewayName string
param vwanId string
param vwanHubId string
param vwanASN int
param routeTableId string //'${vwanHub.id}/hubRouteTables/defaultRouteTable'
param routeTableLabel string
param targetIp string
param bgpPeerIp string
param bgpPeerASN int
param sharedKey string

resource site 'Microsoft.Network/vpnSites@2021-03-01' = {
  name: name
  location: location
  properties: {
    ipAddress: targetIp
    bgpProperties: {
      bgpPeeringAddress: bgpPeerIp
      asn: bgpPeerASN
      peerWeight: 0
    }
    virtualWan: {
      id: vwanId
    }
  }
}

// We update the gateway here with bgpPeeringAddresses
resource gateway 'Microsoft.Network/vpnGateways@2021-03-01' = {
  name: gatewayName
  location: location
  properties:{
    vpnGatewayScaleUnit: 1
    virtualHub: {
      id: vwanHubId
    }
    bgpSettings: {
      asn: vwanASN
      bgpPeeringAddresses: [
        {
          ipconfigurationId: 'Instance0'
          customBgpIpAddresses: [
            '169.254.21.1'
          ]
        }
        {
          ipconfigurationId: 'Instance1'
          customBgpIpAddresses: [
            '169.254.22.1'
          ]
        }
      ]
    }
  }
}

resource connection 'Microsoft.Network/vpnGateways/vpnConnections@2021-03-01' = {
  name: name
  parent: gateway
  properties:{
    enableBgp: true
    remoteVpnSite: {
      id: site.id
    }
    vpnConnectionProtocolType: 'IKEv2'
    sharedKey: sharedKey
    routingConfiguration: {
      associatedRouteTable: {
        id: routeTableId
      }
      propagatedRouteTables: {
        labels:[
          routeTableLabel
        ]
        ids: [
          {
            id: routeTableId
          }
        ]
      }
    }
  }
}
