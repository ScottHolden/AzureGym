param uniqueName string
param location string
param vmSku string
param vmCount int
param nsgId string
param subnetId string
param slbBackendPoolId string
param appgwBackendPoolId string

var cloudInit = loadFileAsBase64('resources/vmCloudInit.yml')

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: uniqueName
  location: location
  sku: {
    name: vmSku
    capacity: vmCount
  }
  properties: {
    overprovision: false
    singlePlacementGroup: false
    upgradePolicy: {
      mode: 'Automatic'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          osType: 'Linux'
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          diskSizeGB: 30
        }
        imageReference: {
          publisher: 'canonical'
          offer: '0001-com-ubuntu-server-focal'
          sku: '20_04-lts-gen2'
          version: 'latest'
        }
      }
      osProfile: {
        computerNamePrefix: 'backendvm'
        customData: cloudInit
        adminUsername: substring(uniqueName, 0, 8)
        // Only for demo use, don't do this in prod :)
        adminPassword: 'Pw${uniqueString(uniqueName, resourceGroup().id)}!'
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${uniqueName}-nic'
            properties: {
              primary: true
              enableAcceleratedNetworking: true
              networkSecurityGroup: {
                id: nsgId
              }
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    primary: true
                    subnet: {
                      id: subnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: slbBackendPoolId
                      }
                    ]
                    applicationGatewayBackendAddressPools: [
                      {
                        id: appgwBackendPoolId
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}
