param location string
param uniqueName string
param sourceRepo string
param dockerFilePath string

var imageName = '${uniqueName}/windup:v1'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: uniqueName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource buildTask 'Microsoft.ContainerRegistry/registries/taskRuns@2019-06-01-preview' = {
  name: uniqueString(imageName)
  parent: containerRegistry
  properties: {
    runRequest: {
      type: 'DockerBuildRequest'
      dockerFilePath: dockerFilePath
      imageNames: [
        imageName
      ]
      isPushEnabled: true
      sourceLocation: sourceRepo
      platform: {
        os: 'Linux'
        architecture: 'amd64'
      }
      agentConfiguration: {
        cpu: 2
      }
    }
  }
}

resource containerPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: '${uniqueName}-containerpull'
  location: location
}

resource containerPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // ACR Pull
}

resource containerPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(uniqueName, containerPullIdentity.id, containerPullRoleDefinition.id)
  scope: containerRegistry
  properties: {
    principalId: containerPullIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: containerPullRoleDefinition.id
  }
}

output containerImage string = '${containerRegistry.properties.loginServer}/${imageName}'
output containerPullIdentityId string = containerPullIdentity.id
