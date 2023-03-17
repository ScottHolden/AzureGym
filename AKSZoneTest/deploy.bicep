@description('The location all resources will be deployed to')
param location string = resourceGroup().location

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'akszone'

@description('Tags to be applied to all deployed resources')
param tags object = {
  'Demo-Name': 'AKSZoneTest'
  'Demo-Repo': 'https://github.com/ScottHolden/AzureGym/AKSZoneTest'
}

@description('Repo that contains the workload container dockerfile')
param sourceRepo string = 'https://github.com/ScottHolden/AzureGym.git'

@description('Path within sourceRepo to the Dockerfile to build')
param dockerfilePath string = 'AKSZoneTest/src/Dockerfile'

var uniqueNameFormat = '${prefix}-{0}-${uniqueString(resourceGroup().id, prefix)}'
var uniqueShortName = toLower('${prefix}${uniqueString(resourceGroup().id, prefix)}')

var workloadNodes = 6
var podReplicas = workloadNodes * 2

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: format(uniqueNameFormat, 'workspace')
  location: location
  properties: {}
}

module aksCluster 'modules/aks.bicep' = {
  name: '${deployment().name}-aks'
  params: {
    location: location
    aksClusterName: format(uniqueNameFormat, 'akscluster')
    aksDnsPrefix: uniqueShortName
    vnetName: format(uniqueNameFormat, 'vnet')
    logAnalyticsWorkspaceResourceID: logAnalytics.id
    workloadNodes: workloadNodes
    tags: tags
  }
}

module container 'modules/container.bicep' = {
  name: '${deployment().name}-container'
  params: {
    location: location
    registryName: take('${uniqueShortName}registry', 50)
    imageName: 'hopworkload'
    sourceRepo: sourceRepo
    dockerFilePath: dockerfilePath
    pullPrincipalId: aksCluster.outputs.kubletIdentity
  }
}

module kubeDeploy 'modules/kube.bicep' = {
  name: '${deployment().name}-kube'
  params: {
    aksCluserName: aksCluster.outputs.aksCluserName
    containerImage: container.outputs.image
    replicas: podReplicas
  }
}
