param uniqueName string
param location string
param appgwSubnetId string
param appgwPrivateIp string

var appGwName = uniqueName
var backendPoolName = 'backendPool'
var privateFrontend = 'appGwPrivateFrontendIp'

resource appgwPIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${uniqueName}-appgw'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource appGw 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: appGwName
  location: location
  properties: {
    enableHttp2: false
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appgwSubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: appgwPIP.id
          }
        }
      }
      {
        name: privateFrontend
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: appgwPrivateIp
          subnet: {
            id: appgwSubnetId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'http'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {}
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'http'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          protocol: 'Http'
          requireServerNameIndication: false
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, privateFrontend)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'http')
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'httpRouting'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, backendPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'http')
          }
        }
      }
    ]
  }
}

output appgwBackendPoolId string = '${appGw.id}/backendAddressPools/${backendPoolName}'
output appgwPrivateIp string = appgwPrivateIp
