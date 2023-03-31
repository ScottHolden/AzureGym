param location string
param endpointName string
param endpointNicName string
param subnetId string
param nodeResourceGroup string
param privateLinkServiceId string
param tags object

// So AKS takes its time to deploy the internal LB and PLS, 
//  so we have no choice but to use a Deployment Script to wait for it. :(
//  Worst case we spend an extra ~90 seconds waiting for an instant completion

var waitScriptName = 'waitscript-${uniqueString(endpointName, endpointNicName, subnetId, privateLinkServiceId)}'

resource waitIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: waitScriptName
  location: location
  tags: tags
}

module waitRoleAssign 'private-endpoint-script-role.bicep' = {
  name: '${deployment().name}-waitrole'
  scope: resourceGroup(nodeResourceGroup)
  params: {
    principalId: waitIdentity.properties.principalId
  }
}

resource waitScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: waitScriptName
  location: location
  dependsOn: [ waitRoleAssign ]
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${waitIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: '1'
    azCliVersion: '2.43.0'
    environmentVariables: [
      {
        name: 'RESOURCE_ID'
        value: privateLinkServiceId
      }
    ]
    scriptContent: 'az resource wait --exists --ids $RESOURCE_ID'
    timeout: 'PT30M'
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
  }
  tags: tags
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: endpointName
  location: location
  tags: tags
  dependsOn: [ waitScript ]
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: endpointName
        properties: {
          privateLinkServiceId: privateLinkServiceId
        }
      }
    ]
    customNetworkInterfaceName: endpointNicName
  }
}
