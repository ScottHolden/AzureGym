param location string
param registryName string
param imageName string
param sourceRepo string
param dockerFilePath string
param imageTagSeed string = utcNow()

var imageNameWithTag = '${imageName}:v1-${uniqueString(imageTagSeed)}'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: registryName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
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

output image string = '${containerRegistry.properties.loginServer}/${imageNameWithTag}'
output registryName string = containerRegistry.name
