param location string
param vnetName string
param vnetaddressPrefix string
param nodeSubnetPrefix string
param nodeSubnetName string = 'node-subnet'
param clusterName string
param clusterDnsPrefix string
param nodeCount int
param nodeSize string
param podCidr string
param logAnalyticsWorkspaceResourceID string
param tags object

var nodeZones = pickZones('Microsoft.Compute', 'virtualMachines', location, 3)

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ vnetaddressPrefix ]
    }
    subnets: [{
        name: nodeSubnetName
        properties: {
          addressPrefix: nodeSubnetPrefix
        }
    }]
  }
  resource nodeSubnet 'subnets@2022-09-01' existing = {
    name: nodeSubnetName
  }
}

resource cluster 'Microsoft.ContainerService/managedClusters@2022-11-02-preview' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  properties: {
    dnsPrefix: clusterDnsPrefix
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      networkPluginMode: 'Overlay'
      podCidr: podCidr
    }
    agentPoolProfiles: [
      {
        name: 'primary'
        mode: 'System'
        osType: 'Linux'
        count: nodeCount
        vmSize: nodeSize
        type: 'VirtualMachineScaleSets'
        availabilityZones: nodeZones
        vnetSubnetID: vnet::nodeSubnet.id
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

output vnetName string = vnet.name
output vnetId string = vnet.id
output clusterName string = cluster.name
output kubeletIdentityObjectId string = cluster.properties.identityProfile.kubeletidentity.objectId
