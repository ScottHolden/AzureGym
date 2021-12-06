@description('The location for all resources to be deployed')
param location string = 'AustraliaEast'

@description('The prefix to be used for all resource names')
param prefix string = 'Demo'

@description('The username for all deployed VMs')
param username string = 'vwandemo'

@description('The ssh public key to be deployed to all VMs')
param sshPublicKey string

@description('The vm size for all deployed VMs (Total 4 VMs, must have quota)')
param vmSize string = 'Standard_D2s_v4'

@description('The ip address that should be allowed for SSH access, if left empty, no ssh rule will be added. Should be in a 100.100.100.100/32 format.')
param allowedIp string = ''

@description('The shared key to use for the ipsec VPN, should be random, long, and should remain the same if redeployed')
param sharedKey string = 'bJR3pKyHI/ojhgnzXHqwA0KTxjhaCJP1HVIEfmwqlHKKOKuD5DvSufNIZ8U0Rp4rBZlhMjDP8SplNyGKvCH2Pw=='

@description('An array of zones & address spaaces to deploy, don\'t change this for the default demo topology')
param zoneAddressSpaces object = {
  Blue: [
    '10.10.1.0/24'
    '10.10.2.0/24'
  ]
  Green: [
    '10.20.1.0/24'
  ]
}
@description('The on-premises address space to deploy, this will be a vnet, don\'t change this for the default demo topology')
param onpremAddressSpace string = '10.0.0.0/24'

@description('The address space to use for vwan routing/gateways, don\'t change this for the default demo topology')
param vwanAddressSpace string = '10.250.0.0/24'

var deploymentPrefix = '${prefix}-${uniqueString(subscription().id, deployment().name)}'
var zoneNames =  [for zone in items(zoneAddressSpaces): zone.key]

module zones 'modules/zone.bicep' = [for zone in items(zoneAddressSpaces): {
  name: '${deploymentPrefix}-${zone.key}'
  params: {
    prefix: prefix
    location: location
    zoneName: zone.key
    zoneAddressSpaces: zone.value
    username: username
    sshPublicKey: sshPublicKey
    vmSize: vmSize
  }
}]

module vnetFlatten 'modules/array-flatten.bicep' = {
  name: '${deploymentPrefix}-vnetFlatten'
  params: {
    value: [for i in range(0, length(items(zoneAddressSpaces))): zones[i].outputs.vnets]
  }
}

module vwan 'modules/vwan.bicep' = {
  name: '${deploymentPrefix}-VWan'
  params: {
    name: prefix
    location: location
    addressSpace: vwanAddressSpace
    zones: zoneNames
    // Todo: Make indexes dynamic
    vnets: vnetFlatten.outputs.value
  }
}

module onprem 'modules/onprem.bicep' = {
  name: '${deploymentPrefix}-Onprem'
  params: {
    prefix: prefix
    location: location
    allowedIp: allowedIp
    username: username
    sshPublicKey: sshPublicKey
    addressSpace: onpremAddressSpace
    vmSize: vmSize
    sharedKey: sharedKey
    remoteASN: vwan.outputs.vwanASN
    vwanPip: vwan.outputs.vwanPip
  }
}

module connection 'modules/vwan-s2s.bicep' = {
  name: '${deploymentPrefix}-Connection'
  params: {
    name: 'onprem'
    location: location
    vwanId: vwan.outputs.vwanId
    vwanHubId: vwan.outputs.vwanHubId
    vwanASN: vwan.outputs.vwanASN
    gatewayName: vwan.outputs.gatewayName
    routeTableId: vwan.outputs.defaultRouteTableId
    routeTableLabel: vwan.outputs.defaultRouteTableLabel
    targetIp: onprem.outputs.pip
    sharedKey: sharedKey
    bgpPeerIp: onprem.outputs.bgpip
    bgpPeerASN: onprem.outputs.bgpasn
  }
}
