param logAnalyticsWorkspaceResourceID string
param location string
param tags object = {}
param aksClusterName string
param aksDnsPrefix string
param vnetName string
param workloadNodes int

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

@description('The workload node pool high-level configurations. The following properties are required on each element of the array: name, nodeSubnetAddressPrefix, podSubnetAddressPrefix, vmCount, vmSize. You can also optionally define: taints')
param workloadNodePool object = {
  name: 'shared'
  nodeSubnetAddressPrefix: '10.197.64.0/23'
  podSubnetAddressPrefix: '10.197.68.0/22'
  vmCount: workloadNodes
  vmSize: 'standard_d2s_v5'
}

var nodeSubnetFormat = 'aks-{0}-nodepool'
var podSubnetFormat = 'aks-{0}-pods'
var nodeZones = pickZones('Microsoft.Compute', 'virtualMachines', location, 3)

// **--- Networking - Mapping to configuration ---**
var nodeSubnets = [for nodePool in [systemNodePool, workloadNodePool]: {
  name: format(nodeSubnetFormat, nodePool.name)
  properties: {
    addressPrefix: nodePool.nodeSubnetAddressPrefix
  }
}]
var podSubnets = [for nodePool in [systemNodePool, workloadNodePool]: {
  name: format(podSubnetFormat, nodePool.name)
  properties: {
    addressPrefix: nodePool.podSubnetAddressPrefix
    delegations: [{
      name: 'aks-delegation'
      properties: {
        serviceName: 'Microsoft.ContainerService/managedClusters'
      }
    }]
  }
}]

// **--- Resource deployments begin here ---**
resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: vnetName
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
  name: aksClusterName
  location: location
  tags: tags
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
    agentPoolProfiles: [
      {
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
      {
        name: workloadNodePool.name
        mode: 'User'
        osType: 'Linux'
        count: workloadNodePool.vmCount
        vmSize: workloadNodePool.vmSize
        type: 'VirtualMachineScaleSets'
        availabilityZones: nodeZones
        vnetSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, format(nodeSubnetFormat, workloadNodePool.name))
        podSubnetID: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, format(podSubnetFormat, workloadNodePool.name))
        nodeTaints: contains(workloadNodePool, 'taints') ? workloadNodePool.taints : []
      }
    ]
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
}

output kubletIdentity string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output aksCluserName string = aksCluster.name
