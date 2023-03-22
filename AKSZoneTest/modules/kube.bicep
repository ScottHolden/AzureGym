param aksCluserName string
param containerImage string
param replicas int
param hops int = 4
param deployStandard bool
param deployTopologyAware bool

resource aksClusterRef 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' existing = {
  name: aksCluserName
}

module kubeApplyStandard 'kube-deployment.bicep' = if (deployStandard) {
  name: '${deployment().name}-apply-std'
  params: {
    containerImage: containerImage
    kubeConfig: aksClusterRef.listClusterAdminCredential().kubeconfigs[0].value
    replicas: replicas
    hops: hops
    topologyAware: false
    namespaceName: 'zone-test-standard'
    prefix: 'zt-std'
  }
}

module kubeApply 'kube-deployment.bicep' = if (deployTopologyAware) {
  name: '${deployment().name}-apply-tpa'
  params: {
    containerImage: containerImage
    kubeConfig: aksClusterRef.listClusterAdminCredential().kubeconfigs[0].value
    replicas: replicas
    hops: hops
    topologyAware: true
    namespaceName: 'zone-test-topologyaware'
    prefix: 'zt-tpa'
  }
}
