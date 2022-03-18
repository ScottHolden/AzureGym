param location string = resourceGroup().location
param prefix string = 'demo'
param vmSku string = 'Standard_D2s_v4'
param vmCount int = 6

var uniqueName = '${prefix}${uniqueString(resourceGroup().id, prefix)}'

module networking 'modules/networking.bicep' = {
  name: '${uniqueName}-networking'
  params: {
    location: location
    uniqueName: uniqueName
  }
}

module apimBase 'modules/apim-base.bicep' = {
  name: '${uniqueName}-apim-base'
  params: {
    location: location
    uniqueName: uniqueName
    subnetId: networking.outputs.apimSubnetId
  }
}

module slb 'modules/slb.bicep' = {
  name: '${uniqueName}-slb'
  params: {
    location: location
    uniqueName: uniqueName
    backendSubnetId: networking.outputs.backendSubnetId
  }
}

module appgw 'modules/appgw.bicep' = {
  name: '${uniqueName}-appgw'
  params: {
    location: location
    uniqueName: uniqueName
    appgwSubnetId: networking.outputs.appgwSubnetId
    appgwPrivateIp: networking.outputs.appgwPrivateIp
  }
}

module vmss 'modules/vmss.bicep' = {
  name: '${uniqueName}-vmss'
  params: {
    location: location
    uniqueName: uniqueName
    vmSku: vmSku
    vmCount: vmCount
    subnetId: networking.outputs.backendSubnetId
    nsgId: networking.outputs.defaultNSGId
    appgwBackendPoolId: appgw.outputs.appgwBackendPoolId
    slbBackendPoolId: slb.outputs.slbBackendPoolId
  }
}

module apimApis 'modules/apim-apis.bicep' = {
  name: '${uniqueName}-apim-apis'
  params: {
    apimName: apimBase.outputs.apimName
    appgwPrivateIp: appgw.outputs.appgwPrivateIp
    slbPrivateIp: slb.outputs.slbPrivateIp
  }
}

output slbUIEndpoint string = apimApis.outputs.slbUIEndpoint
output appgwUIEndpoint string = apimApis.outputs.appgwUIEndpoint
