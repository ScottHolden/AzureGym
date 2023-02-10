@description('The location all resources will be deployed to')
param location string = resourceGroup().location

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'windup'

@description('*Leave blank to build a new container* Container image to use')
param containerImageOverride string = 'eggboy/windup:6.1.2'

var uniqueName = '${toLower(prefix)}${uniqueString(prefix, resourceGroup().id)}'

var buildSourceRepo = 'https://github.com/ScottHolden/AzureGym.git'
var buildDockerFilePath = 'AzureGym/WindupAppSvc/windup/Dockerfile'

module containerBuild 'modules/containerBuild.bicep' = if(empty(containerImageOverride)) {
  name: '${deployment().name}-build'
  params: {
    location: location
    uniqueName: uniqueName
    sourceRepo: buildSourceRepo
    dockerFilePath: buildDockerFilePath
  }
}

module appSvc 'modules/appSvc.bicep' = {
  name:'${deployment().name}-appsvc'
  params: {
    location: location
    uniqueName: uniqueName
    containerImage: empty(containerImageOverride) ? containerBuild.outputs.containerImage : containerImageOverride
    acrUserManagedIdentityID: empty(containerImageOverride) ? containerBuild.outputs.containerPullIdentityId : ''
  }
}

output windupUrl string = appSvc.outputs.url
