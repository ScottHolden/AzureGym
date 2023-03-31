param aksCluserName string
param containerImage string
param replicas int
param namespaceName string
param workloadName string

resource aksClusterRef 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' existing = {
  name: aksCluserName
}

module kubeApply 'kube-deployment.bicep' = {
  name: '${deployment().name}-deploy'
  params: {
    containerImage: containerImage
    kubeConfig: aksClusterRef.listClusterAdminCredential().kubeconfigs[0].value
    replicas: replicas
    namespaceName: namespaceName
    workloadName: workloadName
  }
}
