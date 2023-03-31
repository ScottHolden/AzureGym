param location string
param registryName string
param imageName string
param sourceRepo string
param dockerFilePath string
param pullPrincipalIds array
param imageTagSeed string = utcNow()

var imageNameWithTag = '${imageName}:v1-${uniqueString(imageTagSeed)}'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: registryName
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
        imageNameWithTag
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

resource containerPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // ACR Pull
}

resource containerPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for principalId in pullPrincipalIds: {
  name: guid(containerRegistry.id, principalId, containerPullRoleDefinition.id)
  scope: containerRegistry
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: containerPullRoleDefinition.id
  }
}]

output image string = '${containerRegistry.properties.loginServer}/${imageNameWithTag}'
