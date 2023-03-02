param location string
param aksClusterName string
param aksDnsPrefix string
param nodePools array
param logAnalyticsWorkspaceResourceID string
param tags object

// Auto pick zones
var nodeZones = pickZones('Microsoft.Compute', 'virtualMachines', location, 3)

// Defaults
var defaultVmSize = 'standard_d2s_v5'
var defaultVmCount = 1
var systemNodeTaints = [ 'CriticalAddonsOnly=true:NoSchedule' ]

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
  name: toLower(aksClusterName)
  location: location
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  properties: {
    dnsPrefix: aksDnsPrefix
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
    }
    agentPoolProfiles: map(nodePools, nodePool => {
      name: toLower(nodePool.name)
      mode: contains(nodePool, 'system') && nodePool.system ? 'System' : 'User'
      osType: 'Linux'
      type: 'VirtualMachineScaleSets'
      availabilityZones: nodeZones
      vmSize: contains(nodePool, 'vmSize') ? nodePool.vmSize : defaultVmSize
      count: contains(nodePool, 'vmCount') ? nodePool.vmCount : defaultVmCount
      minCount: contains(nodePool, 'vmCountMin') ? nodePool.vmCountMin : null
      maxCount: contains(nodePool, 'vmCountMax') ? nodePool.vmCountMax : null
      enableAutoScaling: contains(nodePool, 'vmCountMin') || contains(nodePool, 'vmCountMax')
      vnetSubnetID: nodePool.nodeSubnetId
      podSubnetID: nodePool.podSubnetId
      // Todo: concat config node taints
      nodeTaints: contains(nodePool, 'system') && nodePool.system ? systemNodeTaints : []
    })
    aadProfile: {
      enableAzureRBAC: true
      managed: true
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceResourceID
        }
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
}

output clusterName string = aksCluster.name
output clusterId string = aksCluster.id
