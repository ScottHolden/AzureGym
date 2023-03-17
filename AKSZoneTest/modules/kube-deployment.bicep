@secure()
param kubeConfig string
param containerImage string
param replicas int
param hops int

var namespaceName = 'zonetest'

import 'kubernetes@1.0.0' with {
  namespace: namespaceName
  kubeConfig: kubeConfig
}

resource namespace 'core/Namespace@v1' = {
  metadata: {
    name: namespaceName
  }
}

resource zonetestDeployment 'apps/Deployment@v1' = [for index in range(0, hops): {
  dependsOn: [ namespace ]
  metadata: {
    name: 'zone-test-fwd-${index}'
  }
  spec: {
    replicas: replicas
    selector: {
      matchLabels: {
        app: 'zone-test-fwd-${index}'
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'zone-test-fwd-${index}'
        }
      }
      spec: {
        nodeSelector: {
          'beta.kubernetes.io/os': 'linux'
        }
        containers: [
          {
            name: 'zone-test-fwd'
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
                value: index < hops - 1 ? 'http://zone-test-fwd-${index + 1}/' : ''
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
    name: 'zone-test-fwd-${index}'
  }
  spec: {
    type: index == 0 ? 'LoadBalancer' : null
    ports: [
      {
        port: 80
      }
    ]
    selector: {
      app: 'zone-test-fwd-${index}'
    }
  }
}]
