param location string
param prefix string
param username string
param sshPublicKey string
param vmSize string
param allowedIp string
param sharedKey string
param vwanPip string
param localASN int = 61337
param localBGPPeer string = '169.254.21.2'
param remoteASN int
param remoteBGPPeer string = '169.254.21.1'

var zoneTag = 'OnPrem'

module vnet 'vnet.bicep' = {
  name: '${deployment().name}-vnet'
  params: {
    name: '${prefix}-OnPrem'
    location: location
    addressSpace: '10.0.0.0/24'
    zoneTag: zoneTag
    securityRules: empty(allowedIp) ? [] : [
      {
        name: 'SSH'
        properties: {
          priority: 320
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: allowedIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

module vm 'vm.bicep' = {
  name: '${deployment().name}-vm'
  params: {
    name: '${prefix}-OnPrem'
    location: location
    subnetId: vnet.outputs.defaultSubnetId
    deployPip: true
    ipForwarding: true
    username: username
    sshPublicKey: sshPublicKey
    vmSize: vmSize
    zoneTag: zoneTag
    networkTag: vnet.outputs.networkTag
  }
}

module script 'scripts/vm-router.bicep' = {
  name: '${deployment().name}-vmscript'
  params: {
    vmName: vm.outputs.vmname
    location: location
    privateIp: vm.outputs.ip
    sharedKey: sharedKey
    vwanPip: vwanPip
    localASN: localASN
    localBGPPeer: localBGPPeer
    remoteASN: remoteASN
    remoteBGPPeer: remoteBGPPeer
  }
}

output pip string = vm.outputs.pip
output bgpip string = localBGPPeer
output bgpasn int = localASN
