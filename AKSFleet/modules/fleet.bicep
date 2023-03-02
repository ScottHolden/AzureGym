param location string
param fleetName string
param fleetDnsPrefix string
param memberClusters array
param tags object

resource fleet 'Microsoft.ContainerService/fleets@2022-09-02-preview' = {
  name: fleetName
  location: location
  properties: {
    hubProfile: {
      dnsPrefix: fleetDnsPrefix
    }
  }
  tags: tags
}

resource fleetMembers 'Microsoft.ContainerService/fleets/members@2022-09-02-preview' = [for cluster in memberClusters: {
  parent: fleet
  name: cluster.name
  properties: {
    clusterResourceId: cluster.id
  }
}]
