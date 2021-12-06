param name string
param location string
param username string
param sshPublicKey string
param vmSize string
param subnetId string
param deployPip bool = false
param ipForwarding bool = false
param zoneTag string
param networkTag string

var vmTag = '${networkTag}/${name}'

resource pip 'Microsoft.Network/publicIpAddresses@2019-02-01' = if (deployPip) {
  name: name
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags:{
    zone: zoneTag
    network: networkTag
    vm: vmTag
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2018-10-01' = {
  name: name
  location: location
  properties: {
    enableIPForwarding: ipForwarding
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: deployPip ? {
            id: pip.id
          } : null
        }
      }
    ]
  }
  tags:{
    zone: zoneTag
    network: networkTag
    vm: vmTag
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-impish'
        sku: '21_10'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    securityProfile: {}
    osProfile: {
      computerName: uniqueString(name)
      adminUsername: username
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${username}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
  }
  tags:{
    zone: zoneTag
    network: networkTag
    vm: vmTag
  }
}

output vmname string = vm.name
output pip string = deployPip ? pip.properties.ipAddress : ''
output ip string = nic.properties.ipConfigurations[0].properties.privateIPAddress
