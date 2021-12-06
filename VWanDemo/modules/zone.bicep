param location string
param prefix string
param username string
param sshPublicKey string
param vmSize string
param zoneName string
param zoneAddressSpaces array

module vnets 'vnet.bicep' = [for (addressSpace, i) in zoneAddressSpaces: {
  name: '${deployment().name}-vnet${zoneName}${i + 1}'
  params: {
    name: '${prefix}-${zoneName}${i + 1}'
    location: location
    addressSpace: addressSpace
    zoneTag: zoneName
  }
}]

module vms 'vm.bicep' = [for (addressSpace, i) in zoneAddressSpaces: {
  name: '${deployment().name}-vm${zoneName}${i + 1}A'
  params: {
    name: '${prefix}-${zoneName}${i + 1}A'
    location: location
    subnetId: vnets[i].outputs.defaultSubnetId
    username: username
    sshPublicKey: sshPublicKey
    vmSize: vmSize
    zoneTag: zoneName
    networkTag: vnets[i].outputs.networkTag
  }
}]

output vnets array = [for (addressSpace, i) in zoneAddressSpaces: {
  id: vnets[i].outputs.networkID
  zone: zoneName
}]
