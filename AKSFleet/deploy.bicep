@description('The location all resources will be deployed to')
param location string = resourceGroup().location

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'aksfleet'

@description('Tags to be applied to all deployed resources')
param tags object = {
  'Demo-Name': 'AKSFleet'
  'Demo-Repo': 'https://github.com/ScottHolden/AzureGym/AKSFleet'
}

// Config is stored in the config.json file
var config = loadJsonContent('config.json')

var uniqueNameFormat = '${prefix}-{0}-${uniqueString(resourceGroup().id, prefix)}'
var uniqueShortNameFormat = toLower('${prefix}{0}${uniqueString(resourceGroup().id, prefix)}')
var nodeSubnetFormat = 'aks-{0}-{1}-nodepool'
var podSubnetFormat = 'aks-{0}-{1}-pods'

var nodeSubnets = flatten(map(config.clusters, cluster => map(cluster.nodePools, nodePool => {
  name: format(nodeSubnetFormat, cluster.cluserName, nodePool.name)
  addressPrefix: nodePool.nodeSubnetAddressPrefix
})))

var podSubnets = flatten(map(config.clusters, cluster => map(cluster.nodePools, nodePool => {
  name: format(podSubnetFormat, cluster.cluserName, nodePool.name)
  addressPrefix: nodePool.podSubnetAddressPrefix
  aksDelegation: true
})))

var gatewaySubnet = {
  name: 'gateway'
  addressPrefix: config.gatewaySubnetAddressPrefix
}

// Resource Deployment Starts Here

module vnet 'modules/vnet.bicep' = {
  name: '${deployment().name}-vnet'
  params: {
    location: location
    vnetName: format(uniqueNameFormat, 'vnet')
    addressSpace: config.addressSpace
    subnets: concat([gatewaySubnet], nodeSubnets, podSubnets)
    tags: tags
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: format(uniqueNameFormat, 'workspace')
  location: location
  properties: {}
  tags: tags
}

module aks 'modules/aks.bicep' = [for cluster in config.clusters: {
  name: '${deployment().name}-aks-${cluster.cluserName}'
  params: {
    location: location
    aksClusterName: format(uniqueNameFormat, 'aks-${cluster.cluserName}')
    aksDnsPrefix: toLower(take(format(uniqueShortNameFormat, cluster.cluserName), 24))
    logAnalyticsWorkspaceResourceID: logAnalytics.id
    nodePools: map(cluster.nodePools, nodePool => union({
      nodeSubnetId: '${vnet.outputs.subnetIdPrefix}/${format(nodeSubnetFormat, cluster.cluserName, nodePool.name)}'
      podSubnetId: '${vnet.outputs.subnetIdPrefix}/${format(podSubnetFormat, cluster.cluserName, nodePool.name)}'
    }, nodePool))
    tags: tags
  }
}]

module fleet 'modules/fleet.bicep' = {
  name: '${deployment().name}-fleet'
  params: {
    location: location
    fleetName: format(uniqueNameFormat, 'fleet')
    fleetDnsPrefix: toLower(take(format(uniqueShortNameFormat, 'fleet'), 24))
    // Note: Range workaround for looped module output
    memberClusters: [for i in range(0, length(config.clusters)): {
      name: take(toLower(aks[i].outputs.clusterName), 50)
      id: aks[i].outputs.clusterId
    }]
    tags: tags
  }
  dependsOn: aks
}

