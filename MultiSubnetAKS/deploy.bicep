/* 
 Multi Subnet AKS
  This demo deploys a VNet and an AKS Cluster with the following configuration:
  - A dedicated system pool
  - Multiple workload pools
  Each of these node pools have a seperate node & pod subnet
*/

@description('The location all resources will be deployed to')
param location string = resourceGroup().location

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'aksdemo'

@description('The address space prefixes to use for the vnet. All subnets defined in the params should be contained within this.')
param vnetAddressSpacePrefixes array = [
  '10.197.0.0/16'
]

@description('The system node pool high-level configuration. The following properties are required: name, nodeSubnetAddressPrefix, podSubnetAddressPrefix, vmCount, vmSize')
param systemNodePool object = {
  name: 'system'
  nodeSubnetAddressPrefix: '10.197.4.0/23'
  podSubnetAddressPrefix: '10.197.8.0/22'
  vmCount: 3
  vmSize: 'standard_d2s_v5'
}

@description('An array of workload node pool high-level configurations. The following properties are required on each element of the array: name, nodeSubnetAddressPrefix, podSubnetAddressPrefix, vmCount, vmSize. You can also optionally define: taints')
param workloadNodePools array = [
  {
    name: 'shared'
    nodeSubnetAddressPrefix: '10.197.64.0/23'
    podSubnetAddressPrefix: '10.197.68.0/22'
    vmCount: 3
    vmSize: 'standard_d2s_v5'
  }
  {
    name: 'protected'
    nodeSubnetAddressPrefix: '10.197.72.0/23'
    podSubnetAddressPrefix: '10.197.76.0/22'
    vmCount: 3
    vmSize: 'standard_d2s_v5'
    taints: [
      'Workload=protected:NoSchedule'
    ]
  }
]

@description('Tags to be applied to all deployed resources')
param tags object = {
  'Demo-Name': 'MultiSubnetAKS'
  'Demo-Repo': 'https://github.com/ScottHolden/AzureGym/MultiSubnetAKS'
}

// **--- Helper configuration ---**
var uniqueNameFormat = '${prefix}-{0}-${uniqueString(resourceGroup().id, prefix)}'
var uniqueShortName = toLower('${prefix}${uniqueString(resourceGroup().id, prefix)}')
var nodeSubnetFormat = 'aks-{0}-nodepool'
var podSubnetFormat = 'aks-{0}-pods'
var nodeZones = pickZones('Microsoft.Compute', 'virtualMachines', location, 3)

// **--- Networking - Mapping to configuration ---**
var nodeSubnets = [for cluster in concat([ systemNodePool ], workloadNodePools): {
  name: format(nodeSubnetFormat, cluster.name)
  properties: {
    addressPrefix: cluster.nodeSubnetAddressPrefix
  }
}]
var podSubnets = [for cluster in concat([ systemNodePool ], workloadNodePools): {
  name: format(podSubnetFormat, cluster.name)
  properties: {
    addressPrefix: cluster.podSubnetAddressPrefix
  }
}]

// **--- Node (Agent) Pools - Mapping to configuration ---**
var systemAgentPool = {
  name: systemNodePool.name
  mode: 'System'
  osType: 'Linux'
  count: systemNodePool.vmCount
  vmSize: systemNodePool.vmSize
  type: 'VirtualMachineScaleSets'
  availabilityZones: nodeZones
  vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, format(nodeSubnetFormat, systemNodePool.name))
  podSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, format(podSubnetFormat, systemNodePool.name))
  nodeTaints: [ 'CriticalAddonsOnly=true:NoSchedule' ]
}
var workloadAgentPools = [for cluster in workloadNodePools: {
  name: cluster.name
  mode: 'User'
  osType: 'Linux'
  count: cluster.vmCount
  vmSize: cluster.vmSize
  type: 'VirtualMachineScaleSets'
  availabilityZones: nodeZones
  vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, format(nodeSubnetFormat, cluster.name))
  podSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, format(podSubnetFormat, cluster.name))
  nodeTaints: contains(cluster, 'taints') ? cluster.taints : []
}]

// **--- Resource deployments begin here ---**
resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: format(uniqueNameFormat, 'vnet')
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressSpacePrefixes
    }
    subnets: concat(nodeSubnets, podSubnets)
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' = {
  name: format(uniqueNameFormat, 'akscluster')
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  properties: {
    dnsPrefix: uniqueShortName
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
    }
    agentPoolProfiles: concat([ systemAgentPool ], workloadAgentPools)
    aadProfile: {
      enableAzureRBAC: true
      managed: true
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}
