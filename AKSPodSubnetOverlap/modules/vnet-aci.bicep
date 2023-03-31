param location string
param vnetName string
param addressSpace string
param subnetPrefix string
param appGwName string
param appGwSubnetPrefix string
param appGwIp string
param aciName string
param acrName string
param imageName string
param tags object

var aciSubnetName = 'acisubnet'
var appGwSubnetName = 'appgw'

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: acrName
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ addressSpace, appGwSubnetPrefix ]
    }
    subnets: [
      {
        name: aciSubnetName
        properties: {
          addressPrefix: subnetPrefix
          delegations: [
            {
              name: 'Microsoft.ContainerInstance.containerGroups'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
      {
        name: appGwSubnetName
        properties: {
          addressPrefix: appGwSubnetPrefix
        }
      }
    ]
  }
  resource aciSubnet 'subnets@2022-09-01' existing = {
    name: aciSubnetName
  }
  resource appGwSubnet 'subnets@2022-09-01' existing = {
    name: appGwSubnetName
  }
}

resource aci 'Microsoft.ContainerInstance/containerGroups@2021-10-01' = {
  name: aciName
  location: location
  properties: {
    restartPolicy: 'Always'
    ipAddress: {
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
      ]
      type: 'Private'
    }
    imageRegistryCredentials: [
      {
        server: acr.properties.loginServer
        username: acr.listCredentials().username
        password: acr.listCredentials().passwords[0].value
      }
    ]
    subnetIds: [
      {
        id: vnet::aciSubnet.id
      }
    ]
    containers: [
      {
        name: 'pathtester'
        properties: {
          image: imageName
          environmentVariables: [
            {
              name: 'pod_name'
              value: 'pathtester'
            }
            {
              name: 'k8s_hostname'
              value: 'aci'
            }
            {
              name: 'cluster_name'
              value: 'aci'
            }
          ]
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 2
              memoryInGB: 8
            }
          }
        }
      }
    ]
    osType: 'Linux'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource appGwPip 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: appGwName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

var appGwGatewayConfig = 'appgwgateway'
var appGwFrontendPublicConfig = 'appgwpublicfrontend'
var appGwFrontendPrivateConfig = 'appgwprivatefrontend'
var appGwFrontendPort = 'appgwhttp'
var appGwBackendPool = 'acibackend'
var appGwBackendSettings = 'httpbackend'
var appGwPublicRoutingRule = 'publichttptoaci'
var appGwPublicHttpListener = 'publichttplistener'
var appGwPrivateRoutingRule = 'privatehttptoaci'
var appGwPrivateHttpListener = 'privatehttplistener'

resource appGw 'Microsoft.Network/applicationGateways@2022-09-01' = {
  name: appGwName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 1
    }
    gatewayIPConfigurations: [ {
        name: appGwGatewayConfig
        properties: {
          subnet: {
            id: vnet::appGwSubnet.id
          }
        }
      } ]
    frontendIPConfigurations: [
      {
        name: appGwFrontendPublicConfig
        properties: {
          publicIPAddress: {
            id: appGwPip.id
          }
        }
      }
      {
        name: appGwFrontendPrivateConfig
        properties: {
          subnet: {
            id: vnet::appGwSubnet.id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: appGwIp
        }
      }
    ]
    frontendPorts: [ {
        name: appGwFrontendPort
        properties: {
          port: 80
        }
      } ]
    backendAddressPools: [ {
        name: appGwBackendPool
        properties: {
          backendAddresses: [ {
              ipAddress: aci.properties.ipAddress.ip
            } ]
        }
      } ]
    backendHttpSettingsCollection: [ {
        name: appGwBackendSettings
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 3600
        }
      } ]
    httpListeners: [
      {
        name: appGwPublicRoutingRule
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, appGwFrontendPublicConfig)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, appGwFrontendPort)
          }
          protocol: 'Http'
        }
      }
      {
        name: appGwPrivateRoutingRule
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, appGwFrontendPrivateConfig)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, appGwFrontendPort)
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: appGwPublicHttpListener
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, appGwPublicRoutingRule)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, appGwBackendPool)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, appGwBackendSettings)
          }
        }
      }
      {
        name: appGwPrivateHttpListener
        properties: {
          ruleType: 'Basic'
          priority: 15
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, appGwPrivateRoutingRule)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, appGwBackendPool)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, appGwBackendSettings)
          }
        }
      }
    ]
  }
}

output vnetName string = vnet.name
