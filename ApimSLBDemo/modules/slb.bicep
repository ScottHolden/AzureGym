param uniqueName string
param location string
param backendSubnetId string

var slbName = uniqueName
var probeName = 'httpProbe'
var backendPoolName = 'backendPool'
var privateFrontend = 'internal'

resource slb 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: slbName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: privateFrontend
        properties: {
          subnet: {
            id: backendSubnetId
          }
          privateIPAddressVersion: 'IPv4'
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
      }
    ]
    probes: [
      {
        name: probeName
        properties: {
          port: 80
          protocol: 'Tcp'
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'http'
        properties: {
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', slbName, probeName)
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', slbName, 'internal')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', slbName, backendPoolName)
          }
        }
      }
    ]
  }
}

output slbBackendPoolId string = '${slb.id}/backendAddressPools/${backendPoolName}'
output slbPrivateIp string = reference('${slb.id}/frontendIPConfigurations/${privateFrontend}', slb.apiVersion).privateIPAddress
