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

// A bit of overkill but fine for demo, AKS needs permission to join LB to Subnet
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
}

resource containerPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(vnet::nodeSubnet.id, cluster.id, contributorRoleDefinition.id)
  scope: vnet::nodeSubnet
  properties: {
    principalId: cluster.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output clusterName string = cluster.name
output kubeletIdentityObjectId string = cluster.properties.identityProfile.kubeletidentity.objectId
