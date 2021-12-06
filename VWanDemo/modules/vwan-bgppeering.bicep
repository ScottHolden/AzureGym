param name string
param location string
param vwanHubId string
param vwanASN int

resource gateway 'Microsoft.Network/vpnGateways@2021-03-01' = {
  name: name
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
