param vmName string
param location string
param privateIp string
param vwanPip string
param sharedKey string
param localASN int
param remoteASN int
param localBGPPeer string
param remoteBGPPeer string

// Would love to simplify this :D
var _script00 = loadTextContent('./vm-router.sh')
var _script01 = replace(_script00, '{{PrivateIP}}', privateIp)
var _script02 = replace(_script01, '{{VWanPIP}}', vwanPip)
var _script03 = replace(_script02, '{{SharedKey}}', sharedKey)
var _script04 = replace(_script03, '{{LocalBGPPeer}}', localBGPPeer)
var _script05 = replace(_script04, '{{RemoteBGPPeer}}', remoteBGPPeer)
var _script06 = replace(_script05, '{{LocalASN}}', string(localASN))
var _script07 = replace(_script06, '{{RemoteASN}}', string(remoteASN))
//
var script = base64(_script07)

resource customScript 'Microsoft.Compute/virtualMachines/extensions@2019-03-01' = {
  name: '${vmName}/setup'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: {
      script: script
    }
  }
}
