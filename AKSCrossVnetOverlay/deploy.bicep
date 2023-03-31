@description('The location all resources will be deployed to')
param location string = resourceGroup().location

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'akscvo'

@description('Source Repo for Dockerfile')
param sourceRepo string = 'https://github.com/ScottHolden/AzureGym.git'

@description('Dockerfile path in Source Repo')
param dockerFilePath string = 'AKSCrossVnetOverlay/src/Dockerfile'

@description('Nodes per cluster')
param perClusterNodeCount int = 3

@description('Nodes VM size')
param nodeSize string = 'standard_d4s_v5'

@description('Network configuration')
param networkConfig object = {
  cluster1: {
    addressSpace: '10.1.0.0/22'
    nodeSubnetCidr: '10.1.1.0/24'
    podOverlayCidr: '10.250.0.0/16'
  }
  cluster2: {
    addressSpace: '10.2.0.0/22'
    nodeSubnetCidr: '10.2.1.0/24'
    podOverlayCidr: '10.250.0.0/16'
  }
}

@description('Tags to be applied to all deployed resources')
param tags object = {
  'Demo-Name': 'AKSCrossVnetOverlay'
  'Demo-Repo': 'https://github.com/ScottHolden/AzureGym/AKSCrossVnetOverlay'
}

var uniqueNameFormat = '${prefix}-{0}-${uniqueString(resourceGroup().id, prefix)}'
var uniqueShortNameFormat = toLower('${prefix}{0}${uniqueString(resourceGroup().id, prefix)}')

var podReplicas = perClusterNodeCount // 1 Pod per node
var namespaceName = 'test-app'
var workloadName = 'pathtester'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: format(uniqueNameFormat, 'workspace')
  location: location
  properties: {}
}

module cluster1 'modules/vnet-aks-cni-overlay.bicep' = {
  name: '${deployment().name}-cluster1'
  params: {
    location: location
    vnetName: format(uniqueNameFormat, 'cluster1-vnet')
    vnetaddressPrefix: networkConfig.cluster1.addressSpace
    nodeSubnetPrefix: networkConfig.cluster1.nodeSubnetCidr
    clusterName: format(uniqueNameFormat, 'cluster1')
    clusterDnsPrefix: format(uniqueShortNameFormat, 'c1')
    nodeCount: perClusterNodeCount
    nodeSize: nodeSize
    podCidr: networkConfig.cluster1.podOverlayCidr
    logAnalyticsWorkspaceResourceID: logAnalytics.id
    tags: tags
  }
}

module cluster2 'modules/vnet-aks-cni-overlay.bicep' = {
  name: '${deployment().name}-cluster2'
  params: {
    location: location
    vnetName: format(uniqueNameFormat, 'cluster2-vnet')
    vnetaddressPrefix: networkConfig.cluster2.addressSpace
    nodeSubnetPrefix: networkConfig.cluster2.nodeSubnetCidr
    clusterName: format(uniqueNameFormat, 'cluster2')
    clusterDnsPrefix: format(uniqueShortNameFormat, 'c2')
    nodeCount: perClusterNodeCount
    nodeSize: nodeSize
    podCidr: networkConfig.cluster2.podOverlayCidr
    logAnalyticsWorkspaceResourceID: logAnalytics.id
    tags: tags
  }
}

module vnetPeering 'modules/vnet-peeting.bicep' = {
  name: '${deployment().name}-peering'
  params: {
    vnet1name: cluster1.outputs.vnetName
    vnet2name: cluster2.outputs.vnetName
  }
}

module containerImage 'modules/container-image.bicep' = {
  name: '${deployment().name}-conatiner'
  params: {
    location: location
    registryName: format(uniqueShortNameFormat, 'acr')
    imageName: workloadName
    sourceRepo: sourceRepo
    dockerFilePath: dockerFilePath
    pullPrincipalIds: [
      cluster1.outputs.kubeletIdentityObjectId
      cluster2.outputs.kubeletIdentityObjectId
    ]
  }
}

module kubeApplyCluster1 'modules/kube-apply.bicep' = {
  name: '${deployment().name}-cl1-kube'
  params: {
    aksCluserName: cluster1.outputs.clusterName
    containerImage: containerImage.outputs.image
    namespaceName: namespaceName
    workloadName: workloadName
    replicas: podReplicas
  }
}

module kubeApplyCluster2 'modules/kube-apply.bicep' = {
  name: '${deployment().name}-cl2-kube'
  params: {
    aksCluserName: cluster2.outputs.clusterName
    containerImage: containerImage.outputs.image
    namespaceName: namespaceName
    workloadName: workloadName
    replicas: podReplicas
  }
}
