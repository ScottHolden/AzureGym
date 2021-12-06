param location string = 'AustraliaEast'
param prefix string = 'Demo'
param username string = 'vwandemo'
param sshPublicKey string
param vmSize string = 'Standard_D2s_v4'
param allowedIp string = ''
param sharedKey string = 'bJR3pKyHI/ojhgnzXHqwA0KTxjhaCJP1HVIEfmwqlHKKOKuD5DvSufNIZ8U0Rp4rBZlhMjDP8SplNyGKvCH2Pw=='

param zoneAddressSpaces object = {
  Blue: [
    '10.10.1.0/24'
    '10.10.2.0/24'
  ]
  Green: [
    '10.20.1.0/24'
  ]
}
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
