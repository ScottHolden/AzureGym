param prefix string = 'Valheim'
param vmSize string = 'Standard_D2s_v4'
param location string = resourceGroup().location
param valheimServerName string = 'AzValheim Test'
param valheimWorldName string = 'AzValheim'
param valheimServerPassword string {
  secure: true
}
param sshPublicKey string

module valheimServer './modules/basicvm.bicep' = {
  name: 'valheimServer'
  params: {
    prefix: prefix
    location: location
    size: vmSize
    sshPublicKey: sshPublicKey
  }
}

module valheimScript './modules/valheimscript.bicep' = {
  name: 'valheimScript'
  params: {
    location: location
    vmName: valheimServer.outputs.vmName
    serverName: valheimServerName
    serverPassword: valheimServerPassword
    worldName: valheimWorldName
  }
}