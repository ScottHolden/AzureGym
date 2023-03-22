@secure()
param kubeConfig string
param containerImage string
param replicas int
param hops int
param topologyAware bool = false
param namespaceName string
param prefix string


import 'kubernetes@1.0.0' with {
  namespace: namespaceName
  kubeConfig: kubeConfig
}

var topologyAwareAnnotations = {
  'service.kubernetes.io/topology-aware-hints' : 'auto'
}

resource namespace 'core/Namespace@v1' = {
  metadata: {
    name: namespaceName
  }
}

resource zonetestDeployment 'apps/Deployment@v1' = [for index in range(0, hops): {
  dependsOn: [ namespace ]
  metadata: {
    name: '${prefix}-fwd-${index}'
  }
  spec: {
    replicas: replicas
    selector: {
      matchLabels: {
        app: '${prefix}-fwd-${index}'
      }
    }
    template: {
      metadata: {
        labels: {
          app: '${prefix}-fwd-${index}'
        }
      }
      spec: {
        nodeSelector: {
          'beta.kubernetes.io/os': 'linux'
        }
        containers: [
          {
            name: '${prefix}-fwd'
            image: containerImage
            ports: [
              {
                containerPort: 80
              }
            ]
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
                name: 'k8s_hostname'
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'spec.nodeName'
                  }
                }
              }
              {
                name: 'next_hop'
                value: index < hops - 1 ? 'http://${prefix}-fwd-${index + 1}/' : ''
              }
            ]
          }
        ]
      }
    }
  }
}]

resource zonetestService 'core/Service@v1' = [for index in range(0, hops): {
  dependsOn: [ namespace ]
  metadata: {
    name: '${prefix}-fwd-${index}'
    annotations: topologyAware ? topologyAwareAnnotations : null
  }
  spec: {
    type: index == 0 ? 'LoadBalancer' : null
    ports: [
      {
        port: 80
      }
    ]
    selector: {
      app: '${prefix}-fwd-${index}'
    }
  }
}]
