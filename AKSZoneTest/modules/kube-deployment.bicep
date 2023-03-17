param aksCluserName string
param containerImage string
param replicas int

resource aksClusterRef 'Microsoft.ContainerService/managedClusters@2022-07-02-preview' existing = {
  name: aksCluserName
}

import 'kubernetes@1.0.0' with {
  namespace: namespace.metadata.name
  kubeConfig: aksClusterRef.listClusterAdminCredential().kubeconfigs[0].value
}

resource namespace 'core/Namespace@v1' = {
  metadata: {
    name: 'zonetest'
  }
}

resource zonetestDeployment 'apps/Deployment@v1' = {
  metadata: {
    name: 'zone-test-fwd-0'
  }
  spec: {
    replicas: replicas
    selector: {
      matchLabels: {
        app: 'zone-test-fwd-0'
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'zone-test-fwd-0'
        }
      }
      spec: {
        nodeSelector: {
          'beta.kubernetes.io/os': 'linux'
        }
        containers: [
          {
            name: 'zone-test-fwd-0'
            image: containerImage
            ports: [
              {
                containerPort: 80
              }
            ]
            resources: {
              requests: {
                cpu: '250m'
              }
              limits: {
                cpu: '500m'
              }
            }
            env: [
              {
                name: 'pod_name'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.name'
                  }
                }
              }
              {
                name: 'k8s_region'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.labels[\'topology.kubernetes.io/region\']'
                  }
                }
              }
              {
                name: 'k8s_zone'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.labels[\'topology.kubernetes.io/zone\']'
                  }
                }
              }
              {
                name: 'k8s_agentpool'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.labels[\'kubernetes.azure.com/agentpool\']'
                  }
                }
              }
              {
                name: 'k8s_hostname'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.labels[\'kubernetes.io/hostname\']'
                  }
                }
              }
            ]
          }
        ]
      }
    }
  }
}

resource zonetestService 'core/Service@v1' = {
  metadata: {
    name: 'zone-test-fwd-0'
  }
  spec: {
    type: 'LoadBalancer'
    ports: [
      {
        port: 80
      }
    ]
    selector: {
      app: 'zone-test-fwd-0'
    }
  }
}
